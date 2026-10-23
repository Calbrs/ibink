import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart'
    show debugPrint, debugPrintSynchronously, kDebugMode;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/theme.dart';
import 'core/session.dart';
import 'core/api_client.dart';
import 'core/app_logger.dart';
import 'core/local_storage.dart';
import 'routes/app_routes.dart';

/// Wraps startup so that anything thrown before `runApp` still reaches the log
/// instead of vanishing into the console.
Future<void> main() async {
  runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Flutter's default debugPrint is throttled and silently DROPS lines
      // under load. During development that means a holey log file and missing
      // errors, so switch to the synchronous variant.
      if (kDebugMode) {
        debugPrint = debugPrintSynchronously;
      }

      // Logger first: everything after this point is covered.
      await AppLogger.instance.init();

      FlutterError.onError = (details) {
        AppLogger.instance.error(
          'FlutterError',
          details.exceptionAsString(),
          details.exception,
          details.stack,
        );
        FlutterError.presentError(details);
      };
      PlatformDispatcher.instance.onError = (error, stack) {
        AppLogger.instance.error(
          'PlatformError',
          'Uncaught async/platform error',
          error,
          stack,
        );
        return true;
      };

      AppLogger.instance.section('App startup');
      await AppLogger.instance.guard('Bootstrap', 'load .env', () async {
        await dotenv.load(fileName: '.env');
      });

      AppLogger.instance.info(
        'Bootstrap',
        'API base URL: ${_safeBaseUrl()}',
      );

      AppLogger.instance.info(
        'Bootstrap',
        'Log file: ${AppLogger.instance.fileLocation ?? 'console only (no file sink on this platform)'}',
      );

      await AppLogger.instance.guard('Bootstrap', 'restore session', () async {
        await Session.instance.init();
        await LocalStorage.instance.init();
        ApiClient.instance.restoreTokenFromSession();
      });

      AppLogger.instance.info(
        'Bootstrap',
        'Session restored, loggedIn=${Session.instance.isLoggedIn}',
      );

      runApp(const ZumimoApp());
    },
    (error, stack) {
      AppLogger.instance.error('Zone', 'Uncaught error', error, stack);
    },
  );
}

String _safeBaseUrl() {
  try {
    return dotenv.env['API_BASE_URL'] ?? 'unknown';
  } catch (_) {
    return 'unavailable';
  }
}

class ZumimoApp extends StatefulWidget {
  const ZumimoApp({super.key});

  @override
  State<ZumimoApp> createState() => _ZumimoAppState();
}

class _ZumimoAppState extends State<ZumimoApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Transparent status bar + edge-to-edge so content draws under it.
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemStatusBarContrastEnforced: false,
        systemNavigationBarContrastEnforced: false,
      ),
    );
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Flush whenever the app leaves the foreground — that is the last reliable
    // moment before the OS may kill the process and take buffered logs with it.
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      AppLogger.instance.flush();
      if (state == AppLifecycleState.paused) {
        AppLogger.instance.debug('App', 'App paused, log flushed.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Onbaio Seller',
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,
      theme: AppTheme.theme,
    );
  }
}