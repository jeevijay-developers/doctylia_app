import 'package:doctylia_app/core/result/result.dart';
import 'package:doctylia_app/features/dashboard/domain/entities/dashboard_snapshot.dart';

abstract interface class DashboardRepository {
  Future<Result<DashboardSnapshot>> loadDashboard(String doctorId);

  /// Supabase mode will emit for appointments, patients, and invoices changes.
  Stream<void> watchDashboardChanges(String doctorId);
}
