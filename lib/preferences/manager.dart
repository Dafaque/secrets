import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';

const String _cfgFileName = "config.json";
const String _dropAfterKey = "drop_after";
const String _checkSumKey = "checksum";
const int _defaultDropAfter = 3;


class PreferencesManager {
  Directory _documents = Directory.current;
  final Logger _logger;
  Map<String, dynamic> _prefs = {
    _dropAfterKey: _defaultDropAfter,
  };

  PreferencesManager(this._logger);

  Future<void> init() {
    return getApplicationDocumentsDirectory().then((Directory dir){
      _logger.i("documents directory found");
      _documents = dir;
      File cfgFile = File(_getConfigFilePath());
      return cfgFile;
    }).then((File cfgFile) {
      return cfgFile.exists().then((bool ok) {
        if (!ok) {
          cfgFile.writeAsString(jsonEncode(_prefs));
          _logger.i("config file created");
        }
        return;
      }).then((_){
        _logger.i("loading config file");
        return cfgFile.readAsString();
      }).then((String cfgFileContent){
        _prefs = jsonDecode(cfgFileContent);
        _logger.i("config file loaded: $_prefs");
      }).catchError((Object? e, StackTrace _){
        _logger.e("failed to init preferences", error: e);
      });
    });
  }

  Directory getDocumentsDirectory() {
    return _documents;
  }
  Future<void> drop() {
    _logger.i("deinitializing");
    return File(_getConfigFilePath()).delete();
  }

  String _getConfigFilePath(){
    String path = _documents.path;
    if (path.endsWith("/")) {
      path = path.trimRight();
    }
    return "$path/$_cfgFileName";
  }
  void done() {}

  Future<void> save(){
    return File(_getConfigFilePath()).writeAsString(jsonEncode(_prefs)).
      catchError((Object? e){
        const msg = "failed to save preferences";
        _logger.e(msg, error: e);
        throw msg;
    });
  }

  void setDropAfter(int dropAfter) {
    _prefs[_dropAfterKey] = dropAfter;
  }
  int getDropAfter() {
    if (!_prefs.containsKey(_dropAfterKey)){
      return _defaultDropAfter;
    }
    return _prefs[_dropAfterKey];
  }
}