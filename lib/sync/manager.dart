import 'dart:math';

import 'package:logger/logger.dart';
import 'dart:io';
import 'dart:async';
import 'package:secrets/db/manager.dart';
import 'package:secrets/preferences/manager.dart';
import 'package:secrets/crypto/manager.dart';
import 'package:secrets/sync/client.dart';
import 'package:secrets/sync/model.dart';
import 'package:secrets/sync/server.dart';

class SyncManager {
  final Logger _logger;
  final PreferencesManager _prefs;
  final StorageManager _storage;
  final EncryptionManager _encryption;
  final StreamController<SyncStatus> _statusController;
  ServerSocket? _server;
  SyncClientConnection? _client;
  bool _isClosed = false;

  SyncManager(this._logger, this._prefs, this._storage, this._encryption)
      : _statusController = StreamController<SyncStatus>.broadcast();

  Stream<SyncStatus> get status => _statusController.stream;

  Future<String> getLocalIpAddress() async {
    return NetworkInterface.list().then((interfaces) {
      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 &&
              addr.address.startsWith('192.168')) {
            return addr.address;
          }
        }
      }
      return '';
    });
  }

  Future<AddrInfo?> startServer() async {
    if (_isClosed) {
      _logger.w('Cannot start server: manager is closed');
      return null;
    }

    final localIp = await getLocalIpAddress();
    if (localIp.isEmpty) return null;

    try {
      final server = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
      _server = server;
      _statusController.add(SyncStatus(
          SyncState.waitingForClient, 'Waiting for client connection'));
      _logger.d('TCP Server listening on $localIp:${server.port}');
      final sessionKey =
          List<int>.generate(32, (i) => Random.secure().nextInt(256));
      server.listen((socket) {
        _logger.d(
            'Client connected from ${socket.remoteAddress.address}:${socket.remotePort}');
        SyncHostConnection(
          socket,
          _logger,
          _prefs.getAppVersion(),
          _storage,
          _encryption,
          _statusController,
          sessionKey,
        );
      });

      return AddrInfo(localIp, server.port, sessionKey);
    } catch (e) {
      _statusController
          .add(SyncStatus(SyncState.error, 'Failed to start server: $e'));
      _logger.e('Failed to start server', error: e);
      return null;
    }
  }

  Future<void> stopServer() async {
    if (_server != null) {
      await _server!.close();
      _server = null;
      _logger.d('TCP Server stopped');
    }
  }

  Future<void> connect(AddrInfo info, {Function()? onFinished}) async {
    if (_isClosed) {
      _logger.w('Cannot connect: manager is closed');
      return;
    }

    try {
      final socket = await Socket.connect(info.ip, info.port);
      _logger.d('Connected to server at ${info.ip}:${info.port}');

      _client = SyncClientConnection(socket, _logger, _prefs.getAppVersion(),
          _storage, _encryption, _statusController, info.key,
          onFinished: onFinished);
    } catch (e) {
      _statusController
          .add(SyncStatus(SyncState.error, 'Failed to connect to server: $e'));
      _logger.e('Failed to connect to server', error: e);
      rethrow;
    }
  }

  Future<void> close() async {
    if (_isClosed) return;
    _isClosed = true;

    await stopServer();
    await _client?.close();
    _client = null;
    await _statusController.close();

    _logger.d('SyncManager closed');
  }
}
