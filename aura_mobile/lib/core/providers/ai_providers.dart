import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aura_mobile/ai/run_anywhere_service.dart';
import 'package:aura_mobile/data/datasources/llm_service.dart';

// Core AI Services
final runAnywhereProvider = Provider((ref) => RunAnywhere());
final llmServiceProvider = Provider((ref) => LLMServiceImpl(ref.watch(runAnywhereProvider)));
