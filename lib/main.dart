import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'client/connection.dart';
import 'models/config.dart';
import 'settings/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Hide status bar and navigation bar.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // Load saved config or fall back to defaults.
  final config = await Config.load() ?? Config.defaults();

  runApp(MyApp(initialConfig: config));
}

class MyApp extends StatelessWidget {
  final Config initialConfig;

  const MyApp({super.key, required this.initialConfig});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Remote Keyboard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
      home: HomePage(initialConfig: initialConfig),
    );
  }
}

class HomePage extends StatefulWidget {
  final Config initialConfig;

  const HomePage({super.key, required this.initialConfig});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  late Config _config;

  final _connection = Connection.instance;
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  bool _sending = false;

  /// True only while this page is the top-most route.
  /// Set to false before pushing any route, back to true after it pops.
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    _config = widget.initialConfig;

    WidgetsBinding.instance.addPostFrameCallback((_) => _refocus());

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _focusNode.addListener(() {
      if (!_isActive) return; // don't steal focus from pushed screens
      if (!_focusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (!mounted || !_isActive) return;
          _refocus();
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _sendText() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);

    final result = await _connection.pasteText(_config, text);

    if (result.success) {
      _controller.clear();
    } else {
      _showSnackBar(result.errorMessage ?? 'Unknown error');
    }

    setState(() => _sending = false);

    _refocus();
  }

  Future<void> _backspace() async {
    final result = await _connection.backspace(_config);
    if (!result.success) {
      _showSnackBar(result.errorMessage ?? 'Unknown error');
    }
    _refocus();
  }

  Future<void> _openSettings() async {
    setState(() => _isActive = false); // pause focus stealing

    final updated = await Navigator.of(context).push<Config>(
      MaterialPageRoute(builder: (_) => SettingsScreen(current: _config)),
    );

    if (updated != null) {
      setState(() => _config = updated);
    }

    setState(() => _isActive = true); // resume focus stealing
    _refocus();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  void _refocus() {
    _focusNode.requestFocus();
    SystemChannels.textInput.invokeMethod('TextInput.show');
  }

  void _showSnackBar(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _isActive ? _refocus : null,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // ── Settings ──────────────────────────────────────────
                FilledButton(
                  onPressed: _openSettings,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(56, 56),
                    padding: EdgeInsets.zero,
                  ),
                  child: const Icon(Icons.settings),
                ),

                const SizedBox(width: 12),

                // ── Text field ────────────────────────────────────────
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    autofocus: true,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    minLines: null,
                    maxLines: null,
                    expands: true,
                    decoration: InputDecoration(
                      hintText: 'Type here…',
                      border: const OutlineInputBorder(),
                      suffixIcon: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _controller,
                        builder: (_, value, __) {
                          if (value.text.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          return IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _controller.clear();
                              _refocus();
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // ── Send ──────────────────────────────────────────────
                FilledButton(
                  onPressed: _sending ? null : _sendText,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(56, 56),
                    padding: EdgeInsets.zero,
                  ),
                  child: _sending
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                ),

                const SizedBox(width: 12),

                // ── Backspace ─────────────────────────────────────────
                FilledButton(
                  onPressed: _backspace,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(56, 56),
                    padding: EdgeInsets.zero,
                  ),
                  child: const Icon(Icons.backspace),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
