import 'package:logger/logger.dart' show Logger, Level, DateTimeFormat, PrettyPrinter;
import 'package:flutter/material.dart';
import 'package:secrets/crypto/manager.dart';
import 'package:secrets/preferences/manager.dart';
import 'package:secrets/db/repository.dart';
import 'package:secrets/view/main.dart';

const primaryColor = Color(0xFFffb3b4);

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
  DB db = DB(logger, pManager);

  runApp(Entry(db, encManager, pManager));
}

class Entry extends StatelessWidget {
  final DB _db;
  final EncryptionManager  _encManager;
  final PreferencesManager _pManager;
  const Entry(
      this._db,
      this._encManager,
      this._pManager,
      {super.key});
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: primaryColor,
        colorScheme: const ColorScheme(
          brightness: Brightness.dark,
          primary: primaryColor,
          onPrimary: Color(0xFF561d22),
          primaryContainer: Color(0xFF733337),
          onPrimaryContainer: Color(0xFFffdada),
          secondary: Color(0xFFe6bdbd),
          onSecondary: Color(0xFF44292a),
          secondaryContainer: Color(0xFF5d3f40),
          onSecondaryContainer: Color(0xFFffdada),
          tertiary: Color(0xFFe6c18d),
          onTertiary: Color(0xFF422c05),
          tertiaryContainer: Color(0xFF5b421a),
          onTertiaryContainer: Color(0xFFffddb0),

          surface: Color(0xFF1a1111),
          onSurface: Color(0xFFf0dede),
          surfaceDim: Color(0xFF1a1111),
          surfaceBright: Color(0xFF413737),
          surfaceContainerLowest: Color(0xFF140c0c),
          surfaceContainerLow: Color(0xFF221919),
          surfaceContainer: Color(0xFF271d1d),
          surfaceContainerHigh: Color(0xFF322828),
          surfaceContainerHighest: Color(0xFF3d3232),
          onSurfaceVariant: Color(0xFFd7c1c1),
          outline: Color(0xFF9f8c8c),
          outlineVariant: Color(0xFF524343),
          scrim: Color(0xFF000000),
          shadow: Color(0xFF000000),
          inverseSurface: Color(0xFFf0dede),
          onInverseSurface: Color(0xFF382e2e),
          inversePrimary: Color(0xFF8f4a4d),
          // surfaceTint: Color(0xFFFFFFFF),

          error: Color(0xFFffb4ab),
          onError: Color(0xFF690005),
          errorContainer: Color(0xFF93000a),
          onErrorContainer: Color(0xFFffdad6),
        )
      ),

      home: MainView(_db, _encManager, _pManager),
    );
  }
}

