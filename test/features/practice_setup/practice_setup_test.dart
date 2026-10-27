import 'package:doctylia_app/app/providers/repository_overrides.dart';
import 'package:doctylia_app/app/app.dart';
import 'package:doctylia_app/app/router/app_router.dart';
import 'package:doctylia_app/core/storage/preferences_store.dart';
import 'package:doctylia_app/features/auth/domain/entities/doctor_profile.dart';
import 'package:doctylia_app/features/auth/domain/entities/doctor_session.dart';
import 'package:doctylia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:doctylia_app/features/auth/presentation/state/auth_state.dart';
import 'package:doctylia_app/shared/entitlements/plan_status.dart';
import '../../support/fake_preferences_store.dart';
import 'package:doctylia_app/core/data/app_data_source.dart';
import 'package:doctylia_app/core/result/result.dart';
import 'package:doctylia_app/core/theme/app_theme.dart';
import 'package:doctylia_app/features/practice_setup/domain/entities/india_states_cities.dart';
import 'package:doctylia_app/features/practice_setup/domain/entities/practice_setup.dart';
import 'package:doctylia_app/features/practice_setup/domain/repositories/practice_setup_repository.dart';
import 'package:doctylia_app/features/practice_setup/presentation/providers/practice_setup_providers.dart';
import 'package:doctylia_app/features/practice_setup/presentation/screens/practice_setup_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final class _RecordingRepository implements PracticeSetupRepository {
  PracticeSetupDetails? saved;

  @override
  String? signedInMobile() => '9876543210';

  @override
  Future<Result<String>> complete(PracticeSetupDetails details) async {
    saved = details;
    return Success(practiceSlugFor(details.fullName));
  }
}

void main() {
  group('web parity helpers', () {
    test('slug matches the web generateSlug', () {
      expect(practiceSlugFor('Dr. Rahul Sharma'), 'dr-rahul-sharma');
      expect(practiceSlugFor('dr Meera  Shah!'), 'dr-meera-shah');
      expect(practiceSlugFor('Anil Kumar'), 'anil-kumar');
    });

    test('phone check matches the web step-2 rule', () {
      expect(normalizeIndianMobile('+91 98765-43210'), '9876543210');
      expect(normalizeIndianMobile('09876543210'), '9876543210');
      expect(normalizeIndianMobile('5876543210'), isNull);
      expect(normalizeIndianMobile('98765'), isNull);
    });

    test('states sorted; cities sorted per state', () {
      expect(indiaStates.length, 36);
      expect(indiaStates.first, 'Andaman and Nicobar Islands');
      final cities = citiesForState('Goa');
      expect(cities, [...cities]..sort());
      expect(citiesForState(null), isEmpty);
    });
  });

  testWidgets('router sends a not-yet-onboarded doctor to setup', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDataSourceProvider.overrideWithValue(const AppDataSource.mock()),
          preferencesStoreProvider.overrideWithValue(
            FakePreferencesStore({'has_seen_onboarding': true}),
          ),
          authControllerProvider.overrideWith(_NewDoctorAuth.new),
          splashMinimumElapsedProvider.overrideWith((ref) async {}),
          practiceSetupRepositoryProvider.overrideWithValue(
            _RecordingRepository(),
          ),
        ],
        child: const DoctyliaApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(PracticeSetupScreen), findsOneWidget);
    expect(find.text('Tell Us About You'), findsOneWidget);
    expect(find.text('Dr. New'), findsOneWidget);
  });

  testWidgets('walks details → clinic → review → live', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final repository = _RecordingRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDataSourceProvider.overrideWithValue(const AppDataSource.mock()),
          practiceSetupRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const PracticeSetupScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Step 1 validates like the web.
    expect(find.text('Tell Us About You'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Please enter your full name'), findsOneWidget);
    expect(find.text('Please select your specialization'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'Dr. Meera Shah');
    await tester.tap(find.text('Select specialization'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dermatologist').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(1), 'MBBS, MD');
    await tester.enterText(find.byType(TextFormField).at(2), '12');
    await tester.enterText(find.byType(TextFormField).at(3), '700');
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // Step 2: phone is prefilled from the login number.
    expect(find.text('Your Clinic'), findsWidgets);
    expect(find.text('9876543210'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(0), 'Care Clinic');
    await tester.tap(find.text('Select state'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bihar').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select city'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Begusarai').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).last, '1 Clinic Road');
    await tester.ensureVisible(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // Step 3 review, then Go Live.
    expect(find.text("You're Almost Done!"), findsOneWidget);
    expect(find.text('doctylia.com/dr/dr-meera-shah'), findsOneWidget);
    await tester.ensureVisible(find.text('Go Live!'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Go Live!'));
    await tester.pumpAndSettle();

    expect(find.text('Your Website is Live! 🎉'), findsOneWidget);
    final saved = repository.saved!;
    expect(saved.fullName, 'Dr. Meera Shah');
    expect(saved.specialization, 'Dermatologist');
    expect(saved.experienceYears, 12);
    expect(saved.consultationFee, 700);
    expect(saved.state, 'Bihar');
    expect(saved.city, 'Begusarai');
    expect(saved.phone, '9876543210');
  });
}

/// Signed-in doctor straight out of signup: profile row exists but
/// onboarding_completed is still false.
class _NewDoctorAuth extends AuthController {
  @override
  Future<AuthState> build() async {
    final now = DateTime(2026, 10, 22);
    final profile = DoctorProfile(
      id: 'new-doctor',
      fullName: 'Dr. New',
      consultationFee: 0,
      createdAt: now,
      gstRegistered: false,
      onboardingCompleted: false,
      planStatus: PlanStatus.trial,
      planTier: PlanTier.free,
      trialStart: now,
      trialEnd: now.add(const Duration(days: 3650)),
      updatedAt: now,
    );
    return AuthState.authenticated(
      DoctorSession(
        userId: profile.id,
        email: '',
        displayName: 'Dr. New',
        planTier: profile.planTier,
        planStatus: profile.planStatus,
        trialEnd: profile.trialEnd,
        profile: profile,
      ),
    );
  }
}
