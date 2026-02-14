import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final embeddingServiceProvider = Provider((ref) => EmbeddingService());

/// Lightweight offline embedding service using TF-IDF bag-of-words.
/// Generates fixed-dimension vectors for text similarity without ML models.
class EmbeddingService {
  static const int _vectorDimension = 512;
  static const Set<String> _stopWords = {
    'a', 'an', 'the', 'is', 'are', 'was', 'were', 'be', 'been', 'being',
    'have', 'has', 'had', 'do', 'does', 'did', 'will', 'would', 'could',
    'should', 'may', 'might', 'shall', 'can', 'need', 'dare', 'ought',
    'used', 'to', 'of', 'in', 'for', 'on', 'with', 'at', 'by', 'from',
    'as', 'into', 'through', 'during', 'before', 'after', 'above', 'below',
    'between', 'out', 'off', 'over', 'under', 'again', 'further', 'then',
    'once', 'here', 'there', 'when', 'where', 'why', 'how', 'all', 'each',
    'every', 'both', 'few', 'more', 'most', 'other', 'some', 'such', 'no',
    'nor', 'not', 'only', 'own', 'same', 'so', 'than', 'too', 'very',
    'just', 'because', 'but', 'and', 'or', 'if', 'while', 'that', 'this',
    'these', 'those', 'i', 'me', 'my', 'we', 'our', 'you', 'your', 'he',
    'him', 'his', 'she', 'her', 'it', 'its', 'they', 'them', 'their',
    'what', 'which', 'who', 'whom',
  };

  /// Generate a deterministic embedding vector for the given text.
  /// Uses hashed n-grams projected into a fixed-size vector space.
  List<double> generateEmbedding(String text) {
    final tokens = _tokenize(text);
    if (tokens.isEmpty) return List.filled(_vectorDimension, 0.0);

    final vector = List<double>.filled(_vectorDimension, 0.0);

    // Unigrams
    for (final token in tokens) {
      final hash = _hashToken(token);
      final index = hash % _vectorDimension;
      final sign = (hash ~/ _vectorDimension) % 2 == 0 ? 1.0 : -1.0;
      vector[index] += sign;
    }

    // Bigrams for capturing word order context
    for (int i = 0; i < tokens.length - 1; i++) {
      final bigram = '${tokens[i]}_${tokens[i + 1]}';
      final hash = _hashToken(bigram);
      final index = hash % _vectorDimension;
      final sign = (hash ~/ _vectorDimension) % 2 == 0 ? 1.0 : -1.0;
      vector[index] += sign * 0.5; // Bigrams get lower weight
    }

    // Trigrams for even more context
    for (int i = 0; i < tokens.length - 2; i++) {
      final trigram = '${tokens[i]}_${tokens[i + 1]}_${tokens[i + 2]}';
      final hash = _hashToken(trigram);
      final index = hash % _vectorDimension;
      final sign = (hash ~/ _vectorDimension) % 2 == 0 ? 1.0 : -1.0;
      vector[index] += sign * 0.25;
    }

    // L2 normalize
    return _normalize(vector);
  }

  /// Compute cosine similarity between two embeddings
  double cosineSimilarity(List<double> a, List<double> b) {
    if (a.isEmpty || b.isEmpty) return 0.0;
    if (a.length != b.length) return 0.0;

    double dot = 0.0;
    double normA = 0.0;
    double normB = 0.0;

    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }

    if (normA == 0 || normB == 0) return 0.0;
    return dot / (sqrt(normA) * sqrt(normB));
  }

  /// Keyword-based similarity fallback when cosine similarity is below threshold
  double keywordSimilarity(String queryText, String documentText) {
    final queryTokens = _tokenize(queryText).toSet();
    final docTokens = _tokenize(documentText).toSet();
    if (queryTokens.isEmpty || docTokens.isEmpty) return 0.0;

    final intersection = queryTokens.intersection(docTokens).length;
    final union = queryTokens.union(docTokens).length;
    return union > 0 ? intersection / union : 0.0;
  }

  List<String> _tokenize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((t) => t.length > 1 && !_stopWords.contains(t))
        .toList();
  }

  /// FNV-1a hash for deterministic token hashing
  int _hashToken(String token) {
    int hash = 0x811c9dc5;
    for (int i = 0; i < token.length; i++) {
      hash ^= token.codeUnitAt(i);
      hash = (hash * 0x01000193) & 0x7FFFFFFF;
    }
    return hash;
  }

  List<double> _normalize(List<double> vector) {
    double norm = 0.0;
    for (final v in vector) {
      norm += v * v;
    }
    if (norm == 0) return vector;
    norm = sqrt(norm);
    return vector.map((v) => v / norm).toList();
  }
}
