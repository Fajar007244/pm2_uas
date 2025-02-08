import 'package:flutter/foundation.dart';

class Logger {
  final String? context;

  Logger([this.context]);

  void _log(String level, String message, {dynamic error, StackTrace? stackTrace}) {
    if (kDebugMode) {
      final contextPrefix = context != null ? '[$context] ' : '';
      print('$level: $contextPrefix$message');
      if (error != null) {
        print('$level details: $error');
      }
      if (stackTrace != null) {
        print('$level stack trace: $stackTrace');
      }
    }
  }

  void d(String message, {dynamic error, StackTrace? stackTrace}) {
    _log('DEBUG', message, error: error, stackTrace: stackTrace);
  }

  void e(String message, {dynamic error, StackTrace? stackTrace}) {
    _log('ERROR', message, error: error, stackTrace: stackTrace);
  }

  void i(String message, {dynamic error}) {
    _log('INFO', message, error: error);
  }

  void w(String message, {dynamic error}) {
    _log('WARNING', message, error: error);
  }
}
