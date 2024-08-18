import 'dart:async';

import 'package:flutter/material.dart';
import 'package:loading_indicator/loading_indicator.dart';
import 'package:secrets/crypto/manager.dart';
import 'package:secrets/crypto/state.dart';
import 'package:secrets/db/repository.dart';
import 'package:secrets/db/state.dart';
import 'package:secrets/preferences/manager.dart';
import 'package:secrets/preferences/state.dart';
import 'package:secrets/view/init.dart';
import 'package:secrets/view/secrets.dart';
import 'package:secrets/view/unlock.dart';

enum _ViewState {loading, error, ready, deinitialized}

class MainView extends StatefulWidget {
  final DB _db;
  final EncryptionManager _enc;
  final PreferencesManager _prefs;
  const MainView(
      this._db,
      this._enc,
      this._prefs,
      {super.key});
  @override
  State<MainView> createState() => _MainViewState();
}

class _MainViewState extends State<MainView> {
  _ViewState _loadingState = _ViewState.loading;
  String? _errMsg;
  int _try = 0;

  StreamSubscription<DBState>? _dbStateSub;
  StreamSubscription<EMState>? _encStateSub;
  StreamSubscription<PMState>? _prefsStateSub;

  @override
  void initState() {
    _encStateSub = widget._enc.getStateStream().listen(_onEncState);
    _dbStateSub = widget._db.getStateStream().listen(_onDBState);
    _prefsStateSub = widget._prefs.getStateStream().listen(_onPrefsState);

    widget._prefs.init();
    super.initState();
  }

  void _onPrefsState(PMState state) {
    switch (state) {
      case PMState.loading:
        break;
      case PMState.failed:
        setState(() {
          _loadingState = _ViewState.error;
          _errMsg = "Failed to initialize properties";
        });
        break;
      case PMState.ready:
        _prefsStateSub?.cancel();
        widget._enc.checkInitialized();
        break;
    }
  }

  void _onEncState(EMState state) {
    switch (state) {
      case EMState.noInitialized:
        showModalBottomSheet(
            context: context, builder: _buildInitSheet
        ).then(_onInitSheetDone);
        break;
      case EMState.failed:
      case EMState.initialized:
        showModalBottomSheet(
          isDismissible: true,
          isScrollControlled: false,
            context: context,
            builder: _buildUnlockSheet
        ).then(_onUnlockSheetDone);
      case EMState.loading:
      case EMState.ready:
        widget._db.open();
        break;
      case EMState.deinitialized:
        setState(() {
          _loadingState = _ViewState.deinitialized;
        });
    }
  }
  
  void _onDBState(DBState state) {
    switch (state) {
      case DBState.ready:
        setState(() {
          _loadingState = _ViewState.ready;
        });
        break;
      case DBState.txOk:
        _showSuccessSnackBar();
        break;
      case DBState.txFail:
        _showFailSnackBar();
      case DBState.closed:
      case DBState.failed:
      case DBState.loading:
        break;
    }
  }
  
  Widget _build() {
    switch (_loadingState) {
      case _ViewState.deinitialized:
        return const Center(
          child:  Text("Storage deinitialized"),
        );
      case _ViewState.ready:
        return SecretsView(widget._db, widget._enc);
      case _ViewState.error:
        return Center(
          child: Text(_errMsg ?? "unknown error"),
        );
      case _ViewState.loading:
      default:
        return const Center(
          child: LoadingIndicator(indicatorType: Indicator.ballClipRotateMultiple, colors: [],),
        );
    }
  }
  Widget _buildInitSheet(BuildContext ctx) {
    return const InitView();
  }
  Widget _buildUnlockSheet(BuildContext ctx) {
    return UnlockView(_try, widget._prefs.dropAfter);
  }
  void _onInitSheetDone(dynamic data) {
    widget._enc.initialize(data.toString());
  }
  void _onUnlockSheetDone(dynamic data) {
    if (_try >= widget._prefs.dropAfter-1) {
      widget._prefs.drop();
      widget._enc.drop();
      return;
    }
    _try++;
    widget._enc.open(data.toString());
  }
  void _showSuccessSnackBar() {
    return _showSnackBar("Secrets updated");
  }
  void _showFailSnackBar() {
    return _showSnackBar("Secrets update failed");
  }
  void _showSnackBar(String msg){
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(milliseconds: 1500),
          content: Text(msg),
        )
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _build(), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }

  @override
  void dispose() {
    _dbStateSub?.cancel();
    widget._db.done();
    _prefsStateSub?.cancel();
    widget._prefs.done();
    _encStateSub?.cancel();
    widget._enc.done();
    super.dispose();
  }
}