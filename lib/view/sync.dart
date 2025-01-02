import 'package:flutter/material.dart';
import 'package:secrets/crypto/manager.dart';
import 'package:secrets/db/manager.dart';
import 'package:secrets/preferences/manager.dart';
import 'package:secrets/sync/manager.dart';

class SyncView extends StatefulWidget {
  final StorageManager _db;
  final EncryptionManager _enc;
  final PreferencesManager _prefs;
  const SyncView(this._db, this._enc, this._prefs, {super.key});

  @override
  State<SyncView> createState() => _SyncViewState();
}

class _SyncViewState extends State<SyncView> {
  SyncManager? _syncManager;
  @override
  void initState() {
    super.initState();
    _syncManager = SyncManager(widget._db, widget._enc, widget._prefs);
    _syncManager!.startServer();
  }

  @override
  void dispose() {
    _syncManager?.stopServer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Sync")),
    );
  }
}
