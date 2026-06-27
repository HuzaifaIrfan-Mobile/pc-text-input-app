import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import '../models/config.dart';

/// Returns true if the certificate's SHA-256 fingerprint matches [expected].
/// [expected] may use colon-separated hex (aa:bb:cc…) or plain hex (aabbcc…).
bool _fingerprintMatches(X509Certificate cert, String expected) {
  final normalised = expected.replaceAll(':', '').toLowerCase();
  if (normalised.isEmpty) return false;

  final digest = sha256.convert(cert.der);
  return digest.toString() == normalised;
}

/// HTTP client that pins the server certificate by SHA-256 fingerprint.
class Connection {
  Connection._();
  static final Connection instance = Connection._();

  /// Builds a one-shot [IOClient] whose TLS callback validates the cert
  /// fingerprint against [config.fingerprint].
  /// If [config.fingerprint] is empty the connection is rejected.
  IOClient _buildClient(Config config) {
    final httpClient = HttpClient()
      ..badCertificateCallback = (X509Certificate cert, String host, int port) {
        if (config.fingerprint.isEmpty) return false;
        return _fingerprintMatches(cert, config.fingerprint);
      };
    return IOClient(httpClient);
  }

  // ---------------------------------------------------------------------------
  // Low-level helpers
  // ---------------------------------------------------------------------------

  Future<http.Response> _post(
    Config config,
    String path,
    Map<String, dynamic> body,
  ) async {
    final client = _buildClient(config);
    try {
      return await client.post(
        Uri.parse('${config.baseUrl}/$path'),
        headers: config.authHeaders,
        body: jsonEncode(body),
      );
    } finally {
      client.close();
    }
  }

  // ---------------------------------------------------------------------------
  // API calls
  // ---------------------------------------------------------------------------

  /// Send text to the remote host (paste_text endpoint).
  Future<ConnectionResult> pasteText(Config config, String text) async {
    try {
      final response = await _post(config, 'paste_text', {'text': text});
      if (response.statusCode == 200) return ConnectionResult.ok();
      return ConnectionResult.error(
          'Server error ${response.statusCode}: ${response.body}');
    } catch (e) {
      return ConnectionResult.error(e.toString());
    }
  }

  /// Send a backspace keystroke to the remote host.
  Future<ConnectionResult> backspace(Config config, {int count = 1}) async {
    try {
      final response = await _post(config, 'backspace', {'count': count});
      if (response.statusCode == 200) return ConnectionResult.ok();
      return ConnectionResult.error(
          'Server error ${response.statusCode}: ${response.body}');
    } catch (e) {
      return ConnectionResult.error(e.toString());
    }
  }
}

class ConnectionResult {
  final bool success;
  final String? errorMessage;

  const ConnectionResult._({required this.success, this.errorMessage});

  factory ConnectionResult.ok() => const ConnectionResult._(success: true);
  factory ConnectionResult.error(String msg) =>
      ConnectionResult._(success: false, errorMessage: msg);
}