import 'package:doctylia_app/core/errors/repository_guard.dart';
import 'package:doctylia_app/core/result/result.dart';
import 'package:doctylia_app/features/foundation/domain/entities/foundation_status.dart';
import 'package:doctylia_app/features/foundation/domain/repositories/foundation_repository.dart';

final class MockFoundationRepository implements FoundationRepository {
  const MockFoundationRepository();

  @override
  Future<Result<FoundationStatus>> loadStatus() {
    return RepositoryGuard.run(
      () => const FoundationStatus(
        dataMode: 'mock',
        layers: ['UI', 'Riverpod state', 'Repository', 'Data source'],
      ),
    );
  }
}
