import 'package:doctylia_app/core/errors/app_failure.dart';
import 'package:doctylia_app/core/errors/repository_guard.dart';
import 'package:doctylia_app/core/result/result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('repository guard preserves known failures', () async {
    final result = await RepositoryGuard.run<void>(
      () => throw const ValidationFailure('Invalid input'),
    );

    expect(result, isA<Failure<void>>());
    expect((result as Failure<void>).failure, isA<ValidationFailure>());
  });

  test('repository guard maps unexpected errors centrally', () async {
    final result = await RepositoryGuard.run<void>(
      () => throw StateError('internal detail'),
    );

    expect(result, isA<Failure<void>>());
    expect((result as Failure<void>).failure, isA<UnknownFailure>());
    expect(
      result.failure.userMessage,
      'Something went wrong. Please try again.',
    );
  });
}
