import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'log_sink.dart';

/// Real file-backed sink.
///
/// Writes `flutter.log` into the app documents directory, rotates at
/// [maxBytes] so a long-running session cannot fill the device, and keeps the
/// previous file as `flutter.log.1` so the crash that preceded a rotation is
/// not lost.
///
/// Two environment variables override the location, which is how you point a
/// development run at the project folder instead of the app sandbox:
///
///   ZUMIMO_LOG_FILE=/full/path/to/flutter.log   exact file to append to
///   ZUMIMO_LOG_DIR=/full/path/to/logs           directory to put flutter.log in
///
/// Note that only a desktop/CI run can honour these — a build running on a
/// phone or emulator is sandboxed to the device and cannot reach the project
/// folder. For mobile, use `tool/dev_log.ps1`, which captures stdout into
/// `<project>/flutter.log`.
class IoLogSink implements LogSink {
  IoLogSink({this.maxBytes = 2 * 1024 * 1024});

  static const String fileName = 'flutter.log';
  static const String rotatedFileName = 'flutter.log.1';

  final int maxBytes;

  File? _file;
  IOSink? _handle;
  bool _ready = false;

  @override
  String? get location => _file?.path;

  Future<File> _resolveFile() async {
    if (_file != null) return _file!;

    final sep = Platform.pathSeparator;

    // Explicit override wins — this is the "write into the project folder"
    // escape hatch used by desktop and CI runs.
    final fileOverride = Platform.environment['ZUMIMO_LOG_FILE'];
    if (fileOverride != null && fileOverride.trim().isNotEmpty) {
      final target = File(fileOverride.trim());
      final parent = target.parent;
      if (!await parent.exists()) {
        await parent.create(recursive: true);
      }
      return _file = target;
    }

    final dirOverride = Platform.environment['ZUMIMO_LOG_DIR'];
    if (dirOverride != null && dirOverride.trim().isNotEmpty) {
      final target = Directory(dirOverride.trim());
      if (!await target.exists()) {
        await target.create(recursive: true);
      }
      return _file = File('${target.path}$sep$fileName');
    }

    final dir = await getApplicationDocumentsDirectory();
    final logsDir = Directory('${dir.path}${Platform.pathSeparator}logs');
    if (!await logsDir.exists()) {
      await logsDir.create(recursive: true);
    }
    return _file = File('${logsDir.path}${Platform.pathSeparator}$fileName');
  }

  Future<void> _ensureOpen() async {
    if (_ready) return;
    try {
      final file = await _resolveFile();
      if (!await file.exists()) {
        await file.create(recursive: true);
      }
      final size = await file.length();
      if (size > maxBytes) {
        await _rotate(file);
      }
      _handle = file.openWrite(mode: FileMode.append);
      _ready = true;
    } catch (_) {
      // A log that cannot be written must never take the app down with it.
      _ready = false;
    }
  }

  Future<void> _rotate(File file) async {
    try {
      await _handle?.close();
      _handle = null;
      final rotated = File('${file.path}.1');
      if (await rotated.exists()) {
        await rotated.delete();
      }
      await file.rename(rotated.path);
      await file.create(recursive: true);
    } catch (_) {
      // If rotation fails just keep appending; rotation is best-effort.
    }
  }

  @override
  Future<void> write(String line) async {
    await _ensureOpen();
    final handle = _handle;
    if (handle == null) return;
    try {
      handle.writeln(line);
    } catch (_) {}
  }

  @override
  Future<void> flush() async {
    try {
      await _handle?.flush();
    } catch (_) {}
  }

  @override
  Future<String?> readAll() async {
    try {
      final file = await _resolveFile();
      if (!await file.exists()) return '';
      return await file.readAsString();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<int> sizeBytes() async {
    try {
      final file = await _resolveFile();
      if (!await file.exists()) return 0;
      return await file.length();
    } catch (_) {
      return 0;
    }
  }

  @override
  Future<void> clear() async {
    try {
      await _handle?.close();
      _handle = null;
      _ready = false;
      final file = await _resolveFile();
      if (await file.exists()) {
        await file.delete();
      }
      final rotated = File('${file.path}.1');
      if (await rotated.exists()) {
        await rotated.delete();
      }
      _ready = false;
    } catch (_) {}
  }

  /// Copies the log to a shareable temp file and returns its path, or null when
  /// unavailable. Used by the share button so the user can send the log to
  /// themselves without digging through the app sandbox.
  @override
  Future<String?> exportCopy() async {
    await flush();
    try {
      final file = await _resolveFile();
      if (!await file.exists()) return null;
      final tmp = File('${(await getTemporaryDirectory()).path}'
          '${Platform.pathSeparator}zumimo-$fileName');
      await tmp.writeAsString(await file.readAsString());
      return tmp.path;
    } catch (_) {
      return null;
    }
  }
}

LogSink createLogSink() => IoLogSink();