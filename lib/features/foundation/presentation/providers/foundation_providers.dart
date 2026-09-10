import 'package:doctylia_app/app/providers/repository_overrides.dart';
import 'package:doctylia_app/core/errors/app_failure.dart';
import 'package:doctylia_app/features/foundation/data/repositories/mock_foundation_repository.dart';
import 'package:doctylia_app/features/foundation/domain/entities/foundation_status.dart';
import 'package:doctylia_app/features/foundation/domain/repositories/foundation_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final foundationRepositoryProvider = Provider<FoundationRepository>((ref) {
  final source = ref.watch(appDataSourceProvider);
  if (!source.isMock) {
    throw UnsupportedError(
      'Remote repositories are intentionally deferred until integration.',
    );
  }
  return const MockFoundationRepository();
});

final foundationStatusProvider = FutureProvider<FoundationStatus>((ref) async {
  final result = await ref.watch(foundationRepositoryProvider).loadStatus();
  return result.fold(
    onSuccess: (value) => value,
    onFailure: (failure) => throw failure,
  );
});

String foundationErrorMessage(Object error) {
  return error is AppFailure
      ? error.userMessage
      : 'The app foundation could not be checked.';
}
