import 'package:doctylia_app/features/auth/domain/entities/account_lookup.dart';
import 'package:doctylia_app/features/auth/domain/entities/doctor_session.dart';

enum AccountResolutionType { doctor, staff, accountError }

class AccountResolution {
  const AccountResolution._(this.type, {this.session});

  const AccountResolution.doctor(DoctorSession session)
    : this._(AccountResolutionType.doctor, session: session);

  const AccountResolution.staff() : this._(AccountResolutionType.staff);

  const AccountResolution.accountError()
    : this._(AccountResolutionType.accountError);

  final AccountResolutionType type;
  final DoctorSession? session;
}

abstract final class AccountRoleResolver {
  /// Mirrors web lookup order: own profiles row, then staff_members fallback.
  static AccountResolution resolve(AccountLookup lookup) {
    if (lookup.hasOwnDoctorProfile) {
      return AccountResolution.doctor(lookup.session!);
    }
    if (lookup.staff != null) {
      return const AccountResolution.staff();
    }
    return const AccountResolution.accountError();
  }
}
