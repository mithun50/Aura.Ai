
import 'dart:convert';
import 'package:aura_mobile/data/datasources/database_helper.dart';
import 'package:aura_mobile/domain/entities/document.dart';
import 'package:aura_mobile/domain/repositories/document_repository.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final documentRepositoryProvider = Provider<DocumentRepository>((ref) {
  return DocumentRepositoryImpl(DatabaseHelper()); // Singleton DB helper
});

class DocumentRepositoryImpl implements DocumentRepository {
  final DatabaseHelper _databaseHelper;

  DocumentRepositoryImpl(this._databaseHelper);

  @override
  Future<void> saveDocument(Document document) async {
    final db = await _databaseHelper.database;
    await db.insert(
      'documents',
      {
        'id': document.id,
        'filename': document.filename,
        'path': document.path,
        'uploadDate': document.uploadDate.millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> saveChunks(List<DocumentChunk> chunks) async {
    final db = await _databaseHelper.database;
    final batch = db.batch();
    
    for (var chunk in chunks) {
      batch.insert(
        'document_chunks',
        {
          'id': chunk.id,
          'documentId': chunk.documentId,
          'content': chunk.content,
          'chunkIndex': chunk.chunkIndex,
          'embedding': chunk.embedding != null ? jsonEncode(chunk.embedding) : null,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    
    await batch.commit(noResult: true);
  }

  @override
  Future<List<Document>> getAllDocuments() async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('documents');
    return List.generate(maps.length, (i) {
      return Document(
        id: maps[i]['id'],
        filename: maps[i]['filename'],
        path: maps[i]['path'],
        uploadDate: DateTime.fromMillisecondsSinceEpoch(maps[i]['uploadDate']),
      );
    });
  }

  @override
  Future<List<DocumentChunk>> getAllChunks() async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('document_chunks');
    return List.generate(maps.length, (i) {
      return DocumentChunk(
        id: maps[i]['id'],
        documentId: maps[i]['documentId'],
        content: maps[i]['content'],
        chunkIndex: maps[i]['chunkIndex'],
        embedding: maps[i]['embedding'] != null
            ? (jsonDecode(maps[i]['embedding']) as List).cast<double>()
            : null,
      );
    });
  }

  @override
  Future<void> deleteDocument(String id) async {
    final db = await _databaseHelper.database;
    // Transaction to delete doc and its chunks
    await db.transaction((txn) async {
      await txn.delete('document_chunks', where: 'documentId = ?', whereArgs: [id]);
      await txn.delete('documents', where: 'id = ?', whereArgs: [id]);
    });
  }
}
