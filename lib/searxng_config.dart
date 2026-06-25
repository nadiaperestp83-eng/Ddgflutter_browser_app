class SearxNGConfig {
  static const String baseUrl =
      'https://searxng-railway-production-9bcc.up.railway.app';

  static String searchUrl(String query) =>
      '$baseUrl/search?q=${Uri.encodeQueryComponent(query)}&format=json';

  static const String homeUrl = baseUrl;
  static const String appName = 'SearxGo';
  static const int primaryColor = 0xFF1A1A2E;
  static const int accentColor = 0xFF00D4FF;

  static const List<String> trackerDomains = [
    'google-analytics.com',
    'googletagmanager.com',
    'doubleclick.net',
    'facebook.com/tr',
    'connect.facebook.net',
    'hotjar.com',
    'segment.com',
    'mixpanel.com',
    'amplitude.com',
    'intercom.io',
    'crisp.chat',
    'ads.twitter.com',
    'analytics.tiktok.com',
  ];

  static bool isTracker(String url) =>
      trackerDomains.any((t) => url.toLowerCase().contains(t));

  // ===== NOVOS MÉTODOS (a correção) =====
  /// Verifica se a string parece ser uma URL (não uma consulta de busca).
  static bool looksLikeUrl(String input) {
    final trimmed = input.trim();
    // Se contém espaço, é uma busca
    if (trimmed.contains(' ')) return false;
    // Se começa com http:// ou https://, é URL
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return true;
    }
    // Se contém um ponto e não tem espaços, provavelmente é domínio
    if (trimmed.contains('.') && !trimmed.contains(' ')) {
      // Pode ser um domínio simples ou com caminho
      return true;
    }
    return false;
  }

  /// Converte uma string para URL completa, adicionando https:// se necessário.
  static String toUrl(String input) {
    final trimmed = input.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    return 'https://$trimmed';
  }

  // Seu método resolveInput já existe, mas não é usado pelo browser.
  // Ele pode ser mantido ou não – não interfere.
  static String resolveInput(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return homeUrl;
    final looksLikeUrl = !trimmed.contains(' ') &&
        (trimmed.contains('.') ||
            trimmed.startsWith('http://') ||
            trimmed.startsWith('https://'));
    if (looksLikeUrl) {
      return trimmed.startsWith('http') ? trimmed : 'https://$trimmed';
    }
    return searchUrl(trimmed);
  }
}
