abstract class Agent {
  String get name;
  Future<bool> canHandle(String intent);
  Stream<String> process(
    String input, {
    Map<String, dynamic>? context,
    List<String> chatHistory,
  });
}
