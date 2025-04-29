import 'package:logger/logger.dart';
import 'package:secrets/crypto/manager.dart';
import 'package:secrets/db/manager.dart';
import 'dart:io';

import 'package:secrets/preferences/manager.dart';

class SyncManager {
  final StorageManager _db;
  final EncryptionManager _enc;
  final PreferencesManager _prefs;
  final Logger _logger;
  ServerSocket? _server;
  Socket? _client;

  SyncManager(this._logger, this._db, this._enc, this._prefs);

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

  Future<int> startServer() async {
    return getLocalIpAddress().then((localIp) {
      if (localIp == '') {
        return 0;
      }
      return ServerSocket.bind(InternetAddress(localIp), 0).then((server) {
        _server = server;
        _logger.d('TCP Server listening on $localIp:${_server!.port}');
        _server!.listen(handleConnection);
        return server.port;
      });
    });
  }

  Future<void> stopServer() async {
    await _server?.close();
    _server = null;
    _logger.d('TCP Server stopped');
  }

  Future<void> connect(int port) async {
    final localIp = await getLocalIpAddress();
    if (localIp.isEmpty) {
      throw 'Could not find local IP address';
    }

    _client = await Socket.connect(localIp, port);
    _logger.d('Connected to server at $localIp:$port');

    // Request data
    _client!.write('get');

    // Listen for incoming data
    _client!.listen(
      (data) {
        final secretStr = String.fromCharCodes(data);
        _logger.d('Received secret: $secretStr');
        // TODO: Parse and store the secret
      },
      onError: (error) {
        _logger.e('Error receiving data', error: error);
        _client?.close();
        _client = null;
      },
      onDone: () {
        _logger.d('Connection closed');
        _client?.close();
        _client = null;
      },
    );
  }

  handleConnection(Socket socket) {
    _logger.d(
        'Client connected from ${socket.remoteAddress.address}:${socket.remotePort}');
    socket.listen((data) {
      _logger.d('Client sent data: ${String.fromCharCodes(data)}');
      var msg = String.fromCharCodes(data);
      if (msg == 'get') {
        _db.getAll().then((secrets) {
          for (var secret in secrets) {
            socket.write(secret.toString());
          }
        });
      }
    });
  }
}
