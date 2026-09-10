import 'package:doctylia_app/core/pagination/page_request.dart';
import 'package:doctylia_app/core/pagination/page_result.dart';
import 'package:doctylia_app/core/result/result.dart';
import 'package:doctylia_app/features/staff/domain/entities/staff_member.dart';

abstract interface class StaffRepository {
  Future<Result<PageResult<StaffMember>>> list(
    PageRequest page, {
    String search = '',
  });
  Future<Result<StaffMember>> save(StaffDraft draft);
  Future<Result<void>> setStatus(String id, StaffStatus status);
  Future<Result<void>> resetPassword(String id, String newPassword);
  Future<Result<void>> delete(String id);
  Stream<void> watchChanges();
}
