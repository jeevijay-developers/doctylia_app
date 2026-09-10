import 'package:doctylia_app/core/storage/preferences_store.dart';
import 'package:doctylia_app/features/onboarding/domain/repositories/onboarding_repository.dart';

final class PreferencesOnboardingRepository implements OnboardingRepository {
  const PreferencesOnboardingRepository(this._preferences);

  static const _onboardingSeenKey = 'has_seen_onboarding';
  final PreferencesStore _preferences;

  @override
  Future<bool> hasSeenOnboarding() async {
    return await _preferences.getBool(_onboardingSeenKey) ?? false;
  }

  @override
  Future<void> markOnboardingSeen() {
    return _preferences.setBool(_onboardingSeenKey, true);
  }
}
