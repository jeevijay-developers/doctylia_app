abstract interface class OnboardingRepository {
  Future<bool> hasSeenOnboarding();
  Future<void> markOnboardingSeen();
}
