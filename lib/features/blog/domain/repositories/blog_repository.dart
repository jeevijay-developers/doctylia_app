import 'package:doctylia_app/core/pagination/page_request.dart';
import 'package:doctylia_app/core/pagination/page_result.dart';
import 'package:doctylia_app/core/result/result.dart';
import 'package:doctylia_app/features/blog/domain/entities/blog_post.dart';

abstract interface class BlogRepository {
  Future<Result<PageResult<BlogPost>>> list(
    PageRequest page, {
    String search = '',
  });
  Future<Result<BlogPost>> save(BlogPostDraft draft);
  Future<Result<void>> togglePublished(String id);
  Future<Result<void>> delete(String id);
  Future<Result<String>> uploadCoverImage(BlogImageUpload upload);
  Future<Result<AiBlogDraft>> generateDraft(String topic);
  Stream<void> watchChanges();
}
