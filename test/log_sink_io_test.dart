@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zumimo_seller/core/app_logger.dart';

/// Verifies the real file sink. Runs in its own isolate so that calling
/// `AppLogger.init()` does not affect the in-memory tests in
/// app_logger_test.dart.
void main() {
  final envPath = Platform.environment['ZUMIMO_LOG_FILE'];

  test('ZUMIMO_LOG_FILE makes the logger write to an explicit path', () async {
    // The sink reads this when it opens the file.
    final logger = AppLogger.instance;
    await logger.init();
    logger.info('SinkTest', 'first line from the real sink');
    await logger.flush();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await logger.flush();

    expect(logger.fileLocation, envPath);
    expect(logger.isFileLoggingAvailable, isTrue);

    final contents = await File(envPath!).readAsString();
    expect(contents, contains('first line from the real sink'));
    expect(contents, contains('SinkTest'));
  },
      skip: envPath == null
          ? 'set ZUMIMO_LOG_FILE to a writable path to exercise the file sink'
          : null);

  test('every physical log line is prefixed, so the file is greppable', () async {
    final logger = AppLogger.instance;
    await logger.init();
    logger.error('SinkTest', 'boom', StateError('bad'), StackTrace.current);
    await logger.flush();

    final text = await logger.readLog();
    final errorLines =
        text.split('\n').where((l) => l.contains('ERROR')).toList();

    expect(errorLines.length, greaterThan(1),
        reason: 'a stack trace should span several prefixed lines');
    for (final line in errorLines) {
      expect(line, matches(RegExp(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3} \|')));
    }
  });
}