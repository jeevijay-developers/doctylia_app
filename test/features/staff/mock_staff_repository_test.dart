import 'package:doctylia_app/core/pagination/page_request.dart';
import 'package:doctylia_app/core/result/result.dart';
import 'package:doctylia_app/features/staff/data/repositories/mock_staff_repository.dart';
import 'package:doctylia_app/features/staff/domain/entities/staff_member.dart';
import 'package:doctylia_app/features/staff/domain/entities/staff_permission.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('permission matrix mirrors all web keys exactly', () {
    expect(StaffPermission.values.map((value) => value.key), [
      'dashboard.view',
      'website.view',
      'website.edit',
      'website.settings',
      'appointments.view',
      'appointments.create',
      'appointments.edit',
      'appointments.cancel',
      'patients.view',
      'patients.add',
      'patients.edit',
      'patients.medical_records',
      'prescriptions.view',
      'prescriptions.create',
      'prescriptions.edit',
      'reviews.view',
      'reviews.manage',
      'blog.view',
      'blog.create',
      'blog.edit',
      'blog.delete',
      'billing.view',
      'billing.manage',
      'profile.view',
      'profile.edit',
      'staff.view',
      'staff.create',
      'staff.edit',
      'staff.disable',
      'inquiries.view',
      'inquiries.manage',
    ]);
  });

  test('staff list paginates and searches', () async {
    final repo = MockStaffRepository();
    final first = (await repo.list(const PageRequest()) as Success).value;
    expect(first.items, hasLength(20));
    expect(first.hasMore, isTrue);
    final filtered =
        (await repo.list(const PageRequest(), search: 'clinic_staff_27')
                as Success)
            .value;
    expect(filtered.items, hasLength(1));
  });

  test('creates, updates, disables, resets, and deletes staff', () async {
    final repo = MockStaffRepository();
    final created = await repo.save(
      const StaffDraft(
        staffName: 'Front Desk',
        username: 'front_desk_new',
        password: 'password8',
        permissions: {StaffPermission.dashboardView},
      ),
    );
    expect(created, isA<Success<StaffMember>>());
    final row = (created as Success<StaffMember>).value;
    expect(await repo.setStatus(row.id, StaffStatus.inactive), isA<Success>());
    expect(await repo.resetPassword(row.id, 'newpass88'), isA<Success>());
    expect(await repo.delete(row.id), isA<Success>());
  });

  test('rejects short staff passwords', () async {
    final repo = MockStaffRepository();
    final result = await repo.save(
      const StaffDraft(
        staffName: 'Front Desk',
        username: 'front_desk_short',
        password: 'short',
        permissions: {},
      ),
    );
    expect(result, isA<Failure>());
  });
}
