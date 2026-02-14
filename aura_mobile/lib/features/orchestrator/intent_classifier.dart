class IntentClassifier {
  Future<String> classify(String input, {bool hasDocuments = false}) async {
    final lowerInput = input.toLowerCase().trim();

    // 1. Memory Store
    if (lowerInput.startsWith('remember that') ||
        lowerInput.startsWith('save this') ||
        lowerInput.startsWith('note that') ||
        lowerInput.startsWith('remember:') ||
        lowerInput.startsWith('memo:') ||
        lowerInput.startsWith('save:')) {
      return 'memory_store';
    }

    // 2. Memory Retrieval
    if (lowerInput.contains('when did i') ||
        lowerInput.contains('what did i say') ||
        lowerInput.contains('what did i save') ||
        lowerInput.contains('do you remember') ||
        lowerInput.contains('remind me') ||
        lowerInput.contains('what do you know about me') ||
        lowerInput.contains('my notes') ||
        lowerInput.contains('my memories') ||
        lowerInput.contains('retrieve') ||
        lowerInput.contains('recall')) {
      return 'memory_retrieve';
    }

    // 3. Web Search
    if (lowerInput.startsWith('search ') ||
        lowerInput.startsWith('search:') ||
        lowerInput.startsWith('google ') ||
        lowerInput.startsWith('look up ') ||
        lowerInput.startsWith('find online ') ||
        lowerInput.contains('search the web') ||
        lowerInput.contains('search online') ||
        lowerInput.contains('latest news') ||
        lowerInput.contains('current weather') ||
        lowerInput.contains('what is happening')) {
      return 'web_search';
    }

    // 4. SMS Query
    if (lowerInput.contains('my messages') ||
        lowerInput.contains('sms from') ||
        lowerInput.contains('text from') ||
        (lowerInput.contains('what did') && lowerInput.contains('text me')) ||
        lowerInput.contains('read my sms') ||
        lowerInput.contains('read my texts') ||
        lowerInput.contains('show my messages') ||
        lowerInput.contains('recent texts') ||
        lowerInput.contains('recent sms')) {
      return 'sms_query';
    }

    // 5. Document Query
    if (hasDocuments &&
        (lowerInput.contains('in the document') ||
            lowerInput.contains('in the pdf') ||
            lowerInput.contains('from the file') ||
            lowerInput.contains('summarize the') ||
            lowerInput.contains('according to') ||
            lowerInput.contains('document') ||
            lowerInput.contains('pdf'))) {
      return 'document_query';
    }

    // 6. File Action
    if (lowerInput.contains('read file') ||
        lowerInput.contains('summarize file')) {
      return 'file_action';
    }

    return 'normal_chat';
  }
}
