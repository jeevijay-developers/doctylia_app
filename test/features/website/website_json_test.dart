import 'package:doctylia_app/core/result/result.dart';
import 'package:doctylia_app/features/website/data/repositories/mock_website_repository.dart';
import 'package:doctylia_app/features/website/data/repositories/supabase_website_repository.dart';
import 'package:doctylia_app/features/website/domain/entities/website_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// Integer columns in Postgres. Sending a Dart double ("500.0") makes
/// PostgREST reject the whole save with 22P02 ("Something went wrong").
const _settingsIntColumns = [
  'online_fee',
  'online_duration',
  'booking_advance_days',
  'max_per_slot',
  'buffer_minutes',
  'cancellation_cutoff_hours',
];

void main() {
  test(
    'website save payloads send whole numbers for integer columns',
    () async {
      final snapshot =
          (await MockWebsiteRepository().load() as Success<WebsiteSnapshot>)
              .value;
      final settings = snapshot.settings.copyWith(onlineFee: 499.0);

      final json = SupabaseWebsiteRepository.settingsJson(settings);
      for (final column in _settingsIntColumns) {
        expect(json[column], isA<int>(), reason: column);
      }
      expect(json['online_fee'], 499);

      for (final service in snapshot.services) {
        final row = SupabaseWebsiteRepository.serviceJson(service);
        expect(row['price'], isA<int>());
        expect(row['duration'], isA<int>());
      }
      for (final package in snapshot.packages) {
        final row = SupabaseWebsiteRepository.packageJson(package);
        expect(row['price'], isA<int>());
        final original = row['original_price'];
        expect(original == null || original is int, isTrue);
      }
    },
  );
}
