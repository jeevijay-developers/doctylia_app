import 'package:doctylia_app/app/app_flavor.dart';
import 'package:doctylia_app/core/data/app_data_source.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final appDataSourceProvider = Provider<AppDataSource>((ref) {
  throw StateError('appDataSourceProvider must be overridden at bootstrap.');
});

AppDataSource appDataSourceFor(AppFlavor flavor) {
  return flavor.usesMockData
      ? const AppDataSource.mock()
      : AppDataSource.remote(flavor.name);
}
