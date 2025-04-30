import 'package:logger/logger.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';
import 'dart:async';
import 'package:encrypt/encrypt.dart';
import 'package:secrets/db/manager.dart';
import 'package:secrets/db/secret.dart';
import 'package:secrets/preferences/manager.dart';
import 'package:secrets/crypto/manager.dart';

enum SyncState {
  ready,
  error,
  processing,
  done,
  waitingForClient,
  waitingForHost,
}

class SyncStatus {
  final SyncState state;
  final String message;

  SyncStatus(this.state, this.message);
}

class AddrInfo {
  final String ip;
  final int port;

  AddrInfo(this.ip, this.port);

  String toUrl() {
    return 'sync://?ip=$ip&port=$port';
  }

  static AddrInfo? fromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      if (uri.scheme != 'sync') return null;

      final ip = uri.queryParameters['ip'];
      final portStr = uri.queryParameters['port'];
      if (ip == null || portStr == null) return null;

      final port = int.parse(portStr);
      return AddrInfo(ip, port);
    } catch (e) {
      return null;
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AddrInfo && other.ip == ip && other.port == port;
  }

  @override
  int get hashCode => ip.hashCode ^ port.hashCode;
}

class SyncMessage {
  final String type;
  final String? payload;

  SyncMessage(this.type, {this.payload});

  String encode() {
    if (payload != null) {
      return '$type:$payload';
    }
    return type;
  }

  static SyncMessage? decode(String data) {
    final parts = data.split(':');
    if (parts.isEmpty) return null;

    final type = parts[0];
    final payload = parts.length > 1 ? parts[1] : null;
    return SyncMessage(type, payload: payload);
  }

  String toProtocol() {
    final message = encode();
    return '${message.length} $message';
  }

  static SyncMessage? fromProtocol(String data) {
    final spaceIndex = data.indexOf(' ');
    if (spaceIndex == -1) return null;

    try {
      final length = int.parse(data.substring(0, spaceIndex));
      final message = data.substring(spaceIndex + 1);
      if (message.length != length) return null;
      return decode(message);
    } catch (e) {
      return null;
    }
  }
}

class SyncHostConnection {
  final Socket socket;
  final Logger logger;
  final String appVersion;
  final StorageManager _storage;
  final EncryptionManager _encryption;
  final StreamController<SyncStatus> _statusController;
  final List<int> sessionKey;
  bool _isClosed = false;
  bool _waitingForAck = false;
  List<Secret>? _cachedSecrets;
  int _currentIndex = 0;
  final List<int> _buffer = [];

  SyncHostConnection(this.socket, this.logger, this.appVersion, this._storage,
      this._encryption, this._statusController)
      : sessionKey =
            List<int>.generate(32, (i) => Random.secure().nextInt(256)) {
    socket.listen((data) {
      _buffer.addAll(data);
      _processBuffer();
    }, onError: _handleError, onDone: _handleDone);
    _sendHello();
  }

  void _processBuffer() {
    final bufferStr = String.fromCharCodes(_buffer);
    final spaceIndex = bufferStr.indexOf(' ');
    if (spaceIndex == -1) {
      logger.d('Waiting for more data, current buffer: $bufferStr');
      return;
    }

    try {
      final length = int.parse(bufferStr.substring(0, spaceIndex));
      if (bufferStr.length < spaceIndex + 1 + length) {
        logger.d(
            'Waiting for full message, need $length bytes, have ${bufferStr.length - spaceIndex - 1}');
        return;
      }

      final message = SyncMessage.fromProtocol(
          bufferStr.substring(0, spaceIndex + 1 + length));
      _buffer.removeRange(0, spaceIndex + 1 + length);

      if (message == null) {
        logger.e('Invalid message format');
        _statusController
            .add(SyncStatus(SyncState.error, 'Invalid message format'));
        _sendError('Invalid message format');
        return;
      }

      logger.d(
          'Processing message: ${message.type} with payload: ${message.payload}');
      _handleData(message);
    } catch (e) {
      logger.e('Failed to parse message length: $e\nBuffer: $bufferStr');
      _statusController
          .add(SyncStatus(SyncState.error, 'Failed to parse message: $e'));
      _sendError('Invalid message format');
      return;
    }
  }

