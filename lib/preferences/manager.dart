import 'dart:async';
import 'dart:io';

import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:secrets/preferences/state.dart';

class PreferencesManager {
  Directory? _documents;
  final Logger _logger;
  final StreamController<PMState> _stateController = StreamController<PMState>();
  PreferencesManager(this._logger);

  void init() async {
    try {
      _documents = await getApplicationDocumentsDirectory();
    } catch(e, _) {
      _logger.e("failed to get documents dir", error: e);
      _stateController.sink.add(PMState.failed);
      return;
    }
    _stateController.sink.add(PMState.ready);
  }
  Stream<PMState> getStateStream() {
    return _stateController.stream;
  }

  Directory getDocumentsDirectory() {
    if (_documents == null) {
      return Directory.current;
    }
    return _documents!;
  }

  void done() {
    _stateController.close();
  }
}