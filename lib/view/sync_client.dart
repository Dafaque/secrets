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
    try {
      final port = int.parse(code);
      // Show the parsed port value
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Found port: $port'),
          duration: const Duration(seconds: 2),
        ),
      );

      widget._syncManager.connect(port).then((_) {
        // Handle successful connection
        Navigator.of(context).pop(true);
      }).catchError((error) {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connection failed: $error')),
        );
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid QR code format')),
      );
    }
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