  void _handleData(SyncMessage message) {
    switch (message.type) {
      case 'hlo':
        _handleHello(message.payload);
        break;
      case 'ack':
        _handleAck();
        break;
      case 'brk':
        _handleBreak();
        break;
      default:
        _sendError('Unknown message type: ${message.type}');
    }
  }

  void _sendHello() {
    final payload = jsonEncode({
      'version': appVersion,
      'key': base64Encode(sessionKey),
    });
    final message =
        SyncMessage('hlo', payload: base64Encode(utf8.encode(payload)));
    socket.write('${message.toProtocol()}\n');
  }

  void _sendError(String error) {
    logger.e(error);
    final message =
        SyncMessage('err', payload: base64Encode(utf8.encode(error)));
    socket.write('${message.toProtocol()}\n');
    _statusController.add(SyncStatus(SyncState.error, error));
    close();
  }

  void _sendCount(int count) {
    final message = SyncMessage('cnt', payload: count.toString());
    socket.write('${message.toProtocol()}\n');
    logger.d('Sent count: $count');
    _waitingForAck = true; // Expect ack after sending count
  }

  void _sendBreak() {
    final message = SyncMessage('brk');
    socket.write('${message.toProtocol()}\n');
    close();
  }

  String _encryptData(String data) {
    final key = Key(Uint8List.fromList(sessionKey));
    final iv = IV.fromSecureRandom(16);
    final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
    final encrypted = encrypter.encrypt(data, iv: iv);

    // Combine IV and encrypted data
    final combined = [...iv.bytes, ...encrypted.bytes];
    return base64Encode(combined);
  }

  String? _decryptData(String encryptedData) {
    try {
      final key = Key(Uint8List.fromList(sessionKey));
      final combined = base64Decode(encryptedData);

      // Extract IV from first 16 bytes
      final iv = IV(Uint8List.fromList(combined.sublist(0, 16)));
      final encrypted = Encrypted(Uint8List.fromList(combined.sublist(16)));

      final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
      final decrypted = encrypter.decrypt(encrypted, iv: iv);

      // Log the decrypted data for debugging
      logger.d('Decrypted data: $decrypted');

      return decrypted;
    } catch (e) {
      logger.e('Failed to decrypt data: $e\nEncrypted data: $encryptedData');
      _statusController
          .add(SyncStatus(SyncState.error, 'Failed to decrypt data: $e'));
      return null;
    }
  }

  void _sendPacket(String data) {
    final encryptedData = _encryptData(data);
    final message = SyncMessage('pac', payload: encryptedData);
    socket.write('${message.toProtocol()}\n');
    _waitingForAck = true;
  }

  void _handleHello(String? payload) {
    if (payload == null) {
      _sendError('Missing hello payload');
      return;
    }

    try {
      final decodedPayload = utf8.decode(base64Decode(payload));
      final data = jsonDecode(decodedPayload);
      final hostVersion = data['version'] as String;
      final hostKey = base64Decode(data['key'] as String);

      // Check version compatibility
      final hostMajor = hostVersion.split('.').first;
      final clientMajor = appVersion.split('.').first;
      if (hostMajor != clientMajor) {
        _sendError('Version mismatch: host=$hostMajor, client=$clientMajor');
        return;
      }

      // Combine keys for session encryption
      for (var i = 0; i < sessionKey.length; i++) {
        sessionKey[i] ^= hostKey[i];
      }

      // Cache all secrets and send count
      _cacheSecrets();
    } catch (e) {
      logger.e('Invalid hello payload: $e\n$payload');
      _sendError('Invalid hello payload: $e');
    }
  }

