import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../network/api_config.dart';

enum AppMediaImageVariant { thumbnail, full }

/// Единая загрузка медиа для карточек/превью.
///
/// Для превью берём backend-thumbnail вместо оригинала, поэтому web/iOS/Android
/// не скачивают тяжёлое изображение для маленькой плитки. Оригинал остаётся для
/// fullscreen viewer, скачивания и share.
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
      AppMediaImageVariant.thumbnail => ApiConfig.getMediaThumbnailUrl(
        url,
        size: thumbnailSize,
      ),
      AppMediaImageVariant.full => ApiConfig.getMediaUrl(url),
    };

    return CachedNetworkImage(
      imageUrl: imageUrl,
      cacheManager: AppMediaCacheManager.instance,
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
      errorWidget: errorWidget ?? _defaultErrorWidget,
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

class AppMediaCacheManager {
  AppMediaCacheManager._();

  static const cacheKey = '2a_user_media_cache_v1';

  /// flutter_cache_manager ограничивает кеш числом объектов, а не байтами.
  /// Ставим высокий лимит для фоток/thumbnail без раздувания памяти: сами
  /// превью приходят уже уменьшенными backend-ом.
  static final CacheManager instance = CacheManager(
    Config(
      cacheKey,
      stalePeriod: const Duration(days: 90),
      maxNrOfCacheObjects: 5000,
    ),
  );
}
