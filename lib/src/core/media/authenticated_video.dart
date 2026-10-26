import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:video_player/video_player.dart';
import '../network/api_config.dart';
import 'authenticated_media.dart';
import 'media_object_url.dart';

class _MediaVideoController extends VideoPlayerController {
  _MediaVideoController(
    super.url, {
    super.httpHeaders,
    this.objectUrl,
    this.progressivePlayback = false,
  }) : super.networkUrl() {
    if (_usesProgressiveIOS) addListener(_resumeBufferedPlayback);
  }
  final String? objectUrl;
  final bool progressivePlayback;
  static const _playbackChannel = MethodChannel(
    'com.twoalogistic.user/video_playback',
  );
  bool _wantsToPlay = false;
  bool _resuming = false;
  bool _disposed = false;
  bool _nativePlaybackAvailable = true;
  bool get _usesProgressiveIOS =>
      progressivePlayback &&
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.iOS;

  Future<void> _playAvailable() async {
    if (_disposed ||
        !_wantsToPlay ||
        !value.isInitialized ||
        _resuming ||
        !_nativePlaybackAvailable) {
      return;
    }
    _resuming = true;
    try {
      await _playbackChannel.invokeMethod<void>('playAvailable', {
        // The plugin exposes this handle for native integration; never persist it.
        // ignore: invalid_use_of_visible_for_testing_member
        'playerId': playerId,
        'rate': value.playbackSpeed,
      });
    } on MissingPluginException {
      // Dart can be hot-reloaded while the installed native runner is older.
      // Buffer tuning is optional: the initialized video must keep playing.
      _nativePlaybackAvailable = false;
      debugPrint(
        '[VideoPlayback] Native buffer tuning unavailable; using standard playback',
      );
    } on PlatformException catch (error) {
      _nativePlaybackAvailable = false;
      debugPrint(
        '[VideoPlayback] Native buffer tuning failed (${error.code}); using standard playback',
      );
    } finally {
      _resuming = false;
    }
  }

  void _resumeBufferedPlayback() {
    if (!_usesProgressiveIOS ||
        !_wantsToPlay ||
        _disposed ||
        _resuming ||
        !value.isBuffering ||
        value.hasError ||
        value.isCompleted) {
      return;
    }
    // AVPlayer may reset its actual rate after a stall. Resume only when the
    // current position (including a seek target) has playable data ahead.
    final position = value.position;
    final hasBuffer = value.buffered.any(
      (range) =>
          range.start <= position &&
          range.end > position &&
          (range.end >= value.duration ||
              range.end - position >= const Duration(seconds: 1)),
    );
    if (hasBuffer) {
      unawaited(
        _playAvailable().catchError((Object error) {
          debugPrint('[VideoPlayback] resume failed: $error');
        }),
      );
    }
  }

  @override
  Future<void> play() async {
    _wantsToPlay = true;
    await super.play();
    if (_usesProgressiveIOS) await _playAvailable();
  }

  @override
  Future<void> pause() async {
    _wantsToPlay = false;
    await super.pause();
  }

  @override
  Future<void> seekTo(Duration position) async {
    await super.seekTo(position);
    if (_usesProgressiveIOS && _wantsToPlay) await _playAvailable();
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    _wantsToPlay = false;
    if (_usesProgressiveIOS) removeListener(_resumeBufferedPlayback);
    try {
      await super.dispose();
    } finally {
      if (objectUrl != null) revokeMediaObjectUrl(objectUrl!);
    }
  }
}

/// Browser media elements cannot send Authorization. Fetch protected bytes
/// with the API client and use a disposable local blob; never put JWTs in URLs.
/// Native players retain HTTP Range seeking through authenticated headers.
Future<VideoPlayerController> createAuthenticatedVideoController(
  BuildContext context,
  String url, {
  bool progressivePlayback = false,
}) async {
  final path = authenticatedMediaPath(url);
  if (path == null) return VideoPlayerController.networkUrl(Uri.parse(url));
  final api = mediaApiClient(context);
  if (kIsWeb) {
    final bytes = await loadMediaBytes(api, url);
    final mimeType = url.toLowerCase().contains('.webm')
        ? 'video/webm'
        : 'video/mp4';
    final objectUrl = createMediaObjectUrl(bytes, mimeType);
    return _MediaVideoController(Uri.parse(objectUrl), objectUrl: objectUrl);
  }
  final token = await api.getToken();
  if (token == null || token.isEmpty) {
    throw StateError('Media authentication required');
  }
  return _MediaVideoController(
    Uri.parse('${ApiConfig.baseUrl}$path'),
    progressivePlayback: progressivePlayback,
    httpHeaders: {
      'Authorization': 'Bearer $token',
      'X-Warehouse-Protocol': '1',
      'Accept-Encoding': 'identity',
    },
  );
}
