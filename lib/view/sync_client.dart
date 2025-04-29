import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:secrets/sync/manager.dart';

class SyncClientView extends StatefulWidget {
  final SyncManager _syncManager;
  const SyncClientView(this._syncManager, {super.key});

  @override
  State<SyncClientView> createState() => _SyncClientViewState();
}

class _SyncClientViewState extends State<SyncClientView> {
  String? _lastScannedCode;

  void _handleScannedCode(String? code) {
    if (code == null) return;

    final addrInfo = AddrInfo.fromUrl(code);
    if (addrInfo == null) {
      _showError('Invalid QR code format');
      return;
    }

    _showServerInfo(addrInfo);
    _connectToServer(addrInfo);
  }

  void _showServerInfo(AddrInfo addrInfo) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Found server at ${addrInfo.ip}:${addrInfo.port}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _connectToServer(AddrInfo addrInfo) async {
    try {
      await widget._syncManager.connect(addrInfo);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      _showError('Connection failed: $error');
    }
  }

  Widget _buildScanner() {
    return ReaderWidget(
      codeFormat: Format.aztec,
      onScan: (result) {
        if (result.isValid && result.text != _lastScannedCode) {
          setState(() => _lastScannedCode = result.text);
          _handleScannedCode(result.text);
        }
      },
    );
  }

  Widget _buildOverlay() {
    return Center(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.7,
        height: MediaQuery.of(context).size.width * 0.7,
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.primary,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _buildInstructions() {
    return Positioned(
      bottom: 32,
      left: 0,
      right: 0,
      child: Center(
        child: Text(
          'Position the QR code within the frame',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
      ),
      body: Stack(
        children: [
          _buildScanner(),
          _buildOverlay(),
          _buildInstructions(),
        ],
      ),
    );
  }
}
