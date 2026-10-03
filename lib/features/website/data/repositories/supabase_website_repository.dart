import 'dart:async';
import 'dart:convert';

import 'package:doctylia_app/core/errors/app_failure.dart';
import 'package:doctylia_app/core/errors/repository_guard.dart';
import 'package:doctylia_app/core/result/result.dart';
import 'package:doctylia_app/features/website/domain/entities/website_models.dart';
import 'package:doctylia_app/features/website/domain/repositories/website_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final class SupabaseWebsiteRepository implements WebsiteRepository {
  SupabaseWebsiteRepository(this._client);
  final SupabaseClient _client;

  String get _doctorId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw const SessionExpiredFailure();
    return id;
  }

  @override
  Future<Result<WebsiteSnapshot>> load() => _guard(() async {
    final result = await Future.wait<dynamic>([
      _client
          .from('website_settings')
          .select()
          .eq('doctor_id', _doctorId)
          .single(),
      _client
          .from('services')
          .select()
          .eq('doctor_id', _doctorId)
          .order('sort_order'),
      _client
          .from('packages')
          .select()
          .eq('doctor_id', _doctorId)
          .order('sort_order'),
      _client
          .from('working_hours')
          .select()
          .eq('doctor_id', _doctorId)
          .order('day_of_week'),
      _client
          .from('gallery_photos')
          .select()
          .eq('doctor_id', _doctorId)
          .order('sort_order'),
      _client
          .from('reviews')
          .select()
          .eq('doctor_id', _doctorId)
          .order('created_at', ascending: false),
      _client.from('profiles').select().eq('id', _doctorId).single(),
    ]);
    final settings = result[0] as Map<String, dynamic>;
    final profile = result[6] as Map<String, dynamic>;
    return WebsiteSnapshot(
      settings: _settings(settings, profile),
      services: (result[1] as List)
          .cast<Map<String, dynamic>>()
          .map(_service)
          .toList(growable: false),
      packages: (result[2] as List)
          .cast<Map<String, dynamic>>()
          .map(_package)
          .toList(growable: false),
      workingHours: (result[3] as List)
          .cast<Map<String, dynamic>>()
          .map(_hour)
          .toList(growable: false),
      gallery: (result[4] as List)
          .cast<Map<String, dynamic>>()
          .map(_gallery)
          .toList(growable: false),
      reviews: (result[5] as List)
          .cast<Map<String, dynamic>>()
          .map(_review)
          .toList(growable: false),
      clinic: _clinic(profile),
    );
  });

  @override
  Future<Result<WebsiteSnapshot>> save(WebsiteSnapshot snapshot) =>
      _guard(() async {
        _validate(snapshot);
        await _client
            .from('website_settings')
            .update(_settingsJson(snapshot.settings))
            .eq('doctor_id', _doctorId);
        if (snapshot.clinic != null) {
          await _client
              .from('profiles')
              .update(_clinicJson(snapshot.clinic!))
              .eq('id', _doctorId);
        }
        await _syncServices(snapshot.services);
        await _syncPackages(snapshot.packages);
        for (final hour in snapshot.workingHours) {
          final values = {
            'is_open': hour.isOpen,
            'start_time': hour.startTime,
            'end_time': hour.endTime,
            'start_time_2': hour.startTime2,
            'end_time_2': hour.endTime2,
          };
          if (hour.id == null) {
            await _client.from('working_hours').insert({
              'doctor_id': _doctorId,
              'day_of_week': hour.dayOfWeek,
              ...values,
            });
          } else {
            await _client
                .from('working_hours')
                .update(values)
                .eq('id', hour.id!)
                .eq('doctor_id', _doctorId);
          }
        }
        return (await load()).fold(
          onSuccess: (value) => value,
          onFailure: (failure) => throw failure,
        );
      });

  Future<void> _syncServices(List<WebsiteService> rows) async {
    final existing = await _client
        .from('services')
        .select('id')
        .eq('doctor_id', _doctorId);
    final kept = rows
        .where((row) => !row.id.startsWith('new-'))
        .map((row) => row.id)
        .toSet();
    final removed = existing
        .map((row) => row['id'] as String)
        .where((id) => !kept.contains(id))
        .toList();
    if (removed.isNotEmpty) {
      await _client
          .from('services')
          .delete()
          .eq('doctor_id', _doctorId)
          .inFilter('id', removed);
    }
    for (final row in rows) {
      final values = _serviceJson(row);
      if (row.id.startsWith('new-')) {
        await _client.from('services').insert({
          'doctor_id': _doctorId,
          ...values,
        });
      } else {
        await _client
            .from('services')
            .update(values)
            .eq('id', row.id)
            .eq('doctor_id', _doctorId);
      }
    }
  }

  Future<void> _syncPackages(List<WebsitePackage> rows) async {
    final existing = await _client
        .from('packages')
        .select('id')
        .eq('doctor_id', _doctorId);
    final kept = rows
        .where((row) => !row.id.startsWith('new-'))
        .map((row) => row.id)
        .toSet();
    final removed = existing
        .map((row) => row['id'] as String)
        .where((id) => !kept.contains(id))
        .toList();
    if (removed.isNotEmpty) {
      await _client
          .from('packages')
          .delete()
          .eq('doctor_id', _doctorId)
          .inFilter('id', removed);
    }
    for (final row in rows) {
      final values = _packageJson(row);
      if (row.id.startsWith('new-')) {
        await _client.from('packages').insert({
          'doctor_id': _doctorId,
          ...values,
        });
      } else {
        await _client
            .from('packages')
            .update(values)
            .eq('id', row.id)
            .eq('doctor_id', _doctorId);
      }
    }
  }

  @override
  Future<Result<String>> uploadHeroPhoto(
    WebsiteImageUpload upload,
  ) => _guard(() async {
    final extension = _extension(upload.fileName);
    _validateImage(extension, upload.bytes.length);
    final path = '$_doctorId/hero-photo.$extension';
    await _client.storage
        .from('doctor-uploads')
        .uploadBinary(
          path,
          upload.bytes,
          fileOptions: FileOptions(upsert: true, contentType: upload.mimeType),
        );
    final publicUrl = _client.storage.from('doctor-uploads').getPublicUrl(path);
    return '$publicUrl?v=${DateTime.now().millisecondsSinceEpoch}';
  });

  @override
  Future<Result<GalleryPhoto>> uploadGalleryPhoto(
    WebsiteImageUpload upload,
  ) => _guard(() async {
    final count = await _client
        .from('gallery_photos')
        .count(CountOption.exact)
        .eq('doctor_id', _doctorId);
    if (count >= 6) {
      throw const ValidationFailure('The gallery supports up to 6 photos.');
    }
    final extension = _extension(upload.fileName);
    _validateImage(extension, upload.bytes.length);
    final path =
        '$_doctorId/gallery/${DateTime.now().millisecondsSinceEpoch}.$extension';
    await _client.storage
        .from('doctor-uploads')
        .uploadBinary(
          path,
          upload.bytes,
          fileOptions: FileOptions(contentType: upload.mimeType),
        );
    final publicUrl = _client.storage.from('doctor-uploads').getPublicUrl(path);
    final row = await _client
        .from('gallery_photos')
        .insert({
          'doctor_id': _doctorId,
          'photo_url': publicUrl,
          'sort_order': count,
        })
        .select()
        .single();
    return _gallery(row);
  });

  @override
  Future<Result<void>> deleteGalleryPhoto(String id) => _guard(() async {
    // Web intentionally deletes the gallery row only; the storage object remains orphaned.
    await _client
        .from('gallery_photos')
        .delete()
        .eq('id', id)
        .eq('doctor_id', _doctorId);
  });

  @override
  Future<Result<GalleryPhoto>> updateGalleryCaption(
    String id,
    String caption,
  ) => _guard(() async {
    final row = await _client
        .from('gallery_photos')
        .update({'caption': _empty(caption)})
        .eq('id', id)
        .eq('doctor_id', _doctorId)
        .select()
        .single();
    return _gallery(row);
  });

  @override
  Future<Result<WebsiteReview>> updateReview(
    String id, {
    bool? isVisible,
    bool? isPinned,
  }) => _guard(() async {
    final values = <String, dynamic>{
      'is_visible': ?isVisible,
      'is_pinned': ?isPinned,
    };
    final row = await _client
        .from('reviews')
        .update(values)
        .eq('id', id)
        .eq('doctor_id', _doctorId)
        .select()
        .single();
    return _review(row);
  });

  @override
  Stream<void> watchChanges() {
    final controller = StreamController<void>();
    final channel = _client.channel('mobile-website-$_doctorId');
    for (final table in [
      'website_settings',
      'services',
      'packages',
      'working_hours',
      'gallery_photos',
      'reviews',
    ]) {
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'doctor_id',
          value: _doctorId,
        ),
        callback: (_) => controller.add(null),
      );
    }
    channel.subscribe();
    controller.onCancel = () async {
      await _client.removeChannel(channel);
      await controller.close();
    };
    return controller.stream;
  }

  static WebsiteSettings _settings(
    Map<String, dynamic> row,
    Map<String, dynamic> profile,
  ) => WebsiteSettings(
    slug: profile['slug'] as String? ?? '',
    heroHeadlineLine1: row['hero_headline_line1'] as String? ?? '',
    heroHeadlineLine2: row['hero_headline_line2'] as String? ?? '',
    heroDescription: row['hero_description'] as String? ?? '',
    theme: row['theme'] as String? ?? 'royal',
    heroPhotoUrl: row['hero_photo_url'] as String?,
    heroLocationLabel: row['hero_location_label'] as String? ?? '',
    heroHoursLabel: row['hero_hours_label'] as String? ?? '',
    heroPrimaryButtonLabel: row['hero_primary_button_label'] as String? ?? '',
    heroSecondaryButtonLabel:
        row['hero_secondary_button_label'] as String? ?? '',
    heroDirectionsLabel: row['hero_directions_label'] as String? ?? '',
    heroStatText: row['hero_stat_text'] as String? ?? '',
    heroStatIcon: row['hero_stat_icon'] as String? ?? 'Star',
    showHeroStatBadge: row['show_hero_stat_badge'] as bool? ?? true,
    showQuickStats: row['show_quick_stats'] as bool? ?? true,
    quickStats: _quickStats(row['seo_keywords']),
    showAbout: row['show_about'] as bool? ?? true,
    showServices: row['show_services'] as bool? ?? true,
    showGallery: row['show_gallery'] as bool? ?? true,
    showReviews: row['show_reviews'] as bool? ?? true,
    showBlog: row['show_blog'] as bool? ?? false,
    showClinicDetails: row['show_clinic_details'] as bool? ?? true,
    showOnlineConsultation: row['show_online_consultation'] as bool? ?? false,
    showPackages: row['show_packages'] as bool? ?? true,
    bookingAdvanceDays: (row['booking_advance_days'] as num?)?.toInt() ?? 7,
    maxPerSlot: (row['max_per_slot'] as num?)?.toInt() ?? 1,
    cancellationCutoffHours:
        (row['cancellation_cutoff_hours'] as num?)?.toInt() ?? 2,
    autoConfirm: row['auto_confirm'] as bool? ?? true,
    bufferMinutes: (row['buffer_minutes'] as num?)?.toInt() ?? 0,
    requirePayment: row['require_payment'] as bool? ?? false,
    onlineFee: (row['online_fee'] as num?)?.toDouble() ?? 500,
    onlineDuration: (row['online_duration'] as num?)?.toInt() ?? 30,
    videoProvider: row['video_provider'] as String? ?? 'zoom',
    whatsappNumber: row['whatsapp_number'] as String? ?? '',
    whatsappMessage: row['whatsapp_message'] as String? ?? '',
    seoTitle: row['seo_title'] as String? ?? '',
    seoDescription: row['seo_description'] as String? ?? '',
    seoKeywords: row['seo_keywords'] as String? ?? '',
    socialFacebook: row['social_facebook'] as String? ?? '',
    socialInstagram: row['social_instagram'] as String? ?? '',
    socialYoutube: row['social_youtube'] as String? ?? '',
    socialLinkedin: row['social_linkedin'] as String? ?? '',
    googleAnalyticsId: row['google_analytics_id'] as String? ?? '',
  );

  // Several of these columns are Postgres integers (online_fee, prices):
  // a Dart double serialises as "500.0" and PostgREST rejects the whole
  // update with 22P02, which surfaced as "Something went wrong".
  @visibleForTesting
  static Map<String, dynamic> settingsJson(WebsiteSettings s) =>
      _settingsJson(s);

  @visibleForTesting
  static Map<String, dynamic> serviceJson(WebsiteService row) =>
      _serviceJson(row);

  @visibleForTesting
  static Map<String, dynamic> packageJson(WebsitePackage row) =>
      _packageJson(row);

  static Map<String, dynamic> _serviceJson(WebsiteService row) => {
    'name': row.name.trim(),
    'description': _empty(row.description),
    'price': row.price.round(),
    'type': row.type,
    'duration': row.durationMinutes,
    'active': row.active,
    'sort_order': row.sortOrder,
  };

  static Map<String, dynamic> _packageJson(WebsitePackage row) => {
    'name': row.name.trim(),
    'tagline': _empty(row.tagline),
    'price': row.price.round(),
    'original_price': row.originalPrice?.round(),
    'duration': _empty(row.duration),
    'features': row.features,
    'slots_available': row.slotsAvailable,
    'active': row.active,
    'is_popular': row.isPopular,
    'sort_order': row.sortOrder,
  };

  static Map<String, dynamic> _settingsJson(WebsiteSettings s) => {
    'hero_headline_line1': s.heroHeadlineLine1,
    'hero_headline_line2': s.heroHeadlineLine2,
    'hero_description': s.heroDescription,
    'theme': s.theme,
    'hero_photo_url': s.heroPhotoUrl,
    'hero_location_label': s.heroLocationLabel,
    'hero_hours_label': s.heroHoursLabel,
    'hero_primary_button_label': s.heroPrimaryButtonLabel,
    'hero_secondary_button_label': s.heroSecondaryButtonLabel,
    'hero_directions_label': s.heroDirectionsLabel,
    'hero_stat_text': s.heroStatText,
    'hero_stat_icon': s.heroStatIcon,
    'show_hero_stat_badge': s.showHeroStatBadge,
    'show_quick_stats': s.showQuickStats,
    'show_about': s.showAbout,
    'show_services': s.showServices,
    'show_gallery': s.showGallery,
    'show_reviews': s.showReviews,
    'show_blog': s.showBlog,
    'show_clinic_details': s.showClinicDetails,
    'show_online_consultation': s.showOnlineConsultation,
    'show_packages': s.showPackages,
    'booking_advance_days': s.bookingAdvanceDays,
    'max_per_slot': s.maxPerSlot,
    'cancellation_cutoff_hours': s.cancellationCutoffHours,
    'auto_confirm': s.autoConfirm,
    'buffer_minutes': s.bufferMinutes,
    'require_payment': s.requirePayment,
    'online_fee': s.onlineFee.round(),
    'online_duration': s.onlineDuration,
    'video_provider': s.videoProvider,
    'whatsapp_number': _empty(s.whatsappNumber),
    'whatsapp_message': _empty(s.whatsappMessage),
    'seo_title': _empty(s.seoTitle),
    'seo_description': _empty(s.seoDescription),
    'seo_keywords': jsonEncode(
      s.quickStats.map((row) => row.toJson()).toList(),
    ),
    'social_facebook': _empty(s.socialFacebook),
    'social_instagram': _empty(s.socialInstagram),
    'social_youtube': _empty(s.socialYoutube),
    'social_linkedin': _empty(s.socialLinkedin),
    'google_analytics_id': _empty(s.googleAnalyticsId),
  };

  static WebsiteService _service(Map<String, dynamic> row) => WebsiteService(
    id: row['id'] as String,
    name: row['name'] as String,
    description: row['description'] as String? ?? '',
    price: (row['price'] as num).toDouble(),
    type: row['type'] as String,
    durationMinutes: (row['duration'] as num?)?.toInt() ?? 30,
    active: row['active'] as bool,
    sortOrder: (row['sort_order'] as num).toInt(),
  );

  static List<WebsiteQuickStat> _quickStats(Object? value) {
    if (value is! String || value.isEmpty) return defaultQuickStats;
    try {
      final decoded = jsonDecode(value);
      if (decoded is! List || decoded.isEmpty) return defaultQuickStats;
      return decoded.whereType<Map>().map((row) {
        final value = Map<String, dynamic>.from(row);
        return WebsiteQuickStat(
          id: value['id'] as String? ?? 'custom',
          label: value['label'] as String? ?? '',
          value: value['value'] as String? ?? '',
          icon: value['icon'] as String? ?? 'Users',
          active: value['active'] as bool? ?? true,
        );
      }).toList();
    } catch (_) {
      return defaultQuickStats;
    }
  }

  static WebsitePackage _package(Map<String, dynamic> row) => WebsitePackage(
    id: row['id'] as String,
    name: row['name'] as String,
    tagline: row['tagline'] as String? ?? '',
    price: (row['price'] as num).toDouble(),
    originalPrice: (row['original_price'] as num?)?.toDouble(),
    duration: row['duration'] as String? ?? '',
    features: row['features'] is List
        ? (row['features'] as List).whereType<String>().toList()
        : const [],
    slotsAvailable: (row['slots_available'] as num?)?.toInt(),
    active: row['active'] as bool,
    isPopular: row['is_popular'] as bool,
    sortOrder: (row['sort_order'] as num).toInt(),
  );
  static WorkingHour _hour(Map<String, dynamic> row) => WorkingHour(
    id: row['id'] as String,
    dayOfWeek: (row['day_of_week'] as num).toInt(),
    isOpen: row['is_open'] as bool,
    startTime: row['start_time'] as String?,
    endTime: row['end_time'] as String?,
    startTime2: row['start_time_2'] as String?,
    endTime2: row['end_time_2'] as String?,
  );
  static GalleryPhoto _gallery(Map<String, dynamic> row) => GalleryPhoto(
    id: row['id'] as String,
    photoUrl: row['photo_url'] as String,
    sortOrder: (row['sort_order'] as num).toInt(),
    caption: row['caption'] as String?,
  );
  static WebsiteReview _review(Map<String, dynamic> row) => WebsiteReview(
    id: row['id'] as String,
    patientName: row['patient_name'] as String,
    rating: (row['rating'] as num).toInt(),
    reviewText: row['review_text'] as String?,
    isVisible: row['is_visible'] as bool,
    isPinned: row['is_pinned'] as bool,
    createdAt: DateTime.parse(row['created_at'] as String),
  );
  static WebsiteClinic _clinic(Map<String, dynamic> row) => WebsiteClinic(
    fullName: row['full_name'] as String? ?? '',
    specialization: row['specialization'] as String? ?? '',
    qualifications: row['qualifications'] as String? ?? '',
    experienceYears: (row['experience_years'] as num?)?.toInt() ?? 0,
    phone: row['phone'] as String? ?? '',
    clinicName: row['clinic_name'] as String? ?? '',
    city: row['city'] as String? ?? '',
    state: row['state'] as String? ?? '',
    address: row['address'] as String? ?? '',
    consultationFee: (row['consultation_fee'] as num?)?.toDouble() ?? 0,
    registrationNumber: row['registration_number'] as String? ?? '',
    clinicEmail: row['clinic_email'] as String? ?? '',
  );
  static Map<String, dynamic> _clinicJson(WebsiteClinic p) => {
    'full_name': _empty(p.fullName),
    'specialization': _empty(p.specialization),
    'qualifications': _empty(p.qualifications),
    'experience_years': p.experienceYears,
    'phone': _empty(p.phone),
    'clinic_name': _empty(p.clinicName),
    'city': _empty(p.city),
    'state': _empty(p.state),
    'address': _empty(p.address),
    'consultation_fee': p.consultationFee,
    'registration_number': _empty(p.registrationNumber),
    'clinic_email': _empty(p.clinicEmail),
  };

  static void _validate(WebsiteSnapshot snapshot) {
    if (snapshot.clinic != null) {
      if (snapshot.clinic!.fullName.trim().isEmpty) {
        throw const ValidationFailure('Doctor name is required.');
      }
      if (snapshot.clinic!.specialization.trim().isEmpty) {
        throw const ValidationFailure('Specialization is required.');
      }
    }
    for (final service in snapshot.services) {
      if (service.name.trim().isEmpty) {
        throw const ValidationFailure('Every service needs a name.');
      }
      if (service.price < 0) {
        throw ValidationFailure(
          'Price for "${service.name}" cannot be negative.',
        );
      }
      if (service.durationMinutes < 1) {
        throw ValidationFailure(
          'Duration for "${service.name}" must be at least 1 minute.',
        );
      }
    }
    for (final package in snapshot.packages) {
      if (package.name.trim().isEmpty) {
        throw const ValidationFailure('Every package needs a name.');
      }
      if (package.price < 0 ||
          (package.originalPrice != null && package.originalPrice! < 0)) {
        throw ValidationFailure(
          'Price for "${package.name}" cannot be negative.',
        );
      }
    }
    final s = snapshot.settings;
    if (s.onlineFee < 0) {
      throw const ValidationFailure(
        'Online consultation fee cannot be negative.',
      );
    }
    if (s.bookingAdvanceDays < 1 || s.bookingAdvanceDays > 365) {
      throw const ValidationFailure(
        'Advance booking days must be between 1 and 365.',
      );
    }
    if (s.maxPerSlot < 1 || s.maxPerSlot > 50) {
      throw const ValidationFailure(
        'Max bookings per slot must be between 1 and 50.',
      );
    }
    if (s.cancellationCutoffHours < 0) {
      throw const ValidationFailure(
        'Cancellation cutoff hours cannot be negative.',
      );
    }
  }

  static void _validateImage(String extension, int size) {
    if (!{'jpg', 'jpeg', 'png', 'webp', 'gif'}.contains(extension)) {
      throw const ValidationFailure('Choose a JPG, PNG, WebP or GIF image.');
    }
    if (size > 10 * 1024 * 1024) {
      throw const ValidationFailure('Image must be smaller than 10 MB.');
    }
  }

  static String _extension(String name) =>
      name.contains('.') ? name.split('.').last.toLowerCase() : '';
  static String? _empty(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? null : text;
  }

  Future<Result<T>> _guard<T>(Future<T> Function() operation) =>
      RepositoryGuard.run(() async {
        try {
          return await operation();
        } catch (error, stackTrace) {
          if (error is AppFailure) rethrow;
          final text = error.toString().toLowerCase();
          if (error is TimeoutException ||
              text.contains('socketexception') ||
              text.contains('failed host lookup')) {
            throw NetworkFailure(cause: error, stackTrace: stackTrace);
          }
          if (error is PostgrestException && error.code == '42501') {
            throw const PermissionFailure();
          }
          if (text.contains('online_consultation_requires_premium')) {
            throw const PlanRestrictedFailure('online consultation');
          }
          if (error is PostgrestException &&
              const {'22P02', '23502', '23514'}.contains(error.code)) {
            throw const ValidationFailure(
              'One of the values in this section is not valid. '
              'Please check numbers and required fields.',
            );
          }
          throw ServerFailure(cause: error, stackTrace: stackTrace);
        }
      });
}
