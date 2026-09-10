import 'dart:async';

import 'package:doctylia_app/core/errors/app_failure.dart';
import 'package:doctylia_app/core/errors/repository_guard.dart';
import 'package:doctylia_app/core/logging/app_logger.dart';
import 'package:doctylia_app/core/pagination/page_request.dart';
import 'package:doctylia_app/core/pagination/page_result.dart';
import 'package:doctylia_app/core/result/result.dart';
import 'package:doctylia_app/features/blog/domain/entities/blog_post.dart';
import 'package:doctylia_app/features/blog/domain/repositories/blog_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final class SupabaseBlogRepository implements BlogRepository {
  SupabaseBlogRepository(this._client);

  final SupabaseClient _client;

  String get _doctorId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw const SessionExpiredFailure();
    return id;
  }

  @override
  Future<Result<PageResult<BlogPost>>> list(
    PageRequest page, {
    String search = '',
  }) => _guard(() async {
    final term = search.replaceAll(RegExp(r'[,()%_]'), ' ').trim();
    dynamic rowsQuery = _client
        .from('blog_posts')
        .select(
          'id,title,excerpt,content,category,featured_image_url,is_published,published_at,created_at,updated_at',
        )
        .eq('doctor_id', _doctorId);
    dynamic countQuery = _client
        .from('blog_posts')
        .count(CountOption.exact)
        .eq('doctor_id', _doctorId);
    if (term.isNotEmpty) {
      final filter = 'title.ilike.%$term%,category.ilike.%$term%';
      rowsQuery = rowsQuery.or(filter);
      countQuery = countQuery.or(filter);
    }
    final result = await Future.wait<dynamic>([
      rowsQuery
          .order('created_at', ascending: false)
          .range(page.offset, page.offset + page.limit - 1),
      countQuery,
    ]);
    final rows = (result[0] as List).cast<Map<String, dynamic>>();
    final total = result[1] as int;
    final hasMore = page.offset + rows.length < total;
    return PageResult(
      items: rows.map(_fromJson).toList(growable: false),
      hasMore: hasMore,
      nextOffset: hasMore ? page.offset + page.limit : null,
      totalCount: total,
    );
  });

  @override
  Future<Result<BlogPost>> save(BlogPostDraft draft) => _guard(() async {
    if (draft.title.trim().isEmpty) {
      throw const ValidationFailure('Title is required.');
    }
    final now = DateTime.now().toUtc().toIso8601String();
    final values = <String, dynamic>{
      'title': draft.title.trim(),
      'excerpt': _empty(draft.excerpt),
      'content': _empty(draft.content),
      'category': _empty(draft.category),
      'featured_image_url': _empty(draft.featuredImageUrl),
      'is_published': draft.isPublished,
      'published_at': draft.isPublished ? now : null,
    };
    final Map<String, dynamic> row;
    if (draft.id == null) {
      row = await _client
          .from('blog_posts')
          .insert({'doctor_id': _doctorId, ...values})
          .select()
          .single();
    } else {
      row = await _client
          .from('blog_posts')
          .update(values)
          .eq('id', draft.id!)
          .eq('doctor_id', _doctorId)
          .select()
          .single();
    }
    if (draft.isPublished) {
      unawaited(_autoEnableBlogVisibilityBestEffort());
    }
    return _fromJson(row);
  });

  @override
  Future<Result<void>> togglePublished(String id) => _guard(() async {
    final current = await _client
        .from('blog_posts')
        .select('is_published')
        .eq('id', id)
        .eq('doctor_id', _doctorId)
        .maybeSingle();
    if (current == null) {
      throw const ValidationFailure('This blog post no longer exists.');
    }
    final publish = current['is_published'] != true;
    await _client
        .from('blog_posts')
        .update({
          'is_published': publish,
          'published_at': publish
              ? DateTime.now().toUtc().toIso8601String()
              : null,
        })
        .eq('id', id)
        .eq('doctor_id', _doctorId);
    if (publish) {
      unawaited(_autoEnableBlogVisibilityBestEffort());
    }
  });

  @override
  Future<Result<void>> delete(String id) => _guard(() async {
    await _client
        .from('blog_posts')
        .delete()
        .eq('id', id)
        .eq('doctor_id', _doctorId);
  });

  @override
  Future<Result<String>> uploadCoverImage(
    BlogImageUpload upload,
  ) => _guard(() async {
    final extension = _extension(upload.fileName);
    if (!{'jpg', 'jpeg', 'png', 'webp'}.contains(extension) ||
        !{
          'image/jpeg',
          'image/jpg',
          'image/png',
          'image/webp',
        }.contains(upload.mimeType)) {
      throw const ValidationFailure('Please choose a JPG, PNG, or WebP image.');
    }
    if (upload.bytes.length > 5 * 1024 * 1024) {
      throw const ValidationFailure('Please choose an image under 5 MB.');
    }
    final path =
        '$_doctorId/blog/${DateTime.now().millisecondsSinceEpoch}.$extension';
    await _client.storage
        .from('doctor-uploads')
        .uploadBinary(
          path,
          upload.bytes,
          fileOptions: FileOptions(contentType: upload.mimeType),
        );
    return _client.storage.from('doctor-uploads').getPublicUrl(path);
  });

  @override
  Future<Result<AiBlogDraft>> generateDraft(String topic) => _guard(() async {
    final cleanTopic = topic.trim();
    if (cleanTopic.isEmpty) {
      throw const ValidationFailure('Enter a topic for the article.');
    }
    final profile = await _client
        .from('profiles')
        .select('full_name,specialization')
        .eq('id', _doctorId)
        .single();
    final response = await _client.functions
        .invoke(
          'ai-blog-writer',
          body: {
            'topic': cleanTopic,
            'doctorName': profile['full_name'],
            'specialization': profile['specialization'],
          },
        )
        .timeout(const Duration(seconds: 45));
    if (response.data is! Map) {
      throw const ServerFailure();
    }
    final data = Map<String, dynamic>.from(response.data as Map);
    final content = data['content'] as String?;
    if (content == null || content.trim().isEmpty) {
      throw const ServerFailure();
    }
    return AiBlogDraft(
      title: (data['title'] as String?)?.trim().isNotEmpty == true
          ? data['title'] as String
          : cleanTopic,
      excerpt: data['excerpt'] as String? ?? '',
      content: content,
      category: (data['category'] as String?)?.trim().isNotEmpty == true
          ? data['category'] as String
          : 'General Health',
    );
  });

  @override
  Stream<void> watchChanges() {
    final controller = StreamController<void>();
    final channel = _client
        .channel('mobile-blog-$_doctorId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'blog_posts',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'doctor_id',
            value: _doctorId,
          ),
          callback: (_) => controller.add(null),
        )
        .subscribe();
    controller.onCancel = () async {
      await _client.removeChannel(channel);
      await controller.close();
    };
    return controller.stream;
  }

  Future<void> _maybeAutoEnableBlogVisibility() async {
    final settings = await _client
        .from('website_settings')
        .select('show_blog,blog_auto_enabled')
        .eq('doctor_id', _doctorId)
        .maybeSingle();
    if (settings == null || settings['blog_auto_enabled'] == true) return;
    await _client
        .from('website_settings')
        .update({
          if (settings['show_blog'] != true) 'show_blog': true,
          'blog_auto_enabled': true,
        })
        .eq('doctor_id', _doctorId);
  }

  Future<void> _autoEnableBlogVisibilityBestEffort() async {
    try {
      await _maybeAutoEnableBlogVisibility().timeout(
        const Duration(seconds: 8),
      );
    } catch (error, stackTrace) {
      AppLogger.error(
        'Blog saved, but website visibility could not be auto-enabled',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  static BlogPost _fromJson(Map<String, dynamic> row) => BlogPost(
    id: row['id'] as String,
    title: row['title'] as String,
    excerpt: row['excerpt'] as String?,
    content: row['content'] as String?,
    category: row['category'] as String?,
    featuredImageUrl: row['featured_image_url'] as String?,
    isPublished: row['is_published'] as bool,
    publishedAt: _date(row['published_at']),
    createdAt: DateTime.parse(row['created_at'] as String),
    updatedAt: DateTime.parse(row['updated_at'] as String),
  );

  Future<Result<T>> _guard<T>(Future<T> Function() operation) =>
      RepositoryGuard.run(() async {
        try {
          return await operation();
        } catch (error, stackTrace) {
          if (error is AppFailure) rethrow;
          if (error is TimeoutException) {
            throw const RemoteServiceFailure(
              'AI generation timed out. Please try again.',
            );
          }
          if (error is FunctionException) {
            final details = error.details;
            final detailMap = details is Map
                ? Map<String, dynamic>.from(details)
                : const <String, dynamic>{};
            final detailMessage =
                detailMap['error'] ??
                detailMap['message'] ??
                detailMap['details'];
            final message = detailMessage is String && detailMessage.isNotEmpty
                ? detailMessage
                : 'AI generation failed. Please try again.';
            if (error.status == 403) {
              throw RemoteServiceFailure(message);
            }
            if (error.status == 429) {
              throw const RemoteServiceFailure(
                'Too many AI requests. Please wait and retry.',
              );
            }
            if (error.status == 402) {
              throw const RemoteServiceFailure('AI credits are exhausted.');
            }
            if (error.status == 0) {
              throw RemoteServiceFailure(message);
            }
            throw RemoteServiceFailure(message);
          }
          final message = error.toString().toLowerCase();
          if (message.contains('socketexception') ||
              message.contains('failed host lookup')) {
            throw NetworkFailure(cause: error, stackTrace: stackTrace);
          }
          if (error is PostgrestException && error.code == '42501') {
            throw const PermissionFailure();
          }
          throw ServerFailure(cause: error, stackTrace: stackTrace);
        }
      });

  static DateTime? _date(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;
  static String? _empty(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? null : text;
  }

  static String _extension(String name) =>
      name.contains('.') ? name.split('.').last.toLowerCase() : '';
}
