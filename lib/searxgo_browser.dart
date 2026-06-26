import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;
import 'searxng_config.dart';
import 'models/search_result.dart';

enum _Screen { home, results, webview }

class SearxGoBrowser extends StatefulWidget {
  const SearxGoBrowser({Key? key}) : super(key: key);

  @override
  State<SearxGoBrowser> createState() => _SearxGoBrowserState();
}

class _SearxGoBrowserState extends State<SearxGoBrowser> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  InAppWebViewController? _webController;

  _Screen _screen = _Screen.home;
  bool _isSearching = false;
  bool _isEditing = false;
  double _webProgress = 0;
  bool _webLoading = false;
  int _blockedCount = 0;
  bool _currentIsHttps = false;
  String _currentUrl = '';

  SearchResponse? _searchResponse;
  String? _errorMsg;

  // Paleta — igual ao DDG
  static const Color _pageBg   = Color(0xFFEEEEEE); // fundo da página
  static const Color _barBg    = Color(0xFFF1F1F1); // fundo da barra
  static const Color _pillBg   = Colors.white;      // pílula de busca
  static const Color _iconGray = Color(0xFF5F5F5F); // ícones
  static const Color _hintGray = Color(0xFF8A8A8A); // placeholder
  static const Color _cardBg   = Color(0xFFFFFFFF); // cards resultado
  static const Color _cardBorder = Color(0xFFE0E0E0);
  static const Color _textMain = Color(0xFF1A1A1A); // texto principal
  static const Color _textSub  = Color(0xFF5F5F5F); // texto secundário
  static const Color _accent   = Color(0xFF00D4FF); // ciano

  final InAppWebViewSettings _webSettings = InAppWebViewSettings(
    useShouldOverrideUrlLoading: true,
    javaScriptEnabled: true,
    domStorageEnabled: true,
    databaseEnabled: true,
    allowFileAccess: true,
    allowContentAccess: true,
    mediaPlaybackRequiresUserGesture: false,
    allowsInlineMediaPlayback: true,
    incognito: true,
    cacheEnabled: false,
    clearCache: true,
    builtInZoomControls: false,
    displayZoomControls: false,
    supportZoom: true,
    userAgent:
        'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
  );

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(() {
      final hasFocus = _searchFocus.hasFocus;
      setState(() => _isEditing = hasFocus);
      if (_screen == _Screen.webview) {
        if (hasFocus) {
          _searchController.text = _currentUrl;
          _searchController.selection = TextSelection(
            baseOffset: 0,
            extentOffset: _searchController.text.length,
          );
        } else {
          _searchController.text = _domainOnly(_currentUrl);
        }
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  String _domainOnly(String url) {
    if (url.isEmpty) return '';
    try {
      final uri = Uri.parse(url);
      if (uri.host.isEmpty) return url;
      return uri.host.replaceFirst('www.', '');
    } catch (_) {
      return url;
    }
  }

  void _onSubmit(String input) {
    final t = input.trim();
    if (t.isEmpty) return;
    _searchFocus.unfocus();
    if (SearxNGConfig.looksLikeUrl(t)) {
      _loadInWebView(SearxNGConfig.toUrl(t));
    } else {
      _doSearch(t);
    }
  }

  void _loadInWebView(String url) {
    setState(() {
      _screen = _Screen.webview;
      _webProgress = 0;
      _webLoading = true;
      _currentIsHttps = url.startsWith('https://');
      _currentUrl = url;
    });
    _webController?.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
    _searchController.text = _domainOnly(url);
  }

  Future<void> _doSearch(String query) async {
    setState(() {
      _isSearching = true;
      _screen = _Screen.results;
      _errorMsg = null;
      _searchResponse = null;
      _searchController.text = query;
    });

    try {
      final uri = Uri.parse(SearxNGConfig.searchUrl(query));
      final res = await http.get(uri, headers: {
        'Accept': 'application/json',
        'User-Agent': 'SearxGo/1.0',
      }).timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final json = jsonDecode(utf8.decode(res.bodyBytes));
        setState(() {
          _searchResponse = SearchResponse.fromJson(json);
          _isSearching = false;
        });
      } else {
        setState(() {
          _errorMsg = 'Erro ${res.statusCode}';
          _isSearching = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMsg = 'Falha: $e';
        _isSearching = false;
      });
    }
  }

  void _goBack() {
    if (_screen == _Screen.webview) {
      if (_searchResponse != null) {
        setState(() {
          _screen = _Screen.results;
          _searchController.text = _searchResponse!.query;
          _currentIsHttps = false;
          _currentUrl = '';
        });
      } else {
        setState(() {
          _screen = _Screen.home;
          _searchController.clear();
          _currentIsHttps = false;
          _currentUrl = '';
        });
      }
    } else if (_screen == _Screen.results) {
      setState(() {
        _screen = _Screen.home;
        _searchController.clear();
      });
    }
  }

  Future<void> _burnAll() async {
    await CookieManager.instance().deleteAllCookies();
    await _webController?.clearCache();
    await _webController?.clearHistory();
    await _webController?.evaluateJavascript(source: '''
      try { localStorage.clear(); } catch(e) {}
      try { sessionStorage.clear(); } catch(e) {}
      try {
        indexedDB.databases().then(function(dbs) {
          dbs.forEach(function(db) { indexedDB.deleteDatabase(db.name); });
        });
      } catch(e) {}
    ''');
    await _webController?.loadUrl(
      urlRequest: URLRequest(url: WebUri('about:blank')),
    );
    if (mounted) {
      setState(() {
        _screen = _Screen.home;
        _searchController.clear();
        _searchResponse = null;
        _errorMsg = null;
        _blockedCount = 0;
        _webProgress = 0;
        _webLoading = false;
        _currentIsHttps = false;
        _currentUrl = '';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(children: [
            Icon(Icons.local_fire_department,
                color: Color(0xFFE07A2A), size: 18),
            SizedBox(width: 8),
            Text('Dados de navegação apagados'),
          ]),
          duration: Duration(seconds: 2),
          backgroundColor: Color(0xFF333333),
        ),
      );
    }
  }

  void _onTabsTap() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Gerenciador de abas em breve'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    IconData leadingIcon;
    Color leadingIconColor;
    if (_isEditing || _screen != _Screen.webview) {
      leadingIcon = Icons.search;
      leadingIconColor = _iconGray;
    } else if (_currentIsHttps) {
      leadingIcon = Icons.lock_outline;
      leadingIconColor = _iconGray;
    } else {
      leadingIcon = Icons.public;
      leadingIconColor = _iconGray;
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark, // status bar escura (ícones pretos)
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: _pageBg, // cinza claro — igual DDG
        endDrawer: _SettingsDrawer(
          accent: _accent,
          onBurnTap: () {
            Navigator.pop(context);
            _burnAll();
          },
        ),
        body: SafeArea(
          child: Column(
            children: [
              _TopBar(
                controller: _searchController,
                focusNode: _searchFocus,
                accent: _accent,
                isEditing: _isEditing,
                isWebLoading: _webLoading,
                webProgress: _webProgress,
                blockedCount: _blockedCount,
                showBack: _screen != _Screen.home,
                leadingIcon: leadingIcon,
                leadingIconColor: leadingIconColor,
                onSubmit: _onSubmit,
                onBack: _goBack,
                onMenuTap: () => _scaffoldKey.currentState?.openEndDrawer(),
                onFireTap: _burnAll,
                onTabsTap: _onTabsTap,
              ),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    return Stack(
      children: [
        // WebView sempre no DOM
        Offstage(
          offstage: _screen != _Screen.webview,
          child: InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri('about:blank')),
            initialSettings: _webSettings,
            onWebViewCreated: (c) => _webController = c,
            onLoadStart: (c, url) =>
                setState(() { _webLoading = true; _webProgress = 0; }),
            onLoadStop: (c, url) {
              final u = url?.toString() ?? '';
              if (u.isNotEmpty && u != 'about:blank') {
                setState(() {
                  _webLoading = false;
                  _webProgress = 1;
                  _currentIsHttps = u.startsWith('https://');
                  _currentUrl = u;
                  if (!_searchFocus.hasFocus) {
                    _searchController.text = _domainOnly(u);
                  }
                });
              }
            },
            onProgressChanged: (c, p) =>
                setState(() => _webProgress = p / 100.0),
            shouldOverrideUrlLoading: (c, action) async {
              final url = action.request.url?.toString() ?? '';
              if (SearxNGConfig.isTracker(url)) {
                setState(() => _blockedCount++);
                return NavigationActionPolicy.CANCEL;
              }
              return NavigationActionPolicy.ALLOW;
            },
          ),
        ),

        // Home
        if (_screen == _Screen.home)
          Container(
            color: _pageBg, // cinza claro igual à barra
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shield, size: 64,
                      color: _accent.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  Text(
                    SearxNGConfig.appName,
                    style: const TextStyle(
                      color: Color(0xFF1A1A2E),
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      fontFamily: 'sans-serif',
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Busca privada — sem rastreadores',
                    style: TextStyle(
                        color: _iconGray,
                        fontSize: 14,
                        fontFamily: 'sans-serif'),
                  ),
                ],
              ),
            ),
          ),

        // Resultados
        if (_screen == _Screen.results)
          _isSearching
              ? Container(
                  color: _pageBg,
                  child: Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFF1A1A2E))))
              : _errorMsg != null
                  ? Container(
                      color: _pageBg,
                      child: Center(
                          child: Text(_errorMsg!,
                              style: const TextStyle(
                                  color: Colors.redAccent))))
                  : _searchResponse != null
                      ? _ResultsScreen(
                          response: _searchResponse!,
                          accent: _accent,
                          pageBg: _pageBg,
                          cardBg: _cardBg,
                          cardBorder: _cardBorder,
                          textMain: _textMain,
                          textSub: _textSub,
                          onResultTap: _loadInWebView,
                          onSuggestionTap: _doSearch,
                        )
                      : const SizedBox.shrink(),
      ],
    );
  }
}

