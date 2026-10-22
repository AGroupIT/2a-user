import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

import 'authenticated_media.dart';
import 'browser_video_session.dart';
import '../network/api_config.dart';
import 'media_file_metadata.dart';
import 'private_video_source_stub.dart'
    if (dart.library.io) 'private_video_source_io.dart'
    if (dart.library.js_interop) 'private_video_source_web.dart';

class _StreamingVideoController extends VideoPlayerController {
  _StreamingVideoController(super.url, {super.httpHeaders, this.session})
    : super.networkUrl();
  final BrowserVideoSession? session;
  @override
  Future<void> dispose() async {
    try {
      await super.dispose();
    } finally {
      await session?.dispose();
    }
  }
}

/// Signed scan recordings stream through their capability URL without bearer
/// headers. Other protected videos consume disposable local media.
Future<VideoPlayerController> createAuthenticatedVideoController(
  BuildContext context,
  String url,
) async {
  final path = authenticatedMediaPath(url);
  if (path != null) {
    final uri = Uri.parse(path);
    if (uri.path == '/assembly-scan-media/playback' &&
        (uri.queryParameters['token']?.isNotEmpty ?? false)) {
      // Preserve Range playback for large recordings. The signed token is the
      // credential; never give a platform player the account bearer token.
      return VideoPlayerController.networkUrl(
        Uri.parse('${ApiConfig.baseUrl}$path'),
      );
    }
  }
  if (path == null) {
    return VideoPlayerController.networkUrl(Uri.parse(url));
  }
  if (photoDeskVideoPath(path) != null) {
    final api = mediaApiClient(context);
    if (kIsWeb) {
      late _StreamingVideoController controller;
      final session = await BrowserVideoSession.open(
        path: path,
        getToken: api.getToken,
        onInvalid: () {
          controller.pause().ignore();
        },
      );
      controller = _StreamingVideoController(session.url, session: session);
      return controller;
    }
    final token = await api.getToken();
    if (token == null || token.isEmpty) {
      throw StateError('Media authentication required');
    }
    return _StreamingVideoController(
      Uri.parse('${ApiConfig.baseUrl}$path'),
      httpHeaders: {
        'Authorization': 'Bearer $token',
        'X-Warehouse-Protocol': '1',
      },
    );
  }
  final bytes = await loadMediaBytes(mediaApiClient(context), url);
  final mime = mediaMimeType(url, isVideo: true);
  return createPrivateVideoSource(bytes, mime);
}
