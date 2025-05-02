import 'package:logger/logger.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:async';
import 'package:encrypt/encrypt.dart';
import 'package:secrets/db/manager.dart';
import 'package:secrets/db/secret.dart';
import 'package:secrets/crypto/manager.dart';
import 'package:secrets/sync/model.dart';

class SyncHostConnection {
  final Socket _socket;
  final Logger _logger;
  final String _appVersion;
  final StorageManager _storage;
  final EncryptionManager _encryption;
  final StreamController<SyncStatus> _statusController;
  final List<int> _sessionKey;
  bool _isClosed = false;
  bool _waitingForAck = false;
  List<Secret>? _cachedSecrets;
  int _currentIndex = 0;
  final List<int> _buffer = [];

  SyncHostConnection(
      this._socket,
      this._logger,
      this._appVersion,
      this._storage,
      this._encryption,
      this._statusController,
      this._sessionKey) {
    _socket.listen((data) {
      _buffer.addAll(data);
      _processBuffer();
    }, onError: _handleError, onDone: _handleDone);
    _sendHello();
  }

  void _processBuffer() {
    final bufferStr = String.fromCharCodes(_buffer);
    final spaceIndex = bufferStr.indexOf(' ');
    if (spaceIndex == -1) {
      _logger.d('Waiting for more data, current buffer: $bufferStr');
      return;
    }

    try {
      final length = int.parse(bufferStr.substring(0, spaceIndex));
      if (bufferStr.length < spaceIndex + 1 + length) {
        _logger.d(
            'Waiting for full message, need $length bytes, have ${bufferStr.length - spaceIndex - 1}');
        return;
      }

      final message = SyncMessage.fromProtocol(
          bufferStr.substring(0, spaceIndex + 1 + length));
      _buffer.removeRange(0, spaceIndex + 1 + length);

      if (message == null) {
        _logger.e('Invalid message format');
        _statusController
            .add(SyncStatus(SyncState.error, 'Invalid message format'));
        _sendError('Invalid message format');
        return;
      }

      _logger.d(
          'Processing message: ${message.type} with payload: ${message.payload}');
      _handleData(message);
    } catch (e) {
      _logger.e('Failed to parse message length: $e\nBuffer: $bufferStr');
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
    final message = SyncMessage('hlo', payload: _appVersion);
    _socket.write('${message.toProtocol()}\n');
  }

  void _sendError(String error) {
    _logger.e(error);
    final message = SyncMessage('err', payload: error);
    _socket.write('${message.toProtocol()}\n');
    _statusController.add(SyncStatus(SyncState.error, error));
    close();
  }

  void _sendCount(int count) {
    final message = SyncMessage('cnt', payload: count.toString());
    _socket.write('${message.toProtocol()}\n');
    _waitingForAck = true; // Expect ack after sending count
    _logger.d('Sent count: $count');
  }

  void _sendBreak() {
    final message = SyncMessage('brk');
    _socket.write('${message.toProtocol()}\n');
    close();
  }

  String _encryptData(String data) {
    final key = Key(Uint8List.fromList(_sessionKey));
    final iv = IV.fromSecureRandom(16);
    final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
    final encrypted = encrypter.encrypt(data, iv: iv);

    // Combine IV and encrypted data
    final combined = [...iv.bytes, ...encrypted.bytes];
    return base64Encode(combined);
  }

  void _sendPacket(String data) {
    final encryptedData = _encryptData(data);
    final message = SyncMessage('pac', payload: encryptedData);
    _socket.write('${message.toProtocol()}\n');
    _waitingForAck = true;
  }

  void _handleHello(String? payload) {
    if (payload == null) {
      _sendError('Missing hello payload');
      return;
    }

    try {
      final hostVersion = payload;

      // Check version compatibility
      final hostMajor = hostVersion.split('.').first;
      final clientMajor = _appVersion.split('.').first;
      if (hostMajor != clientMajor) {
        _sendError('Version mismatch: host=$hostMajor, client=$clientMajor');
        return;
      }

      // Cache all secrets and send count
      _cacheSecrets();
    } catch (e) {
      _logger.e('Invalid hello payload: $e\n$payload');
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
      _logger.e('Unexpected ack');
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
          'Sending secret $_currentIndex/${_cachedSecrets!.length}'));
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
    _logger.e('Connection error', error: error);
    _statusController
        .add(SyncStatus(SyncState.error, 'Connection error: $error'));
    close();
  }

  void _handleDone() {
    _logger.d('Done called');
    close();
  }

  Future<void> close() async {
    if (_isClosed) return;
    _isClosed = true;
    try {
      await _socket.close();
      _logger.d('Connection closed');
      _statusController.add(SyncStatus(SyncState.done, 'Connection closed'));
    } catch (e) {
      _logger.e('Error closing connection', error: e);
      _statusController
          .add(SyncStatus(SyncState.error, 'Error closing connection: $e'));
    }
  }
}
