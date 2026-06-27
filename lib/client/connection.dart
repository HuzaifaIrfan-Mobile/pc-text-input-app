import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import '../models/config.dart';

/// Singleton HTTP client that accepts self-signed TLS certificates.
class Connection {
  Connection._();
  static final Connection instance = Connection._();

  late final IOClient _client = _buildClient();

  static IOClient _buildClient() {
    final httpClient = HttpClient()
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
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
    return _client.post(
      Uri.parse('${config.baseUrl}/$path'),
      headers: config.authHeaders,
      body: jsonEncode(body),
    );
  }

  // ---------------------------------------------------------------------------
  // API calls
  // ---------------------------------------------------------------------------

  /// Send text to the remote host (paste_text endpoint).
  Future<ConnectionResult> pasteText(Config config, String text) async {
    try {
      final response = await _post(config, 'paste_text', {'text': text});
      if (response.statusCode == 200) {
        return ConnectionResult.ok();
      }
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
      if (response.statusCode == 200) {
        return ConnectionResult.ok();
      }
      return ConnectionResult.error(
          'Server error ${response.statusCode}: ${response.body}');
    } catch (e) {
      return ConnectionResult.error(e.toString());
    }
  }

  void dispose() => _client.close();
}

class ConnectionResult {
  final bool success;
  final String? errorMessage;

  const ConnectionResult._({required this.success, this.errorMessage});

  factory ConnectionResult.ok() => const ConnectionResult._(success: true);
  factory ConnectionResult.error(String msg) =>
      ConnectionResult._(success: false, errorMessage: msg);
}