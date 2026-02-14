class IntentClassifier {
  Future<String> classify(String input) async {
    final lowerInput = input.toLowerCase();

    if (lowerInput.contains('remember that') ||
        lowerInput.contains('save this')) {
      return 'memory_store';
    }
    if (lowerInput.contains('what did i') ||
        lowerInput.contains('retrieve') ||
        lowerInput.contains('recall')) {
      return 'memory_retrieve';
    }
    if (lowerInput.startsWith('search ') ||
        lowerInput.contains('search the web') ||
        lowerInput.contains('latest news')) {
      return 'web_search';
    }
    if (lowerInput.contains('read file') ||
        lowerInput.contains('summarize file')) {
      return 'file_action';
    }
    if (lowerInput.contains('document') || lowerInput.contains('pdf')) {
      return 'document_query';
    }

    return 'normal_chat';
  }
}
