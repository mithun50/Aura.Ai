import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aura_mobile/data/datasources/database_helper.dart';
import 'package:aura_mobile/data/repositories/memory_repository_impl.dart';
import 'package:aura_mobile/domain/repositories/memory_repository.dart';

// Database Provider
final databaseHelperProvider = Provider((ref) => DatabaseHelper());

// Repository Providers
final memoryRepositoryProvider = Provider<MemoryRepository>((ref) {
  return MemoryRepositoryImpl(ref.watch(databaseHelperProvider));
});
