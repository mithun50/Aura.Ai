import 'dart:io';
import 'package:aura_mobile/domain/entities/document.dart';
import 'package:aura_mobile/domain/repositories/document_repository.dart';
import 'package:aura_mobile/domain/services/embedding_service.dart';
import 'package:aura_mobile/domain/services/document_parser.dart';
import 'package:aura_mobile/core/services/permission_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as p;
import 'package:aura_mobile/data/repositories/document_repository_impl.dart';
import 'package:flutter/foundation.dart';

final permissionServiceProvider = Provider((ref) => PermissionService());

final documentServiceProvider = Provider((ref) => DocumentService(
      ref.read(documentRepositoryProvider),
      ref.read(embeddingServiceProvider),
      ref.read(permissionServiceProvider),
    ));

class DocumentService {
  final DocumentRepository _repository;
  final EmbeddingService _embeddingService;
  final PermissionService _permissionService;

  DocumentService(this._repository, this._embeddingService, this._permissionService);

  /// Check if any documents have been uploaded
  Future<bool> hasDocuments() async {
    try {
      final docs = await _repository.getAllDocuments();
      return docs.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<String?> pickAndProcessDocument() async {
    // Request storage permission before picking files
    final hasPermission = await _permissionService.requestStoragePermission();
    if (!hasPermission) {
      throw Exception('Storage permission is required to upload documents.');
    }

    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: DocumentParserFactory.supportedExtensions,
    );

    if (result != null) {
      final filePath = result.files.single.path;
      if (filePath == null) {
        throw Exception('Could not access the selected file. Please try again.');
      }
      File file = File(filePath);
      await processDocument(file);
      return result.files.single.name;
    }
    return null;
  }

  Future<void> processDocument(File file) async {
    final extension = p.extension(file.path).replaceFirst('.', '');
    final parser = DocumentParserFactory.getParser(extension);
    if (parser == null) {
      throw Exception('Unsupported file type: .$extension');
    }

    String text = '';
    try {
      text = await parser.parse(file);
    } catch (e) {
      if (kDebugMode) debugPrint('Error reading document: $e');
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
    final allDocs = await _repository.getAllDocuments();

    // Build doc name lookup
    final docNames = <String, String>{};
    for (final doc in allDocs) {
      docNames[doc.id] = doc.filename;
    }

    final scoredChunks = allChunks.map((chunk) {
      double score = -1.0;
      if (chunk.embedding != null && chunk.embedding!.isNotEmpty) {
        try {
          score = _embeddingService.cosineSimilarity(queryEmbedding, chunk.embedding!);
          // Keyword fallback when cosine is below threshold
          if (score < 0.2) {
            final keywordScore = _embeddingService.keywordSimilarity(query, chunk.content);
            score = score > keywordScore ? score : keywordScore;
          }
        } catch (e) {
          score = -1.0;
        }
      }
      return MapEntry(chunk, score);
    }).toList();

    scoredChunks.sort((a, b) => b.value.compareTo(a.value));

    return scoredChunks
        .take(limit)
        .where((entry) => entry.value > 0.1)
        .map((entry) {
          final docName = docNames[entry.key.documentId] ?? 'Unknown';
          return '[Source: $docName, chunk ${entry.key.chunkIndex + 1}]\n${entry.key.content}';
        })
        .toList();
  }
}
