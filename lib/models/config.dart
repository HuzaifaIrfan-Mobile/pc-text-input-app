import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

const _kConfigKey = 'remote_keyboard_config';

class Config {
  final String createdOn;
  final int version;
  final String host;
  final int port;
  final String pairToken;
  final String fingerprint;

  const Config({
    required this.createdOn,
    required this.version,
    required this.host,
    required this.port,
    required this.pairToken,
    required this.fingerprint,
  });

  factory Config.defaults() => Config(
        createdOn: DateTime.now().toUtc().toIso8601String(),
        version: 1,
        host: '',
        port: 51237,
        pairToken: '',
        fingerprint: '',
      );

  factory Config.fromJson(Map<String, dynamic> json) => Config(
        createdOn: json['createdOn'] as String? ?? '',
        version: json['version'] as int? ?? 1,
        host: json['host'] as String? ?? '',
        port: json['port'] as int? ?? 51237,
        pairToken: json['pairToken'] as String? ?? '',
        fingerprint: json['fingerprint'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'createdOn': createdOn,
        'version': version,
        'host': host,
        'port': port,
        'pairToken': pairToken,
        'fingerprint': fingerprint,
      };

  Config copyWith({
    String? createdOn,
    int? version,
    String? host,
    int? port,
    String? pairToken,
    String? fingerprint,
  }) =>
      Config(
        createdOn: createdOn ?? this.createdOn,
        version: version ?? this.version,
        host: host ?? this.host,
        port: port ?? this.port,
        pairToken: pairToken ?? this.pairToken,
        fingerprint: fingerprint ?? this.fingerprint,
      );

  /// Save to shared preferences.
  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kConfigKey, jsonEncode(toJson()));
  }

  /// Load from shared preferences. Returns null if nothing saved yet.
  static Future<Config?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kConfigKey);
    if (raw == null) return null;
    try {
      return Config.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Delete saved config from shared preferences.
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kConfigKey);
  }

  String get baseUrl => 'https://$host:$port';

  Map<String, String> get authHeaders => {
        'Authorization': 'Bearer $pairToken',
        'Content-Type': 'application/json',
      };

  @override
  String toString() => 'Config(host: $host, port: $port)';
}