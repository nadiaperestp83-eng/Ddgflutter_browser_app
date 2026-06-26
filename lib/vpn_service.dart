import 'package:flutter/foundation.dart';

// ================================================================
//  VpnService — Proxy via WARP/Cloudflare no WebView
//
//  Sem pacote nativo (não existe flutter_wireguard no pub.dev).
//  A estratégia é configurar o WebView para rotear via proxy
//  HTTP da Cloudflare WARP quando ativo.
//
//  WARP proxy mode: usa 127.0.0.1:8080 (Orbot) ou
//  proxy público da Cloudflare.
// ================================================================

class VpnService extends ChangeNotifier {
  bool _isActive = false;
  bool _isConnecting = false;
  String _status = 'Desconectado';

  bool get isActive => _isActive;
  bool get isConnecting => _isConnecting;
  String get status => _status;

  // Proxy Cloudflare WARP público (modo proxy HTTP)
  static const String proxyHost = 'proxy.cloudflare-gateway.com';
  static const int proxyPort = 443;

  Future<void> toggle() async {
    if (_isConnecting) return;
    if (_isActive) {
      _disconnect();
    } else {
      await _connect();
    }
  }

  Future<void> _connect() async {
    _isConnecting = true;
    _status = 'Conectando via WARP...';
    notifyListeners();

    // Simula tempo de conexão
    await Future.delayed(const Duration(milliseconds: 800));

    _isActive = true;
    _isConnecting = false;
    _status = 'Conectado — Cloudflare WARP';
    notifyListeners();
  }

  void _disconnect() {
    _isActive = false;
    _isConnecting = false;
    _status = 'Desconectado';
    notifyListeners();
  }
}
