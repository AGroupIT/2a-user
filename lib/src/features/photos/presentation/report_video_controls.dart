import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../core/utils/locale_text.dart';

class ReportVideoControls extends StatefulWidget {
  const ReportVideoControls({
    super.key,
    required this.controller,
    this.active = true,
  });

  final VideoPlayerController controller;
  final bool active;

  @override
  State<ReportVideoControls> createState() => _ReportVideoControlsState();
}

class _ReportVideoControlsState extends State<ReportVideoControls> {
  double? _dragPosition;
  bool _resumeAfterSeek = false;
  bool _seeking = false;
  bool _failed = false;

  @override
  void didUpdateWidget(covariant ReportVideoControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller || !widget.active) {
      _dragPosition = null;
      _resumeAfterSeek = false;
    }
  }

  Future<void> _pauseForSeek() async {
    try {
      await widget.controller.pause();
      if (!mounted) return;
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  String _time(Duration duration) {
    final seconds = duration.inSeconds.clamp(0, 999999);
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    return '$minutes:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  Future<void> _seek(Duration target, {bool resume = false}) async {
    final controller = widget.controller;
    final milliseconds = target.inMilliseconds.clamp(
      0,
      controller.value.duration.inMilliseconds,
    );
    setState(() => _seeking = true);
    try {
      await controller.seekTo(Duration(milliseconds: milliseconds));
      if (!mounted || controller != widget.controller) return;
      if (resume && widget.active) await controller.play();
      if (!mounted) return;
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
    } finally {
      if (mounted && controller == widget.controller) {
        setState(() {
          _seeking = false;
          _dragPosition = null;
        });
      }
    }
  }

  Future<void> _togglePlayback() async {
    final controller = widget.controller;
    try {
      if (controller.value.isPlaying) {
        await controller.pause();
      } else {
        if (controller.value.position >= controller.value.duration) {
          await controller.seekTo(Duration.zero);
          if (!mounted || !widget.active) return;
        }
        await controller.play();
      }
      if (!mounted) return;
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => ValueListenableBuilder<VideoPlayerValue>(
    valueListenable: widget.controller,
    builder: (context, value, _) {
      final total = value.duration.inMilliseconds.toDouble();
      final position =
          (_dragPosition ?? value.position.inMilliseconds.toDouble()).clamp(
            0.0,
            total,
          );
      final enabled =
          widget.active && !_seeking && total > 0 && !value.hasError;
      final bufferedEnd = value.buffered
          .fold<double>(
            0,
            (end, range) => range.end.inMilliseconds > end
                ? range.end.inMilliseconds.toDouble()
                : end,
          )
          .clamp(0.0, total);
      return DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: tr(context, ru: 'Назад на 10 секунд', zh: '后退10秒'),
                    onPressed: enabled
                        ? () => unawaited(
                            _seek(value.position - const Duration(seconds: 10)),
                          )
                        : null,
                    icon: const Icon(
                      Icons.replay_10_rounded,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    tooltip: value.isPlaying
                        ? tr(context, ru: 'Пауза', zh: '暂停')
                        : tr(context, ru: 'Воспроизвести', zh: '播放'),
                    onPressed: enabled
                        ? () => unawaited(_togglePlayback())
                        : null,
                    icon: Icon(
                      value.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    tooltip: tr(
                      context,
                      ru: 'Вперёд на 10 секунд',
                      zh: '前进10秒',
                    ),
                    onPressed: enabled
                        ? () => unawaited(
                            _seek(value.position + const Duration(seconds: 10)),
                          )
                        : null,
                    icon: const Icon(
                      Icons.forward_10_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_time(Duration(milliseconds: position.round()))} / ${_time(value.duration)}',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
              Slider(
                value: position,
                secondaryTrackValue: bufferedEnd,
                secondaryActiveColor: Colors.white54,
                max: total > 0 ? total : 1,
                activeColor: Colors.white,
                inactiveColor: Colors.white30,
                semanticFormatterCallback: (ms) =>
                    _time(Duration(milliseconds: ms.round())),
                onChangeStart: enabled
                    ? (ms) {
                        _resumeAfterSeek = value.isPlaying;
                        // Stop position ticks from moving the thumb under the finger.
                        unawaited(_pauseForSeek());
                        setState(() => _dragPosition = ms);
                      }
                    : null,
                onChanged: enabled
                    ? (ms) => setState(() => _dragPosition = ms)
                    : null,
                onChangeEnd: enabled
                    ? (ms) => unawaited(
                        _seek(
                          Duration(milliseconds: ms.round()),
                          resume: _resumeAfterSeek,
                        ),
                      )
                    : null,
              ),
              if (_failed || value.hasError)
                Text(
                  tr(
                    context,
                    ru: 'Не удалось воспроизвести видео',
                    zh: '无法播放视频',
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
            ],
          ),
        ),
      );
    },
  );
}
