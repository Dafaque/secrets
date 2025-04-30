import 'package:logger/logger.dart'
    show Logger, Level, DateTimeFormat, PrettyPrinter;
import 'package:flutter/material.dart';
import 'package:secrets/crypto/manager.dart';
import 'package:secrets/preferences/manager.dart';
import 'package:secrets/db/manager.dart';
import 'package:secrets/sync/manager.dart';
import 'package:secrets/view/main.dart';

// https://material-foundation.github.io/material-theme-builder/
// https://romannurik.github.io/AndroidAssetStudio/
const primaryColor = Color(0xFFb0f953);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  Logger logger = Logger(
    level: Level.debug,
    filter: null,
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
  );
  PreferencesManager pManager = PreferencesManager(logger);
  EncryptionManager encManager = EncryptionManager(logger, pManager);
  StorageManager db = StorageManager(logger, pManager);
  SyncManager syncManager = SyncManager(logger, pManager, db, encManager);

  runApp(Entry(db, encManager, pManager, syncManager));
}

class Entry extends StatelessWidget {
  final StorageManager _db;
  final EncryptionManager _encManager;
  final PreferencesManager _pManager;
  final SyncManager _syncManager;
  const Entry(this._db, this._encManager, this._pManager, this._syncManager,
      {super.key});
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
          fontFamily: "Anonymous Pro",
          useMaterial3: true,
          primaryColor: primaryColor,
          colorScheme: const ColorScheme(
            brightness: Brightness.dark,

            primary: primaryColor,
            onPrimary: Color(0xFF1f3700),
            primaryContainer: Color(0xFF88cd29),
            onPrimaryContainer: Color(0xFF1d3300),
            secondary: Color(0xFFadd27e),
            onSecondary: Color(0xFF1f3700),
            secondaryContainer: Color(0xFF284500),
            onSecondaryContainer: Color(0xFFb7dd87),
            tertiary: Color(0xFF73ffa6),
            onTertiary: Color(0xFF00391c),
            tertiaryContainer: Color(0xFF00d678),
            onTertiaryContainer: Color(0xFF00361a),

            surfaceDim: Color(0xFF10150b),
            surface: Color(0xFF10150b),
            surfaceBright: Color(0xFF363b2f),
            surfaceContainerLowest: Color(0xFF0b1006),
            surfaceContainerLow: Color(0xFF191d12),
            surfaceContainer: Color(0xFF1d2116),
            surfaceContainerHigh: Color(0xFF272c20),
            surfaceContainerHighest: Color(0xFF32362a),
            onSurface: Color(0xFFe0e4d3),
            onSurfaceVariant: Color(0xFFc1cab1),
            outline: Color(0xFF8c947d),
            outlineVariant: Color(0xFF424937),

            inverseSurface: Color(0xFFe0e4d3),
            onInverseSurface: Color(0xFF2d3226),
            inversePrimary: Color(0xFF406900),

            error: Color(0xFFffb4ab),
            onError: Color(0xFF690005),
            errorContainer: Color(0xFF93000a),
            onErrorContainer: Color(0xFFffdad6),

            scrim: Color(0xFF000000),
            shadow: Color(0xFF000000),
            // surfaceTint: Color(0xFFFFFFFF),
          )),
      home: MainView(_db, _encManager, _pManager, _syncManager),
    );
  }
}
