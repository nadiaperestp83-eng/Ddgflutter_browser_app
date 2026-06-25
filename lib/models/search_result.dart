class SearchResult {
  final String title;
  final String url;
  final String content;
  final String engine;
  final String? publishedDate;
  final String? thumbnail;

  SearchResult({
    required this.title,
    required this.url,
    required this.content,
    required this.engine,
    this.publishedDate,
    this.thumbnail,
  });

  factory SearchResult.fromJson(Map<String, dynamic> j) => SearchResult(
        title: j['title'] ?? '',
        url: j['url'] ?? '',
        content: j['content'] ?? '',
        engine: j['engine'] ?? '',
        publishedDate: j['publishedDate'],
        thumbnail: (j['thumbnail'] ?? '').toString().isNotEmpty
            ? j['thumbnail']
            : null,
      );
}

class SearchResponse {
  final String query;
  final List<SearchResult> results;
  final List<String> suggestions;

  SearchResponse({
    required this.query,
    required this.results,
    required this.suggestions,
  });

  factory SearchResponse.fromJson(Map<String, dynamic> j) => SearchResponse(
        query: j['query'] ?? '',
        results: (j['results'] as List? ?? [])
            .map((r) => SearchResult.fromJson(r as Map<String, dynamic>))
            .toList(),
        suggestions: (j['suggestions'] as List? ?? [])
            .map((s) => s.toString())
            .toList(),
      );
}
