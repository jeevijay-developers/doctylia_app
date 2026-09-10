import 'package:doctylia_app/core/storage/preferences_store.dart';
import 'package:doctylia_app/features/onboarding/data/repositories/preferences_onboarding_repository.dart';
import 'package:doctylia_app/features/onboarding/domain/repositories/onboarding_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final onboardingRepositoryProvider = Provider<OnboardingRepository>((ref) {
  return PreferencesOnboardingRepository(ref.watch(preferencesStoreProvider));
});

final onboardingSeenProvider =
    AsyncNotifierProvider<OnboardingController, bool>(OnboardingController.new);

class OnboardingController extends AsyncNotifier<bool> {
  @override
  Future<bool> build() {
    return ref.read(onboardingRepositoryProvider).hasSeenOnboarding();
  }

  Future<void> complete() async {
    await ref.read(onboardingRepositoryProvider).markOnboardingSeen();
    state = const AsyncData(true);
  }
}
