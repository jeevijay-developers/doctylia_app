import 'package:doctylia_app/features/auth/domain/entities/doctor_session.dart';

class StaffLookup {
  const StaffLookup({required this.status});
  final String status;
}

class AccountLookup {
  const AccountLookup({
    required this.hasOwnDoctorProfile,
    this.session,
    this.staff,
  });

  final DoctorSession? session;
  final bool hasOwnDoctorProfile;
  final StaffLookup? staff;
}
