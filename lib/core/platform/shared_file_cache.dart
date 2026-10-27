import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:doctylia_app/core/logging/app_logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Exports (patient lists, prescriptions, invoices) contain patient data, so
/// they must not pile up in the app cache. Each share writes into one
/// dedicated folder that is emptied before the next share, shortly after the
/// share sheet closes, and on every app start.
abstract final class SharedFileCache {
  static const _folderName = 'doctylia-share';

  /// share_plus copies shared files into `<cache>/share_plus` on Android and
  /// only clears it on the next share.
  static const _pluginFolderName = 'share_plus';

  /// Long enough for the receiving app to read the file after the sheet
  /// closes; the next app start cleans up if the process dies first.
  static const _deleteDelay = Duration(minutes: 2);

  static Future<void> shareText({
    required String fileName,
    required String content,
    required String mimeType,
    String? subject,
  }) => shareBytes(
    fileName: fileName,
    bytes: Uint8List.fromList(utf8.encode(content)),
    mimeType: mimeType,
    subject: subject,
  );

  static Future<void> shareBytes({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    String? subject,
  }) async {
    await _clear(_folderName);
    final directory = await _directory(_folderName);
    await directory.create(recursive: true);
    final file = File('${directory.path}${Platform.pathSeparator}$fileName');
    await file.writeAsBytes(bytes, flush: true);
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: mimeType)],
          subject: subject,
        ),
      );
    } finally {
      unawaited(
        Future<void>.delayed(_deleteDelay, () => _delete(file)),
      );
    }
  }

  /// Removes everything left over from earlier sessions. Call at startup,
  /// before any share can be in progress.
  static Future<void> purge() async {
    await _clear(_folderName);
    await _clear(_pluginFolderName);
  }

  static Future<Directory> _directory(String name) async {
    final temp = await getTemporaryDirectory();
    return Directory('${temp.path}${Platform.pathSeparator}$name');
  }

  static Future<void> _clear(String name) async {
    try {
      final directory = await _directory(name);
      if (await directory.exists()) await directory.delete(recursive: true);
    } catch (error, stackTrace) {
      AppLogger.error(
        'Could not clear shared files',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  static Future<void> _delete(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (error, stackTrace) {
      AppLogger.error(
        'Could not delete shared file',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
