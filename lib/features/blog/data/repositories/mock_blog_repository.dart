import 'package:doctylia_app/core/errors/repository_guard.dart';
import 'package:doctylia_app/core/pagination/page_request.dart';
import 'package:doctylia_app/core/pagination/page_result.dart';
import 'package:doctylia_app/core/result/result.dart';
import 'package:doctylia_app/features/blog/domain/entities/blog_post.dart';
import 'package:doctylia_app/features/blog/domain/repositories/blog_repository.dart';

final class MockBlogRepository implements BlogRepository {
  MockBlogRepository() : _items = _seed();
  final List<BlogPost> _items;
  @override
  Future<Result<PageResult<BlogPost>>> list(
    PageRequest page, {
    String search = '',
  }) => RepositoryGuard.run(() {
    final term = search.trim().toLowerCase();
    final rows =
        _items
            .where(
              (row) =>
                  term.isEmpty ||
                  row.title.toLowerCase().contains(term) ||
                  (row.category ?? '').toLowerCase().contains(term),
            )
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final end = (page.offset + page.limit + 1).clamp(0, rows.length);
    final lookahead = page.offset >= rows.length
        ? <BlogPost>[]
        : rows.sublist(page.offset, end);
    return PageResult.fromLookahead(
      rows: lookahead,
      request: page,
      totalCount: rows.length,
    );
  });
  @override
  Future<Result<BlogPost>> save(BlogPostDraft draft) => RepositoryGuard.run(() {
    if (draft.title.trim().isEmpty) throw ArgumentError('Title is required.');
    final now = DateTime.now();
    final existing = draft.id == null
        ? -1
        : _items.indexWhere((row) => row.id == draft.id);
    final post = BlogPost(
      id: draft.id ?? 'blog-${now.microsecondsSinceEpoch}',
      title: draft.title.trim(),
      excerpt: draft.excerpt,
      content: draft.content,
      category: draft.category,
      featuredImageUrl: draft.featuredImageUrl,
      isPublished: draft.isPublished,
      publishedAt: draft.isPublished ? now : null,
      createdAt: existing < 0 ? now : _items[existing].createdAt,
      updatedAt: now,
    );
    if (existing < 0) {
      _items.add(post);
    } else {
      _items[existing] = post;
    }
    return post;
  });
  @override
  Future<Result<void>> togglePublished(String id) => RepositoryGuard.run(() {
    final index = _items.indexWhere((row) => row.id == id);
    if (index < 0) throw StateError('Blog post not found.');
    final row = _items[index];
    _items[index] = row.copyWith(
      isPublished: !row.isPublished,
      publishedAt: row.isPublished ? null : DateTime.now(),
    );
  });
  @override
  Future<Result<void>> delete(String id) =>
      RepositoryGuard.run(() => _items.removeWhere((row) => row.id == id));
  @override
  Future<Result<String>> uploadCoverImage(BlogImageUpload upload) =>
      RepositoryGuard.run(() => 'https://example.com/blog/${upload.fileName}');
  @override
  Future<Result<AiBlogDraft>> generateDraft(
    String topic,
  ) => RepositoryGuard.run(() async {
    if (topic.trim().isEmpty) throw ArgumentError('Enter a topic.');
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final value = topic.trim();
    return AiBlogDraft(
      title: 'A doctor’s guide to $value',
      excerpt: 'Practical, patient-friendly guidance about $value.',
      content:
          'Understanding $value can help you make confident health decisions.\n\nStart with simple daily habits, notice changes early, and seek professional advice when symptoms persist. Every patient is different, so recommendations should be personalized with your doctor.\n\nBook a consultation if you would like guidance tailored to your health history.',
      category: 'General Health',
    );
  });
  @override
  Stream<void> watchChanges() => const Stream.empty();
}

List<BlogPost> _seed() {
  final now = DateTime.now();
  const titles = [
    'Simple habits for a healthier heart',
    'Managing seasonal allergies',
    'Understanding preventive checkups',
    'Healthy sleep for busy adults',
  ];
  return List.generate(
    28,
    (index) => BlogPost(
      id: 'blog-$index',
      title: titles[index % titles.length],
      excerpt: 'Clear, practical health advice for patients and families.',
      content:
          'Patient-friendly article content for the selected health topic.',
      category: index.isEven ? 'General Health' : 'Prevention',
      isPublished: index % 3 != 0,
      publishedAt: index % 3 != 0 ? now.subtract(Duration(days: index)) : null,
      createdAt: now.subtract(Duration(days: index)),
      updatedAt: now.subtract(Duration(days: index)),
    ),
  );
}
