import 'dart:async';

import 'package:doctylia_app/core/errors/app_failure.dart';
import 'package:doctylia_app/core/errors/repository_guard.dart';
import 'package:doctylia_app/core/pagination/page_request.dart';
import 'package:doctylia_app/core/pagination/page_result.dart';
import 'package:doctylia_app/core/result/result.dart';
import 'package:doctylia_app/features/reviews/domain/entities/review.dart';
import 'package:doctylia_app/features/reviews/domain/repositories/review_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final class SupabaseReviewRepository implements ReviewRepository {
  SupabaseReviewRepository(this._client);

  final SupabaseClient _client;

  String get _doctorId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw const SessionExpiredFailure();
    return id;
  }

  @override
  Future<Result<PageResult<PatientReview>>> list(
    PageRequest page, {
    String search = '',
    ReviewFilter filter = ReviewFilter.all,
  }) => _guard(() async {
    final term = search.replaceAll(RegExp(r'[,()%_]'), ' ').trim();
    dynamic rowsQuery = _client
        .from('reviews')
        .select(
          'id,patient_name,rating,review_text,is_pinned,is_verified,is_visible,created_at',
        )
        .eq('doctor_id', _doctorId);
    dynamic countQuery = _client
        .from('reviews')
        .count(CountOption.exact)
        .eq('doctor_id', _doctorId);

    if (term.isNotEmpty) {
      final filter = 'patient_name.ilike.%$term%,review_text.ilike.%$term%';
      rowsQuery = rowsQuery.or(filter);
      countQuery = countQuery.or(filter);
    }

    switch (filter) {
      case ReviewFilter.all:
        break;
      case ReviewFilter.fiveStars:
        rowsQuery = rowsQuery.eq('rating', 5);
        countQuery = countQuery.eq('rating', 5);
      case ReviewFilter.verified:
        rowsQuery = rowsQuery.eq('is_verified', true);
        countQuery = countQuery.eq('is_verified', true);
      case ReviewFilter.hidden:
        rowsQuery = rowsQuery.eq('is_visible', false);
        countQuery = countQuery.eq('is_visible', false);
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
  Future<Result<ReviewStats>> getStats() => _guard(() async {
    // Web derives all four cards from every review loaded for the doctor.
    final rows = await _client
        .from('reviews')
        .select('rating,is_verified,is_pinned')
        .eq('doctor_id', _doctorId);
    final total = rows.length;
    final ratingTotal = rows.fold<num>(
      0,
      (sum, row) => sum + (row['rating'] as num),
    );
    return ReviewStats(
      total: total,
      averageRating: total == 0 ? 0 : ratingTotal / total,
      verified: rows.where((row) => row['is_verified'] == true).length,
      pinned: rows.where((row) => row['is_pinned'] == true).length,
    );
  });

  @override
  Future<Result<void>> togglePinned(String id) =>
      _toggle(id, column: 'is_pinned');

  @override
  Future<Result<void>> toggleVisible(String id) =>
      _toggle(id, column: 'is_visible');

  Future<Result<void>> _toggle(String id, {required String column}) =>
      _guard(() async {
        final current = await _client
            .from('reviews')
            .select(column)
            .eq('id', id)
            .eq('doctor_id', _doctorId)
            .maybeSingle();
        if (current == null) {
          throw const ValidationFailure('This review no longer exists.');
        }
        final nextValue = current[column] != true;
        final updated = await _client
            .from('reviews')
            .update({column: nextValue})
            .eq('id', id)
            .eq('doctor_id', _doctorId)
            .select(column)
            .maybeSingle();
        if (updated == null || updated[column] != nextValue) {
          throw const PermissionFailure();
        }
      });

  @override
  Stream<void> watchChanges() {
    final controller = StreamController<void>();
    final channel = _client
        .channel('mobile-reviews-$_doctorId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'reviews',
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

  static PatientReview _fromJson(Map<String, dynamic> row) => PatientReview(
    id: row['id'] as String,
    patientName: row['patient_name'] as String,
    rating: (row['rating'] as num).toInt(),
    reviewText: row['review_text'] as String?,
    isPinned: row['is_pinned'] as bool,
    isVerified: row['is_verified'] as bool,
    isVisible: row['is_visible'] as bool,
    createdAt: DateTime.parse(row['created_at'] as String),
  );

  Future<Result<T>> _guard<T>(Future<T> Function() operation) =>
      RepositoryGuard.run(() async {
        try {
          return await operation();
        } catch (error, stackTrace) {
          if (error is AppFailure) rethrow;
          final message = error.toString().toLowerCase();
          if (error is TimeoutException ||
              message.contains('socketexception') ||
              message.contains('failed host lookup')) {
            throw NetworkFailure(cause: error, stackTrace: stackTrace);
          }
          if (error is PostgrestException && error.code == '42501') {
            throw const PermissionFailure();
          }
          throw ServerFailure(cause: error, stackTrace: stackTrace);
        }
      });
}
