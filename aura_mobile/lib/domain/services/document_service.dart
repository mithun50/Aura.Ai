import 'dart:io';
import 'package:aura_mobile/domain/entities/document.dart';
import 'package:aura_mobile/domain/repositories/document_repository.dart';
import 'package:aura_mobile/domain/services/embedding_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:read_pdf_text/read_pdf_text.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as p;
import 'package:aura_mobile/data/repositories/document_repository_impl.dart';
import 'package:flutter/foundation.dart';

final documentServiceProvider = Provider((ref) => DocumentService(
      ref.read(documentRepositoryProvider),
      ref.read(embeddingServiceProvider),
    ));

class DocumentService {
  final DocumentRepository _repository;
  final EmbeddingService _embeddingService;

  DocumentService(this._repository, this._embeddingService);

  Future<void> pickAndProcessDocument() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null) {
      File file = File(result.files.single.path!);
      await processDocument(file);
    }
  }

  Future<void> processDocument(File file) async {
    String text = '';
    try {
      text = await ReadPdfText.getPDFtext(file.path);
    } catch (e) {
      if (kDebugMode) debugPrint('Error reading PDF: $e');
      return;
    }

    if (text.isEmpty) return;

    final docId = const Uuid().v4();
    final document = Document(
      id: docId,
      filename: p.basename(file.path),
      path: file.path,
      uploadDate: DateTime.now(),
    );

    // 1. Save Document Metadata
    await _repository.saveDocument(document);

    // 2. Chunk Text with overlap for better retrieval
    final chunks = _chunkText(text, 500, 100);

    // 3. Generate Embeddings & Save Chunks
    List<DocumentChunk> docChunks = [];
    for (int i = 0; i < chunks.length; i++) {
      final chunkContent = chunks[i];
      try {
        final embedding = _embeddingService.generateEmbedding(chunkContent);
        docChunks.add(DocumentChunk(
          id: const Uuid().v4(),
          documentId: docId,
          content: chunkContent,
          chunkIndex: i,
          embedding: embedding,
        ));
      } catch (e) {
        if (kDebugMode) debugPrint('Error embedding chunk $i: $e');
      }
    }

    await _repository.saveChunks(docChunks);
  }

  /// Chunk text with overlap for better context preservation
  List<String> _chunkText(String text, int chunkSize, int overlap) {
    List<String> chunks = [];
    final cleanText = text.replaceAll(RegExp(r'\s+'), ' ').trim();

    int start = 0;
    while (start < cleanText.length) {
      int end = start + chunkSize;
      if (end > cleanText.length) end = cleanText.length;

      // Try to break at sentence boundary
      if (end < cleanText.length) {
        final lastPeriod = cleanText.lastIndexOf('. ', end);
        if (lastPeriod > start + (chunkSize ~/ 2)) {
          end = lastPeriod + 1;
        }
      }

      chunks.add(cleanText.substring(start, end).trim());
      start = end - overlap;
      if (start < 0) start = 0;
      if (start >= cleanText.length) break;
    }
    return chunks;
  }

  Future<List<String>> retrieveRelevantContext(String query,
      {int limit = 3}) async {
    final queryEmbedding = _embeddingService.generateEmbedding(query);
    final allChunks = await _repository.getAllChunks();

    final scoredChunks = allChunks.map((chunk) {
      if (chunk.embedding == null || chunk.embedding!.isEmpty) {
        return MapEntry(chunk, -1.0);
      }
      try {
        final score =
            _embeddingService.cosineSimilarity(queryEmbedding, chunk.embedding!);
        return MapEntry(chunk, score);
      } catch (e) {
        return MapEntry(chunk, -1.0);
      }
    }).toList();

    scoredChunks.sort((a, b) => b.value.compareTo(a.value));

    return scoredChunks
        .take(limit)
        .where((entry) => entry.value > 0.15) // Lower threshold for TF-IDF
        .map((entry) => entry.key.content)
        .toList();
  }
}
