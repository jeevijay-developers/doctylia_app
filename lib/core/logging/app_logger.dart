import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

abstract final class AppLogger {
  static void info(String message) {
    developer.log(message, name: 'Doctylia');
    if (kDebugMode) debugPrint('[Doctylia] $message');
  }

  static void error(String message, {Object? error, StackTrace? stackTrace}) {
    developer.log(
      message,
      name: 'Doctylia',
      error: error,
      stackTrace: stackTrace,
      level: 1000,
    );
    if (kDebugMode) {
      debugPrint('[Doctylia] ERROR: $message');
      if (error != null) debugPrint('  $error');
      if (stackTrace != null) debugPrintStack(stackTrace: stackTrace);
    }
  }
}
