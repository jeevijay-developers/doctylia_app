import 'package:doctylia_app/core/pagination/page_request.dart';
import 'package:doctylia_app/core/pagination/page_result.dart';
import 'package:doctylia_app/core/result/result.dart';
import 'package:doctylia_app/features/billing/domain/entities/billing_models.dart';

abstract interface class BillingRepository {
  Future<Result<BillingSummary>> getSummary();
  Future<Result<PageResult<BillingTransaction>>> listTransactions(
    PageRequest page,
    BillingQuery query,
  );
  Future<Result<List<BillingTransaction>>> exportTransactions(
    BillingQuery query,
  );
  Future<Result<PageResult<Invoice>>> listInvoices(
    PageRequest page, {
    String search = '',
  });
  Future<Result<Invoice>> getInvoice(String id);
  Stream<void> watchChanges();
}
