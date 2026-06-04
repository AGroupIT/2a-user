import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../network/api_config.dart';

enum AppMediaImageVariant { thumbnail, full }

/// Единая загрузка медиа для карточек/превью.
///
/// Важно: сейчас превью намеренно грузятся через тот же рабочий media URL,
/// что и fullscreen viewer. Backend-thumbnail endpoint может ломать превью
/// на карточках, хотя оригинал при клике открывается корректно. Когда
/// thumbnail-пайплайн будет стабильно проверен на production, сюда можно
/// вернуть ApiConfig.getMediaThumbnailUrl для AppMediaImageVariant.thumbnail.
class AppCachedMediaImage extends StatelessWidget {
  const AppCachedMediaImage({
    super.key,
    required this.url,
    this.variant = AppMediaImageVariant.thumbnail,
    this.thumbnailSize = 360,
    this.fit,
    this.memCacheWidth,
    this.memCacheHeight,
    this.maxWidthDiskCache,
    this.maxHeightDiskCache,
    this.fadeInDuration = Duration.zero,
    this.fadeOutDuration = Duration.zero,
    this.useOldImageOnUrlChange = false,
    this.filterQuality = FilterQuality.low,
    this.imageBuilder,
    this.placeholder,
    this.errorWidget,
  });

  final String url;
  final AppMediaImageVariant variant;
  final int thumbnailSize;
  final BoxFit? fit;
  final int? memCacheWidth;
  final int? memCacheHeight;
  final int? maxWidthDiskCache;
  final int? maxHeightDiskCache;
  final Duration fadeInDuration;
  final Duration fadeOutDuration;
  final bool useOldImageOnUrlChange;
  final FilterQuality filterQuality;
  final ImageWidgetBuilder? imageBuilder;
  final PlaceholderWidgetBuilder? placeholder;
  final LoadingErrorWidgetBuilder? errorWidget;

  @override
  Widget build(BuildContext context) {
    final imageUrl = switch (variant) {
      AppMediaImageVariant.thumbnail => ApiConfig.getMediaUrl(url),
      AppMediaImageVariant.full => ApiConfig.getMediaUrl(url),
    };
    final fallbackErrorWidget = errorWidget ?? _defaultErrorWidget;

    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: fit,
      memCacheWidth: memCacheWidth,
      memCacheHeight: memCacheHeight,
      maxWidthDiskCache: maxWidthDiskCache,
      maxHeightDiskCache: maxHeightDiskCache,
      fadeInDuration: fadeInDuration,
      fadeOutDuration: fadeOutDuration,
      useOldImageOnUrlChange: useOldImageOnUrlChange,
      filterQuality: filterQuality,
      imageBuilder: imageBuilder,
      placeholder: placeholder ?? _defaultPlaceholder,
      errorWidget: (context, url, error) {
        debugPrint('[AppCachedMediaImage] failed: $url — $error');
        return fallbackErrorWidget(context, url, error);
      },
    );
  }

  static Widget _defaultPlaceholder(BuildContext context, String url) {
    return Container(
      color: Colors.black.withValues(alpha: 0.06),
      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }

  static Widget _defaultErrorWidget(
    BuildContext context,
    String url,
    Object error,
  ) {
    return Container(
      color: Colors.black.withValues(alpha: 0.06),
      child: const Center(child: Icon(Icons.broken_image_outlined)),
    );
  }
}
