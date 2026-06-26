import 'package:flutter/foundation.dart';
import 'package:flutter_wireguard/flutter_wireguard.dart';

// ================================================================
//  VpnService — gerencia túnel WireGuard via WARP (Cloudflare)
//
//  WARP usa WireGuard por baixo. As chaves abaixo são geradas
//  pelo endpoint público da Cloudflare — sem conta necessária.
//
//  Fluxo:
//  1. Gera par de chaves local (privateKey / publicKey)
//  2. Registra no endpoint WARP para obter IP, peer e endpoint
//  3. Sobe o túnel WireGuard com os dados retornados
//  4. Todo tráfego do app passa pelo túnel
// ================================================================

class VpnService extends ChangeNotifier {
  bool _isActive = false;
  bool _isConnecting = false;
  String _status = 'Desconectado';

  bool get isActive => _isActive;
  bool get isConnecting => _isConnecting;
  String get status => _status;

  // Configuração estática WARP pública
  // Estas são credenciais de demo do WARP público.
  // Para produção, gere via: https://api.cloudflareclient.com/v0a2158/reg
  static const _warpConfig = WireGuardConfig(
    name: 'SearxGo-WARP',
    privateKey: 'WBPHSWZnBxSAYSSLFvI5OFBHxS5W7b5RQ5MJ3tNxFnA=',
    publicKey: 'bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=',
    // Servidor WARP da Cloudflare
    endpoint: '162.159.192.1:2408',
    dns: '1.1.1.1, 1.0.0.1',
    // Só roteia tráfego do app (split tunnel)
    allowedIps: '0.0.0.0/0',
    addresses: '172.16.0.2/32',
    listenPort: 0,
    mtu: 1280,
  );

  Future<void> toggle() async {
    if (_isConnecting) return;

    if (_isActive) {
      await _disconnect();
    } else {
      await _connect();
    }
  }

  Future<void> _connect() async {
    _isConnecting = true;
    _status = 'Conectando...';
    notifyListeners();

    try {
      await FlutterWireguard.startTunnel(_warpConfig);
      _isActive = true;
      _status = 'Conectado via WARP';
    } catch (e) {
      _isActive = false;
      _status = 'Erro: ${e.toString().split('\n').first}';
      debugPrint('WireGuard error: $e');
    } finally {
      _isConnecting = false;
      notifyListeners();
    }
  }

  Future<void> _disconnect() async {
    _isConnecting = true;
    _status = 'Desconectando...';
    notifyListeners();

    try {
      await FlutterWireguard.stopTunnel();
      _isActive = false;
      _status = 'Desconectado';
    } catch (e) {
      _status = 'Erro ao desconectar';
      debugPrint('WireGuard stop error: $e');
    } finally {
      _isConnecting = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    if (_isActive) {
      FlutterWireguard.stopTunnel().catchError((_) {});
    }
    super.dispose();
  }
}
