import 'package:doctylia_app/core/errors/repository_guard.dart';
import 'package:doctylia_app/core/result/result.dart';
import 'package:doctylia_app/features/practice_setup/domain/entities/practice_setup.dart';
import 'package:doctylia_app/features/practice_setup/domain/repositories/practice_setup_repository.dart';

/// Mock mode: accepts the details and returns the would-be slug; persists
/// nothing (mock sessions carry no profiles row, so setup never shows).
final class MockPracticeSetupRepository implements PracticeSetupRepository {
  const MockPracticeSetupRepository();

  @override
  String? signedInMobile() => '9876543210';

  @override
  Future<Result<String>> complete(PracticeSetupDetails details) {
    return RepositoryGuard.run(() => practiceSlugFor(details.fullName));
  }
}
