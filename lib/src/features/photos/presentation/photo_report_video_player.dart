import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../core/media/authenticated_video.dart';
import '../../../core/utils/locale_text.dart';
import '../../../core/ui/media_loading_indicator.dart';
import 'report_video_controls.dart';

typedef ReportVideoControllerFactory =
    Future<VideoPlayerController> Function(BuildContext context, String url);

Future<VideoPlayerController> _createReportVideoController(
  BuildContext context,
  String url,
) =>
    createAuthenticatedVideoController(context, url, progressivePlayback: true);

/// Only the visible gallery page may open a stream or own a playing decoder.
class PhotoReportVideoPlayer extends StatefulWidget {
  const PhotoReportVideoPlayer({
    super.key,
    required this.url,
    required this.active,
    this.controllerFactory = _createReportVideoController,
  });

  final String url;
  final bool active;
  final ReportVideoControllerFactory controllerFactory;

  @override
  State<PhotoReportVideoPlayer> createState() => _PhotoReportVideoPlayerState();
}

class _PhotoReportVideoPlayerState extends State<PhotoReportVideoPlayer> {
  VideoPlayerController? _controller;
  int _generation = 0;
  bool _started = false, _failed = false;
  Duration _position = Duration.zero;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _startIfActive();
  }

  @override
  void didUpdateWidget(covariant PhotoReportVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url || !widget.active) {
      _generation++;
      final old = _controller;
      _position = oldWidget.url == widget.url
          ? old?.value.position ?? _position
          : Duration.zero;
      _controller = null;
      _started = false;
      _failed = false;
      if (old != null) unawaited(old.dispose());
    }
    _startIfActive();
  }

  void _startIfActive() {
    if (!widget.active || _started) return;
    _started = true;
    unawaited(_initialize(++_generation));
  }

  bool _current(int generation) =>
      mounted && widget.active && generation == _generation;

  Future<void> _initialize(int generation) async {
    VideoPlayerController? pending;
    try {
      pending = await widget.controllerFactory(context, widget.url);
      if (!_current(generation)) {
        await pending.dispose();
        return;
      }
      await pending.initialize();
      if (!_current(generation)) {
        await pending.dispose();
        return;
      }
      await pending.setLooping(true);
      if (!_current(generation)) {
        await pending.dispose();
        return;
      }
      if (_position > Duration.zero) await pending.seekTo(_position);
      if (!_current(generation)) {
        await pending.dispose();
        return;
      }
      await pending.play();
      if (!_current(generation)) {
        await pending.dispose();
        return;
      }
      setState(() => _controller = pending);
    } catch (_) {
      await pending?.dispose();
      if (!_current(generation)) return;
      setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _generation++;
    unawaited(_controller?.dispose() ?? Future<void>.value());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (!widget.active) {
      return const Icon(Icons.play_circle_outline, color: Colors.white70);
    }
    if (_failed) {
      return IconButton(
        tooltip: tr(context, ru: 'Повторить загрузку видео', zh: '重试加载视频'),
        icon: const Icon(Icons.refresh_rounded, color: Colors.white),
        onPressed: () => setState(() {
          _failed = false;
          _started = false;
          _startIfActive();
        }),
      );
    }
    if (controller == null) {
      return const MediaLoadingIndicator();
    }
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (context, value, _) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: GestureDetector(
              onTap: () =>
                  value.isPlaying ? controller.pause() : controller.play(),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AspectRatio(
                    aspectRatio: value.aspectRatio > 0
                        ? value.aspectRatio
                        : 16 / 9,
                    child: VideoPlayer(controller),
                  ),
                  if (value.isBuffering) const MediaLoadingIndicator(),
                  if (!value.isPlaying && !value.isBuffering)
                    const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 44,
                    ),
                ],
              ),
            ),
          ),
          ReportVideoControls(controller: controller, active: widget.active),
        ],
      ),
    );
  }
}