  Future<void> _cacheSecrets() async {
    try {
      _cachedSecrets = await _storage.getAll();
      _statusController.add(SyncStatus(SyncState.processing,
          'Found ${_cachedSecrets!.length} secrets to sync'));
      _sendCount(_cachedSecrets!.length);
    } catch (e) {
      _sendError('Failed to get secrets: $e');
    }
  }

  void _handleAck() {
    if (!_waitingForAck) {
      logger.e('Unexpected ack');
      _statusController
          .add(SyncStatus(SyncState.error, 'Unexpected ack received'));
      _sendError('Unexpected ack');
      return;
    }
    _waitingForAck = false;

    if (_cachedSecrets == null || _currentIndex >= _cachedSecrets!.length) {
      _statusController
          .add(SyncStatus(SyncState.done, 'Sync completed successfully'));
      _sendBreak();
      return;
    }

    final secret = _cachedSecrets![_currentIndex++];
    try {
      final decryptedValue = _encryption.decryptAES(secret.value ?? '');
      final secretToSend = Secret()
        ..title = secret.title
        ..value = decryptedValue
        ..type = secret.type
        ..createdUTC = secret.createdUTC;
      _statusController.add(SyncStatus(SyncState.processing,
          'Sending secret ${_currentIndex}/${_cachedSecrets!.length}: ${secret.title}'));
      _sendPacket(secretToSend.toString());
      _waitingForAck = true; // Set waiting for ack after sending packet
    } catch (e) {
      _sendError('Failed to decrypt secret: $e');
    }
  }

  void _handleBreak() {
    close();
  }

  void _handleError(Object error) {
    logger.e('Connection error', error: error);
    _statusController
        .add(SyncStatus(SyncState.error, 'Connection error: $error'));
    close();
  }

  void _handleDone() {
    logger.d('Connection closed');
    _statusController.add(SyncStatus(SyncState.done, 'Connection closed'));
    close();
  }

  Future<void> close() async {
    if (_isClosed) return;
    _isClosed = true;
    try {
      await socket.close();
      logger.d('Connection closed');
    } catch (e) {
      logger.e('Error closing connection', error: e);
      _statusController
          .add(SyncStatus(SyncState.error, 'Error closing connection: $e'));
    }
  }
}

class SyncClientConnection {
  final Socket socket;
  final Logger logger;
  final String appVersion;
  final Function()? onFinished;
  final List<int> sessionKey;
  final StorageManager _storage;
  final EncryptionManager _encryption;
  final StreamController<SyncStatus> _statusController;
  bool _isClosed = false;
  bool _waitingForPacket = false;
  int _totalSecrets = 0;
  int _receivedSecrets = 0;
  final List<int> _buffer = [];

  SyncClientConnection(this.socket, this.logger, this.appVersion, this._storage,
      this._encryption, this._statusController, {this.onFinished})
      : sessionKey =
            List<int>.generate(32, (i) => Random.secure().nextInt(256)) {
    socket.listen((data) {
      _buffer.addAll(data);
      _processBuffer();
    }, onError: _handleError, onDone: _handleDone);
    _statusController
        .add(SyncStatus(SyncState.waitingForHost, 'Waiting for host response'));
    _sendHello();
  }

  void _processBuffer() {
    final bufferStr = String.fromCharCodes(_buffer);
    final spaceIndex = bufferStr.indexOf(' ');
    if (spaceIndex == -1) {
      logger.d('Waiting for more data, current buffer: $bufferStr');
      return;
    }

    try {
      final length = int.parse(bufferStr.substring(0, spaceIndex));
      if (bufferStr.length < spaceIndex + 1 + length) {
        logger.d(
            'Waiting for full message, need $length bytes, have ${bufferStr.length - spaceIndex - 1}');
        return;
      }

      final message = SyncMessage.fromProtocol(
          bufferStr.substring(0, spaceIndex + 1 + length));
      _buffer.removeRange(0, spaceIndex + 1 + length);

      if (message == null) {
        logger.e('Invalid message format');
        _statusController
            .add(SyncStatus(SyncState.error, 'Invalid message format'));
        close();
        return;
      }

      logger.d(
          'Processing message: ${message.type} with payload: ${message.payload}');
      _handleData(message);
    } catch (e) {
      logger.e('Failed to parse message length: $e\nBuffer: $bufferStr');
      _statusController
          .add(SyncStatus(SyncState.error, 'Failed to parse message: $e'));
      close();
      return;
    }
  }

