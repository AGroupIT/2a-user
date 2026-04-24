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
  /// Default параметры. Профиль "Вариант B" из обсуждения 2026-04-24:
  /// максимальное качество, БЕЗ ресайза — экономим канал на более
  /// эффективном формате (WebP Q92 vs JPEG), но сохраняем все пиксели
  /// и все детали. iPhone 4032x3024 → тот же 4032x3024 в WebP Q92.
  /// Обычно даёт 2x-3x экономию размера при визуально неотличимом
  /// качестве. Критично для фотоотчётов, где важны мелкие детали
  /// (текст на накладной, повреждения груза и т.п.).
  static const int _defaultMaxSide = 8000; // фактически «не ресайзить»
  static const int _defaultQuality = 92;

  /// Сжимает произвольную картинку в WebP. Если WebP не доступен на
  /// платформе (iOS Simulator без libwebp) — fallback: возвращаем оригинал
  /// с правильным mime-type.
  ///
  /// [sourceBytes] — оригинальные байты (то, что пришло из image_picker).
  /// [sourceName] — исходное имя файла (для fallback mime-type определения).
  /// [maxSide] — ограничение по длинной стороне в пикселях. По умолчанию
  ///   8000 — практически не ресайзим (важные детали сохраняются).
  /// [quality] — 0-100, WebP/JPEG quality. По умолчанию 92 — визуально
  ///   неотличимо от оригинала.
  ///
  /// Возвращает record: (bytes, mimeType, extension).
  static Future<({Uint8List bytes, String mimeType, String extension})> compressForUpload(
    Uint8List sourceBytes, {
    String? sourceName,
    int maxSide = _defaultMaxSide,
    int quality = _defaultQuality,
    CompressFormat preferredFormat = CompressFormat.webp,
  }) async {
    if (sourceBytes.isEmpty) {
      return (bytes: sourceBytes, mimeType: 'application/octet-stream', extension: 'bin');
    }

    // Маленькие картинки (<500KB) не трогаем — экономия сомнительна,
    // а сжатие может дать итог БОЛЬШЕ оригинала (для уже сжатых
    // скриншотов, мелких фото с невысоким разрешением).
    if (sourceBytes.lengthInBytes < 500 * 1024) {
      return _pickFallbackTypeFromName(sourceBytes, sourceName);
    }

    try {
      final compressed = await FlutterImageCompress.compressWithList(
        sourceBytes,
        minWidth: maxSide,
        minHeight: maxSide,
        quality: quality,
        format: preferredFormat,
        keepExif: false,
      );

      if (compressed.isEmpty || compressed.length >= sourceBytes.length) {
        // Сжатие не дало выигрыша — возвращаем оригинал.
        return _pickFallbackTypeFromName(sourceBytes, sourceName);
      }

      final (mimeType, ext) = _mimeForFormat(preferredFormat);
      if (kDebugMode) {
        debugPrint(
          '[ImageCompressor] ${sourceBytes.lengthInBytes} B → ${compressed.length} B '
          '(${(100 * compressed.length / sourceBytes.lengthInBytes).toStringAsFixed(0)}%) $mimeType',
        );
      }
      return (bytes: compressed, mimeType: mimeType, extension: ext);
    } catch (e) {
      debugPrint('[ImageCompressor] compress failed: $e — sending original');
      return _pickFallbackTypeFromName(sourceBytes, sourceName);
    }
  }

  static (String, String) _mimeForFormat(CompressFormat f) => switch (f) {
        CompressFormat.webp => ('image/webp', 'webp'),
        CompressFormat.jpeg => ('image/jpeg', 'jpg'),
        CompressFormat.png => ('image/png', 'png'),
        CompressFormat.heic => ('image/heic', 'heic'),
      };

  static ({Uint8List bytes, String mimeType, String extension}) _pickFallbackTypeFromName(
    Uint8List bytes,
    String? name,
  ) {
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
