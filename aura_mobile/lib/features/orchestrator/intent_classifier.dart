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

    // 2. Memory Retrieval — checked before web_search so "search my notes" routes here
    if (lowerInput.contains('when did i') ||
        lowerInput.contains('what did i say') ||
        lowerInput.contains('what did i save') ||
        lowerInput.contains('do you remember') ||
        lowerInput.contains('remind me') ||
        lowerInput.contains('what do you know about me') ||
        lowerInput.contains('my notes') ||
        lowerInput.contains('my memories') ||
        lowerInput.contains('retrieve') ||
        lowerInput.contains('recall') ||
        lowerInput.contains('search my notes') ||
        lowerInput.contains('search my memories') ||
        lowerInput.contains('find my notes') ||
        lowerInput.contains('find in my notes') ||
        lowerInput.contains('look up my notes')) {
      return 'memory_retrieve';
    }

    // 3. SMS Query — checked before web_search so "search my messages" routes here
    if (lowerInput.contains('my messages') ||
        lowerInput.contains('sms from') ||
        lowerInput.contains('text from') ||
        (lowerInput.contains('what did') && lowerInput.contains('text me')) ||
        lowerInput.contains('read my sms') ||
        lowerInput.contains('read my texts') ||
        lowerInput.contains('show my messages') ||
        lowerInput.contains('recent texts') ||
        lowerInput.contains('recent sms') ||
        lowerInput.contains('search my messages') ||
        lowerInput.contains('messages from')) {
      return 'sms_query';
    }

    // 4. Web Search
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

    // 5. Document Query — also handles file_action (read/summarize file)
    if (hasDocuments &&
        (lowerInput.contains('in the document') ||
            lowerInput.contains('in the pdf') ||
            lowerInput.contains('from the file') ||
            lowerInput.contains('summarize the') ||
            lowerInput.contains('according to') ||
            lowerInput.contains('document') ||
            lowerInput.contains('pdf') ||
            lowerInput.contains('read file') ||
            lowerInput.contains('summarize file') ||
            lowerInput.contains('uploaded file') ||
            lowerInput.contains('my file'))) {
      return 'document_query';
    }

    return 'normal_chat';
  }
}
