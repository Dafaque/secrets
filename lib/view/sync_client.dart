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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Scanned code: $code')),
    );

    AddrInfo? addrInfo;
    if (code.startsWith('sync://')) {
      addrInfo = AddrInfo.fromUrl(code);
    } else if (code.startsWith('addr')) {
      addrInfo = AddrInfo.fromString(code);
    }

    if (addrInfo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid QR code format')),
      );
      return;
    }

    // Show the parsed address
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Found server at ${addrInfo.ip}:${addrInfo.port}'),
        duration: const Duration(seconds: 2),
      ),
    );

    widget._syncManager.connect(addrInfo.port).then((_) {
      // Handle successful connection
      Navigator.of(context).pop(true);
    }).catchError((error) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connection failed: $error')),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
      ),
      body: Stack(
        children: [
          // Scanner
          ReaderWidget(
            codeFormat: Format.aztec,
            onScan: (result) {
              if (result.isValid && result.text != _lastScannedCode) {
                setState(() => _lastScannedCode = result.text);
                _handleScannedCode(result.text);
              }
            },
          ),

          // Overlay
          Center(
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
          ),

          // Instructions
          Positioned(
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
          ),
        ],
      ),
    );
  }
}
