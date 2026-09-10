import 'dart:async';

import 'package:doctylia_app/core/errors/app_failure.dart';
import 'package:doctylia_app/core/logging/app_logger.dart';
import 'package:doctylia_app/core/result/result.dart';

abstract final class RepositoryGuard {
  static Future<Result<T>> run<T>(FutureOr<T> Function() operation) async {
    try {
      return Success(await operation());
    } on AppFailure catch (failure) {
      AppLogger.error(
        'Repository operation failed',
        error: failure.cause ?? failure,
        stackTrace: failure.stackTrace,
      );
      return Failure(failure);
    } catch (error, stackTrace) {
      AppLogger.error(
        'Unexpected repository error',
        error: error,
        stackTrace: stackTrace,
      );
      return Failure(UnknownFailure(cause: error, stackTrace: stackTrace));
    }
  }
}
