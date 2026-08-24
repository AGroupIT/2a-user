import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/ui/app_colors.dart';
import '../../../core/utils/error_utils.dart';
import '../../../core/utils/locale_text.dart';
import '../data/assembly_scan_sessions_provider.dart';
import '../domain/assembly_scan_session.dart';
import 'assembly_scan_session_screen.dart';
import 'assembly_scan_text.dart';

class AssemblyScanSessionsSection extends ConsumerWidget {
  final int assemblyId;
  final String assemblyNumber;

  const AssemblyScanSessionsSection({
    super.key,
    required this.assemblyId,
    required this.assemblyNumber,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(assemblyScanSessionsProvider(assemblyId));

    return KeyedSubtree(
      key: const Key('assembly-scan-evidence-card'),
      child: sessionsAsync.when(
        loading: () => const _LoadingSection(),
        error: (error, _) => _ErrorSection(
          error: error,
          onRetry: () =>
              ref.invalidate(assemblyScanSessionsProvider(assemblyId)),
        ),
        data: (sessions) => _SessionsPreview(
          assemblyId: assemblyId,
          assemblyNumber: assemblyNumber,
          sessions: sessions,
        ),
      ),
    );
  }
}

class _SessionsPreview extends StatelessWidget {
  final int assemblyId;
  final String assemblyNumber;
  final List<AssemblyScanSession> sessions;

  const _SessionsPreview({
    required this.assemblyId,
    required this.assemblyNumber,
    required this.sessions,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(count: sessions.length),
        if (sessions.isEmpty) ...[
          const SizedBox(height: 14),
          const _EmptyEvidenceState(),
        ] else ...[
          const SizedBox(height: 14),
          for (var index = 0; index < sessions.length; index++) ...[
            if (index > 0) const SizedBox(height: 10),
            _SessionRow(
              session: sessions[index],
              approachNumber: _approachNumber(sessions, sessions[index]),
              emphasized: index == 0,
              onTap: () => _openSession(
                context,
                assemblyId: assemblyId,
                assemblyNumber: assemblyNumber,
                session: sessions[index],
                approachNumber: _approachNumber(sessions, sessions[index]),
              ),
            ),
          ],
        ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final int count;

  const _SectionHeader({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6F8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withValues(alpha: 0.035)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: context.brandPrimary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              Icons.video_camera_back_rounded,
              color: context.brandPrimary,
              size: 23,
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
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.15,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  count == 0
                      ? tr(
                          context,
                          ru: 'Здесь появится подтверждение работы склада',
                          zh: '仓库扫描记录将显示在这里',
                        )
                      : assemblyScanApproachCountText(context, count),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
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

class _SessionRow extends StatelessWidget {
  final AssemblyScanSession session;
  final int approachNumber;
  final VoidCallback onTap;
  final bool emphasized;

  const _SessionRow({
    required this.session,
    required this.approachNumber,
    required this.onTap,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    final date = DateFormat(
      'dd.MM · HH:mm',
    ).format(session.startedAt.toLocal());
    final duration = session.durationMs == null
        ? null
        : Duration(milliseconds: session.durationMs!);

    return Material(
      color: emphasized
          ? context.brandPrimary.withValues(alpha: 0.07)
          : const Color(0xFFF7F8FA),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: emphasized
                  ? context.brandPrimary.withValues(alpha: 0.14)
                  : Colors.black.withValues(alpha: 0.04),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: context.brandPrimary.withValues(alpha: 0.12),
                  ),
                ),
                child: Text(
                  '$approachNumber',
                  style: TextStyle(
                    color: context.brandPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 7,
                      runSpacing: 5,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          tr(
                            context,
                            ru: 'Подход $approachNumber',
                            zh: '第 $approachNumber 次',
                          ),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                        AssemblyScanStatusChip(status: session.status),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      children: [
                        _RowMeta(icon: Icons.schedule_rounded, text: date),
                        if (duration != null)
                          _RowMeta(
                            icon: Icons.timer_outlined,
                            text: _compactDuration(duration),
                          ),
                        _RowMeta(
                          icon: Icons.qr_code_scanner_rounded,
                          text: assemblyScanTrackCountText(
                            context,
                            session.scanCount,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: AppColors.textSecondary.withValues(alpha: 0.75),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RowMeta extends StatelessWidget {
  final IconData icon;
  final String text;

  const _RowMeta({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyEvidenceState extends StatelessWidget {
  const _EmptyEvidenceState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        tr(
          context,
          ru: 'После сканирования треков здесь можно будет посмотреть запись и перейти к каждому моменту.',
          zh: '扫描完成后，可在此查看录像并跳转到每个轨迹的扫描时刻。',
        ),
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          height: 1.35,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _LoadingSection extends StatelessWidget {
  const _LoadingSection();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: context.brandPrimary.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: context.brandPrimary,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            tr(context, ru: 'Загружаем видео сканирования', zh: '正在加载扫描视频'),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _ErrorSection extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _ErrorSection({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final info = ErrorUtils.getErrorInfo(error);
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: Colors.redAccent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(info.icon, color: Colors.redAccent),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            info.getMessage(context),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
        IconButton.filledTonal(
          tooltip: tr(context, ru: 'Повторить', zh: '重试'),
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    );
  }
}

int _approachNumber(
  List<AssemblyScanSession> sessions,
  AssemblyScanSession target,
) {
  final chronological = [...sessions]
    ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
  final index = chronological.indexWhere((session) => session.id == target.id);
  return index < 0 ? 1 : index + 1;
}

void _openSession(
  BuildContext context, {
  required int assemblyId,
  required String assemblyNumber,
  required AssemblyScanSession session,
  required int approachNumber,
}) {
  showAssemblyScanSessionSheet(
    context,
    assemblyId: assemblyId,
    assemblyNumber: assemblyNumber,
    sessionId: session.id,
    approachNumber: approachNumber,
  );
}

String _compactDuration(Duration duration) {
  final totalSeconds = duration.inSeconds.clamp(0, 359999);
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}
