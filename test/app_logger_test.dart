import 'package:flutter_test/flutter_test.dart';
import 'package:zumimo_seller/core/app_logger.dart';

void main() {
  group('AppLogger.redact', () {
    test('masks bearer tokens', () {
      final out = AppLogger.redact('Authorization: Bearer abc123def456.ghi789');
      expect(out.contains('abc123def456'), isFalse);
      expect(out.contains('<redacted>'), isTrue);
    });

    test('masks json token fields but keeps the rest of the payload', () {
      const input = '{"access_token":"secret-value","user_id":42}';
      final out = AppLogger.redact(input);
      expect(out.contains('secret-value'), isFalse);
      expect(out.contains('42'), isTrue);
      expect(out.contains('user_id'), isTrue);
    });

    test('masks refresh_token, phone_token and password', () {
      for (final field in ['refresh_token', 'phone_token', 'password']) {
        final out = AppLogger.redact('{"$field":"leak-me"}');
        expect(out.contains('leak-me'), isFalse, reason: field);
      }
    });

    test('masks secret env assignments', () {
      final out = AppLogger.redact('TIKTOK_CLIENT_SECRET=supersecret123');
      expect(out.contains('supersecret123'), isFalse);
    });

    test('masks X-API-KEY header', () {
      final out = AppLogger.redact('X-API-KEY: topsecretkey');
      expect(out.contains('topsecretkey'), isFalse);
    });

    test('leaves ordinary diagnostics untouched', () {
      const input = '← GET /products 200 (143ms) fields=[name, price]';
      expect(AppLogger.redact(input), input);
    });

    test('does not crash on null-ish or odd input', () {
      expect(AppLogger.redact(''), '');
      expect(AppLogger.redact('{"unclosed": '), '{"unclosed": ');
      expect(AppLogger.redact('Bearer'), 'Bearer');
    });
  });

  group('LogEntry.format', () {
    test('produces a stable, greppable line shape', () {
      final when = DateTime(2026, 10, 2, 14, 22, 31, 123);
      final line = AppLogger.format(when, LogLevel.error, 'ApiClient', 'boom');
      expect(line, '2026-10-02 14:22:31.123 | ERROR | ApiClient    | boom');
    });

    test('keeps a level/tag separator in every line so logs can be filtered', () {
      final when = DateTime(2026, 1, 1);
      for (final level in LogLevel.values) {
        final line = AppLogger.format(when, level, 'Tag', 'msg');
        expect(line.split('|').length, 4);
        expect(line.contains(level.label), isTrue);
      }
    });

    test('headers every line of a multi-line error so grep still matches', () {
      final when = DateTime(2026, 10, 2, 9, 0, 0);
      final entry = LogEntry(
        when,
        LogLevel.error,
        'ApiClient',
        'request failed\nat Foo.bar()\nat Baz.qux()',
      );
      final lines = entry.formatted.split('\n');
      expect(lines.length, 3);
      for (final line in lines) {
        expect(line, startsWith('2026-10-02 09:00:00.000 |'));
        expect(line, contains('ERROR'));
        expect(line, contains('ApiClient'));
      }
    });

    test('collapses blank continuation lines instead of emitting bare newlines', () {
      final when = DateTime(2026, 10, 2);
      final entry = LogEntry(when, LogLevel.error, 'Tag', 'head\n\n   \ntail');
      expect(entry.formatted.split('\n').length, 2);
    });
  });

  group('logging pipeline', () {
    test('records entries in the ring buffer and respects level filtering', () async {
      final logger = AppLogger.instance;
      logger.setDebugEnabled(true);

      logger.info('Test', 'visible info');
      logger.error('Test', 'visible error');
      expect(logger.entries.any((e) => e.message == 'visible info'), isTrue);
      expect(logger.entries.any((e) => e.message == 'visible error'), isTrue);

      logger.setDebugEnabled(false);
      logger.debug('Test', 'should be dropped');
      expect(logger.entries.any((e) => e.message == 'should be dropped'), isFalse);

      logger.setDebugEnabled(true);
    });

    test('guard() swallows and logs errors instead of rethrowing', () async {
      final logger = AppLogger.instance;
      final result = await logger.guard<String>(
        'Test',
        'deliberate failure',
        () async => throw StateError('kaboom'),
      );
      expect(result, isNull);
      expect(
        logger.entries.any(
          (e) => e.level == LogLevel.error && e.message.contains('deliberate failure'),
        ),
        isTrue,
      );
    });

    test('guard() returns the value and runs onSuccess', () async {
      final logger = AppLogger.instance;
      var seen = '';
      final result = await logger.guard<String>(
        'Test',
        'deliberate success',
        () async => 'value',
        onSuccess: (v) => seen = v,
      );
      expect(result, 'value');
      expect(seen, 'value');
    });

    test('cap the ring buffer so a long session cannot grow without bound', () {
      final logger = AppLogger.instance;
      for (var i = 0; i < 1200; i++) {
        logger.info('Flood', 'entry $i');
      }
      expect(logger.entries.length, lessThanOrEqualTo(1000));
    });
  });
}