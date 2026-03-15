import 'package:flutter/foundation.dart';

/// Structured logger following format: [LEVEL] [COMPONENT] [ACTION] Message (key=value, ...)
class Logger {
  final String component;

  const Logger(this.component);

  void debug(String action, String message, [Map<String, dynamic>? metadata]) {
    _log('DEBUG', action, message, metadata);
  }

  void info(String action, String message, [Map<String, dynamic>? metadata]) {
    _log('INFO', action, message, metadata);
  }

  void warn(String action, String message, [Map<String, dynamic>? metadata]) {
    _log('WARN', action, message, metadata);
  }

  void error(String action, String message, [Map<String, dynamic>? metadata]) {
    _log('ERROR', action, message, metadata);
  }

  void _log(String level, String action, String message,
      Map<String, dynamic>? metadata) {
    final timestamp = DateTime.now().toIso8601String();
    final buffer = StringBuffer();
    buffer.write('[$level] [$component] [$action] $message');

    if (metadata != null && metadata.isNotEmpty) {
      buffer.write(' (');
      final entries = metadata.entries.map((e) => '${e.key}=${e.value}');
      buffer.write(entries.join(', '));
      buffer.write(')');
    }

    // Use debugPrint to avoid truncation in production
    if (kDebugMode) {
      debugPrint('[$timestamp] ${buffer.toString()}');
    }
  }

  /// Log exception with stack trace
  void exception(String action, String message, dynamic error,
      [StackTrace? stackTrace]) {
    final metadata = {
      'error': error.toString(),
      if (stackTrace != null) 'stack': stackTrace.toString().split('\n').first,
    };
    this.error(action, message, metadata);
  }
}
