import 'package:doctylia_app/core/result/result.dart';
import 'package:doctylia_app/features/website/data/repositories/mock_website_repository.dart';
import 'package:doctylia_app/features/website/domain/entities/website_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'website aggregate preserves schema-aligned settings and collections',
    () async {
      final repo = MockWebsiteRepository();
      final loaded = (await repo.load() as Success).value as WebsiteSnapshot;
      expect(loaded.settings.slug, 'doctor');
      expect(loaded.services, isNotEmpty);
      expect(loaded.workingHours, hasLength(7));
      final changed = loaded.copyWith(
        settings: loaded.settings.copyWith(showBlog: false),
      );
      await repo.save(changed);
      final reloaded = (await repo.load() as Success).value as WebsiteSnapshot;
      expect(reloaded.settings.showBlog, isFalse);
    },
  );
}
