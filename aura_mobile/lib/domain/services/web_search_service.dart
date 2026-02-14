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

  DateTime? _lastSearchTime;

  /// Search DuckDuckGo and return parsed results with retry and rate limiting
  Future<List<SearchResult>> search(String query, {int maxResults = 3}) async {
    if (!await isOnline()) return [];

    // Rate limiting: minimum 1 second between searches
    if (_lastSearchTime != null) {
      final elapsed = DateTime.now().difference(_lastSearchTime!);
      if (elapsed.inMilliseconds < 1000) {
        await Future.delayed(Duration(milliseconds: 1000 - elapsed.inMilliseconds));
      }
    }
    _lastSearchTime = DateTime.now();

    // Try with 1 retry and backoff
    for (int attempt = 0; attempt < 2; attempt++) {
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
          final body = response.data as String;
          // Check for captcha/blocking
          if (body.contains('g-recaptcha') || body.contains('captcha')) {
            if (kDebugMode) debugPrint('WebSearch: captcha detected, backing off');
            if (attempt == 0) {
              await Future.delayed(const Duration(seconds: 3));
              continue;
            }
            return [];
          }
          return _parseHtmlResults(body, maxResults);
        } else if (response.statusCode == 429) {
          if (kDebugMode) debugPrint('WebSearch: rate limited (429)');
          if (attempt == 0) {
            await Future.delayed(const Duration(seconds: 3));
            continue;
          }
        }
      } catch (e) {
        if (kDebugMode) debugPrint('WebSearch error (attempt ${attempt + 1}): $e');
        if (attempt == 0) {
          await Future.delayed(const Duration(seconds: 2));
          continue;
        }
      }
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

  /// Format search results as compact context string for the LLM.
  /// Keeps snippets short to avoid hallucination from excessive context.
  String formatResultsAsContext(List<SearchResult> results) {
    if (results.isEmpty) return '';

    final buffer = StringBuffer();
    buffer.writeln('WEB SEARCH RESULTS (use these to answer):');
    final limited = results.take(3).toList();
    for (int i = 0; i < limited.length; i++) {
      // Truncate snippet to 200 chars to keep context lean
      String snippet = limited[i].snippet;
      if (snippet.length > 200) {
        snippet = '${snippet.substring(0, 200)}...';
      }
      buffer.writeln('[${i + 1}] ${limited[i].title}');
      buffer.writeln('    $snippet');
      buffer.writeln('    Source: ${limited[i].url}');
    }
    return buffer.toString();
  }
}
