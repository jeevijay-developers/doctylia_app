import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// "Doctylia v1.0.0 (1)" from the installed app. Errors (e.g. widget tests
/// without the platform plugin) leave it unresolved; callers hide the line.
final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return 'Doctylia v${info.version} (${info.buildNumber})';
});
