import 'package:doctylia_app/core/errors/app_failure.dart';
import 'package:doctylia_app/core/result/result.dart';
import 'package:doctylia_app/features/auth/data/repositories/mock_auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_preferences_store.dart';

void main() {
  group('MockAuthRepository', () {
    late FakePreferencesStore preferences;
    late MockAuthRepository repository;

    setUp(() {
      preferences = FakePreferencesStore();
      repository = MockAuthRepository(preferences);
    });

    test(
      'accepts only the temporary doctor credentials and persists',
      () async {
        final rejected = await repository.signIn(
          email: MockAuthRepository.doctorEmail,
          password: 'wrong',
        );
        expect(rejected, isA<Failure>());
        expect((rejected as Failure).failure, isA<AuthFailure>());

        final accepted = await repository.signIn(
          email: '  DOCTOR@GMAIL.COM ',
          password: MockAuthRepository.doctorPassword,
        );
        expect(accepted, isA<Success>());

        final restored = await MockAuthRepository(preferences).restoreSession();
        expect(restored, isA<Success>());
        final lookup = (restored as Success).value;
        expect(lookup, isNotNull);
        expect(lookup!.hasOwnDoctorProfile, isTrue);
        expect(lookup.session!.email, MockAuthRepository.doctorEmail);
      },
    );

    test('sign out clears the persisted session', () async {
      await repository.signIn(
        email: MockAuthRepository.doctorEmail,
        password: MockAuthRepository.doctorPassword,
      );
      await repository.signOut();

      final restored = await repository.restoreSession();
      expect((restored as Success).value, isNull);
    });

    test(
      'password reset validates email without sending in mock mode',
      () async {
        final invalid = await repository.sendPasswordReset('not-an-email');
        expect(invalid, isA<Failure>());
        expect((invalid as Failure).failure, isA<ValidationFailure>());

        final valid = await repository.sendPasswordReset('doctor@gmail.com');
        expect(valid, isA<Success>());
      },
    );
  });
}
