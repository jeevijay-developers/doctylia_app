import 'package:doctylia_app/core/pagination/page_request.dart';
import 'package:doctylia_app/core/pagination/page_result.dart';
import 'package:doctylia_app/core/result/result.dart';
import 'package:doctylia_app/features/inquiries/domain/entities/patient_inquiry.dart';

abstract interface class InquiryRepository {
  Future<Result<PageResult<PatientInquiry>>> list(
    PageRequest page, {
    String search = '',
    InquiryStatus? status,
  });
  Future<Result<InquiryStats>> getStats();
  Future<Result<void>> setStatus(String id, InquiryStatus status);
  Stream<void> watchChanges();
}
