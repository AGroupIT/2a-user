import 'dart:async';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';
import '../network/api_config.dart';

/// Return a relative API path only for an exact trusted origin and media path.
/// External images, look-alike domains and arbitrary URLs never receive tokens.
String? authenticatedMediaPath(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null || uri.userInfo.isNotEmpty) return null;
  if (uri.hasAuthority) {
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    final trusted = <String>{
      Uri.parse(ApiConfig.baseUrl).origin,
      Uri.parse(ApiConfig.mediaBaseUrl).origin,
      'https://api.2a-logistic.com',
      if (ApiConfig.fallbackBaseUrl != null)
        Uri.parse(ApiConfig.fallbackBaseUrl!).origin,
    };
    trusted.add('https://2alogistic.2a-marketing.ru');
    if (!uri.hasScheme || !trusted.contains(uri.origin)) return null;
  } else if (uri.hasScheme) {
    return null;
  }
  final path = uri.path.startsWith('/') ? uri.path : '/${uri.path}';
  final upload =
      path.startsWith('/uploads/') || path.startsWith('/api/uploads/');
  final attachment = RegExp(
    r'^/(?:api/)?support/attachments/[0-9]+$',
  ).hasMatch(path);
  final playback =
      path == '/api/assembly-scan-media/playback' ||
      path == '/assembly-scan-media/playback';
  if (!upload && !attachment && !playback) return null;
  final apiPath = path.startsWith('/api/') ? path.substring(4) : path;
  return Uri(path: apiPath, query: uri.hasQuery ? uri.query : null).toString();
}

ApiClient mediaApiClient(BuildContext context) =>
    ProviderScope.containerOf(context, listen: false).read(apiClientProvider);

Future<Response<List<int>>> loadMediaResponse(
  ApiClient api,
  String url, {
  ProgressCallback? onReceiveProgress,
}) async {
  final path = authenticatedMediaPath(url);
  final options = Options(
    responseType: ResponseType.bytes,
    // Already-compressed media must retain Content-Length. The API compresses
    // gzip requests as chunked responses, which report an unknown byte total.
    headers: {
      if (!kIsWeb) 'Accept-Encoding': 'identity',
      // Browsers own Accept-Encoding. A complete single range keeps these
      // upload responses uncompressed while preserving their exact byte size.
      if (kIsWeb && path != null && path.startsWith('/uploads/'))
        'Range': 'bytes=0-',
    },
    receiveTimeout: const Duration(minutes: 5),
    followRedirects: false,
    maxRedirects: 0,
  );
  final Response<List<int>> response;
  if (path != null) {
    response = onReceiveProgress == null
        ? await api.get<List<int>>(path, options: options)
        : await api.getWithProgress<List<int>>(
            path,
            options: options,
            onReceiveProgress: onReceiveProgress,
          );
  } else {
    final dio = Dio();
    try {
      response = await dio.get<List<int>>(
        url,
        options: options,
        onReceiveProgress: onReceiveProgress,
      );
    } finally {
      dio.close();
    }
  }
  if (response.statusCode != 200 && response.statusCode != 206) {
    throw StateError('Media request denied');
  }
  return response;
}

Future<Uint8List> loadMediaBytes(
  ApiClient api,
  String url, {
  ProgressCallback? onReceiveProgress,
}) async {
  final response = await loadMediaResponse(
    api,
    url,
    onReceiveProgress: onReceiveProgress,
  );
  final bytes = response.data;
  if (bytes == null || bytes.isEmpty) throw StateError('Empty media response');
  return Uint8List.fromList(bytes);
}

ImageProvider authenticatedImageProvider(
  BuildContext context,
  String url, {
  double scale = 1,
}) {
  if (authenticatedMediaPath(url) == null) {
    return NetworkImage(url, scale: scale);
  }
  return AuthenticatedMediaImage(url, mediaApiClient(context), scale: scale);
}

/// Cache identity includes the provider container's API client, so credentials
/// or warehouse changes cannot reuse decoded images from an older session.
class AuthenticatedMediaImage extends ImageProvider<AuthenticatedMediaImage> {
  const AuthenticatedMediaImage(this.url, this.api, {this.scale = 1})
    : _sessionIdentity = null;
  const AuthenticatedMediaImage._key(
    this.url,
    this.api,
    this.scale,
    this._sessionIdentity,
  );
  final String? _sessionIdentity;
  final String url;
  final ApiClient api;
  final double scale;

  @override
  Future<AuthenticatedMediaImage> obtainKey(
    ImageConfiguration configuration,
  ) async =>
      AuthenticatedMediaImage._key(url, api, scale, await api.getToken());

  @override
  ImageStreamCompleter loadImage(
    AuthenticatedMediaImage key,
    ImageDecoderCallback decode,
  ) {
    final chunks = StreamController<ImageChunkEvent>();
    final codec = key
        ._decode(
          decode,
          (received, total) => chunks.add(
            ImageChunkEvent(
              cumulativeBytesLoaded: received,
              expectedTotalBytes: total > 0 ? total : null,
            ),
          ),
        )
        .whenComplete(() => unawaited(chunks.close()));
    return MultiFrameImageStreamCompleter(
      codec: codec,
      scale: scale,
      chunkEvents: chunks.stream,
    );
  }

