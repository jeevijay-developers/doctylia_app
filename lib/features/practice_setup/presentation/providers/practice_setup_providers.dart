import 'package:doctylia_app/app/providers/repository_overrides.dart';
import 'package:doctylia_app/features/practice_setup/data/repositories/mock_practice_setup_repository.dart';
import 'package:doctylia_app/features/practice_setup/domain/repositories/practice_setup_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final practiceSetupRepositoryProvider = Provider<PracticeSetupRepository>((
  ref,
) {
  final source = ref.watch(appDataSourceProvider);
  if (!source.isMock) {
    throw UnsupportedError(
      'Override practiceSetupRepositoryProvider with the Supabase repository.',
    );
  }
  return const MockPracticeSetupRepository();
});
