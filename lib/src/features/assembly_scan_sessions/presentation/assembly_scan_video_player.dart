import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../core/ui/app_colors.dart';
import '../../../core/utils/error_utils.dart';
import '../../../core/utils/locale_text.dart';
import '../data/assembly_scan_sessions_provider.dart';
import '../domain/assembly_scan_session.dart';

class AssemblyScanVideoPlayer extends ConsumerStatefulWidget {
  final AssemblyScanSession session;
  final String? initialMarkerId;

  const AssemblyScanVideoPlayer({
    super.key,
    required this.session,
    this.initialMarkerId,
  });

  @override
  ConsumerState<AssemblyScanVideoPlayer> createState() =>
      _AssemblyScanVideoPlayerState();
}

class _AssemblyScanVideoPlayerState
    extends ConsumerState<AssemblyScanVideoPlayer> {
  VideoPlayerController? _controller;
  AssemblyScanVideo? _selectedVideo;
  AssemblyScanPlaybackToken? _playbackToken;
  Object? _error;
  bool _isLoading = false;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadInitialVideo();
    });
  }

  @override
  void didUpdateWidget(covariant AssemblyScanVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    final mustReload =
        shouldReloadAssemblyScanVideoPlayer(
          oldWidget.session,
          widget.session,
        ) ||
        oldWidget.initialMarkerId != widget.initialMarkerId;
    if (!mustReload) return;
    _loadInitialVideo(
      preferredVideoId: _selectedVideo?.id,
      preservePosition: oldWidget.session.id == widget.session.id,
    );
  }

  @override
  void dispose() {
    _loadGeneration += 1;
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _disposeController() async {
    final previous = _controller;
    _controller = null;
    _selectedVideo = null;
    _playbackToken = null;
    if (previous != null) await previous.dispose();
    if (mounted) setState(() {});
  }

  void _loadInitialVideo({
    String? preferredVideoId,
    bool preservePosition = false,
  }) {
    final videos = widget.session.readyVideos;
    if (videos.isEmpty) {
      _loadGeneration += 1;
      _disposeController();
      return;
    }

    final initialMarker = _markerForInitialSeek();
    final markerVideo = initialMarker == null
        ? null
        : widget.session.videoForMarker(initialMarker);
    final selectedVideo =
        markerVideo ?? _videoById(videos, preferredVideoId) ?? videos.first;
    final currentPosition = preservePosition
        ? _controller?.value.position
        : null;
    final isPlaying =
        preservePosition && (_controller?.value.isPlaying ?? false);
    final markerOffset = initialMarker == null
        ? null
        : assemblyScanMarkerOffsetForVideo(
            widget.session,
            initialMarker,
            selectedVideo,
          );
    _loadVideo(
      selectedVideo,
      seekTo: markerOffset ?? currentPosition,
      autoPlay: markerOffset != null || isPlaying,
    );
  }

  AssemblyScanMarker? _markerForInitialSeek() {
    final markerId = widget.initialMarkerId;
    if (markerId == null || markerId.isEmpty) return null;
    for (final marker in widget.session.markers) {
      if (marker.id == markerId) return marker;
    }
    return null;
  }

  AssemblyScanVideo? _videoById(
    List<AssemblyScanVideo> videos,
    String? videoId,
  ) {
    if (videoId == null) return null;
    for (final video in videos) {
      if (video.id == videoId) return video;
    }
    return null;
  }

  Future<void> _loadVideo(
    AssemblyScanVideo video, {
    Duration? seekTo,
    bool autoPlay = false,
  }) async {
    final generation = ++_loadGeneration;
    setState(() {
      _isLoading = true;
      _error = null;
      _selectedVideo = video;
    });

    final previous = _controller;
    _controller = null;
    if (previous != null) await previous.dispose();
    if (!mounted || generation != _loadGeneration) return;

    VideoPlayerController? pendingController;
    try {
      final token = await ref
          .read(assemblyScanSessionsRepositoryProvider)
          .createPlaybackToken(
            assemblyId: widget.session.assemblyId,
            sessionId: widget.session.id,
            videoId: video.id,
          );
      if (!mounted || generation != _loadGeneration) return;

      final controller = VideoPlayerController.networkUrl(token.url);
      pendingController = controller;
      await controller.initialize();
      if (!mounted || generation != _loadGeneration) {
        await controller.dispose();
        return;
      }
      await controller.setLooping(false);
      if (!mounted || generation != _loadGeneration) {
        await controller.dispose();
        return;
      }

      if (seekTo != null) {
        final safePosition = _clampPosition(seekTo, controller.value.duration);
        await controller.seekTo(safePosition);
        if (!mounted || generation != _loadGeneration) {
          await controller.dispose();
          return;
        }
      }
      if (autoPlay) {
        await controller.play();
        if (!mounted || generation != _loadGeneration) {
          await controller.dispose();
          return;
        }
      }
      if (!mounted || generation != _loadGeneration) {
        await controller.dispose();
        return;
      }

      setState(() {
        _controller = controller;
        _playbackToken = token;
        _isLoading = false;
      });
      pendingController = null;
    } catch (error) {
      await pendingController?.dispose();
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _error = error;
        _isLoading = false;
      });
    }
  }

  Future<void> _togglePlayback() async {
    final controller = _controller;
    final video = _selectedVideo;
    if (controller == null || video == null) return;

    if (_playbackToken?.isExpiringSoon == true) {
      await _loadVideo(
        video,
        seekTo: controller.value.position,
        autoPlay: true,
      );
      if (!mounted) return;
      return;
    }

    if (controller.value.isPlaying) {
      await controller.pause();
      if (!mounted) return;
    } else {
      await controller.play();
      if (!mounted) return;
    }
  }

  Future<void> _seekToMarker(AssemblyScanMarker marker) async {
    final video = widget.session.videoForMarker(marker);
    if (video == null) return;
    final offset = widget.session.markerOffsetInVideo(marker, video);
    if (_selectedVideo?.id != video.id || _controller == null) {
      await _loadVideo(video, seekTo: offset, autoPlay: true);
      if (!mounted) return;
      return;
    }
    await _controller!.seekTo(
      _clampPosition(offset, _controller!.value.duration),
    );
    if (!mounted) return;
    await _controller!.play();
    if (!mounted) return;
  }

  Duration _clampPosition(Duration value, Duration duration) {
    if (value < Duration.zero) return Duration.zero;
    if (duration > Duration.zero && value > duration) return duration;
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final readyVideos = widget.session.readyVideos;
    if (readyVideos.isEmpty) {
      if (widget.session.status == AssemblyScanSessionStatus.failed) {
        return const SizedBox.shrink();
      }
      return _PlayerMessage(
        icon: Icons.video_file_outlined,
        text: tr(context, ru: 'Готовых роликов пока нет', zh: '暂无可播放的视频'),
      );
    }

    final mediaCard = _VideoSectionCard(
      key: const Key('assembly-scan-player-card'),
      title: tr(context, ru: 'Запись сканирования', zh: '扫描录像'),
      subtitle: _availableFragmentCountText(context, readyVideos.length),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (readyVideos.length > 1) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var index = 0; index < readyVideos.length; index++) ...[
                    ChoiceChip(
                      label: Text(
                        _fragmentLabel(context, readyVideos[index], index),
                      ),
                      selected: _selectedVideo?.id == readyVideos[index].id,
                      onSelected: (_) => _loadVideo(readyVideos[index]),
                      showCheckmark: false,
                      avatar: Icon(
                        Icons.movie_outlined,
                        size: 17,
                        color: _selectedVideo?.id == readyVideos[index].id
                            ? context.brandPrimary
                            : AppColors.textSecondary,
                      ),
                    ),
                    if (index + 1 < readyVideos.length)
                      const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          _buildPlayerSurface(context),
        ],
      ),
    );

    final markersCard = widget.session.markers.isEmpty
        ? null
        : _VideoSectionCard(
            key: const Key('assembly-scan-markers-card'),
            title: tr(context, ru: 'Отсканированные треки', zh: '已扫描轨迹'),
            subtitle: tr(
              context,
              ru: 'Нажмите на трек, чтобы перейти к моменту сканирования',
              zh: '点击轨迹可跳转到扫描时刻',
            ),
            child: Column(
              children: [
                for (
                  var index = 0;
                  index < widget.session.markers.length;
                  index++
                )
                  _MarkerRow(
                    marker: widget.session.markers[index],
                    sequence: index + 1,
                    isAvailable:
                        widget.session.videoForMarker(
                          widget.session.markers[index],
                        ) !=
                        null,
                    onTap: () => _seekToMarker(widget.session.markers[index]),
                  ),
              ],
            ),
          );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 900 && markersCard != null) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 7, child: mediaCard),
              const SizedBox(width: 16),
              Expanded(flex: 5, child: markersCard),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            mediaCard,
            if (markersCard != null) ...[
              const SizedBox(height: 16),
              markersCard,
            ],
          ],
        );
      },
    );
  }

  Widget _buildPlayerSurface(BuildContext context) {
    if (_isLoading) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: const DecoratedBox(
            decoration: BoxDecoration(color: Color(0xFF111318)),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        ),
      );
    }

    final error = _error;
    if (error != null) {
      final errorInfo = ErrorUtils.getErrorInfo(error);
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: DecoratedBox(
            decoration: const BoxDecoration(color: Color(0xFF111318)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.play_disabled_rounded,
                    color: Colors.white70,
                    size: 34,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    errorInfo.getMessage(context),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: _selectedVideo == null
                        ? null
                        : () => _loadVideo(_selectedVideo!),
                    child: Text(tr(context, ru: 'Повторить', zh: '重试')),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: const ColoredBox(
            color: Color(0xFF111318),
            child: Center(
              child: Icon(
                Icons.video_library_outlined,
                color: Colors.white38,
                size: 38,
              ),
            ),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: ColoredBox(
        color: Colors.black,
        child: ValueListenableBuilder<VideoPlayerValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            return Column(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: SizedBox(
                          width: value.size.width <= 0
                              ? 1600
                              : value.size.width,
                          height: value.size.height <= 0
                              ? 900
                              : value.size.height,
                          child: VideoPlayer(controller),
                        ),
                      ),
                    ),
                    Semantics(
                      button: true,
                      label: value.isPlaying
                          ? tr(context, ru: 'Пауза', zh: '暂停')
                          : tr(context, ru: 'Воспроизвести', zh: '播放'),
                      child: IconButton.filled(
                        onPressed: _togglePlayback,
                        iconSize: 34,
                        style: IconButton.styleFrom(
                          minimumSize: const Size(58, 58),
                          backgroundColor: Colors.white.withValues(alpha: 0.92),
                          foregroundColor: Colors.black,
                        ),
                        icon: Icon(
                          value.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                  child: Column(
                    children: [
                      VideoProgressIndicator(
                        controller,
                        allowScrubbing: true,
                        colors: VideoProgressColors(
                          playedColor: context.brandPrimary,
                          bufferedColor: Colors.white38,
                          backgroundColor: Colors.white12,
                        ),
                      ),
                      const SizedBox(height: 5),
                      _MarkerTimeline(
                        session: widget.session,
                        video: _selectedVideo,
                        duration: value.duration,
                        onMarkerTap: _seekToMarker,
                      ),
                      Row(
                        children: [
                          Text(
                            _formatDuration(value.position),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _formatDuration(value.duration),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

Duration? assemblyScanMarkerOffsetForVideo(
  AssemblyScanSession session,
  AssemblyScanMarker marker,
  AssemblyScanVideo video,
) {
  if (session.videoForMarker(marker)?.id != video.id) return null;
  return session.markerOffsetInVideo(marker, video);
}

bool shouldReloadAssemblyScanVideoPlayer(
  AssemblyScanSession previous,
  AssemblyScanSession next,
) {
  if (previous.id != next.id) return true;
  final previousSignature = _readyVideoReloadSignature(previous);
  final nextSignature = _readyVideoReloadSignature(next);
  if (previousSignature.length != nextSignature.length) return true;
  for (var index = 0; index < previousSignature.length; index += 1) {
    if (previousSignature[index] != nextSignature[index]) return true;
  }
  return false;
}

List<(String, int, int, int?, String)> _readyVideoReloadSignature(
  AssemblyScanSession session,
) {
  return session.readyVideos
      .map(
        (video) => (
          video.id,
          video.recordingOffsetMs,
          video.partIndex,
          video.durationMs,
          video.status,
        ),
      )
      .toList(growable: false);
}

class _MarkerTimeline extends StatelessWidget {
  final AssemblyScanSession session;
  final AssemblyScanVideo? video;
  final Duration duration;
  final ValueChanged<AssemblyScanMarker> onMarkerTap;

  const _MarkerTimeline({
    required this.session,
    required this.video,
    required this.duration,
    required this.onMarkerTap,
  });

  @override
  Widget build(BuildContext context) {
    final selectedVideo = video;
    if (selectedVideo == null || duration.inMilliseconds <= 0) {
      return const SizedBox(height: 12);
    }
    final markers = session.markers
        .where(
          (marker) => session.videoForMarker(marker)?.id == selectedVideo.id,
        )
        .toList();

    return SizedBox(
      height: 44,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final usableWidth = (constraints.maxWidth - 44).clamp(
            0.0,
            double.infinity,
          );
          return Stack(
            children: [
              for (final marker in markers)
                Positioned(
                  left:
                      (session
                                  .markerOffsetInVideo(marker, selectedVideo)
                                  .inMilliseconds /
                              duration.inMilliseconds)
                          .clamp(0.0, 1.0) *
                      usableWidth,
                  child: Semantics(
                    button: true,
                    label: tr(
                      context,
                      ru: '${marker.trackNumber}, перейти к ${_formatDuration(Duration(milliseconds: marker.sessionOffsetMs))}',
                      zh: '${marker.trackNumber}，跳转到 ${_formatDuration(Duration(milliseconds: marker.sessionOffsetMs))}',
                    ),
                    child: InkResponse(
                      radius: 22,
                      onTap: () => onMarkerTap(marker),
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: Center(
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: context.brandSecondary,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _MarkerRow extends StatelessWidget {
  final AssemblyScanMarker marker;
  final int sequence;
  final bool isAvailable;
  final VoidCallback onTap;

  const _MarkerRow({
    required this.marker,
    required this.sequence,
    required this.isAvailable,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final productName = marker.productName?.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Semantics(
        button: isAvailable,
        enabled: isAvailable,
        label: isAvailable
            ? tr(
                context,
                ru: '${marker.trackNumber}, перейти к моменту ${_formatDuration(Duration(milliseconds: marker.sessionOffsetMs))}',
                zh: '${marker.trackNumber}，跳转到 ${_formatDuration(Duration(milliseconds: marker.sessionOffsetMs))}',
              )
            : tr(
                context,
                ru: '${marker.trackNumber}, момент видео недоступен',
                zh: '${marker.trackNumber}，该时刻的视频不可用',
              ),
        child: Material(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: isAvailable ? onTap : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isAvailable
                          ? context.brandPrimary.withValues(alpha: 0.1)
                          : Colors.black.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: isAvailable
                        ? Text(
                            '$sequence',
                            style: TextStyle(
                              color: context.brandPrimary,
                              fontWeight: FontWeight.w900,
                            ),
                          )
                        : const Icon(
                            Icons.videocam_off_outlined,
                            size: 19,
                            color: AppColors.textSecondary,
                          ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          marker.trackNumber,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        if (productName != null && productName.isNotEmpty)
                          Text(
                            productName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        if (!isAvailable)
                          Text(
                            tr(
                              context,
                              ru: 'Момент видео недоступен',
                              zh: '该时刻的视频不可用',
                            ),
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    _formatDuration(
                      Duration(milliseconds: marker.sessionOffsetMs),
                    ),
                    style: TextStyle(
                      color: isAvailable
                          ? context.brandPrimary
                          : AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  if (isAvailable) ...[
                    const SizedBox(width: 5),
                    Icon(
                      Icons.play_arrow_rounded,
                      size: 18,
                      color: context.brandPrimary,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VideoSectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _VideoSectionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withValues(alpha: 0.035)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 24,
            spreadRadius: -14,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontFamily: 'Gilroy',
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.15,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.3,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _PlayerMessage extends StatelessWidget {
  final IconData icon;
  final String text;

  const _PlayerMessage({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withValues(alpha: 0.035)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

String _fragmentLabel(
  BuildContext context,
  AssemblyScanVideo video,
  int index,
) {
  final start = Duration(milliseconds: video.recordingOffsetMs);
  final duration = Duration(milliseconds: video.durationMs ?? 0);
  final end = start + duration;
  final range = video.durationMs == null
      ? _formatDuration(start)
      : '${_formatDuration(start)}–${_formatDuration(end)}';
  return tr(
    context,
    ru: 'Фрагмент ${index + 1} · $range',
    zh: '片段 ${index + 1} · $range',
  );
}

String _availableFragmentCountText(BuildContext context, int count) {
  final mod100 = count % 100;
  final mod10 = count % 10;
  final ru = mod100 >= 11 && mod100 <= 14
      ? '$count доступных фрагментов'
      : switch (mod10) {
          1 => '$count доступный фрагмент',
          2 || 3 || 4 => '$count доступных фрагмента',
          _ => '$count доступных фрагментов',
        };
  return tr(context, ru: ru, zh: '$count 个可用片段');
}

String _formatDuration(Duration value) {
  final totalSeconds = value.inSeconds.clamp(0, 359999);
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  final mm = minutes.toString().padLeft(2, '0');
  final ss = seconds.toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$mm:$ss' : '$minutes:$ss';
}
