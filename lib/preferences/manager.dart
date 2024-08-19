import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';

const String _cfgFileName = "config.yml";
const String _dropAfterKey = "drop_after";
const String _checkSumKey = "checksum";

class PreferencesManager {
  Directory _documents = Directory.current;
  final Logger _logger;
  Map<String, dynamic> _prefs = {
    _dropAfterKey: 3,
  };

  int dropAfter = 0;

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
        dropAfter = _prefs[_dropAfterKey] ?? 3;
        _logger.i("initialized");
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
    String path = _documents.path;
    if (path.endsWith("/")) {
      path = path.trimRight();
    }
    File cfg = File(_getConfigFilePath());
    return cfg.delete();
  }

  String _getConfigFilePath(){
    String path = _documents.path;
    if (path.endsWith("/")) {
      path = path.trimRight();
    }
    return "$path/$_cfgFileName";
  }
  void done() {}

  void setDropAfter(int dropAfter) {
    _prefs[_dropAfterKey] = dropAfter;
  }
}