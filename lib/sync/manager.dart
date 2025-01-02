import 'package:secrets/crypto/manager.dart';
import 'package:secrets/db/manager.dart';
import 'dart:io';

import 'package:secrets/preferences/manager.dart';

class SyncManager {
  final StorageManager _db;
  final EncryptionManager _enc;
  final PreferencesManager _prefs;
  ServerSocket? _server;

  SyncManager(this._db, this._enc, this._prefs);

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
        print('TCP Server listening on $localIp:${_server!.port}');
        _server!.listen(handleConnection);
        return server.port;
      });
    });
  }

  Future<void> stopServer() async {
    await _server?.close();
    _server = null;
    print('TCP Server stopped');
  }

  handleConnection(Socket socket) {
    print(
        'Client connected from ${socket.remoteAddress.address}:${socket.remotePort}');
    socket.listen((data) {
      print('Client sent data: ${String.fromCharCodes(data)}');
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
