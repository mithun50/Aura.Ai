import 'package:dio/dio.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final webSearchServiceProvider = Provider((ref) => WebSearchService());

class SearchResult {
  final String title;
  final String snippet;
  final String url;

  SearchResult({
    required this.title,
    required this.snippet,
    required this.url,
  });

  @override
  String toString() => '$title: $snippet ($url)';
}

/// DuckDuckGo web search service for online queries.
/// Uses DuckDuckGo HTML lite endpoint (no API key needed).
class WebSearchService {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {
      'User-Agent':
          'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
    },
  ));

  /// Check if device has internet connectivity
  Future<bool> isOnline() async {
    try {
      final result = await Connectivity().checkConnectivity();
      return !result.contains(ConnectivityResult.none);
    } catch (_) {
      return false;
    }
  }

  /// Search DuckDuckGo and return parsed results
  Future<List<SearchResult>> search(String query, {int maxResults = 5}) async {
    if (!await isOnline()) return [];

    try {
      final response = await _dio.get(
        'https://html.duckduckgo.com/html/',
        queryParameters: {'q': query},
        options: Options(
          responseType: ResponseType.plain,
          followRedirects: true,
        ),
      );

      if (response.statusCode == 200) {
        return _parseHtmlResults(response.data as String, maxResults);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('WebSearch error: $e');
    }
    return [];
  }

  /// Parse DuckDuckGo HTML response into structured results
  List<SearchResult> _parseHtmlResults(String html, int maxResults) {
    final results = <SearchResult>[];

    // Extract result blocks: <a class="result__a" href="...">title</a>
    // and <a class="result__snippet">snippet</a>
    final resultBlockRegex = RegExp(
      r'class="result__a"[^>]*href="([^"]*)"[^>]*>(.*?)</a>.*?class="result__snippet"[^>]*>(.*?)</a>',
      dotAll: true,
    );

    for (final match in resultBlockRegex.allMatches(html)) {
      if (results.length >= maxResults) break;

      String url = match.group(1) ?? '';
      String title = _stripHtml(match.group(2) ?? '');
      String snippet = _stripHtml(match.group(3) ?? '');

      // DuckDuckGo wraps URLs in a redirect — extract actual URL
      final udParam = RegExp(r'uddg=([^&]+)').firstMatch(url);
      if (udParam != null) {
        url = Uri.decodeComponent(udParam.group(1)!);
      }

      if (title.isNotEmpty && snippet.isNotEmpty) {
        results.add(SearchResult(
          title: title.trim(),
          snippet: snippet.trim(),
          url: url.trim(),
        ));
      }
    }

    // Fallback: simpler parsing if regex didn't match
    if (results.isEmpty) {
      final simpleLinkRegex = RegExp(
        r'class="result__a"[^>]*href="([^"]*)"[^>]*>(.*?)</a>',
        dotAll: true,
      );
      final simpleSnippetRegex = RegExp(
        r'class="result__snippet"[^>]*>(.*?)</a>',
        dotAll: true,
      );

      final links = simpleLinkRegex.allMatches(html).toList();
      final snippets = simpleSnippetRegex.allMatches(html).toList();

      for (int i = 0; i < links.length && results.length < maxResults; i++) {
        String url = links[i].group(1) ?? '';
        String title = _stripHtml(links[i].group(2) ?? '');
        String snippet =
            i < snippets.length ? _stripHtml(snippets[i].group(1) ?? '') : '';

        final udParam = RegExp(r'uddg=([^&]+)').firstMatch(url);
        if (udParam != null) {
          url = Uri.decodeComponent(udParam.group(1)!);
        }

        if (title.isNotEmpty) {
          results.add(SearchResult(
            title: title.trim(),
            snippet: snippet.trim(),
            url: url.trim(),
          ));
        }
      }
    }

    return results;
  }

  /// Strip HTML tags from a string
  String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Format search results as context string for the LLM
  String formatResultsAsContext(List<SearchResult> results) {
    if (results.isEmpty) return '';

    final buffer = StringBuffer();
    buffer.writeln('WEB SEARCH RESULTS:');
    for (int i = 0; i < results.length; i++) {
      buffer.writeln('[${i + 1}] ${results[i].title}');
      buffer.writeln('    ${results[i].snippet}');
      buffer.writeln('    Source: ${results[i].url}');
      buffer.writeln('');
    }
    return buffer.toString();
  }
}
