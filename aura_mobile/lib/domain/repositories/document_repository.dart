
import 'package:aura_mobile/domain/entities/document.dart';

abstract class DocumentRepository {
  Future<void> saveDocument(Document document);
  Future<List<Document>> getAllDocuments();
  Future<void> saveChunks(List<DocumentChunk> chunks);
  Future<List<DocumentChunk>> getAllChunks();
  Future<void> deleteDocument(String id);
}
