import 'package:aura_mobile/features/agents/domain/agent.dart';
import 'package:aura_mobile/domain/services/document_service.dart';

class RAGAgent implements Agent {
  final DocumentService _documentService;

  RAGAgent(this._documentService);

  @override
  String get name => 'RAGAgent';

  @override
  Future<bool> canHandle(String intent) async {
    return intent == 'document_query';
  }

  @override
  Stream<String> process(String input, {Map<String, dynamic>? context}) async* {
    yield 'Searching your documents...';

    final results = await _documentService.retrieveRelevantContext(input);
    if (results.isEmpty) {
      yield '\n\nNo relevant information found in your documents.';
    } else {
      yield '\n\nRelevant excerpts:\n';
      for (int i = 0; i < results.length; i++) {
        yield '\n[${i + 1}] ${results[i]}\n';
      }
    }
  }
}
