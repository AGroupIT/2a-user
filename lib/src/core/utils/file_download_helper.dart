import 'dart:typed_data';
import 'package:flutter/widgets.dart';

import 'file_download_stub.dart'
    if (dart.library.html) 'file_download_web.dart'
    if (dart.library.io) 'file_download_mobile.dart';

/// Скачивание файла - использует платформо-специфичную реализацию
Future<bool> downloadFile({
  required Uint8List bytes,
  required String fileName,
  GlobalKey? shareButtonKey,
}) async {
  return downloadFileImpl(
    bytes: bytes,
    fileName: fileName,
    shareButtonKey: shareButtonKey,
  );
}
