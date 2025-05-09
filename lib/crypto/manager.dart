import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart';
import 'package:logger/logger.dart';
import 'package:secrets/crypto/rand.dart';
import 'package:secrets/preferences/manager.dart';

class EncryptionManager {
  final Logger _logger;
  Key _key = Key.allZerosOfLength(32);
  IV _iv = IV.allZerosOfLength(16);
  final PreferencesManager _prefs;
  EncryptionManager(this._logger, this._prefs);

  Future<bool> checkInitialized() {
    return File(_getEncFilePath()).exists();
  }

  Future<void> initialize(String pin) {
    String ivString = randomHexString(16);
    String encFileContent = "iv=$ivString";
    Digest digest = sha256.convert(pin.runes.toList());
    _key = Key.fromUtf8(digest.toString().substring(0,32));
    final String encrypted = encryptAES(encFileContent);

    final File encFile = File(_getEncFilePath());
    return encFile.writeAsString(encrypted).then((_){
      _iv = IV.fromUtf8(ivString);
      _logger.i("initialized");
    });
  }
  Future<void> open(String pin) {
    Digest digest = sha256.convert(pin.runes.toList());
    _key = Key.fromUtf8(digest.toString().substring(0,32));
    return File(_getEncFilePath()).readAsString().then((String content){
      try {
         String paramsStr = decryptAES(content);
         if (!paramsStr.startsWith("iv=")) {
           throw "Corrupted .enc file";
         }
         _iv = IV.fromUtf8(paramsStr.substring(3));
         _logger.i("initialized");
      } catch(e) {
        const msg = "failed to open .enc file";
        _logger.e(msg, error: e);
        throw msg;
      }
    });
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
  void done() {}
  Future<void> drop(){
    _logger.i("deinitializing");
    File f = File(_getEncFilePath());
    return f.delete();
  }
}