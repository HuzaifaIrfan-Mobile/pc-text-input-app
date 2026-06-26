import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

const host = "192.168.18.241";
const port = 51237;

const pairToken =
    "b3213c498a637145f5e4cd1d214181f5696e8d525b81c6c9cfe30ff84b98d0c5";

final baseUrl = "https://$host:$port";

const headers = {
  "Authorization": "Bearer $pairToken",
  "Content-Type": "application/json",
};

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Remote Keyboard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final IOClient client;

  final controller = TextEditingController();
  final focusNode = FocusNode();

  bool sending = false;

  @override
  void initState() {
    super.initState();

    client = _createHttpClient();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      focusNode.requestFocus();
      SystemChannels.textInput.invokeMethod('TextInput.show');
    });

    focusNode.addListener(() {
      if (!focusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (!mounted) return;

          focusNode.requestFocus();
          SystemChannels.textInput.invokeMethod('TextInput.show');
        });
      }
    });
  }

  IOClient _createHttpClient() {
    final httpClient = HttpClient();

    httpClient.badCertificateCallback =
        (X509Certificate cert, String host, int port) {
          // Accept self-signed certificate
          return true;
        };

    return IOClient(httpClient);
  }

  Future<void> sendText() async {
    final text = controller.text.trim();

    if (text.isEmpty || sending) return;

    setState(() {
      sending = true;
    });

    try {
      final response = await client.post(
        Uri.parse("$baseUrl/paste_text"),
        headers: headers,
        body: jsonEncode({"text": text}),
      );

      if (response.statusCode == 200) {
        controller.clear();
      } else {
        _showSnackBar("Server Error ${response.statusCode}\n${response.body}");
      }
    } catch (e) {
      _showSnackBar(e.toString());
    }

    setState(() {
      sending = false;
    });

    focusNode.requestFocus();
    SystemChannels.textInput.invokeMethod('TextInput.show');
  }

  Future<void> backspace() async {
    try {
      await client.post(
        Uri.parse("$baseUrl/backspace"),
        headers: headers,
        body: jsonEncode({"count": 1}),
      );
    } catch (e) {
      _showSnackBar(e.toString());
    }

    focusNode.requestFocus();
    SystemChannels.textInput.invokeMethod('TextInput.show');
  }

  void _showSnackBar(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  void dispose() {
    client.close();
    controller.dispose();
    focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        focusNode.requestFocus();
        SystemChannels.textInput.invokeMethod('TextInput.show');
      },
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    autofocus: true,

                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,

                    minLines: null,
                    maxLines: null, // Unlimited

                    expands: true,

                    decoration: InputDecoration(
                      hintText: "Type here...",
                      border: const OutlineInputBorder(),
                      suffixIcon: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: controller,
                        builder: (_, value, __) {
                          if (value.text.isEmpty)
                            return const SizedBox.shrink();

                          return IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              controller.clear();
                              focusNode.requestFocus();
                              SystemChannels.textInput.invokeMethod(
                                'TextInput.show',
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                FilledButton(
                  onPressed: sending ? null : sendText,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(56, 56),
                    padding: EdgeInsets.zero,
                  ),
                  child: sending
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                ),

                const SizedBox(width: 12),

                FilledButton(
                  onPressed: backspace,
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
