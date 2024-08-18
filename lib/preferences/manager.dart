import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:secrets/preferences/state.dart';

const String _cfgFileName = "config.yml";
const String _dropAfterKey = "drop_after";
const String _checkSumKey = "checksum";

class PreferencesManager {
  Directory _documents = Directory.current;
  final Logger _logger;
  final StreamController<PMState> _stateController = StreamController<PMState>();

  int dropAfter = 0;

  PreferencesManager(this._logger);

  void init() async {
    Map<String, dynamic> prefs = {
      _dropAfterKey: 3,
    };
    getApplicationDocumentsDirectory().then((Directory dir){
      _logger.i("documents directory found");
      _documents = dir;
      File cfgFile = File(_getConfigFilePath());
      return cfgFile;
    }).then((File cfgFile) {
      cfgFile.exists().then((bool ok) {
        if (!ok) {
          cfgFile.writeAsString(jsonEncode(prefs));
          _logger.i("config file created");
        }
        return;
      }).then((_){
        _logger.i("loading config file");
        return cfgFile.readAsString();
      }).then((String cfgFileContent){
        prefs = jsonDecode(cfgFileContent);
        _logger.i("config file loaded: $prefs");
        dropAfter = prefs[_dropAfterKey] ?? 3;
        _stateController.sink.add(PMState.ready);
      }).catchError((Object? e, StackTrace _){
        _logger.e("failed to init preferences", error: e);
        _stateController.sink.add(PMState.failed);
      });
    }).catchError((Object? e, StackTrace _){
      _logger.e("failed to init preferences", error: e);
      _stateController.sink.add(PMState.failed);
    });
    return;

  }
  Stream<PMState> getStateStream() {
    return _stateController.stream;
  }

  Directory getDocumentsDirectory() {
    return _documents;
  }
  void drop() {
    String path = _documents.path;
    if (path.endsWith("/")) {
      path = path.trimRight();
    }
    File cfg = File(_getConfigFilePath());
    cfg.deleteSync();
  }

  String _getConfigFilePath(){
    String path = _documents.path;
    if (path.endsWith("/")) {
      path = path.trimRight();
    }
    return "$path/$_cfgFileName";
  }
  void done() {
    _stateController.close();
  }

}