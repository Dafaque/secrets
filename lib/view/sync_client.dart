import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:secrets/sync/manager.dart';
import 'dart:async';

class SyncClientView extends StatefulWidget {
  final SyncManager _syncManager;
  const SyncClientView(this._syncManager, {super.key});

  @override
  State<SyncClientView> createState() => _SyncClientViewState();
}

class _SyncClientViewState extends State<SyncClientView> {
  String? _lastScannedCode;
  final List<SyncStatus> _statusHistory = [];
  bool _isConnected = false;
  bool _hasError = false;
  StreamSubscription<SyncStatus>? _statusSubscription;

  @override
  void initState() {
    super.initState();
    _statusSubscription = widget._syncManager.status.listen((status) {
      if (mounted) {
        setState(() {
          _statusHistory.add(status);
          if (status.state == SyncState.processing ||
              status.state == SyncState.done) {
            _isConnected = true;
          } else if (status.state == SyncState.error) {
            _hasError = true;
            _isConnected = false;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    super.dispose();
  }

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
    setState(() {
      _hasError = true;
      _statusHistory.add(SyncStatus(SyncState.error, message));
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  Future<void> _connectToServer(AddrInfo addrInfo) async {
    try {
      setState(() {
        _hasError = false;
        _isConnected = false;
        _statusHistory.clear();
      });
      await widget._syncManager.connect(addrInfo, onFinished: () {
        if (mounted) {
          setState(() {
            _isConnected = false;
            _statusHistory.add(SyncStatus(SyncState.done, 'Connection closed'));
          });
        }
      });
    } catch (error) {
      _showError('Connection failed: $error');
    }
  }

  Widget _buildScanner() {
    return ReaderWidget(
      codeFormat: Format.aztec,
      isMultiScan: false,
      showScannerOverlay: true,
      showFlashlight: false,
      showGallery: false,
      showToggleCamera: false,
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

  Widget _buildStatusList() {
    return Expanded(
      child: ListView.builder(
        itemCount: _statusHistory.length,
        itemBuilder: (context, index) {
          final status = _statusHistory[index];
          IconData icon;
          Color color;

          switch (status.state) {
            case SyncState.processing:
              icon = Icons.sync;
              color = Theme.of(context).colorScheme.primary;
              break;
            case SyncState.error:
              icon = Icons.error_outline;
              color = Theme.of(context).colorScheme.error;
              break;
            case SyncState.done:
              icon = Icons.check_circle_outline;
              color = Theme.of(context).colorScheme.primary;
              break;
            case SyncState.waitingForHost:
              icon = Icons.hourglass_empty;
              color = Theme.of(context).colorScheme.secondary;
              break;
            default:
              icon = Icons.info_outline;
              color = Theme.of(context).colorScheme.secondary;
          }

          return ListTile(
            leading: Icon(icon, color: color),
            title: Text(
              status.message,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            subtitle: Text(
              status.state.toString().split('.').last,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: color,
                  ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildErrorView() {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  'Connection Error',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  _statusHistory.isNotEmpty
                      ? _statusHistory.last.message
                      : 'Unknown error occurred',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
        _buildStatusList(),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () {
            setState(() {
              _hasError = false;
              _isConnected = false;
              _statusHistory.clear();
            });
          },
          child: const Text('Try Again'),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Connection Error'),
        ),
        body: _buildErrorView(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
      ),
      body: Column(
        children: [
          if (!_isConnected) ...[
            Expanded(
              child: Stack(
                children: [
                  _buildScanner(),
                  _buildOverlay(),
                  _buildInstructions(),
                ],
              ),
            ),
          ],
          if (_statusHistory.isNotEmpty) ...[
            const Divider(),
            _buildStatusList(),
          ],
          if (_isConnected) ...[
            const SizedBox(height: 16),
            Text(
              'Syncing with server...',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ],
      ),
    );
  }
}
