import 'dart:math';

/// Legacy vector store service.
/// New code should use EmbeddingService.cosineSimilarity() directly.
class VectorStoreService {
  double cosineSimilarity(List<double> vectorA, List<double> vectorB) {
    if (vectorA.isEmpty || vectorB.isEmpty) return 0.0;
    if (vectorA.length != vectorB.length) return 0.0;

    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;

    for (int i = 0; i < vectorA.length; i++) {
      dotProduct += vectorA[i] * vectorB[i];
      normA += vectorA[i] * vectorA[i];
      normB += vectorB[i] * vectorB[i];
    }

    if (normA == 0 || normB == 0) return 0.0;

    return dotProduct / (sqrt(normA) * sqrt(normB));
  }
}
