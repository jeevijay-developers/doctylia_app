import 'package:doctylia_app/core/errors/app_failure.dart';
import 'package:doctylia_app/core/errors/repository_guard.dart';
import 'package:doctylia_app/core/pagination/page_request.dart';
import 'package:doctylia_app/core/pagination/page_result.dart';
import 'package:doctylia_app/core/result/result.dart';
import 'package:doctylia_app/features/staff/domain/entities/staff_member.dart';
import 'package:doctylia_app/features/staff/domain/entities/staff_permission.dart';
import 'package:doctylia_app/features/staff/domain/repositories/staff_repository.dart';

final class MockStaffRepository implements StaffRepository {
  MockStaffRepository() : _items = _seedStaff();
  final List<StaffMember> _items;

  @override
  Future<Result<PageResult<StaffMember>>> list(
    PageRequest page, {
    String search = '',
  }) => RepositoryGuard.run(() {
    final term = search.trim().toLowerCase();
    final rows =
        _items
            .where(
              (row) =>
                  term.isEmpty ||
                  row.staffName.toLowerCase().contains(term) ||
                  row.username.toLowerCase().contains(term),
            )
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final end = (page.offset + page.limit + 1).clamp(0, rows.length);
    final lookahead = page.offset >= rows.length
        ? <StaffMember>[]
        : rows.sublist(page.offset, end);
    return PageResult.fromLookahead(
      rows: lookahead,
      request: page,
      totalCount: rows.length,
    );
  });

  @override
  Future<Result<StaffMember>> save(StaffDraft draft) => RepositoryGuard.run(() {
    final name = draft.staffName.trim();
    final username = draft.username.trim().toLowerCase();
    if (name.isEmpty) throw const ValidationFailure('Staff name is required.');
    if (!RegExp(r'^[a-zA-Z0-9._-]{3,32}$').hasMatch(username)) {
      throw const ValidationFailure(
        'Username must be 3-32 characters using letters, numbers, dot, underscore, or hyphen.',
      );
    }
    if (draft.id == null && (draft.password?.length ?? 0) < 8) {
      throw const ValidationFailure('Password must be at least 8 characters.');
    }
    final duplicate = _items.any(
      (row) => row.id != draft.id && row.username.toLowerCase() == username,
    );
    if (duplicate) {
      throw const ConflictFailure(
        'This username is already in use. Please choose another one.',
      );
    }
    final now = DateTime.now();
    if (draft.id == null) {
      final row = StaffMember(
        id: 'staff-${now.microsecondsSinceEpoch}',
        doctorId: 'doctor-1',
        staffName: name,
        username: username,
        status: draft.status,
        permissions: draft.permissions,
        createdAt: now,
        updatedAt: now,
        createdBy: 'doctor-1',
      );
      _items.add(row);
      return row;
    }
    final index = _items.indexWhere((row) => row.id == draft.id);
    if (index < 0) throw const NotFoundFailure('Staff account not found.');
    return _items[index] = _items[index].copyWith(
      staffName: name,
      username: username,
      permissions: draft.permissions,
      updatedAt: now,
    );
  });

  @override
  Future<Result<void>> setStatus(String id, StaffStatus status) =>
      RepositoryGuard.run(() {
        final index = _items.indexWhere((row) => row.id == id);
        if (index < 0) throw const NotFoundFailure('Staff account not found.');
        _items[index] = _items[index].copyWith(
          status: status,
          updatedAt: DateTime.now(),
        );
      });

  @override
  Future<Result<void>> resetPassword(String id, String newPassword) =>
      RepositoryGuard.run(() {
        if (!_items.any((row) => row.id == id)) {
          throw const NotFoundFailure('Staff account not found.');
        }
        if (newPassword.length < 8) {
          throw const ValidationFailure(
            'Password must be at least 8 characters.',
          );
        }
      });

  @override
  Future<Result<void>> delete(String id) => RepositoryGuard.run(() {
    if (!_items.any((row) => row.id == id)) {
      throw const NotFoundFailure('Staff account not found.');
    }
    _items.removeWhere((row) => row.id == id);
  });

  @override
  Stream<void> watchChanges() => const Stream.empty();
}

List<StaffMember> _seedStaff() {
  final now = DateTime.now();
  const names = [
    'Aarav Reception',
    'Nisha Nurse',
    'Vikram Assistant',
    'Sara Desk',
  ];
  return List.generate(27, (index) {
    final permissions = <StaffPermission>{
      StaffPermission.dashboardView,
      StaffPermission.appointmentsView,
      StaffPermission.patientsView,
      if (index.isEven) StaffPermission.appointmentsCreate,
      if (index % 3 == 0) StaffPermission.prescriptionsView,
    };
    return StaffMember(
      id: 'staff-$index',
      doctorId: 'doctor-1',
      staffName: names[index % names.length],
      username: 'clinic_staff_${index + 1}',
      status: index % 5 == 0 ? StaffStatus.inactive : StaffStatus.active,
      permissions: permissions,
      createdAt: now.subtract(Duration(days: index * 4)),
      updatedAt: now.subtract(Duration(days: index)),
      createdBy: 'doctor-1',
      lastLoginAt: index % 4 == 0
          ? null
          : now.subtract(Duration(hours: index * 8)),
    );
  });
}
