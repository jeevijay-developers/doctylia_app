import 'package:doctylia_app/app/providers/repository_overrides.dart';
import 'package:doctylia_app/core/realtime/repository_change_coordinator.dart';
import 'package:doctylia_app/features/website/data/repositories/mock_website_repository.dart';
import 'package:doctylia_app/features/website/domain/entities/website_models.dart';
import 'package:doctylia_app/features/website/domain/repositories/website_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final websiteRepositoryProvider = Provider<WebsiteRepository>((ref) {
  if (!ref.watch(appDataSourceProvider).isMock) {
    throw UnsupportedError('Supabase website editor is deferred.');
  }
  return MockWebsiteRepository();
});
final websiteProvider =
    AsyncNotifierProvider<WebsiteController, WebsiteSnapshot>(
      WebsiteController.new,
    );

class WebsiteController extends AsyncNotifier<WebsiteSnapshot> {
  WebsiteRepository get _repo => ref.read(websiteRepositoryProvider);
  @override
  Future<WebsiteSnapshot> build() async {
    final changes = RepositoryChangeCoordinator(
      changes: _repo.watchChanges(),
      refresh: refresh,
    );
    ref.onDispose(changes.dispose);
    return _load();
  }

  Future<WebsiteSnapshot> _load() async {
    final result = await _repo.load();
    return result.fold(
      onSuccess: (value) => value,
      onFailure: (failure) => throw failure,
    );
  }

  void updateSettings(WebsiteSettings settings) {
    final current = state.value;
    if (current != null) {
      state = AsyncData(current.copyWith(settings: settings));
    }
  }

  void updateServices(List<WebsiteService> services) {
    final current = state.value;
    if (current != null) {
      state = AsyncData(current.copyWith(services: services));
    }
  }

  void updateHours(List<WorkingHour> hours) {
    final current = state.value;
    if (current != null) {
      state = AsyncData(current.copyWith(workingHours: hours));
    }
  }

  void updatePackages(List<WebsitePackage> packages) {
    final current = state.value;
    if (current != null) {
      state = AsyncData(current.copyWith(packages: packages));
    }
  }

  void updateClinic(WebsiteClinic clinic) {
    final current = state.value;
    if (current != null) state = AsyncData(current.copyWith(clinic: clinic));
  }

  Future<String?> uploadHero(WebsiteImageUpload upload) async {
    final result = await _repo.uploadHeroPhoto(upload);
    return result.fold(
      onSuccess: (url) {
        final current = state.value;
        if (current != null) {
          state = AsyncData(
            current.copyWith(
              settings: current.settings.copyWith(heroPhotoUrl: url),
            ),
          );
        }
        return null;
      },
      onFailure: (failure) => failure.userMessage,
    );
  }

  Future<String?> uploadGallery(WebsiteImageUpload upload) async {
    final result = await _repo.uploadGalleryPhoto(upload);
    return result.fold(
      onSuccess: (photo) {
        final current = state.value;
        if (current != null) {
          state = AsyncData(
            current.copyWith(gallery: [...current.gallery, photo]),
          );
        }
        return null;
      },
      onFailure: (failure) => failure.userMessage,
    );
  }

  Future<String?> deleteGallery(String id) async {
    final result = await _repo.deleteGalleryPhoto(id);
    return result.fold(
      onSuccess: (_) {
        final current = state.value;
        if (current != null) {
          state = AsyncData(
            current.copyWith(
              gallery: current.gallery.where((row) => row.id != id).toList(),
            ),
          );
        }
        return null;
      },
      onFailure: (failure) => failure.userMessage,
    );
  }

  Future<String?> updateCaption(String id, String caption) async {
    final result = await _repo.updateGalleryCaption(id, caption);
    return result.fold(
      onSuccess: (photo) {
        final current = state.value;
        if (current != null) {
          state = AsyncData(
            current.copyWith(
              gallery: [
                for (final row in current.gallery)
                  if (row.id == id) photo else row,
              ],
            ),
          );
        }
        return null;
      },
      onFailure: (failure) => failure.userMessage,
    );
  }

  Future<String?> updateReview(
    String id, {
    bool? isVisible,
    bool? isPinned,
  }) async {
    final result = await _repo.updateReview(
      id,
      isVisible: isVisible,
      isPinned: isPinned,
    );
    return result.fold(
      onSuccess: (review) {
        final current = state.value;
        if (current != null) {
          state = AsyncData(
            current.copyWith(
              reviews: [
                for (final row in current.reviews)
                  if (row.id == id) review else row,
              ],
            ),
          );
        }
        return null;
      },
      onFailure: (failure) => failure.userMessage,
    );
  }

  Future<String?> save() async {
    final current = state.value;
    if (current == null) return 'Website settings are not ready.';
    final result = await _repo.save(current);
    return result.fold(
      onSuccess: (value) {
        state = AsyncData(value);
        return null;
      },
      onFailure: (failure) => failure.userMessage,
    );
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(_load);
  }
}
