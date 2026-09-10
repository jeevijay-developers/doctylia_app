import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

abstract interface class ExternalLinkService {
  Future<bool> open(Uri uri);
}

final class UrlLauncherExternalLinkService implements ExternalLinkService {
  const UrlLauncherExternalLinkService();

  @override
  Future<bool> open(Uri uri) {
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

final externalLinkServiceProvider = Provider<ExternalLinkService>((ref) {
  return const UrlLauncherExternalLinkService();
});
