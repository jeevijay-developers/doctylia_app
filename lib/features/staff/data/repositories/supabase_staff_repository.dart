import 'dart:async';

import 'package:doctylia_app/core/errors/app_failure.dart';
import 'package:doctylia_app/core/errors/repository_guard.dart';
import 'package:doctylia_app/core/pagination/page_request.dart';
import 'package:doctylia_app/core/pagination/page_result.dart';
import 'package:doctylia_app/core/result/result.dart';
import 'package:doctylia_app/features/staff/domain/entities/staff_member.dart';
import 'package:doctylia_app/features/staff/domain/entities/staff_permission.dart';
import 'package:doctylia_app/features/staff/domain/repositories/staff_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final class SupabaseStaffRepository implements StaffRepository {
  SupabaseStaffRepository(this._client);

  final SupabaseClient _client;

  String get _doctorId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw const SessionExpiredFailure();
    return id;
  }

  @override
  Future<Result<PageResult<StaffMember>>> list(
    PageRequest page, {
    String search = '',
  }) => _guard(() async {
    final doctorId = _doctorId;
    final term = search.replaceAll(RegExp(r'[,()%_]'), ' ').trim();
    dynamic rowsQuery = _client
        .from('staff_members')
        .select()
        .eq('doctor_id', doctorId);
    dynamic countQuery = _client
        .from('staff_members')
        .count(CountOption.exact)
        .eq('doctor_id', doctorId);
    if (term.isNotEmpty) {
      final filter = 'staff_name.ilike.%$term%,username.ilike.%$term%';
      rowsQuery = rowsQuery.or(filter);
      countQuery = countQuery.or(filter);
    }
    final result = await Future.wait<dynamic>([
      rowsQuery
          .order('created_at', ascending: false)
          .range(page.offset, page.offset + page.limit - 1),
      countQuery,
    ]);
    final rows = (result[0] as List).cast<Map<String, dynamic>>();
    final total = result[1] as int;
    final hasMore = page.offset + rows.length < total;
    return PageResult(
      items: rows.map(_fromJson).toList(growable: false),
      hasMore: hasMore,
      nextOffset: hasMore ? page.offset + page.limit : null,
      totalCount: total,
    );
  });

  @override
  Future<Result<StaffMember>> save(StaffDraft draft) => _guard(() async {
    final doctorId = _doctorId;
    final staffName = draft.staffName.trim();
    final username = draft.username.trim();
    _validateIdentity(staffName, username);
    final permissionValues = _permissionsToJson(draft.permissions);

    if (draft.id == null) {
      final password = draft.password ?? '';
      if (password.length < 8) {
        throw const ValidationFailure(
          'Password must be at least 8 characters.',
        );
      }
      final response = await _client.functions
          .invoke(
            'create-staff-account',
            body: {
              'staff_name': staffName,
              'username': username,
              'password': password,
              'status': draft.status.name,
              'permissions': permissionValues,
            },
          )
          .timeout(const Duration(seconds: 30));
      final responseData = _responseMap(response.data);
      final rawStaff = responseData['staff'];
      if (responseData['ok'] != true || rawStaff is! Map) {
        throw const ServerFailure();
      }
      final staffId = rawStaff['id'];
      if (staffId is! String || staffId.isEmpty) {
        throw const ServerFailure();
      }
      final row = await _client
          .from('staff_members')
          .select()
          .eq('id', staffId)
          .eq('doctor_id', doctorId)
          .single();
      return _fromJson(row);
    }

    final row = await _client
        .from('staff_members')
        .update({
          'staff_name': staffName,
          'username': username,
          'permissions': permissionValues,
        })
        .eq('id', draft.id!)
        .eq('doctor_id', doctorId)
        .select()
        .single();
    return _fromJson(row);
  });

  @override
  Future<Result<void>> setStatus(String id, StaffStatus status) =>
      _guard(() async {
        await _client
            .from('staff_members')
            .update({'status': status.name})
            .eq('id', id)
            .eq('doctor_id', _doctorId);
      });

  @override
  Future<Result<void>> resetPassword(String id, String newPassword) =>
      _guard(() async {
        if (newPassword.length < 8) {
          throw const ValidationFailure(
            'Password must be at least 8 characters.',
          );
        }
        final response = await _client.functions
            .invoke(
              'reset-staff-password',
              body: {'staff_id': id, 'new_password': newPassword},
            )
            .timeout(const Duration(seconds: 30));
        if (_responseMap(response.data)['ok'] != true) {
          throw const ServerFailure();
        }
      });

  @override
  Future<Result<void>> delete(String id) => _guard(() async {
    final response = await _client.functions
        .invoke('delete-staff-account', body: {'staff_id': id})
        .timeout(const Duration(seconds: 30));
    if (_responseMap(response.data)['ok'] != true) {
      throw const ServerFailure();
    }
  });

  @override
  Stream<void> watchChanges() {
    final controller = StreamController<void>();
    final channel = _client
        .channel('mobile-staff-$_doctorId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'staff_members',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'doctor_id',
            value: _doctorId,
          ),
          callback: (_) => controller.add(null),
        )
        .subscribe();
    controller.onCancel = () async {
      await _client.removeChannel(channel);
      await controller.close();
    };
    return controller.stream;
  }

  static void _validateIdentity(String staffName, String username) {
    if (staffName.isEmpty) {
      throw const ValidationFailure('Staff name is required.');
    }
    if (username.isEmpty) {
      throw const ValidationFailure('Username is required.');
    }
    if (!RegExp(r'^[a-zA-Z0-9._-]{3,32}$').hasMatch(username)) {
      throw const ValidationFailure(
        'Username must be 3-32 characters using letters, numbers, dots, underscores, or hyphens.',
      );
    }
  }

  static Map<String, bool> _permissionsToJson(
    Set<StaffPermission> permissions,
  ) => {
    for (final permission in StaffPermission.values)
      permission.key: permissions.contains(permission),
  };

  static Set<StaffPermission> _permissionsFromJson(Object? value) {
    if (value is! Map) return <StaffPermission>{};
    return {
      for (final permission in StaffPermission.values)
        if (value[permission.key] == true) permission,
    };
  }

  static Map<String, dynamic> _responseMap(Object? value) => value is Map
      ? Map<String, dynamic>.from(value)
      : const <String, dynamic>{};

  static StaffMember _fromJson(Map<String, dynamic> row) => StaffMember(
    id: row['id'] as String,
    doctorId: row['doctor_id'] as String,
    staffName: row['staff_name'] as String,
    username: row['username'] as String,
    status: row['status'] == 'inactive'
        ? StaffStatus.inactive
        : StaffStatus.active,
    permissions: _permissionsFromJson(row['permissions']),
    createdAt: DateTime.parse(row['created_at'] as String),
    updatedAt: DateTime.parse(row['updated_at'] as String),
    createdBy: row['created_by'] as String,
    lastLoginAt: row['last_login_at'] is String
        ? DateTime.tryParse(row['last_login_at'] as String)
        : null,
  );

  Future<Result<T>> _guard<T>(Future<T> Function() operation) =>
      RepositoryGuard.run(() async {
        try {
          return await operation();
        } catch (error, stackTrace) {
          if (error is AppFailure) rethrow;
          if (error is FunctionException) {
            final details = error.details;
            final detailMap = details is Map
                ? Map<String, dynamic>.from(details)
                : const <String, dynamic>{};
            final detailMessage = detailMap['error'] ?? detailMap['message'];
            final message = detailMessage is String && detailMessage.isNotEmpty
                ? detailMessage
                : 'The staff account action failed. Please try again.';
            if (error.status == 409) {
              throw ConflictFailure(message, cause: error);
            }
            if (error.status == 401) throw const SessionExpiredFailure();
            if (error.status == 403) throw const PermissionFailure();
            if (error.status == 429) throw const RateLimitFailure();
            throw RemoteServiceFailure(
              message,
              cause: error,
              stackTrace: stackTrace,
            );
          }
          final message = error.toString().toLowerCase();
          if (error is TimeoutException ||
              message.contains('socketexception') ||
              message.contains('failed host lookup')) {
            throw NetworkFailure(cause: error, stackTrace: stackTrace);
          }
          if (error is PostgrestException) {
            if (error.code == '42501') throw const PermissionFailure();
            if (error.code == '23505') {
              throw ConflictFailure(
                'That username is already in use.',
                cause: error,
              );
            }
          }
          throw ServerFailure(cause: error, stackTrace: stackTrace);
        }
      });
}
