import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import 'log_sink.dart';
import 'log_sink_stub.dart' if (dart.library.io) 'log_sink_io.dart';

/// ============================================================================
/// app_logger.dart
///
/// App-wide logging. Every log line goes to two places:
///
///  1. the platform console (debug builds only, so release builds stay quiet)
///  2. `flutter.log` in the app documents directory (see LogSink)
///
/// Plus an in-memory ring buffer, which is what the in-app log viewer renders
/// so it works on web too and does not have to re-read a multi-megabyte file.
///
/// Usage:
///   AppLogger.instance.info('Orders', 'loaded 12 orders');
///   AppLogger.instance.error('ApiClient', 'boom', error, stackTrace);
/// ============================================================================

enum LogLevel {
  debug('DEBUG', 0),
  info('INFO', 1),
  warn('WARN', 2),
  error('ERROR', 3);

  const LogLevel(this.label, this.severity);

  final String label;
  final int severity;

  String get padded => label.padRight(5);
}

class LogEntry {
  final DateTime time;
  final LogLevel level;
  final String tag;
  final String message;

  const LogEntry(this.time, this.level, this.tag, this.message);

  /// Every physical line gets the timestamp/level/tag header, including
  /// continuation lines of a multi-line stack trace. Without this, grep or
  /// Select-String on the log only matches the first line of an error and you
  /// lose track of which request it belonged to.
  String get formatted {
    final lines = message.split('\n');
    final buffer = StringBuffer(AppLogger.format(time, level, tag, lines.first));
    for (final line in lines.skip(1)) {
      if (line.trim().isEmpty) {
        continue;
      }
      buffer.write('\n');
      buffer.write(AppLogger.format(time, level, tag, line.trim()));
    }
    return buffer.toString();
  }

  Map<String, dynamic> toJson() => {
        'time': time.toIso8601String(),
        'level': level.label,
        'tag': tag,
        'message': message,
      };
}

class AppLogger {
  AppLogger._();

  static final AppLogger instance = AppLogger._();

  LogSink? _sink;

  /// Newest-last ring buffer backing the in-app viewer.
  final Queue<LogEntry> _buffer = Queue<LogEntry>();
  static const int _maxBufferEntries = 1000;

  /// Serialises writes so two log calls can never interleave mid-line.
  Future<void> _writeQueue = Future<void>.value();

  bool _initialised = false;

  /// When false, debug-level lines are dropped before doing any work.
  bool _debugEnabled = kDebugMode;

  /// Below this level nothing is persisted. Defaults to `debug` in debug
  /// builds and `info` in release builds.
  LogLevel _minLevel = kDebugMode ? LogLevel.debug : LogLevel.info;

  String? get fileLocation => _sink?.location;
  bool get isFileLoggingAvailable => _sink?.location != null;
  bool get isInitialised => _initialised;

  List<LogEntry> get entries => List.unmodifiable(_buffer);

  // --------------------------------------------------------------------
  // SETUP
  // --------------------------------------------------------------------

  Future<void> init({bool? forceDebugLogging}) async {
    if (_initialised) return;
    _initialised = true;

    if (forceDebugLogging != null) {
      _debugEnabled = forceDebugLogging;
    }

    try {
      _sink = createLogSink();
    } catch (e) {
      _sink = createLogSink();
      debugPrint('[AppLogger] sink init failed: $e');
    }

final sink = _sink;
      final banner = StringBuffer()
        ..writeln('=== Onbaio Seller log started ===')
        ..writeln('platform : ${defaultTargetPlatform.name}')
        ..writeln('mode     : ${kDebugMode ? "debug" : "release"}')
        ..writeln('==========================');

      for (final line in banner.toString().split('\n')) {
        if (line.trim().isEmpty) continue;
        _record(LogLevel.info, 'App', line);
      }

      // Force the sink to open now rather than on the first log call, so a
      // permissions/rotation failure surfaces here instead of silently later.
      await sink?.readAll();
      await flush();

      _record(
        LogLevel.info,
        'App',
        'log file : ${sink?.location ?? 'unavailable (in-memory only)'}',
      );
      await flush();
    }

  /// Turns verbose logging on/off at runtime (the viewer has a toggle).
  void setDebugEnabled(bool enabled) {
    if (_debugEnabled == enabled) return;
    _debugEnabled = enabled;
    _minLevel = enabled ? LogLevel.debug : LogLevel.info;
  }

  bool get debugEnabled => _debugEnabled;

  // --------------------------------------------------------------------
  // CORE
  // --------------------------------------------------------------------

  static String format(DateTime time, LogLevel level, String tag, String message) {
    final t = time.toIso8601String().replaceFirst('T', ' ').split('.').first;
    final ms = time.millisecond.toString().padLeft(3, '0');
    return '$t.$ms | ${level.padded} | ${tag.padRight(12)} | $message';
  }

  void debug(String tag, String message) => log(LogLevel.debug, tag, message);

  void info(String tag, String message) => log(LogLevel.info, tag, message);

  void warn(String tag, String message, [Object? error]) => log(
        LogLevel.warn,
        tag,
        error == null ? message : '$message — $error',
      );

