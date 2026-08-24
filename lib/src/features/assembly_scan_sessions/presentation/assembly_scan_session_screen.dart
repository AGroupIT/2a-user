import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/ui/app_colors.dart';
import '../../../core/ui/app_layout.dart';
import '../../../core/ui/blurred_modal_bottom_sheet.dart';
import '../../../core/ui/sheet_handle.dart';
import '../../../core/utils/error_utils.dart';
import '../../../core/utils/locale_text.dart';
import '../data/assembly_scan_sessions_provider.dart';
import '../domain/assembly_scan_session.dart';
import 'assembly_scan_video_player.dart';

class AssemblyScanSessionScreen extends ConsumerWidget {
  final int assemblyId;
  final String assemblyNumber;
  final String sessionId;
  final int approachNumber;
  final String? initialMarkerId;

  const AssemblyScanSessionScreen({
    super.key,
    required this.assemblyId,
    required this.assemblyNumber,
    required this.sessionId,
    required this.approachNumber,
    this.initialMarkerId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final horizontal = AppLayout.horizontalMargin(context);

    return Scaffold(
      backgroundColor: AppColors.brandBg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(horizontal, 12, horizontal, 0),
                  child: _PageHeader(assemblyNumber: assemblyNumber),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: AssemblyScanSessionContent(
                    assemblyId: assemblyId,
                    assemblyNumber: assemblyNumber,
                    sessionId: sessionId,
                    approachNumber: approachNumber,
                    initialMarkerId: initialMarkerId,
                    horizontalPadding: horizontal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AssemblyScanSessionContent extends ConsumerWidget {
  final int assemblyId;
  final String assemblyNumber;
  final String sessionId;
  final int approachNumber;
  final String? initialMarkerId;
  final double horizontalPadding;

  const AssemblyScanSessionContent({
    super.key,
    required this.assemblyId,
    required this.assemblyNumber,
    required this.sessionId,
    required this.approachNumber,
    this.initialMarkerId,
    this.horizontalPadding = 16,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (assemblyId: assemblyId, sessionId: sessionId);
    final sessionAsync = ref.watch(assemblyScanSessionProvider(key));
    final padding = EdgeInsets.fromLTRB(
      horizontalPadding,
      0,
      horizontalPadding,
      32,
    );

    return sessionAsync.when(
      loading: () =>
          ListView(padding: padding, children: const [_LoadingPage()]),
      error: (error, _) => ListView(
        padding: padding,
        children: [
          _SessionError(
            error: error,
            onRetry: () => ref.invalidate(assemblyScanSessionProvider(key)),
          ),
        ],
      ),
      data: (session) => RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(assemblyScanSessionProvider(key));
          await ref.read(assemblyScanSessionProvider(key).future);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: padding,
          children: [
            _SessionHeroCard(
              session: session,
              assemblyNumber: assemblyNumber,
              approachNumber: approachNumber,
            ),
            if (session.status == AssemblyScanSessionStatus.partial ||
                session.hasKnownGap) ...[
              const SizedBox(height: 12),
              _StateNotice(
                icon: Icons.warning_amber_rounded,
                color: Colors.orange.shade800,
                title: tr(
                  context,
                  ru: 'Запись доступна частично',
                  zh: '录像部分可用',
                ),
                message: tr(
                  context,
                  ru: 'Один из фрагментов мог не сохраниться. Доступные моменты и треки отмечены ниже.',
                  zh: '部分片段可能未保存，可用时刻和轨迹已在下方标记。',
                ),
              ),
            ],
            if (_isProcessing(session.status)) ...[
              const SizedBox(height: 12),
              _StateNotice(
                icon: Icons.hourglass_top_rounded,
                color: context.brandPrimary,
                title: tr(context, ru: 'Видео обрабатывается', zh: '视频处理中'),
                message: tr(
                  context,
                  ru: 'Подход уже сохранён. Потяните вниз, чтобы проверить готовность роликов.',
                  zh: '此次扫描已保存，下拉可检查视频是否就绪。',
                ),
              ),
            ],
            if (session.status == AssemblyScanSessionStatus.failed) ...[
              const SizedBox(height: 12),
              _StateNotice(
                icon: Icons.videocam_off_rounded,
                color: Colors.redAccent,
                title: tr(context, ru: 'Видео не сохранилось', zh: '视频未保存'),
                message: tr(
                  context,
                  ru: 'Для этого подхода нет доступной записи.',
                  zh: '此次扫描没有可用录像。',
                ),
              ),
            ],
            const SizedBox(height: 16),
            AssemblyScanVideoPlayer(
              session: session,
              initialMarkerId: initialMarkerId,
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showAssemblyScanSessionSheet(
  BuildContext context, {
  required int assemblyId,
  required String assemblyNumber,
  required String sessionId,
  required int approachNumber,
  String? initialMarkerId,
}) {
  return showBlurredModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.brandBg,
    barrierColor: Colors.black.withValues(alpha: 0.28),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    clipBehavior: Clip.antiAlias,
    builder: (sheetContext) => FractionallySizedBox(
      heightFactor: 0.94,
      child: Column(
        children: [
          const SheetHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 6, 10, 14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: sheetContext.brandGradient,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(
                    Icons.video_camera_back_rounded,
                    color: Colors.white,
                    size: 23,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr(sheetContext, ru: 'Видео сканирования', zh: '扫描视频'),
                        style: const TextStyle(
                          fontFamily: 'Gilroy',
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tr(
                          sheetContext,
                          ru: 'Сборка $assemblyNumber · Подход $approachNumber',
                          zh: '集货 $assemblyNumber · 第 $approachNumber 次',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: tr(sheetContext, ru: 'Закрыть', zh: '关闭'),
                  onPressed: () => Navigator.pop(sheetContext),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Expanded(
            child: AssemblyScanSessionContent(
              assemblyId: assemblyId,
              assemblyNumber: assemblyNumber,
              sessionId: sessionId,
              approachNumber: approachNumber,
              initialMarkerId: initialMarkerId,
            ),
          ),
        ],
      ),
    ),
  );
}

class _PageHeader extends StatelessWidget {
  final String assemblyNumber;

  const _PageHeader({required this.assemblyNumber});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => Navigator.maybePop(context),
            child: const SizedBox(
              width: 46,
              height: 46,
              child: Icon(Icons.arrow_back_rounded),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr(context, ru: 'Видео сканирования', zh: '扫描视频'),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontFamily: 'Gilroy',
                  fontSize: 23,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.35,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                tr(
                  context,
                  ru: 'Сборка $assemblyNumber',
                  zh: '集货 $assemblyNumber',
                ),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SessionHeroCard extends StatelessWidget {
  final AssemblyScanSession session;
  final String assemblyNumber;
  final int approachNumber;

  const _SessionHeroCard({
    required this.session,
    required this.assemblyNumber,
    required this.approachNumber,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd.MM.yyyy · HH:mm');
    final duration = _sessionDuration(session);

    return Container(
      key: const Key('assembly-scan-session-hero'),
      decoration: BoxDecoration(
        gradient: context.brandGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: context.brandPrimary.withValues(alpha: 0.22),
            blurRadius: 28,
            spreadRadius: -12,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.22),
                    ),
                  ),
                  child: const Icon(
                    Icons.qr_code_scanner_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr(
                          context,
                          ru: 'Подход $approachNumber',
                          zh: '第 $approachNumber 次',
                        ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'Gilroy',
                          fontSize: 22,
                          height: 1.05,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.25,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        dateFormat.format(session.startedAt.toLocal()),
                        style: const TextStyle(
                          color: Color(0xE6FFFFFF),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                AssemblyScanStatusChip(status: session.status, inverted: true),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _HeroMetric(
                    icon: Icons.timer_outlined,
                    value: _formatDuration(duration),
                    label: tr(context, ru: 'длительность', zh: '时长'),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: _HeroMetric(
                    icon: Icons.inventory_2_outlined,
                    value: '${session.scanCount}',
                    label: tr(context, ru: 'треков', zh: '轨迹'),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: _HeroMetric(
                    icon: Icons.movie_filter_outlined,
                    value: '${session.readyVideos.length}',
                    label: tr(context, ru: 'фрагментов', zh: '片段'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _HeroMetric({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(height: 7),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xCCFFFFFF),
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class AssemblyScanStatusChip extends StatelessWidget {
  final AssemblyScanSessionStatus status;
  final bool inverted;

  const AssemblyScanStatusChip({
    super.key,
    required this.status,
    this.inverted = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(context, status);
    final background = inverted
        ? Colors.white.withValues(alpha: 0.18)
        : color.withValues(alpha: 0.12);
    final foreground = inverted ? Colors.white : color;

    return Semantics(
      label: _statusLabel(context, status),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
          border: inverted
              ? Border.all(color: Colors.white.withValues(alpha: 0.2))
              : null,
        ),
        child: Text(
          _statusLabel(context, status),
          style: TextStyle(
            color: foreground,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _StateNotice extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String message;

  const _StateNotice({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.35,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingPage extends StatelessWidget {
  const _LoadingPage();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Center(
        child: CircularProgressIndicator(color: context.brandPrimary),
      ),
    );
  }
}

class _SessionError extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _SessionError({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final errorInfo = ErrorUtils.getErrorInfo(error);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(errorInfo.icon, size: 42, color: AppColors.textSecondary),
          const SizedBox(height: 12),
          Text(errorInfo.getMessage(context), textAlign: TextAlign.center),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(tr(context, ru: 'Повторить', zh: '重试')),
          ),
        ],
      ),
    );
  }
}

bool _isProcessing(AssemblyScanSessionStatus status) {
  return status == AssemblyScanSessionStatus.starting ||
      status == AssemblyScanSessionStatus.recording ||
      status == AssemblyScanSessionStatus.reconnecting ||
      status == AssemblyScanSessionStatus.stopping ||
      status == AssemblyScanSessionStatus.processing;
}

Color _statusColor(BuildContext context, AssemblyScanSessionStatus status) {
  return switch (status) {
    AssemblyScanSessionStatus.ready => Colors.green.shade700,
    AssemblyScanSessionStatus.partial => Colors.orange.shade800,
    AssemblyScanSessionStatus.failed => Colors.redAccent,
    _ => context.brandPrimary,
  };
}

String _statusLabel(BuildContext context, AssemblyScanSessionStatus status) {
  return switch (status) {
    AssemblyScanSessionStatus.ready => tr(context, ru: 'Готово', zh: '已完成'),
    AssemblyScanSessionStatus.partial => tr(
      context,
      ru: 'Частично',
      zh: '部分可用',
    ),
    AssemblyScanSessionStatus.failed => tr(context, ru: 'Ошибка', zh: '失败'),
    AssemblyScanSessionStatus.starting => tr(context, ru: 'Запуск', zh: '启动中'),
    AssemblyScanSessionStatus.recording => tr(context, ru: 'Запись', zh: '录制中'),
    AssemblyScanSessionStatus.reconnecting => tr(
      context,
      ru: 'Связь',
      zh: '重连中',
    ),
    AssemblyScanSessionStatus.stopping => tr(
      context,
      ru: 'Завершение',
      zh: '结束中',
    ),
    AssemblyScanSessionStatus.processing => tr(
      context,
      ru: 'Обработка',
      zh: '处理中',
    ),
    AssemblyScanSessionStatus.unknown => tr(
      context,
      ru: 'Неизвестно',
      zh: '未知',
    ),
  };
}

Duration _sessionDuration(AssemblyScanSession session) {
  final durationMs = session.durationMs;
  if (durationMs != null) return Duration(milliseconds: durationMs);
  final endedAt = session.endedAt;
  if (endedAt != null) return endedAt.difference(session.startedAt);
  return DateTime.now().difference(session.startedAt);
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
