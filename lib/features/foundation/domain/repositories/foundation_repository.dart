import 'package:doctylia_app/core/result/result.dart';
import 'package:doctylia_app/features/foundation/domain/entities/foundation_status.dart';

abstract interface class FoundationRepository {
  Future<Result<FoundationStatus>> loadStatus();
}