  void error(
    String tag,
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ]) {
    final buffer = StringBuffer(message);
    if (error != null) buffer.write(' — $error');
    if (stackTrace != null) {
      buffer.write('\n${stackTrace.toString().trimRight()}');
    }
    log(LogLevel.error, tag, buffer.toString());
  }

  /// A visible divider, useful for separating a sequence of related steps.
  void section(String title) {
    log(LogLevel.info, 'Section', '── $title ──');
  }

  void log(LogLevel level, String tag, String message) {
    if (level.severity < _minLevel.severity) return;

    final entry = LogEntry(
      DateTime.now(),
      level,
      tag,
      AppLogger.redact(message),
    );

    _buffer.addLast(entry);
    while (_buffer.length > _maxBufferEntries) {
      _buffer.removeFirst();
    }

    if (kDebugMode) {
      debugPrint(entry.formatted);
    }

    _writeToSink(entry);
  }

  void _record(LogLevel level, String tag, String message) {
    final entry = LogEntry(DateTime.now(), level, tag, message);
    _buffer.addLast(entry);
    while (_buffer.length > _maxBufferEntries) {
      _buffer.removeFirst();
    }
    if (kDebugMode) debugPrint(entry.formatted);
    _writeToSink(entry);
  }

  void _writeToSink(LogEntry entry) {
    final sink = _sink;
    if (sink == null) return;
    _writeQueue = _writeQueue.then((_) async {
      try {
        await sink.write(entry.formatted);
      } catch (_) {
        // Never let logging break the caller.
      }
    });
  }

  // --------------------------------------------------------------------
  // REDACTION
  // --------------------------------------------------------------------

  /// Masks credentials before anything is written. The log gets shared over
  /// WhatsApp/support, so tokens and secrets must never survive in it.
  static String redact(String input) {
    var out = input;

    // Authorization: Bearer <token>
    out = out.replaceAll(
      RegExp(r'Bearer\s+[A-Za-z0-9\-._~+/]+=*', caseSensitive: false),
      'Bearer <redacted>',
    );

    // JSON fields: keep the key, drop the value.
    out = out.replaceAllMapped(
      RegExp(
        r'("(?:access_token|refresh_token|phone_token|token|api_key|apikey|'
        r'secret|password|api_secret_key|authorization)"\s*:\s*")([^"]*)(")',
        caseSensitive: false,
      ),
      (m) => '${m.group(1)}<redacted>${m.group(3)}',
    );

    // Env-style assignments: TIKTOK_CLIENT_SECRET=..., API_SECRET_KEY: ...
    out = out.replaceAll(
      RegExp(
        r'(TIKTOK_CLIENT_SECRET|API_SECRET_KEY|ZUMIMO_API_SECRET_KEY)'
        r'(\s*[=:]\s*)\S+',
        caseSensitive: false,
      ),
      r'$1$2<redacted>',
    );

    // Header form.
    out = out.replaceAll(
      RegExp(r'X-API-KEY:\s*\S+', caseSensitive: false),
      'X-API-KEY: <redacted>',
    );

    return out;
  }

  // --------------------------------------------------------------------
  // OUTPUT
  // --------------------------------------------------------------------

  Future<String> readLog() async {
    final fromFile = await _sink?.readAll();
    if (fromFile != null && fromFile.isNotEmpty) return fromFile;
    return _buffer.map((e) => e.formatted).join('\n');
  }

  Future<int> sizeBytes() async => await _sink?.sizeBytes() ?? _estimateBufferBytes();

  int _estimateBufferBytes() {
    var total = 0;
    for (final e in _buffer) {
      total += e.formatted.length + 1;
    }
    return total;
  }

  /// Path to a shareable copy of the log, or null when unavailable.
  Future<String?> exportCopy() async {
    await flush();
    final path = await _sink?.exportCopy();
    if (path != null) return path;
    // Web / no sink: fall back to writing the buffer somewhere share_plus can
    // still use. Returns null when that is impossible too.
    return null;
  }

  Future<void> flush() async {
    await _writeQueue;
    await _sink?.flush();
  }

  Future<void> clear() async {
    _buffer.clear();
    await _sink?.clear();
    info('App', 'Log cleared by user.');
    await flush();
  }

  /// Runs [body] and logs whatever it throws, returning null on failure.
  /// Lets call sites get error logging without wrapping everything in
  /// try/catch by hand.
  Future<T?> guard<T>(
    String tag,
    String description,
    Future<T> Function() body, {
    void Function(T value)? onSuccess,
  }) async {
    final started = DateTime.now();
    try {
      final result = await body();
      final ms = DateTime.now().difference(started).inMilliseconds;
      info(tag, '$description ok (${ms}ms)');
      onSuccess?.call(result);
      return result;
    } catch (e, st) {
      final ms = DateTime.now().difference(started).inMilliseconds;
      error(tag, '$description failed (${ms}ms)', e, st);
      return null;
    }
  }

  // --------------------------------------------------------------------
  // GLOBAL ERROR HANDLERS
  //
  // Installed from main.dart rather than here: it needs to be inside the same
  // runZonedGuarded that wraps startup, and FlutterError.onError /
  // PlatformDispatcher.onError both have to be assigned before runApp.
  // --------------------------------------------------------------------
}