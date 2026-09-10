import 'package:doctylia_app/core/result/result.dart';
import 'package:doctylia_app/features/dashboard/data/repositories/mock_dashboard_repository.dart';
import 'package:doctylia_app/features/dashboard/domain/entities/dashboard_snapshot.dart';
import 'package:doctylia_app/features/dashboard/domain/repositories/dashboard_repository.dart';

final class CountingDashboardRepository implements DashboardRepository {
  int loadCount = 0;
  final _delegate = const MockDashboardRepository();

  @override
  Future<Result<DashboardSnapshot>> loadDashboard(String doctorId) {
    loadCount++;
    return _delegate.loadDashboard(doctorId);
  }

  @override
  Stream<void> watchDashboardChanges(String doctorId) => const Stream.empty();
}
