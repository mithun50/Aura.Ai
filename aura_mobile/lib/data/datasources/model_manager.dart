import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:aura_mobile/domain/entities/model_info.dart';

class ModelManager {
  /// Get list of all downloaded models
  Future<List<String>> getDownloadedModels() async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final modelFiles = await Directory(docsDir.path)
          .list()
          .where((entity) => entity is File && entity.path.endsWith('.gguf'))
          .map((entity) => entity.path.split('/').last.split('\\\\').last)
          .toList();
      
      return modelFiles;
    } catch (e) {
      debugPrint('Error getting downloaded models: $e');
      return [];
    }
  }

  /// Check if a specific model is downloaded and intact
  Future<bool> isModelDownloaded(String modelId) async {
    final model = getModelById(modelId);
    if (model == null) return false;

    final docsDir = await getApplicationDocumentsDirectory();
    final modelPath = '${docsDir.path}/${model.fileName}';
    final file = File(modelPath);

    if (!await file.exists()) {
      return false;
    }

    final fileSize = await file.length();
    if (fileSize < (model.sizeBytes * 0.99)) {
       debugPrint('Model ${model.id} corrupted: Expected ${model.sizeBytes}, got $fileSize');
       return false;
    }

    return true;
  }

  /// Verify model integrity and delete if corrupt
  Future<bool> verifyAndCleanupModel(String modelId) async {
     final model = getModelById(modelId);
     if (model == null) return false;

     final docsDir = await getApplicationDocumentsDirectory();
     final modelPath = '${docsDir.path}/${model.fileName}';
     final file = File(modelPath);

     if (await file.exists()) {
        final fileSize = await file.length();
        if (fileSize < (model.sizeBytes * 0.99)) {
            debugPrint('Deleting corrupt model: ${model.id}');
            await file.delete();
            return false;
        }
        return true;
     }
     return false;
  }

  /// Get model file path
  Future<String> getModelPath(String modelId) async {
    final model = getModelById(modelId);
    if (model == null) {
      throw Exception('Model not found: $modelId');
    }
    final docsDir = await getApplicationDocumentsDirectory();
    return '${docsDir.path}/${model.fileName}';
  }

  /// Delete a model
  Future<void> deleteModel(String modelId) async {
    try {
      final modelPath = await getModelPath(modelId);
      final file = File(modelPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Error deleting model: $e');
      rethrow;
    }
  }

  /// Get model file size
  Future<int> getModelSize(String modelId) async {
    try {
      final modelPath = await getModelPath(modelId);
      final file = File(modelPath);
      if (await file.exists()) {
        return await file.length();
      }
      return 0;
    } catch (e) {
      debugPrint('Error getting model size: $e');
      return 0;
    }
  }

  /// Get total storage used by all models
  Future<int> getTotalStorageUsed() async {
    int total = 0;
    for (final model in modelCatalog) {
      if (await isModelDownloaded(model.id)) {
        total += await getModelSize(model.id);
      }
    }
    return total;
  }

  /// Get ModelInfo by ID
  ModelInfo? getModelById(String modelId) {
    try {
      return modelCatalog.firstWhere((m) => m.id == modelId);
    } catch (e) {
      return null;
    }
  }
}
