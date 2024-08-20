
import 'dart:async';

import 'package:isar/isar.dart';
import 'package:logger/logger.dart';
import 'package:secrets/db/secret.dart';
import 'package:secrets/preferences/manager.dart';

final class StorageManager {
  final Logger _logger;
  final PreferencesManager _prefs;
  Isar? _db;

  StorageManager(this._logger, this._prefs);

  Future<void> open() {
    return Isar.open(
      [SecretSchema],
      directory: _prefs.getDocumentsDirectory().path,
      name: "secrets",
      inspector: false,
    ).then((Isar db){
      _db = db;
      _logger.i("initialized");
    }).catchError((Object? e) {
      const msg = "failed to open db";
      _logger.e(msg, error: e);
      throw msg;
    });
  }

  Future<List<Secret>> listSecrets(String title) {
    return _db!.secrets.filter().
      titleContains(title).
      findAll().
      catchError((Object? e) {
      const msg = "failed to list secrets";
      _logger.e(msg, error: e);
      throw msg;
    });
  }

  Future<void> addSecret(Secret s) {
    if (_db == null) {
      throw "failed to add secret: db is null";
    }
    return _db!.writeTxn(() {
      return _db!.secrets.put(s);
    }).catchError((Object? e) {
      const msg = "failed to add secret";
      _logger.e(msg, error: e);
      throw msg;
    });
  }

  Future<void> deleteSecret(String strId) {
    if (_db == null) {
      throw "failed to delete secret: db is null";
    }
    Id id;
    id = Id.parse(strId);
    return _db!.writeTxn(() {
      return _db!.secrets.delete(id);
    }).catchError((Object? e) {
      const msg = "failed to delete secret";
      _logger.e(msg, error: e);
      throw msg;
    });
  }

  Future<int> countSecrets() {
    if (_db == null) {
      throw "failed to count secret: db is null";
    }
    return _db!.secrets.count().catchError((Object? e) {
      const msg = "failed to count secrets";
      _logger.e(msg, error: e);
      throw msg;
    });
  }

  void done(){
    _db?.close();
  }
  Future<void> drop(){
    if (_db == null) {
      throw "failed to drop secrets: db is null";
    }
    return _db!.writeTxn(() {
      return _db!.secrets.clear();
    }).catchError((Object? e) {
      const msg = "failed to drop secrets";
      _logger.e(msg, error: e);
      throw msg;
    });
  }
}