import 'dart:typed_data';
import 'package:video_player/video_player.dart';

Future<VideoPlayerController> createPrivateVideoSource(
  Uint8List bytes,
  String mimeType,
) => throw UnsupportedError('Private video is unavailable on this platform');

Future<({String url, Future<void> Function() dispose})>
createPrivateMediaSource(Uint8List bytes, String mimeType) =>
    throw UnsupportedError('Private media is unavailable on this platform');
