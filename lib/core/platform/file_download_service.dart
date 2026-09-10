import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract interface class FileDownloadService {
  Future<void> savePdf({required String fileName, required Uint8List bytes});
}

final class FilePickerDownloadService implements FileDownloadService {
  const FilePickerDownloadService();

  @override
  Future<void> savePdf({
    required String fileName,
    required Uint8List bytes,
  }) async {
    await FilePicker.platform.saveFile(
      dialogTitle: 'Download prescription',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      bytes: bytes,
    );
  }
}

final fileDownloadServiceProvider = Provider<FileDownloadService>((ref) {
  return const FilePickerDownloadService();
});
