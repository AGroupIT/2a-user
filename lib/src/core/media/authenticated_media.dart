import 'dart:async';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';
import '../network/api_config.dart';
import 'media_image_byte_cache.dart';

final _imageByteCaches = Expando<MediaImageByteCache>();

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
  // Reject traversal before rewriting to the authenticated API origin.
  if (path.contains('\\') ||
      path.contains('\u0000') ||
      path.split('/').any((segment) => segment == '.' || segment == '..') ||
      RegExp(r'%2f|%5c|%00|%25', caseSensitive: false).hasMatch(value)) {
    return null;
  }
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
  // The authenticated proxy avoids storage redirects while preserving the
  // signed playback token and the legacy player contract for other clients.
  if (playback) {
    return Uri(
      path: apiPath,
      queryParameters: {
        ...uri.queryParametersAll,
        'proxy': ['1'],
      },
    ).toString();
  }
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
    headers: {
      if (!kIsWeb) 'Accept-Encoding': 'identity',
      if (kIsWeb && path != null && path.startsWith('/uploads/'))
        'Range': 'bytes=0-',
    },
    receiveTimeout: const Duration(minutes: 5),
    followRedirects: false,
    maxRedirects: 0,
    extra: {if (path != null) 'private_media_no_redirect': true},
  );
  final Response<List<int>> response;
  if (path != null) {
    final identity = await api.getMediaCacheIdentity();
    response = onReceiveProgress == null
        ? await api.get<List<int>>(path, options: options)
        : await api.getWithProgress<List<int>>(
            path,
            options: options,
            onReceiveProgress: onReceiveProgress,
          );
    if (await api.getMediaCacheIdentity() != identity) {
      throw StateError('Media session changed');
    }
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

class _AuthenticatedImageCompleter extends MultiFrameImageStreamCompleter {
  _AuthenticatedImageCompleter({
    required super.codec,
    required super.scale,
    super.chunkEvents,
    required this.onDecodeError,
  });
  final VoidCallback onDecodeError;

  @override
  void reportError({
    DiagnosticsNode? context,
    required Object exception,
    StackTrace? stack,
    InformationCollector? informationCollector,
    bool silent = false,
  }) {
    // Valid headers can instantiate a codec whose first/next frame is corrupt.
    onDecodeError();
    super.reportError(
      context: context,
      exception: exception,
      stack: stack,
      informationCollector: informationCollector,
      silent: silent,
    );
  }
}

/// Cache identity includes the API client and authentication session epoch.
/// Logout and login cannot reuse decoded images from an older session.
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
  ) async => AuthenticatedMediaImage._key(
    url,
    api,
    scale,
    await api.getMediaCacheIdentity(),
  );

  @override
  ImageStreamCompleter loadImage(
    AuthenticatedMediaImage key,
    ImageDecoderCallback decode,
  ) {
    // The completer can outlive the byte LRU; do not retain originals here.
    WeakReference<Uint8List>? downloaded;
    final chunks = StreamController<ImageChunkEvent>();
    return _AuthenticatedImageCompleter(
      codec: key
          ._decode(
            decode,
            (bytes) => downloaded = WeakReference(bytes),
            (received, total) => chunks.add(
              ImageChunkEvent(
                cumulativeBytesLoaded: received,
                expectedTotalBytes: total > 0 ? total : null,
              ),
            ),
          )
          .whenComplete(() => unawaited(chunks.close())),
      chunkEvents: chunks.stream,
      scale: scale,
      onDecodeError: () {
        final bytes = downloaded?.target;
        if (bytes != null && key._sessionIdentity != null) {
          _imageByteCaches[api]?.evict(
            key._sessionIdentity,
            authenticatedMediaPath(url) ?? url,
            bytes,
          );
        }
      },
    );
  }

  Future<ui.Codec> _decode(
    ImageDecoderCallback decode,
    ValueChanged<Uint8List> onBytes,
    ProgressCallback onReceiveProgress,
  ) async {
    Uint8List? downloaded;
    final cachePath = authenticatedMediaPath(url) ?? url;
    try {
      if (await api.getMediaCacheIdentity() != _sessionIdentity) {
        throw StateError('Media session changed');
      }
      final cache = _imageByteCaches[api] ??= MediaImageByteCache();
      final bytes = await cache.load(
        _sessionIdentity!,
        cachePath,
        () => loadMediaBytes(api, url, onReceiveProgress: onReceiveProgress),
      );
      downloaded = bytes;
      onBytes(bytes);
      if (await api.getMediaCacheIdentity() != _sessionIdentity) {
        throw StateError('Media session changed');
      }
      return await decode(await ui.ImmutableBuffer.fromUint8List(bytes));
    } catch (_) {
      if (downloaded != null && _sessionIdentity != null) {
        _imageByteCaches[api]?.evict(_sessionIdentity, cachePath, downloaded);
      }
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

ImageProvider _boundedImageProvider(
  BuildContext context,
  String url, {
  int? width,
  int? height,
  double scale = 1,
}) => ResizeImage(
  authenticatedImageProvider(context, url, scale: scale),
  width: width ?? (height == null ? 1600 : null),
  height: height ?? (width == null ? 1600 : null),
  policy: ResizeImagePolicy.fit,
);

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
    image: _boundedImageProvider(
      context,
      url,
      width: cacheWidth,
      height: cacheHeight,
      scale: scale,
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
    final image = _boundedImageProvider(
      context,
      imageUrl,
      width: memCacheWidth,
      height: memCacheHeight,
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
      loadingBuilder: progressIndicatorBuilder == null
          ? null
          : (context, child, progress) {
              if (progress == null) return child;
              return progressIndicatorBuilder!(context, imageUrl, progress);
            },
      frameBuilder: (context, child, frame, synchronous) {
        if (frame == null && !synchronous) {
          return progressIndicatorBuilder?.call(context, imageUrl, null) ??
              placeholder?.call(context, imageUrl) ??
              SizedBox(width: width, height: height);
        }
        return imageBuilder?.call(context, image) ?? child;
      },
    );
  }
}
