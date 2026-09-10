import 'package:doctylia_app/core/result/result.dart';
import 'package:doctylia_app/features/website/domain/entities/website_models.dart';

abstract interface class WebsiteRepository {
  Future<Result<WebsiteSnapshot>> load();
  Future<Result<WebsiteSnapshot>> save(WebsiteSnapshot snapshot);
  Future<Result<String>> uploadHeroPhoto(WebsiteImageUpload upload);
  Future<Result<GalleryPhoto>> uploadGalleryPhoto(WebsiteImageUpload upload);
  Future<Result<void>> deleteGalleryPhoto(String id);
  Future<Result<GalleryPhoto>> updateGalleryCaption(String id, String caption);
  Future<Result<WebsiteReview>> updateReview(
    String id, {
    bool? isVisible,
    bool? isPinned,
  });
  Stream<void> watchChanges();
}
