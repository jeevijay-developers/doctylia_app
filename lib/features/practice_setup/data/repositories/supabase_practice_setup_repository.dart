import 'dart:math';

import 'package:doctylia_app/core/errors/app_failure.dart';
import 'package:doctylia_app/core/errors/repository_guard.dart';
import 'package:doctylia_app/core/result/result.dart';
import 'package:doctylia_app/features/practice_setup/domain/entities/practice_setup.dart';
import 'package:doctylia_app/features/practice_setup/domain/repositories/practice_setup_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final class SupabasePracticeSetupRepository implements PracticeSetupRepository {
  SupabasePracticeSetupRepository(this._client, {Random? random})
    : _random = random ?? Random();

  final SupabaseClient _client;
  final Random _random;

  @override
  String? signedInMobile() {
    final phone = _client.auth.currentUser?.phone;
    return phone == null ? null : normalizeIndianMobile(phone);
  }

  @override
  Future<Result<String>> complete(PracticeSetupDetails details) {
    return RepositoryGuard.run(() async {
      try {
        final userId = _client.auth.currentUser?.id;
        if (userId == null) throw const SessionExpiredFailure();
        final slug = await _uniqueSlug(details.fullName, userId);
        // Same update as the web's handleComplete, plus the State and
        // Consultation Fee the form collects (the web form drops them).
        await _client
            .from('profiles')
            .update({
              'full_name': details.fullName,
              'specialization': details.specialization,
              'qualifications': details.qualifications,
              'experience_years': details.experienceYears,
              'consultation_fee': details.consultationFee,
              'clinic_name': details.clinicName,
              'state': details.state,
              'city': details.city,
              'address': details.address,
              'phone': details.phone,
              'slug': slug,
              'onboarding_completed': true,
            })
            .eq('id', userId);
        return slug;
      } catch (error, stackTrace) {
        if (error is AppFailure) rethrow;
        final message = error.toString().toLowerCase();
        if (message.contains('socketexception') ||
            message.contains('clientexception') ||
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

  /// The web's getUniqueSlug: base slug, plus a 4-char base-36 suffix when
  /// another doctor already has it.
  Future<String> _uniqueSlug(String fullName, String userId) async {
    final base = practiceSlugFor(fullName);
    final slug = base.isEmpty ? 'doctor' : base;
    final clash = await _client
        .from('profiles')
        .select('id')
        .eq('slug', slug)
        .neq('id', userId)
        .limit(1);
    if (clash.isEmpty) return slug;
    const chars = '0123456789abcdefghijklmnopqrstuvwxyz';
    final suffix = List.generate(
      4,
      (_) => chars[_random.nextInt(chars.length)],
    ).join();
    return '$slug-$suffix';
  }
}
