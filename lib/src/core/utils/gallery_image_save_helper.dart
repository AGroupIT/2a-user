import 'package:flutter/foundation.dart';

import 'gallery_image_save_stub.dart'
    if (dart.library.html) 'gallery_image_save_web.dart'
    if (dart.library.io) 'gallery_image_save_mobile.dart';

enum SavedImageDestination { gallery, download }

class SavedImageResult {
  final bool success;
  final SavedImageDestination destination;

  const SavedImageResult({required this.success, required this.destination});
}

/// Сохраняет изображение в системную галерею. В браузере, где прямого доступа
/// к галерее нет, скачивает PNG стандартными средствами браузера.
Future<SavedImageResult> saveImageToGallery({
  required Uint8List bytes,
  required String fileName,
}) async {
  final success = await saveImageToGalleryImpl(
    bytes: bytes,
    fileName: fileName,
  );
  return SavedImageResult(
    success: success,
    destination: kIsWeb || defaultTargetPlatform == TargetPlatform.linux
        ? SavedImageDestination.download
        : SavedImageDestination.gallery,
  );
}