  Future<ui.Codec> _decode(
    ImageDecoderCallback decode,
    ProgressCallback onReceiveProgress,
  ) async {
    try {
      if (await api.getToken() != _sessionIdentity) {
        throw StateError('Media session changed');
      }
      final bytes = await loadMediaBytes(
        api,
        url,
        onReceiveProgress: onReceiveProgress,
      );
      if (await api.getToken() != _sessionIdentity) {
        throw StateError('Media session changed');
      }
      return decode(await ui.ImmutableBuffer.fromUint8List(bytes));
    } catch (_) {
      PaintingBinding.instance.imageCache.evict(this);
      rethrow;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is AuthenticatedMediaImage &&
      other.url == url &&
      identical(other.api, api) &&
      other.scale == scale &&
      other._sessionIdentity == _sessionIdentity;
  @override
  int get hashCode =>
      Object.hash(url, identityHashCode(api), scale, _sessionIdentity);
}

class AuthenticatedImage extends StatelessWidget {
  const AuthenticatedImage.network(
    this.url, {
    super.key,
    this.width,
    this.height,
    this.fit,
    this.errorBuilder,
    this.loadingBuilder,
    this.cacheWidth,
    this.cacheHeight,
    this.filterQuality = FilterQuality.medium,
    this.gaplessPlayback = false,
    this.alignment = Alignment.center,
    this.color,
    this.colorBlendMode,
    this.scale = 1,
    this.semanticLabel,
    this.excludeFromSemantics = false,
  });
  final String url;
  final double? width, height;
  final BoxFit? fit;
  final ImageErrorWidgetBuilder? errorBuilder;
  final ImageLoadingBuilder? loadingBuilder;
  final int? cacheWidth, cacheHeight;
  final FilterQuality filterQuality;
  final bool gaplessPlayback, excludeFromSemantics;
  final AlignmentGeometry alignment;
  final Color? color;
  final BlendMode? colorBlendMode;
  final double scale;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => Image(
    image: ResizeImage.resizeIfNeeded(
      cacheWidth,
      cacheHeight,
      authenticatedImageProvider(context, url, scale: scale),
    ),
    width: width,
    height: height,
    fit: fit,
    errorBuilder: errorBuilder,
    loadingBuilder: loadingBuilder,
    filterQuality: filterQuality,
    gaplessPlayback: gaplessPlayback,
    alignment: alignment,
    color: color,
    colorBlendMode: colorBlendMode,
    semanticLabel: semanticLabel,
    excludeFromSemantics: excludeFromSemantics,
  );
}

/// Memory-only operational images. No unauthenticated disk cache survives a
/// warehouse transfer. The callbacks preserve the existing thumbnail layouts.
class AuthenticatedCachedImage extends StatelessWidget {
  const AuthenticatedCachedImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit,
    this.placeholder,
    this.progressIndicatorBuilder,
    this.errorWidget,
    this.imageBuilder,
    this.memCacheWidth,
    this.memCacheHeight,
    this.maxWidthDiskCache,
    this.maxHeightDiskCache,
    this.fadeInDuration = Duration.zero,
    this.fadeOutDuration = Duration.zero,
    this.filterQuality = FilterQuality.low,
  });
  final FilterQuality filterQuality;
  final Duration fadeInDuration, fadeOutDuration;
  final String imageUrl;
  final double? width, height;
  final BoxFit? fit;
  final Widget Function(BuildContext, String)? placeholder;
  final Widget Function(BuildContext, String, ImageChunkEvent?)?
  progressIndicatorBuilder;
  final Widget Function(BuildContext, String, Object)? errorWidget;
  final Widget Function(BuildContext, ImageProvider)? imageBuilder;
  final int? memCacheWidth,
      memCacheHeight,
      maxWidthDiskCache,
      maxHeightDiskCache;

  @override
  Widget build(BuildContext context) {
    var hasFrame = false;
    final image = ResizeImage.resizeIfNeeded(
      memCacheWidth,
      memCacheHeight,
      authenticatedImageProvider(context, imageUrl),
    );
    return Image(
      image: image,
      filterQuality: filterQuality,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stack) =>
          errorWidget?.call(context, imageUrl, error) ??
          const Icon(Icons.broken_image_outlined),
      frameBuilder: (context, child, frame, synchronous) {
        hasFrame = frame != null || synchronous;
        if (frame == null && !synchronous) {
          if (progressIndicatorBuilder != null) return child;
          return placeholder?.call(context, imageUrl) ??
              SizedBox(width: width, height: height);
        }
        return imageBuilder?.call(context, image) ?? child;
      },
      loadingBuilder: progressIndicatorBuilder == null
          ? null
          : (context, child, progress) {
              return hasFrame
                  ? child
                  : progressIndicatorBuilder!(context, imageUrl, progress);
            },
    );
  }
}
