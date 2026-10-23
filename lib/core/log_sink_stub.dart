import 'log_sink.dart';

/// Web fallback. `dart:io` does not exist in a browser, so nothing is written
/// to disk; `AppLogger` still keeps its in-memory ring buffer, which is what
/// the log viewer displays on this platform.
class StubLogSink implements LogSink {
  @override
  String? get location => null;

  @override
  Future<void> write(String line) async {}

  @override
  Future<void> flush() async {}

  @override
  Future<String?> readAll() async => null;

  @override
  Future<int> sizeBytes() async => 0;

  @override
  Future<void> clear() async {}

  @override
  Future<String?> exportCopy() async => null;
}

LogSink createLogSink() => StubLogSink();