  void _handleData(SyncMessage message) {
    switch (message.type) {
      case 'hlo':
        _handleHello(message.payload);
        break;
      case 'cnt':
        _handleCount(message.payload);
        break;
      case 'pac':
        _handlePacket(message.payload);
        break;
      case 'brk':
        _handleBreak();
        break;
      case 'err':
        _handleServerError(message.payload);
        break;
      default:
        logger.e('Unknown message type: ${message.type}');
        _statusController.add(SyncStatus(
            SyncState.error, 'Unknown message type: ${message.type}'));
        close();
    }
  }

  void _sendHello() {
    final payload = jsonEncode({
      'version': appVersion,
      'key': base64Encode(sessionKey),
    });
    final message =
        SyncMessage('hlo', payload: base64Encode(utf8.encode(payload)));
    socket.write('${message.toProtocol()}\n');
  }

  void _sendAck() {
    final message = SyncMessage('ack');
    socket.write('${message.toProtocol()}\n');
  }

  void _sendBreak() {
    final message = SyncMessage('brk');
    socket.write('${message.toProtocol()}\n');
    close();
  }

  String? _decryptData(String encryptedData) {
    try {
      final key = Key(Uint8List.fromList(sessionKey));
      final combined = base64Decode(encryptedData);

      // Extract IV from first 16 bytes
      final iv = IV(Uint8List.fromList(combined.sublist(0, 16)));
      final encrypted = Encrypted(Uint8List.fromList(combined.sublist(16)));

      final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
      final decrypted = encrypter.decrypt(encrypted, iv: iv);

      // Log the decrypted data for debugging
      logger.d('Decrypted data: $decrypted');

      return decrypted;
    } catch (e) {
      logger.e('Failed to decrypt data: $e\nEncrypted data: $encryptedData');
      _statusController
          .add(SyncStatus(SyncState.error, 'Failed to decrypt data: $e'));
      return null;
    }
  }

  void _handleHello(String? payload) {
    if (payload == null) {
      logger.e('Missing hello payload');
      close();
      return;
    }

    try {
      final decodedPayload = utf8.decode(base64Decode(payload));
      final data = jsonDecode(decodedPayload);
      final hostVersion = data['version'] as String;
      final hostKey = base64Decode(data['key'] as String);

      // Check version compatibility
      final hostMajor = hostVersion.split('.').first;
      final clientMajor = appVersion.split('.').first;
      if (hostMajor != clientMajor) {
        logger.e('Version mismatch: host=$hostMajor, client=$clientMajor');
        _statusController.add(SyncStatus(SyncState.error, 'Version mismatch'));
        close();
        return;
      }

      // Combine keys for session encryption
      for (var i = 0; i < sessionKey.length; i++) {
        sessionKey[i] ^= hostKey[i];
      }

      _statusController
          .add(SyncStatus(SyncState.processing, 'Connected to host'));
      _statusController.add(
          SyncStatus(SyncState.waitingForHost, 'Waiting for secrets count'));
    } catch (e) {
      logger.e('Invalid hello payload: $e\n$payload');
      _statusController
          .add(SyncStatus(SyncState.error, 'Invalid hello payload'));
      close();
    }
  }

  void _handleCount(String? payload) {
    if (payload == null) {
      logger.e('Missing count payload');
      close();
      return;
    }

    try {
      _totalSecrets = int.parse(payload);
      logger.d('Received count: $_totalSecrets');
      _statusController.add(SyncStatus(
          SyncState.processing, 'Starting sync of $_totalSecrets secrets'));
      _sendAck();
      _waitingForPacket = true;
    } catch (e) {
      logger.e('Invalid count payload: $e\nPayload: $payload');
      _statusController
          .add(SyncStatus(SyncState.error, 'Invalid count payload'));
      close();
    }
  }

