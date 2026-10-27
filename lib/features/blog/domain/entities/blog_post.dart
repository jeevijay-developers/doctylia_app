import 'dart:typed_data';

class BlogPost {
  const BlogPost({
    required this.id,
    required this.title,
    required this.isPublished,
    required this.createdAt,
    required this.updatedAt,
    this.excerpt,
    this.content,
    this.category,
    this.featuredImageUrl,
    this.publishedAt,
  });
  final String id;
  final String title;
  final String? excerpt;
  final String? content;
  final String? category;
  final String? featuredImageUrl;
  final bool isPublished;
  final DateTime? publishedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  BlogPost copyWith({
    String? title,
    String? excerpt,
    String? content,
    String? category,
    String? featuredImageUrl,
    bool? isPublished,
    DateTime? publishedAt,
  }) => BlogPost(
    id: id,
    title: title ?? this.title,
    excerpt: excerpt ?? this.excerpt,
    content: content ?? this.content,
    category: category ?? this.category,
    featuredImageUrl: featuredImageUrl ?? this.featuredImageUrl,
    isPublished: isPublished ?? this.isPublished,
    publishedAt: publishedAt ?? this.publishedAt,
    createdAt: createdAt,
    updatedAt: DateTime.now(),
  );
}

/// Practice-wide post counts (unaffected by search / filters), like the
/// web's "3 published · 2 drafts".
class BlogStats {
  const BlogStats({required this.total, required this.published});
  final int total;
  final int published;
  int get drafts => (total - published).clamp(0, total);
}

class BlogPostDraft {
  const BlogPostDraft({
    required this.title,
    required this.content,
    required this.isPublished,
    this.id,
    this.excerpt,
    this.category,
    this.featuredImageUrl,
  });
  final String? id;
  final String title;
  final String? excerpt;
  final String content;
  final String? category;
  final String? featuredImageUrl;
  final bool isPublished;
}

class AiBlogDraft {
  const AiBlogDraft({
    required this.title,
    required this.excerpt,
    required this.content,
    required this.category,
  });
  final String title;
  final String excerpt;
  final String content;
  final String category;
}

class BlogImageUpload {
  const BlogImageUpload({
    required this.fileName,
    required this.bytes,
    required this.mimeType,
  });

  final String fileName;
  final Uint8List bytes;
  final String? mimeType;
}
