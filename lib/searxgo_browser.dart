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

  SearchResponse? _searchResponse;
  String? _errorMsg;

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
    disableDefaultErrorPage: false,
    userAgent:
        'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
  );

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(() => setState(() => _isEditing = _searchFocus.hasFocus));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  // ── Decide: URL direta ou busca JSON ─────────────────────────
  void _onSubmit(String input) {
    final t = input.trim();
    if (t.isEmpty) return;
    _searchFocus.unfocus();

    if (SearxNGConfig.looksLikeUrl(t)) {
      final url = SearxNGConfig.toUrl(t);
      _loadInWebView(url);
    } else {
      _doSearch(t);
    }
  }

  void _loadInWebView(String url) {
    setState(() {
      _screen = _Screen.webview;
      _webProgress = 0;
      _webLoading = true;
    });
    if (_webController != null) {
      _webController!.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
    }
    _searchController.text = url.replaceFirst('https://', '').replaceFirst('http://', '');
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
        });
      } else {
        setState(() {
          _screen = _Screen.home;
          _searchController.clear();
        });
      }
    } else if (_screen == _Screen.results) {
      setState(() {
        _screen = _Screen.home;
        _searchController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = Color(SearxNGConfig.accentColor);
    final barColor = Color(SearxNGConfig.primaryColor);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: const Color(0xFF0D0D1A),
        endDrawer: _SettingsDrawer(accent: accent, barColor: barColor),
        body: SafeArea(
          child: Column(
            children: [
              _TopBar(
                controller: _searchController,
                focusNode: _searchFocus,
                barColor: barColor,
                accent: accent,
                isEditing: _isEditing,
                isWebLoading: _webLoading,
                webProgress: _webProgress,
                blockedCount: _blockedCount,
                showBack: _screen != _Screen.home,
                onSubmit: _onSubmit,
                onBack: _goBack,
                onMenuTap: () => _scaffoldKey.currentState?.openEndDrawer(),
              ),
              Expanded(child: _buildBody(accent)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(Color accent) {
    return Stack(
      children: [
        Offstage(
          offstage: _screen != _Screen.webview,
          child: InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri('about:blank')),
            initialSettings: _webSettings,
            onWebViewCreated: (c) => _webController = c,
            onLoadStop: (c, url) {
              final u = url?.toString() ?? '';
              if (u.isNotEmpty && u != 'about:blank') {
                setState(() {
                  _webLoading = false;
                  _webProgress = 1;
                  if (!_searchFocus.hasFocus) {
                    _searchController.text = u.replaceFirst('https://', '').replaceFirst('http://', '');
                  }
                });
              }
            },
            onLoadStart: (c, url) {
              setState(() {
                _webLoading = true;
                _webProgress = 0;
              });
            },
            onProgressChanged: (c, p) => setState(() => _webProgress = p / 100.0),
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
        if (_screen == _Screen.home) _HomeScreen(accent: accent),
        if (_screen == _Screen.results)
          _isSearching
              ? Center(child: CircularProgressIndicator(color: accent))
              : _errorMsg != null
                  ? Center(child: Text(_errorMsg!, style: const TextStyle(color: Colors.redAccent)))
                  : _ResultsScreen(
                      response: _searchResponse!,
                      accent: accent,
                      onResultTap: _loadInWebView,
                      onSuggestionTap: _doSearch,
                    ),
      ],
    );
  }
}

// ===== Os widgets auxiliares (_TopBar, _HomeScreen, _ResultsScreen, _SettingsDrawer) permanecem exatamente como você os tem =====
// (Não vou repetir para não poluir, mas eles estão corretos e não precisam de alteração)
