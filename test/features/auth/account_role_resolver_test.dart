import 'package:doctylia_app/features/auth/domain/entities/account_lookup.dart';
import 'package:doctylia_app/features/auth/domain/entities/account_resolution.dart';
import 'package:doctylia_app/features/auth/domain/entities/doctor_session.dart';
import 'package:doctylia_app/shared/entitlements/plan_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const session = DoctorSession(
    userId: 'doctor-id',
    email: 'doctor@gmail.com',
    displayName: 'Dr. Doctor',
    planTier: PlanTier.premium,
    planStatus: PlanStatus.active,
  );

  group('AccountRoleResolver', () {
    test('own doctor profile wins before a staff fallback', () {
      final result = AccountRoleResolver.resolve(
        const AccountLookup(
          session: session,
          hasOwnDoctorProfile: true,
          staff: StaffLookup(status: 'active'),
        ),
      );

      expect(result.type, AccountResolutionType.doctor);
      expect(result.session, same(session));
    });

    test('any staff row is rejected from the doctor-only app', () {
      for (final status in ['active', 'inactive']) {
        final result = AccountRoleResolver.resolve(
          AccountLookup(
            session: session,
            hasOwnDoctorProfile: false,
            staff: StaffLookup(status: status),
          ),
        );
        expect(result.type, AccountResolutionType.staff);
      }
    });

    test('unlinked account becomes an account error', () {
      final result = AccountRoleResolver.resolve(
        const AccountLookup(session: session, hasOwnDoctorProfile: false),
      );

      expect(result.type, AccountResolutionType.accountError);
    });
  });
}
