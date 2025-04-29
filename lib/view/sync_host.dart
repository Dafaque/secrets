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

enum _ViewState {
  loading,
  ready,
  error,
}

class _SyncHostViewState extends State<SyncHostView> {
  _ViewState _viewState = _ViewState.loading;
  Uint8List? _barcodeImage;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    widget._syncManager.startServer().then(_onServerStarted);
  }

  void _onServerStarted(int port) {
    try {
      final result = zx.encodeBarcode(
        contents: port.toString(),
        params: EncodeParams(
          format: Format.aztec,
          width: 300,
          height: 300,
        ),
      );

      if (result.isValid && result.data != null) {
        final expectedBytes = 300 * 300;
        if (result.data!.lengthInBytes >= expectedBytes) {
          try {
            final img = imglib.Image.fromBytes(
              width: 300,
              height: 300,
              bytes: result.data!.buffer,
              numChannels: 1,
            );

            // Check some sample pixels from original image
            print('Sample pixels from original image:');
            for (var i = 0; i < 5; i++) {
              final x = i * 60;
              final y = i * 60;
              final pixel = img.getPixel(x, y);
              final gray = imglib.getLuminance(pixel);
              print('Pixel at ($x,$y): gray=$gray');
            }

            // Convert to RGBA and apply theme colors
            final themeColor = Theme.of(context).colorScheme.onSurface;
            final rgbaImg =
                imglib.Image(width: 300, height: 300, numChannels: 4);

            for (var y = 0; y < 300; y++) {
              for (var x = 0; x < 300; x++) {
                final pixel = img.getPixel(x, y);
                final gray = imglib.getLuminance(pixel);

                if (gray < 50) {
                  // Keep the lower threshold that worked
                  // Dark pixels become theme color
                  rgbaImg.setPixelRgba(x, y, themeColor.red, themeColor.green,
                      themeColor.blue, 255);
                } else {
                  // Light pixels become transparent
                  rgbaImg.setPixelRgba(x, y, 0, 0, 0, 0);
                }
              }
            }

            final encodedBytes = Uint8List.fromList(imglib.encodePng(rgbaImg));
            setState(() {
              _barcodeImage = encodedBytes;
              _viewState = _ViewState.ready;
            });
          } catch (e) {
            setState(() {
              _errorMessage = 'Failed to create QR code image';
              _viewState = _ViewState.error;
            });
          }
        } else {
          setState(() {
            _errorMessage = 'Insufficient data for QR code generation';
            _viewState = _ViewState.error;
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Failed to generate QR code';
          _viewState = _ViewState.error;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: ${e.toString()}';
        _viewState = _ViewState.error;
      });
    }
  }

  @override
  void dispose() {
    widget._syncManager.stopServer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Sync")),
      body: switch (_viewState) {
        _ViewState.loading => const Center(
            child: LoadingIndicator(
              indicatorType: Indicator.ballClipRotateMultiple,
              colors: [],
            ),
          ),
        _ViewState.ready => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_barcodeImage != null)
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 300,
                      maxHeight: 300,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: Image.memory(
                          _barcodeImage!,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    "Scan this QR code to sync",
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
          ),
        _ViewState.error => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Colors.red,
                ),
                const SizedBox(height: 16),
                Text(
                  _errorMessage ?? 'An error occurred',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _viewState = _ViewState.loading;
                      _errorMessage = null;
                    });
                    widget._syncManager.startServer().then(_onServerStarted);
                  },
                  child: const Text('Try Again'),
                ),
              ],
            ),
          ),
      },
    );
  }
}
