import 'package:doctylia_app/core/result/result.dart';
import 'package:doctylia_app/features/practice_setup/domain/entities/practice_setup.dart';

abstract interface class PracticeSetupRepository {
  /// The signed-in number, used to prefill the clinic phone (10 digits).
  String? signedInMobile();

  /// Saves the profile, assigns a unique website slug and marks onboarding
  /// complete. Returns the slug (for "View My Website").
  Future<Result<String>> complete(PracticeSetupDetails details);
}