// ================================================================
//  Barra fixa — igual DDG
// ================================================================
class _TopBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final Color accent;
  final bool isEditing, isWebLoading, showBack;
  final double webProgress;
  final int blockedCount;
  final IconData leadingIcon;
  final Color leadingIconColor;
  final ValueChanged<String> onSubmit;
  final VoidCallback onBack, onMenuTap, onFireTap, onTabsTap;

  static const Color _barBg   = Color(0xFFF1F1F1);
  static const Color _pillBg  = Colors.white;
  static const Color _iconGray = Color(0xFF5F5F5F);
  static const Color _hintGray = Color(0xFF8A8A8A);

  const _TopBar({
    required this.controller,
    required this.focusNode,
    required this.accent,
    required this.isEditing,
    required this.isWebLoading,
    required this.webProgress,
    required this.blockedCount,
    required this.showBack,
    required this.leadingIcon,
    required this.leadingIconColor,
    required this.onSubmit,
    required this.onBack,
    required this.onMenuTap,
    required this.onFireTap,
    required this.onTabsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          color: _barBg,
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
          child: Row(
            children: [
              if (showBack)
                IconButton(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back,
                      color: _iconGray, size: 20),
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              Expanded(
                child: Container(
                  height: 44,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: _pillBg,
                    borderRadius: BorderRadius.circular(22),
                    border: isEditing
                        ? Border.all(color: accent, width: 1.5)
                        : null,
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 14),
                      Icon(leadingIcon, size: 16, color: leadingIconColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: controller,
                          focusNode: focusNode,
                          onTap: () {
                            controller.selection = TextSelection(
                              baseOffset: 0,
                              extentOffset: controller.text.length,
                            );
                          },
                          onSubmitted: onSubmit,
                          textInputAction: TextInputAction.go,
                          keyboardType: TextInputType.url,
                          autocorrect: false,
                          // Fonte padrão do sistema (igual Chrome/DDG)
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 16,
                            fontFamily: null, // herda fonte do sistema
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Pesquisar',
                            hintStyle: TextStyle(
                              color: _hintGray,
                              fontSize: 16,
                              fontFamily: null,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      if (blockedCount > 0 && !isEditing)
                        Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.shield, size: 13, color: accent),
                              const SizedBox(width: 2),
                              Text('$blockedCount',
                                  style: TextStyle(
                                      color: accent,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        )
                      else
                        const SizedBox(width: 4),
                    ],
                  ),
                ),
              ),
              IconButton(
                onPressed: onFireTap,
                icon: const Icon(Icons.local_fire_department,
                    color: Color(0xFFE07A2A), size: 22),
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
              InkWell(
                onTap: onTabsTap,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  width: 28,
                  height: 28,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    border: Border.all(color: _iconGray, width: 1.6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  alignment: Alignment.center,
                  child: const Text('1',
                      style: TextStyle(
                          color: _iconGray,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
              ),
              IconButton(
                onPressed: onMenuTap,
                icon: const Icon(Icons.menu, color: _iconGray, size: 22),
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ],
          ),
        ),
        isWebLoading && webProgress > 0 && webProgress < 1
            ? LinearProgressIndicator(
                value: webProgress,
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(
                    const Color(0xFF1A73E8)),
                minHeight: 3,
              )
            : const SizedBox(height: 1),
      ],
    );
  }
}

// ================================================================
//  Resultados — fundo cinza claro, cards brancos, fonte sistema
// ================================================================
class _ResultsScreen extends StatelessWidget {
  final SearchResponse response;
  final Color accent, pageBg, cardBg, cardBorder, textMain, textSub;
  final ValueChanged<String> onResultTap;
  final ValueChanged<String> onSuggestionTap;

  const _ResultsScreen({
    required this.response,
    required this.accent,
    required this.pageBg,
    required this.cardBg,
    required this.cardBorder,
    required this.textMain,
    required this.textSub,
    required this.onResultTap,
    required this.onSuggestionTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: pageBg,
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        itemCount: response.results.length +
            (response.suggestions.isNotEmpty ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == response.results.length) {
            return _SuggestionsRow(
              suggestions: response.suggestions,
              accent: accent,
              onTap: onSuggestionTap,
            );
          }
          final r = response.results[index];
          return _ResultCard(
            result: r,
            accent: accent,
            cardBg: cardBg,
            cardBorder: cardBorder,
            textMain: textMain,
            textSub: textSub,
            onTap: () => onResultTap(r.url),
          );
        },
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final SearchResult result;
  final Color accent, cardBg, cardBorder, textMain, textSub;
  final VoidCallback onTap;

  const _ResultCard({
    required this.result,
    required this.accent,
    required this.cardBg,
    required this.cardBorder,
    required this.textMain,
    required this.textSub,
    required this.onTap,
  });

  String get _domain {
    try {
      return Uri.parse(result.url).host.replaceFirst('www.', '');
    } catch (_) {
      return result.url;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.language, size: 12, color: textSub),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(_domain,
                      style: TextStyle(color: textSub, fontSize: 12),
                      overflow: TextOverflow.ellipsis),
                ),
                Text(result.engine,
                    style: TextStyle(
                        color: textSub.withOpacity(0.6), fontSize: 10)),
              ],
            ),
            const SizedBox(height: 6),
            // Título estilo Google/DDG — azul
            Text(result.title,
                style: const TextStyle(
                  color: Color(0xFF1558D6),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  fontFamily: null, // fonte do sistema
                )),
            if (result.content.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(result.content,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textMain,
                    fontSize: 14,
                    height: 1.4,
                    fontFamily: null,
                  )),
            ],
            if (result.publishedDate != null) ...[
              const SizedBox(height: 4),
              Text(result.publishedDate!,
                  style: TextStyle(color: textSub, fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }
}

class _SuggestionsRow extends StatelessWidget {
  final List<String> suggestions;
  final Color accent;
  final ValueChanged<String> onTap;

  const _SuggestionsRow({
    required this.suggestions,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Sugestões',
              style: TextStyle(
                  color: Color(0xFF5F5F5F), fontSize: 12)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: suggestions
                .map((s) => GestureDetector(
                      onTap: () => onTap(s),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(
                              color: const Color(0xFFE0E0E0)),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(s,
                            style: const TextStyle(
                              color: Color(0xFF1558D6),
                              fontSize: 13,
                            )),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

// ================================================================
//  Drawer
// ================================================================
class _SettingsDrawer extends StatelessWidget {
  final Color accent;
  final VoidCallback onBurnTap;

  const _SettingsDrawer({
    required this.accent,
    required this.onBurnTap,
  });

  static const Color _drawerBg = Color(0xFFF5F5F5);
  static const Color _headerBg = Color(0xFFEEEEEE);
  static const Color _iconGray = Color(0xFF5F5F5F);

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: _drawerBg,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              color: _headerBg,
              child: Row(
                children: [
                  Icon(Icons.shield, color: accent, size: 22),
                  const SizedBox(width: 10),
                  Text(SearxNGConfig.appName,
                      style: TextStyle(
                          color: accent,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Botão fogo
            ListTile(
              leading: const Icon(Icons.local_fire_department,
                  color: Color(0xFFE07A2A), size: 22),
              title: const Text('Apagar dados de navegação',
                  style: TextStyle(
                      color: Color(0xFFE07A2A),
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
              subtitle: const Text(
                  'Cookies, cache, histórico e armazenamento',
                  style: TextStyle(color: Color(0xFF8A8A8A), fontSize: 12)),
              trailing: const Icon(Icons.chevron_right,
                  color: Color(0xFFCCCCCC), size: 18),
              onTap: onBurnTap,
            ),

            const Divider(color: Color(0xFFE0E0E0), height: 1),
            const SizedBox(height: 8),

            _item(Icons.tune, 'Configurações do navegador', _iconGray,
                () => Navigator.pop(context)),
            _item(Icons.search, 'Instância SearxNG', _iconGray,
                () => Navigator.pop(context)),
            _item(Icons.security, 'Privacidade & Trackers', _iconGray,
                () => Navigator.pop(context)),
            _item(Icons.info_outline, 'Sobre', _iconGray,
                () => Navigator.pop(context)),

            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(SearxNGConfig.baseUrl,
                  style: const TextStyle(
                      color: Color(0xFFAAAAAA), fontSize: 11)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _item(IconData icon, String label, Color color, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: color, size: 20),
      title: Text(label,
          style: TextStyle(color: color, fontSize: 15)),
      trailing: const Icon(Icons.chevron_right,
          color: Color(0xFFCCCCCC), size: 18),
      onTap: onTap,
    );
  }
}
