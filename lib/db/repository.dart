
import 'dart:async';

import 'package:isar/isar.dart';
import 'package:logger/logger.dart';
import 'package:secrets/db/secret.dart';
import 'package:secrets/db/state.dart';
import 'package:secrets/preferences/manager.dart';

final class DB {
  final Logger _logger;
  final PreferencesManager _prefs;
  final DBState state = DBState.loading;
  final StreamController<DBState> _stateController = StreamController<DBState>();
  Isar? _db;

  DB(this._logger, this._prefs);

  void open() async {
    try {
      _db = await Isar.open(
        [SecretSchema],
        directory: _prefs.getDocumentsDirectory().path,
        name: "secrets",
        inspector: false,
      );
    } catch(e, _) {
      _stateController.sink.add(DBState.failed);
      return;
    }
    _stateController.sink.add(DBState.ready);
  }

  Future<List<Secret>> listSecrets(String title) {
    return _db!.secrets.filter().titleContains(title).findAll();
  }

  Future<void> createSecret(Secret s) {
    if (_db == null) {
      return Future<void>((){});
    }
    return _db!.writeTxn(() async {
      return _db!.secrets.put(s);
    }).then((_){
      _stateController.sink.add(DBState.txOk);
    }).onError((e, _){
      _onTxError(e, "failed to add secret");
    });
  }

  Future<void> deleteSecret(String strId) {
    Id id;
    try {
      id = Id.parse(strId);
    } catch(e, _) {
      _onTxError(e, "failed to parse id");
      return Future<void>((){});
    }
    return _rmByID(id);
  }

  Future<void> _rmByID(Id id) {
    if (_db == null) {
      _onTxError(null, "failed to rm secret; _db is null");
      return Future<void>((){});
    }
    return _db!.writeTxn(() async {
      return _db!.secrets.delete(id);
    }).then((_){
      _stateController.sink.add(DBState.txOk);
    }).onError((e, _){
      _onTxError(e, "failed to rm secret");
    });
  }

  Future<int> countSecrets() {
    try {
      return _db!.secrets.count();
    } catch(e, _) {
      _logger.e("failed to count secrets", error: e);
      return Future<int>(()=> 0);
    }
  }
  void _onTxError(Object? e, msg) {
    _logger.e(msg, error: e);
    _stateController.sink.add(DBState.txFail);
  }
  Stream<DBState> getStateStream() {
    return _stateController.stream;
  }
  void done(){
    _stateController.close();
    _db?.close();
  }
}