  Future<void> _handlePacket(String? payload) async {
    if (payload == null) {
      logger.e('Missing packet payload');
      close();
      return;
    }

    String? decryptedData;
    try {
      decryptedData = _decryptData(payload);
      if (decryptedData == null) {
        logger.e('Failed to decrypt packet');
        _statusController
            .add(SyncStatus(SyncState.error, 'Failed to decrypt packet'));
        close();
        return;
      }

      final map = jsonDecode(decryptedData);
      final title = map['title'] as String?;

      if (title == null) {
        logger.e('Missing title in secret');
        _statusController
            .add(SyncStatus(SyncState.error, 'Missing title in secret'));
        close();
        return;
      }

      // Check if secret with this title already exists
      final existingSecrets = await _storage.listSecrets(title);
      if (existingSecrets.isNotEmpty) {
        logger.d('Skipping existing secret: $title');
        _statusController.add(SyncStatus(
            SyncState.processing, 'Skipping existing secret: $title'));
        _sendAck();
        return;
      }

      final secret = Secret()
        ..title = title
        ..value = map['value']
        ..type = SecretType.values
            .firstWhere((e) => map['type'].toString().endsWith(e.name))
        ..createdUTC = map['createdUTC'] != null
            ? DateTime.parse(map['createdUTC'])
            : null;

      final encryptedValue = _encryption.encryptAES(secret.value ?? '');
      secret.value = encryptedValue;

      await _storage.addSecret(secret);
      _receivedSecrets++;
      _statusController.add(SyncStatus(SyncState.processing,
          'Received $_receivedSecrets/$_totalSecrets secrets: ${secret.title}'));
      _sendAck();
    } catch (e) {
      logger.e('Failed to process secret: $e\n$decryptedData');
      _statusController
          .add(SyncStatus(SyncState.error, 'Failed to process secret: $e'));
      close();
    }
  }

  void _handleBreak() {
    _statusController
        .add(SyncStatus(SyncState.done, 'Sync completed successfully'));
    close();
  }

  void _handleServerError(String? payload) {
    if (payload != null) {
      try {
        final error = utf8.decode(base64Decode(payload));
        _statusController
            .add(SyncStatus(SyncState.error, 'Server error: $error'));
      } catch (e) {
        _statusController
            .add(SyncStatus(SyncState.error, 'Invalid error payload: $e'));
      }
    }
    close();
  }

  void _handleError(Object error) {
    logger.e('Connection error', error: error);
    _statusController
        .add(SyncStatus(SyncState.error, 'Connection error: $error'));
    close();
  }

  void _handleDone() {
    logger.d('Connection closed');
    _statusController.add(SyncStatus(SyncState.done, 'Connection closed'));
    close();
  }

  void _sendError(String error) {
    logger.e(error);
    final message =
        SyncMessage('err', payload: base64Encode(utf8.encode(error)));
    socket.write('${message.toProtocol()}\n');
    _statusController.add(SyncStatus(SyncState.error, error));
    close();
  }

  Future<void> close() async {
    if (_isClosed) return;
    _isClosed = true;
    try {
      await socket.close();
      logger.d('Connection closed');
      onFinished?.call();
    } catch (e) {
      logger.e('Error closing connection', error: e);
      _statusController
          .add(SyncStatus(SyncState.error, 'Error closing connection: $e'));
    }
  }
}

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

      server.listen((socket) {
        _logger.d(
            'Client connected from ${socket.remoteAddress.address}:${socket.remotePort}');
        SyncHostConnection(socket, _logger, _prefs.getAppVersion(), _storage,
            _encryption, _statusController);
      });

      return AddrInfo(localIp, server.port);
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
          _storage, _encryption, _statusController,
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
