import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:loading_indicator/loading_indicator.dart';
import 'package:secrets/crypto/manager.dart';
import 'package:secrets/db/manager.dart';
import 'package:secrets/preferences/manager.dart';
import 'package:secrets/sync/manager.dart';
import 'package:secrets/view/init.dart';
import 'package:secrets/view/secrets.dart';
import 'package:secrets/view/unlock.dart';

enum _ViewState { loading, error, ready, deinitialized }

class MainView extends StatefulWidget {
  final StorageManager _db;
  final EncryptionManager _enc;
  final PreferencesManager _prefs;
  final SyncManager _syncManager;
  const MainView(this._db, this._enc, this._prefs, this._syncManager,
      {super.key});
  @override
  State<MainView> createState() => _MainViewState();
}

class _MainViewState extends State<MainView> {
  _ViewState _loadingState = _ViewState.loading;
  String? _errMsg;
  int _try = 0;

  @override
  void initState() {
    widget._prefs.init().then((_) {
      return widget._enc.checkInitialized();
    }).then(_encInitialize);
    super.initState();
  }

  void _encInitialize(bool encInitialized) {
    if (encInitialized) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context)
            .push(MaterialPageRoute(builder: _buildUnlockSheet))
            .then(_onUnlockSheetDone);
      });
      return;
    }
    SchedulerBinding.instance.addPostFrameCallback((_) {
      Navigator.of(context)
          .push(MaterialPageRoute(builder: _buildInitSheet))
          .then(_onInitSheetDone);
    });
  }

  Widget _build() {
    switch (_loadingState) {
      case _ViewState.deinitialized:
        return const Center(
          child: Text("Storage deinitialized"),
        );
      case _ViewState.ready:
        return SecretsView(
            widget._db, widget._enc, widget._prefs, widget._syncManager);
      case _ViewState.error:
        return Center(
          child: Text(_errMsg ?? "unknown error"),
        );
      case _ViewState.loading:
      default:
        return const Center(
          child: LoadingIndicator(
            indicatorType: Indicator.ballClipRotateMultiple,
            colors: [],
          ),
        );
    }
  }

  Widget _buildInitSheet(BuildContext ctx) {
    return const InitView();
  }

  Widget _buildUnlockSheet(BuildContext ctx) {
    return UnlockView(_try, widget._prefs.getDropAfter());
  }

  void _onInitSheetDone(dynamic pin) {
    if (pin == null) {
      _encInitialize(false);
      return;
    }
    widget._enc
        .initialize(pin.toString())
        .then((_) => _initStorageManage())
        .catchError((Object? e) {
      _encInitialize(false);
    });
  }

  void _onUnlockSheetDone(dynamic pin) {
    if (_try >= widget._prefs.getDropAfter() - 1) {
      widget._enc.drop().then((_) => widget._prefs.drop()).then((_) {
        setState(() {
          _loadingState = _ViewState.deinitialized;
        });
      });
      return;
    }
    _try++;
    widget._enc
        .open(pin.toString())
        .then((_) => _initStorageManage())
        .catchError((Object? e) {
      _encInitialize(true);
    });
  }

  void _initStorageManage() {
    widget._db.open().then((_) {
      setState(() {
        _loadingState = _ViewState.ready;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _build(),
    );
  }

  @override
  void dispose() {
    widget._db.done();
    widget._prefs.done();
    widget._enc.done();
    super.dispose();
  }
}
