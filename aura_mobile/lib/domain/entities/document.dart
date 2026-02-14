
import 'package:equatable/equatable.dart';

class DocumentChunk extends Equatable {
  final String id;
  final String documentId;
  final String content;
  final int chunkIndex;
  final List<double>? embedding;

  const DocumentChunk({
    required this.id,
    required this.documentId,
    required this.content,
    required this.chunkIndex,
    this.embedding,
  });

  @override
  List<Object?> get props => [id, documentId, content, chunkIndex, embedding];
}

class Document extends Equatable {
  final String id;
  final String filename;
  final String path;
  final DateTime uploadDate;
  final List<DocumentChunk> chunks;

  const Document({
    required this.id,
    required this.filename,
    required this.path,
    required this.uploadDate,
    this.chunks = const [],
  });

  @override
  List<Object?> get props => [id, filename, path, uploadDate, chunks];
}
