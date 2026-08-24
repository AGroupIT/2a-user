import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Клиентское сжатие изображений перед upload'ом.
///
/// Основная задача — сократить payload для китайских клиентов,
/// у которых канал до HK-прокси медленный и с потерями. iPhone-камера
/// генерит JPEG по 3-5 MB, мы уменьшаем до 300-500 KB (WebP Q80)
/// без заметной потери качества для фотоотчётов/вопросов/чата.
///
/// Возвращает исходные байты, если сжатие упало или дало НЕ меньше
/// оригинала (это возможно на очень маленьких уже сжатых файлах).
class ImageCompressor {
  /// Default параметры для нестабильных сетей и Next.js multipart limit.
  ///
  /// Старый режим почти не ресайзил фото (`8000px`, Q92), из-за чего
  /// iPhone/modern camera images могли уходить больше 10MB. Next.js App Router
  /// в production режет такие multipart тела на 10MB до route handler'а, и
  /// `request.formData()` получает битый multipart без финальной boundary.
  static const int _defaultMaxSide = 2400;
  static const int _defaultQuality = 82;

  /// Сжимает произвольную картинку в WebP. Если WebP не доступен на
  /// платформе (iOS Simulator без libwebp) — fallback: возвращаем оригинал
  /// с правильным mime-type.
  ///
  /// [sourceBytes] — оригинальные байты (то, что пришло из image_picker).
  /// [sourceName] — исходное имя файла (для fallback mime-type определения).
  /// [maxSide] — ограничение по длинной стороне в пикселях.
  /// [quality] — 0-100, WebP/JPEG quality.
  ///
  /// Возвращает record: (bytes, mimeType, extension).
  static Future<({Uint8List bytes, String mimeType, String extension})>
  compressForUpload(
    Uint8List sourceBytes, {
    String? sourceName,
    int maxSide = _defaultMaxSide,
    int quality = _defaultQuality,
    CompressFormat preferredFormat = CompressFormat.webp,
    bool forceTranscode = false,
  }) async {
    if (sourceBytes.isEmpty) {
      return (
        bytes: sourceBytes,
        mimeType: 'application/octet-stream',
        extension: 'bin',
      );
    }

    // Маленькие картинки (<500KB) не трогаем — экономия сомнительна,
    // а сжатие может дать итог БОЛЬШЕ оригинала (для уже сжатых
    // скриншотов, мелких фото с невысоким разрешением).
    if (!forceTranscode && sourceBytes.lengthInBytes < 500 * 1024) {
      return _pickFallbackTypeFromName(sourceBytes, sourceName);
    }

    final preferred = await _tryCompress(
      sourceBytes,
      format: preferredFormat,
      maxSide: maxSide,
      quality: quality,
      requireSmaller: !forceTranscode,
    );
    if (preferred != null) return preferred;

    // На некоторых платформах WebP недоступен. В этом случае всё равно
    // пробуем JPEG-resize, а не отправляем оригинальный iPhone JPEG.
    if (preferredFormat != CompressFormat.jpeg) {
      final jpegFallback = await _tryCompress(
        sourceBytes,
        format: CompressFormat.jpeg,
        maxSide: maxSide,
        quality: quality,
        requireSmaller: !forceTranscode,
      );
      if (jpegFallback != null) return jpegFallback;
    }

    return _pickFallbackTypeFromName(sourceBytes, sourceName);
  }

  static Future<({Uint8List bytes, String mimeType, String extension})?>
  _tryCompress(
    Uint8List sourceBytes, {
    required CompressFormat format,
    required int maxSide,
    required int quality,
    bool requireSmaller = true,
  }) async {
    try {
      final compressed = await FlutterImageCompress.compressWithList(
        sourceBytes,
        minWidth: maxSide,
        minHeight: maxSide,
        quality: quality,
        format: format,
        keepExif: false,
      );

      if (compressed.isEmpty ||
          (requireSmaller && compressed.length >= sourceBytes.lengthInBytes)) {
        return null;
      }

      final (mimeType, ext) = _mimeForFormat(format);
      if (kDebugMode) {
        debugPrint(
          '[ImageCompressor] ${sourceBytes.lengthInBytes} B -> ${compressed.length} B '
          '(${(100 * compressed.length / sourceBytes.lengthInBytes).toStringAsFixed(0)}%) $mimeType',
        );
      }
      return (bytes: compressed, mimeType: mimeType, extension: ext);
    } catch (e) {
      debugPrint('[ImageCompressor] $format compress failed: $e');
      return null;
    }
  }

  static (String, String) _mimeForFormat(CompressFormat f) => switch (f) {
    CompressFormat.webp => ('image/webp', 'webp'),
    CompressFormat.jpeg => ('image/jpeg', 'jpg'),
    CompressFormat.png => ('image/png', 'png'),
    CompressFormat.heic => ('image/heic', 'heic'),
  };

  static ({Uint8List bytes, String mimeType, String extension})
  _pickFallbackTypeFromName(Uint8List bytes, String? name) {
    final lowerName = (name ?? '').toLowerCase();
    if (lowerName.endsWith('.png')) {
      return (bytes: bytes, mimeType: 'image/png', extension: 'png');
    }
    if (lowerName.endsWith('.heic') || lowerName.endsWith('.heif')) {
      return (bytes: bytes, mimeType: 'image/heic', extension: 'heic');
    }
    if (lowerName.endsWith('.webp')) {
      return (bytes: bytes, mimeType: 'image/webp', extension: 'webp');
    }
    return (bytes: bytes, mimeType: 'image/jpeg', extension: 'jpg');
  }
}
