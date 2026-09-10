import 'package:doctylia_app/core/pagination/page_request.dart';
import 'package:doctylia_app/core/result/result.dart';
import 'package:doctylia_app/features/blog/data/repositories/mock_blog_repository.dart';
import 'package:doctylia_app/features/blog/domain/entities/blog_post.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('blog list paginates and AI returns typed draft', () async {
    final repo = MockBlogRepository();
    final page = (await repo.list(const PageRequest()) as Success).value;
    expect(page.items, hasLength(20));
    expect(page.hasMore, isTrue);
    final ai =
        (await repo.generateDraft('heart health') as Success).value
            as AiBlogDraft;
    expect(ai.title, contains('heart health'));
    expect(ai.content, isNotEmpty);
  });
  test('blog posts can be saved and published', () async {
    final repo = MockBlogRepository();
    final saved =
        (await repo.save(
                      const BlogPostDraft(
                        title: 'New article',
                        content: 'Content',
                        isPublished: false,
                      ),
                    )
                    as Success)
                .value
            as BlogPost;
    expect(saved.isPublished, isFalse);
    await repo.togglePublished(saved.id);
    final filtered =
        (await repo.list(const PageRequest(), search: 'New article') as Success)
            .value;
    expect(filtered.items.single.isPublished, isTrue);
  });
}
