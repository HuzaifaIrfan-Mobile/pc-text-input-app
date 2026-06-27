import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart'; // ^10.3.7

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/config.dart';
import 'qr_screen.dart';

/// Settings screen — edit connection details, load from JSON file, or scan QR.
/// Pops with the updated [Config] when the user saves.
class SettingsScreen extends StatefulWidget {
  final Config current;

  const SettingsScreen({super.key, required this.current});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _hostCtrl;
  late final TextEditingController _portCtrl;
  late final TextEditingController _tokenCtrl;
  late final TextEditingController _fingerprintCtrl;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _hostCtrl = TextEditingController(text: widget.current.host);
    _portCtrl = TextEditingController(text: widget.current.port.toString());
    _tokenCtrl = TextEditingController(text: widget.current.pairToken);
    _fingerprintCtrl = TextEditingController(text: widget.current.fingerprint);
  }

  @override
  void dispose() {
    _hostCtrl.dispose();
    _portCtrl.dispose();
    _tokenCtrl.dispose();
    _fingerprintCtrl.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Apply a parsed config to the form fields
  // ---------------------------------------------------------------------------

  void _applyConfig(Config cfg) {
    setState(() {
      _hostCtrl.text = cfg.host;
      _portCtrl.text = cfg.port.toString();
      _tokenCtrl.text = cfg.pairToken;
      _fingerprintCtrl.text = cfg.fingerprint;
    });
  }

  // ---------------------------------------------------------------------------
  // Load JSON file — user enters the path manually
  // ---------------------------------------------------------------------------

  Future<void> _loadFromFile() async {
    try {
      // file_picker ^10.x API: FilePicker.platform.pickFiles()
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.isEmpty) return;

      final path = result.files.single.path;
      if (path == null) {
        _showError('Could not get file path.');
        return;
      }

      final content = await File(path).readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      _applyConfig(Config.fromJson(json));
      _showSnack('Config loaded from file.');
    } on PlatformException catch (e) {
      _showError('File picker error: ${e.message}');
    } catch (e) {
      _showError('Failed to load file:\n$e');
    }
  }

  // ---------------------------------------------------------------------------
  // Scan QR code
  // ---------------------------------------------------------------------------

  Future<void> _scanQr() async {
    final config = await Navigator.of(context).push<Config>(
      MaterialPageRoute(builder: (_) => const QrScreen()),
    );

    if (config == null) return;
    _applyConfig(config);
    _showSnack('Config loaded from QR code.');
  }

  // ---------------------------------------------------------------------------
  // Save
  // ---------------------------------------------------------------------------

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);

    final updated = widget.current.copyWith(
      host: _hostCtrl.text.trim(),
      port: int.tryParse(_portCtrl.text.trim()) ?? widget.current.port,
      pairToken: _tokenCtrl.text.trim(),
      fingerprint: _fingerprintCtrl.text.trim(),
    );

    await updated.save();

    setState(() => _saving = false);

    if (mounted) Navigator.of(context).pop(updated);
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  void _showSnack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  void _showError(String msg) => showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Error'),
          content: Text(msg),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Connection Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open),
            tooltip: 'Load from JSON file',
            onPressed: _loadFromFile,
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Scan QR code',
            onPressed: _scanQr,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Remote Host section ──────────────────────────────────────
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.lan, color: theme.colorScheme.primary),
                      const SizedBox(width: 12),
                      Text(
                        'Remote Host',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              _buildField(
                controller: _hostCtrl,
                label: 'Host / IP Address',
                hint: '192.168.1.100',
                icon: Icons.dns,
                keyboardType: TextInputType.url,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Host is required'
                    : null,
              ),

              const SizedBox(height: 16),

              _buildField(
                controller: _portCtrl,
                label: 'Port',
                hint: '51237',
                icon: Icons.electrical_services,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  if (n == null || n < 1 || n > 65535) {
                    return 'Enter a valid port (1–65535)';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),

              // ── Authentication section ────────────────────────────────────
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.lock, color: theme.colorScheme.primary),
                      const SizedBox(width: 12),
                      Text(
                        'Authentication',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              _buildField(
                controller: _tokenCtrl,
                label: 'Pair Token',
                hint: 'Hex token from server',
                icon: Icons.vpn_key,
                maxLines: 3,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Pair token is required'
                    : null,
              ),

              const SizedBox(height: 16),

              _buildField(
                controller: _fingerprintCtrl,
                label: 'TLS Fingerprint',
                hint: 'Server certificate fingerprint',
                icon: Icons.fingerprint,
                maxLines: 3,
              ),

              const SizedBox(height: 32),

              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(_saving ? 'Saving…' : 'Save'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
              ),

              const SizedBox(height: 24),

              // ── Developer footer ─────────────────────────────────────────
              Text(
                'v0.2.0',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => launchUrl(
                  Uri.parse('https://huzaifairfan.com/'),
                  mode: LaunchMode.externalApplication,
                ),
                child: Column(
                  children: [
                    Text(
                      'Developed by Huzaifa Irfan',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.outline),
                    ),
                    Text(
                      'huzaifairfan.com',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: maxLines > 1 ? TextInputType.multiline : keyboardType,
      inputFormatters: inputFormatters,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
      ),
    );
  }
}