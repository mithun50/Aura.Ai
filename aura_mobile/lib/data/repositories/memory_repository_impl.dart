import 'package:aura_mobile/data/datasources/database_helper.dart';
import 'package:aura_mobile/data/models/memory_model.dart';
import 'package:aura_mobile/domain/entities/memory.dart';
import 'package:aura_mobile/domain/repositories/memory_repository.dart';
import 'package:sqflite/sqflite.dart';

class MemoryRepositoryImpl implements MemoryRepository {
  final DatabaseHelper _databaseHelper;

  MemoryRepositoryImpl(this._databaseHelper);

  @override
  Future<void> saveMemory(Memory memory) async {
    final db = await _databaseHelper.database;
    final model = MemoryModel.fromEntity(memory);
    await db.insert(
      'memories',
      model.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<List<Memory>> getMemories() async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('memories');
    return List.generate(maps.length, (i) => MemoryModel.fromJson(maps[i]));
  }

  @override
  Future<List<Memory>> searchMemories(String query) async {
    // Basic text search for now. Vector search to be implemented.
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'memories',
      where: 'content LIKE ?',
      whereArgs: ['%\$query%'],
    );
    return List.generate(maps.length, (i) => MemoryModel.fromJson(maps[i]));
  }

  @override
  Future<void> deleteMemory(String id) async {
    final db = await _databaseHelper.database;
    await db.delete(
      'memories',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
