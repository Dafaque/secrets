import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:image/image.dart' as imglib;
import 'package:loading_indicator/loading_indicator.dart';
import 'package:secrets/sync/manager.dart';

class SyncHostView extends StatefulWidget {
  final SyncManager _syncManager;
  const SyncHostView(this._syncManager, {super.key});

  @override
  State<SyncHostView> createState() => _SyncHostViewState();
}

class _SyncHostViewState extends State<SyncHostView> {
  Uint8List? _barcodeImage;
  bool _isServerRunning = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startServer();
  }

  @override
  void dispose() {
    widget._syncManager.stopServer();
    super.dispose();
  }

  Future<void> _startServer() async {
    final addrInfo = await widget._syncManager.startServer();
    if (addrInfo == null) {
      _showError('Failed to start server');
      return;
    }

    setState(() => _isServerRunning = true);
    await _generateQrCode(addrInfo);
  }

  Future<void> _generateQrCode(AddrInfo addrInfo) async {
    try {
      final result = zx.encodeBarcode(
        contents: addrInfo.toUrl(),
        params: EncodeParams(
          format: Format.aztec,
          width: 300,
          height: 300,
        ),
      );

      if (!result.isValid || result.data == null) {
        _showError('Failed to generate QR code');
        return;
      }

      final img = _processImage(result.data!);
      setState(() => _barcodeImage = img);
    } catch (e) {
      _showError('Failed to process QR code: $e');
    }
  }

  Uint8List _processImage(Uint8List data) {
    final img = imglib.Image.fromBytes(
      width: 300,
      height: 300,
      bytes: data.buffer,
      numChannels: 1,
    );

    final qrColor = Theme.of(context).colorScheme.surface;
    final bgColor = Theme.of(context).colorScheme.primary;
    final rgbaImg = imglib.Image(width: 300, height: 300, numChannels: 4);

    for (var y = 0; y < 300; y++) {
      for (var x = 0; x < 300; x++) {
        final pixel = img.getPixel(x, y);
        final gray = imglib.getLuminance(pixel);

        if (gray < 50) {
          rgbaImg.setPixelRgba(x, y, (qrColor.r * 255).round(),
              (qrColor.g * 255).round(), (qrColor.b * 255).round(), 255);
        } else {
          rgbaImg.setPixelRgba(x, y, (bgColor.r * 255).round(),
              (bgColor.g * 255).round(), (bgColor.b * 255).round(), 255);
        }
      }
    }

    return Uint8List.fromList(imglib.encodePng(rgbaImg));
  }

  void _showError(String message) {
    setState(() => _errorMessage = message);
  }

  Widget _buildQrCode() {
    if (_barcodeImage == null) {
      return const LoadingIndicator(
        indicatorType: Indicator.ballClipRotateMultiple,
        colors: [],
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(
          color: Theme.of(context).colorScheme.primary,
          width: 4,
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300, maxHeight: 300),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: AspectRatio(
            aspectRatio: 1,
            child: Image.memory(_barcodeImage!, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.error_outline, size: 48, color: Colors.red),
        const SizedBox(height: 16),
        Text(
          _errorMessage ?? 'An error occurred',
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _startServer,
          child: const Text('Try Again'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Sync")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _errorMessage != null ? _buildError() : _buildQrCode(),
            const SizedBox(height: 16),
            Text(
              _isServerRunning ? 'Server is running' : 'Starting server...',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Scan this QR code to sync',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}
