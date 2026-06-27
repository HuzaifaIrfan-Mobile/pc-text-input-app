// mobile_scanner: ^7.2.0
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../models/config.dart';

/// Full-screen QR scanner. Pops with a [Config] on success.
/// On non-mobile platforms shows an "unsupported" message instead of the camera.
class QrScreen extends StatefulWidget {
  const QrScreen({super.key});

  @override
  State<QrScreen> createState() => _QrScreenState();
}

class _QrScreenState extends State<QrScreen> {
  MobileScannerController? _controller;
  bool _handled = false;

  bool get _isMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    if (_isMobile) {
      _controller = MobileScannerController();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null) return;

    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final config = Config.fromJson(json);
      _handled = true;
      Navigator.of(context).pop(config);
    } catch (_) {
      // Not valid JSON — keep scanning.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        actions: [
          if (_isMobile)
            IconButton(
              icon: const Icon(Icons.flash_on),
              tooltip: 'Toggle torch',
              onPressed: _controller!.toggleTorch,
            ),
        ],
      ),
      body: _isMobile ? _buildScanner() : _buildUnsupported(context),
    );
  }

  Widget _buildScanner() {
    return Stack(
      children: [
        MobileScanner(
          controller: _controller!,
          onDetect: _onDetect,
        ),
        // Aim reticle overlay
        Center(
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        Positioned(
          bottom: 32,
          left: 0,
          right: 0,
          child: Text(
            'Point at the pairing QR code',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildUnsupported(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.no_photography_outlined, size: 64),
          SizedBox(height: 16),
          Text(
            'QR scanning is only supported\non Android and iOS.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}