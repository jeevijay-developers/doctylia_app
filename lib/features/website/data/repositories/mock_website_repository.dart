import 'package:doctylia_app/core/errors/repository_guard.dart';
import 'package:doctylia_app/core/result/result.dart';
import 'package:doctylia_app/features/website/domain/entities/website_models.dart';
import 'package:doctylia_app/features/website/domain/repositories/website_repository.dart';

final class MockWebsiteRepository implements WebsiteRepository {
  MockWebsiteRepository() : _snapshot = _seed();
  WebsiteSnapshot _snapshot;
  @override
  Future<Result<WebsiteSnapshot>> load() =>
      RepositoryGuard.run(() => _snapshot);
  @override
  Future<Result<WebsiteSnapshot>> save(
    WebsiteSnapshot snapshot,
  ) => RepositoryGuard.run(() {
    if (snapshot.settings.bookingAdvanceDays < 1 ||
        snapshot.settings.bookingAdvanceDays > 365) {
      throw ArgumentError('Advance booking days must be between 1 and 365.');
    }
    if (snapshot.settings.maxPerSlot < 1 || snapshot.settings.maxPerSlot > 50) {
      throw ArgumentError('Max patients per slot must be between 1 and 50.');
    }
    _snapshot = snapshot;
    return snapshot;
  });
  @override
  Future<Result<String>> uploadHeroPhoto(WebsiteImageUpload upload) =>
      RepositoryGuard.run(() => 'https://example.com/doctor/hero-photo.jpg');
  @override
  Future<Result<GalleryPhoto>> uploadGalleryPhoto(WebsiteImageUpload upload) =>
      RepositoryGuard.run(() {
        final photo = GalleryPhoto(
          id: 'gallery-${DateTime.now().microsecondsSinceEpoch}',
          photoUrl: 'https://example.com/doctor/gallery/photo.jpg',
          sortOrder: _snapshot.gallery.length,
        );
        _snapshot = _snapshot.copyWith(gallery: [..._snapshot.gallery, photo]);
        return photo;
      });
  @override
  Future<Result<void>> deleteGalleryPhoto(String id) => RepositoryGuard.run(
    () => _snapshot = _snapshot.copyWith(
      gallery: _snapshot.gallery.where((row) => row.id != id).toList(),
    ),
  );
  @override
  Future<Result<GalleryPhoto>> updateGalleryCaption(
    String id,
    String caption,
  ) => RepositoryGuard.run(() {
    final current = _snapshot.gallery.firstWhere((row) => row.id == id);
    final changed = current.copyWith(caption: caption);
    _snapshot = _snapshot.copyWith(
      gallery: [
        for (final row in _snapshot.gallery)
          if (row.id == id) changed else row,
      ],
    );
    return changed;
  });
  @override
  Future<Result<WebsiteReview>> updateReview(
    String id, {
    bool? isVisible,
    bool? isPinned,
  }) => RepositoryGuard.run(() {
    final current = _snapshot.reviews.firstWhere((row) => row.id == id);
    final changed = current.copyWith(isVisible: isVisible, isPinned: isPinned);
    _snapshot = _snapshot.copyWith(
      reviews: [
        for (final row in _snapshot.reviews)
          if (row.id == id) changed else row,
      ],
    );
    return changed;
  });
  @override
  Stream<void> watchChanges() => const Stream.empty();
}

WebsiteSnapshot _seed() => WebsiteSnapshot(
  settings: const WebsiteSettings(
    slug: 'doctor',
    heroHeadlineLine1: 'Expert care,',
    heroHeadlineLine2: 'close to home.',
    heroDescription: 'Personalized healthcare for you and your family.',
    theme: 'royal',
    showAbout: true,
    showServices: true,
    showGallery: false,
    showReviews: true,
    showBlog: true,
    showClinicDetails: true,
    showOnlineConsultation: true,
    bookingAdvanceDays: 14,
    maxPerSlot: 1,
    cancellationCutoffHours: 4,
    autoConfirm: true,
    bufferMinutes: 10,
    onlineFee: 700,
    onlineDuration: 30,
    whatsappNumber: '+919876543210',
    whatsappMessage: 'Hello, I would like to book an appointment.',
  ),
  services: const [
    WebsiteService(
      id: 'service-1',
      name: 'General Consultation',
      description: 'Comprehensive health consultation',
      price: 700,
      type: 'clinic',
      durationMinutes: 30,
      active: true,
      sortOrder: 0,
    ),
    WebsiteService(
      id: 'service-2',
      name: 'Online Consultation',
      description: 'Secure video consultation',
      price: 700,
      type: 'online',
      durationMinutes: 30,
      active: true,
      sortOrder: 1,
    ),
    WebsiteService(
      id: 'service-3',
      name: 'Follow-up',
      description: 'Follow-up appointment',
      price: 500,
      type: 'both',
      durationMinutes: 20,
      active: true,
      sortOrder: 2,
    ),
  ],
  workingHours: List.generate(
    7,
    (day) => WorkingHour(
      dayOfWeek: day,
      isOpen: day != 0,
      startTime: day == 0 ? null : '09:00',
      endTime: day == 0 ? null : '17:00',
    ),
  ),
  clinic: const WebsiteClinic(
    fullName: 'Aarav Shah',
    specialization: 'General Medicine',
    qualifications: 'MBBS',
    experienceYears: 10,
    phone: '+919876543210',
    clinicName: 'Doctylia Clinic',
    city: 'Mumbai',
    state: 'Maharashtra',
    address: 'Clinic address',
    consultationFee: 700,
    registrationNumber: 'REG-123',
    clinicEmail: 'clinic@example.com',
  ),
);
