
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

  List<Secret> listSecrets(String title) {
    return _db!.secrets.filter().titleContains(title).findAllSync();
  }

  void addSecret(Secret s) {
    try {
      _db!.writeTxn(() async {
        _db!.secrets.put(s);
      }).then((_){
        _stateController.sink.add(DBState.txOk);
      }).onError((e, _){
        _onTxError(e, "failed to add secret");
      });
    } catch (e, _) {
      _onTxError(e, "failed to add secret");
    }
  }

  void deleteSecret(String strId) {
    Id id;
    try {
      id = Id.parse(strId);
    } catch(e, _) {
      _onTxError(e, "failed to parse id");
      return;
    }
    _rmByID(id);

  }
  void _rmByID(Id id) {
    try {
      _db!.writeTxn(() async {
        _db!.secrets.delete(id);
      }).then((_){
        _stateController.sink.add(DBState.txOk);
      }).onError((e, _){
        _onTxError(e, "failed to rm secret");
      });
    } catch (e, _) {
      _onTxError(e, "failed to rm secret");
    }
  }

  void _onTxError(Object? e, msg) {
    _logger.e("msg", error: e);
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