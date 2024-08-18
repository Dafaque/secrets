import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart';
import 'package:logger/logger.dart';
import 'package:secrets/crypto/rand.dart';
import 'package:secrets/crypto/state.dart';
import 'package:secrets/preferences/manager.dart';

class EncryptionManager {
  final Logger _logger;
  Key _key = Key.allZerosOfLength(32);
  IV _iv = IV.allZerosOfLength(16);
  final StreamController<EMState> _stateController = StreamController<EMState>();
  final PreferencesManager _prefs;
  EncryptionManager(this._logger, this._prefs);

  void checkInitialized() async {
    final File encFile = File(_getEncFilePath());
    if (!await encFile.exists()) {
      _stateController.sink.add(EMState.noInitialized);
      return;
    }
    _stateController.sink.add(EMState.initialized);
  }

  void initialize(String pin) {
    String ivString = randomHexString(16);
    String encFileContent = "iv=$ivString";
    try {
      Digest digest = sha256.convert(pin.runes.toList());
      _key = Key.fromUtf8(digest.toString().substring(0,32));
      final String encrypted = encryptAES(encFileContent);

      final File encFile = File(_getEncFilePath());
      encFile.writeAsString(encrypted);
    } catch(e,_) {
      _logger.e("failed to save .enc file", error: e);
      _stateController.sink.add(EMState.failed);
      return;
    }
    _iv = IV.fromUtf8(ivString);
    _stateController.sink.add(EMState.ready);
  }

  void open(String pin) async {
    try {
      Digest digest = sha256.convert(pin.runes.toList());
      _key = Key.fromUtf8(digest.toString().substring(0,32));
      final File encFile = File(_getEncFilePath());
      final String content = await encFile.readAsString();
      final paramsStr = decryptAES(content);
      if (!paramsStr.startsWith("iv=")) {
        throw "Corrupted .enc file";
      }
      _iv = IV.fromUtf8(paramsStr.substring(3));
    } catch(e, _) {
      _logger.e("failed to open .enc file", error: e);
      _stateController.sink.add(EMState.failed);
      return;
    }
    _stateController.sink.add(EMState.ready);
  }

  String _getEncFilePath() {
    String basePath = _prefs.getDocumentsDirectory().path;
    if (basePath.endsWith("/")) {
      basePath = basePath.trimRight();
    }
    return "$basePath/.enc";
  }
  String encryptAES(String text) {
    return Encrypter(AES(_key)).encrypt(text, iv: _iv).base64;
  }
  String decryptAES(String b64cipher) {
    return Encrypter(AES(_key)).decrypt(Encrypted.fromBase64(b64cipher), iv: _iv);
  }
  Stream<EMState> getStateStream() {
    return _stateController.stream;
  }
  void done() {
    _stateController.close();
  }
  void drop(){
    File f = File(_getEncFilePath());
    f.deleteSync();
    _stateController.sink.add(EMState.deinitialized);
  }
}