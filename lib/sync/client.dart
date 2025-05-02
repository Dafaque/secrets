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

class SyncClientConnection {
  final Socket _socket;
  final Logger _logger;
  final String appVersion;
  final Function()? onFinished;
  final List<int> _sessionKey;
  final StorageManager _storage;
  final EncryptionManager _encryption;
  final StreamController<SyncStatus> _statusController;
  bool _isClosed = false;
  int _totalSecrets = 0;
  int _receivedSecrets = 0;
  final List<int> _buffer = [];

  SyncClientConnection(this._socket, this._logger, this.appVersion,
      this._storage, this._encryption, this._statusController, this._sessionKey,
      {this.onFinished}) {
    _socket.listen((data) {
      _buffer.addAll(data);
      _processBuffer();
    }, onError: _handleError, onDone: _handleDone);
    _statusController
        .add(SyncStatus(SyncState.waitingForHost, 'Waiting for host response'));
    _sendHello();
  }

  void _processBuffer() {
    final bufferStr = String.fromCharCodes(_buffer);
    _logger.d('Processing buffer: $bufferStr');
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

      final rawMessage = bufferStr.substring(0, spaceIndex + 1 + length);
      final message = SyncMessage.fromProtocol(rawMessage);
      _buffer.removeRange(0, spaceIndex + 1 + length);

      if (message == null) {
        _logger.e('Invalid message format: <$rawMessage>');
        _statusController
            .add(SyncStatus(SyncState.error, 'Invalid message format'));
        close();
        return;
      }

      _logger.d(
          'Processing message: ${message.type} with payload: ${message.payload}');
      _handleData(message);
    } catch (e) {
      _logger.e('Failed to parse message length: $e\nBuffer: $bufferStr');
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
        _logger.e('Unknown message type: ${message.type}');
        _statusController.add(SyncStatus(
            SyncState.error, 'Unknown message type: ${message.type}'));
        close();
    }
  }

  void _sendHello() {
    final message = SyncMessage('hlo', payload: appVersion);
    _socket.write('${message.toProtocol()}\n');
  }

  void _sendAck() {
    final message = SyncMessage('ack');
    _socket.write('${message.toProtocol()}\n');
  }

  String? _decryptData(String encryptedData) {
    try {
      final key = Key(Uint8List.fromList(_sessionKey));
      final combined = base64Decode(encryptedData);

      // Extract IV from first 16 bytes
      final iv = IV(Uint8List.fromList(combined.sublist(0, 16)));
      final encrypted = Encrypted(Uint8List.fromList(combined.sublist(16)));

      final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
      final decrypted = encrypter.decrypt(encrypted, iv: iv);

      return decrypted;
    } catch (e) {
      _logger.e('Failed to decrypt data: $e\nEncrypted data: $encryptedData');
      _statusController
          .add(SyncStatus(SyncState.error, 'Failed to decrypt data: $e'));
      return null;
    }
  }

  void _handleHello(String? payload) {
    if (payload == null) {
      _logger.e('Missing hello payload');
      close();
      return;
    }

    try {
      final hostVersion = payload;

      // Check version compatibility
      final hostMajor = hostVersion.split('.').first;
      final clientMajor = appVersion.split('.').first;
      if (hostMajor != clientMajor) {
        _logger.e('Version mismatch: host=$hostMajor, client=$clientMajor');
        _statusController.add(SyncStatus(SyncState.error, 'Version mismatch'));
        close();
        return;
      }

      _statusController
          .add(SyncStatus(SyncState.processing, 'Connected to host'));
      _statusController.add(
          SyncStatus(SyncState.waitingForHost, 'Waiting for secrets count'));
    } catch (e) {
      _logger.e('Invalid hello payload: $e\n$payload');
      _statusController
          .add(SyncStatus(SyncState.error, 'Invalid hello payload'));
      close();
    }
  }

  void _handleCount(String? payload) {
    if (payload == null) {
      _logger.e('Missing count payload');
      close();
      return;
    }

    try {
      _totalSecrets = int.parse(payload);
      _logger.d('Received count: $_totalSecrets');
      _statusController.add(SyncStatus(
          SyncState.processing, 'Starting sync of $_totalSecrets secrets'));
      _sendAck();
    } catch (e) {
      _logger.e('Invalid count payload: $e\nPayload: $payload');
      _statusController
          .add(SyncStatus(SyncState.error, 'Invalid count payload'));
      close();
    }
  }

  Future<void> _handlePacket(String? payload) async {
    if (payload == null) {
      _logger.e('Missing packet payload');
      close();
      return;
    }

    String? decryptedData;
    try {
      decryptedData = _decryptData(payload);
      if (decryptedData == null) {
        _logger.e('Failed to decrypt packet');
        _statusController
            .add(SyncStatus(SyncState.error, 'Failed to decrypt packet'));
        close();
        return;
      }

      final map = jsonDecode(decryptedData);
      final title = map['title'] as String?;

      if (title == null) {
        _logger.e('Missing title in secret');
        _statusController
            .add(SyncStatus(SyncState.error, 'Missing title in secret'));
        close();
        return;
      }

      // Check if secret with this title already exists
      final existingSecrets = await _storage.listSecrets(title);
      if (existingSecrets.isNotEmpty) {
        _logger.d('Skipping existing secret: $title');
        _statusController
            .add(SyncStatus(SyncState.processing, 'Skipping existing secret'));
        _sendAck();
        _receivedSecrets++;
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
          'Received $_receivedSecrets/$_totalSecrets secrets'));
      _sendAck();
    } catch (e) {
      _logger.e('Failed to process secret: $e\n$decryptedData');
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
      onFinished?.call();
    } catch (e) {
      _logger.e('Error closing connection', error: e);
      _statusController
          .add(SyncStatus(SyncState.error, 'Error closing connection: $e'));
    }
  }
}
