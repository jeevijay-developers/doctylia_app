import 'dart:collection';

import 'package:doctylia_app/features/staff/domain/entities/staff_permission.dart';

enum StaffStatus { active, inactive }

class StaffMember {
  StaffMember({
    required this.id,
    required this.doctorId,
    required this.staffName,
    required this.username,
    required this.status,
    required Set<StaffPermission> permissions,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    this.lastLoginAt,
  }) : permissions = UnmodifiableSetView(permissions);

  final String id;
  final String doctorId;
  final String staffName;
  final String username;
  final StaffStatus status;
  final UnmodifiableSetView<StaffPermission> permissions;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;
  final DateTime? lastLoginAt;

  StaffMember copyWith({
    String? staffName,
    String? username,
    StaffStatus? status,
    Set<StaffPermission>? permissions,
    DateTime? updatedAt,
    DateTime? lastLoginAt,
  }) => StaffMember(
    id: id,
    doctorId: doctorId,
    staffName: staffName ?? this.staffName,
    username: username ?? this.username,
    status: status ?? this.status,
    permissions: permissions ?? this.permissions,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    createdBy: createdBy,
    lastLoginAt: lastLoginAt ?? this.lastLoginAt,
  );
}

class StaffDraft {
  const StaffDraft({
    this.id,
    required this.staffName,
    required this.username,
    required this.permissions,
    this.password,
    this.status = StaffStatus.active,
  });
  final String? id;
  final String staffName;
  final String username;
  final String? password;
  final StaffStatus status;
  final Set<StaffPermission> permissions;
}
