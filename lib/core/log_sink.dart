/// Contract for persisting log lines somewhere durable.
///
/// Implemented twice: `log_sink_io.dart` writes a real `flutter.log` file on
/// mobile/desktop, `log_sink_stub.dart` is a no-op for web (where `dart:io`
/// does not exist). `AppLogger` talks only to this interface so it never has to
/// care which one it got.
abstract class LogSink {
  /// Human-readable location of the log, shown in the viewer. Null when the
  /// platform cannot persist a file.
  String? get location;

  /// Append [line] (already formatted, newline included) to the log.
  Future<void> write(String line);

  /// Push any buffered data out to storage.
  Future<void> flush();

  /// Whole log contents, or null when unavailable.
  Future<String?> readAll();

  /// Size of the stored log in bytes.
  Future<int> sizeBytes();

  /// Truncate the stored log.
  Future<void> clear();

  /// Copy the log to a shareable location and return its path, or null when the
  /// platform cannot do that (web). Used by the share action.
  Future<String?> exportCopy();
}