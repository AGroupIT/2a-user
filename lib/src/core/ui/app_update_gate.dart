import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/update_gate_provider.dart';
import '../services/update_service.dart';
import 'app_background.dart';
import 'app_colors.dart';

class AppUpdateGate extends ConsumerWidget {
  final Widget child;

  const AppUpdateGate({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appUpdateGateProvider);
    final update = state.update;

    if (state.phase == AppUpdateGatePhase.required && update != null) {
      return _RequiredUpdateScreen(update: update);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        if (state.phase == AppUpdateGatePhase.optional && update != null)
          _OptionalUpdateBanner(update: update),
      ],
    );
  }
}

class _OptionalUpdateBanner extends ConsumerWidget {
  final UpdateInfo update;

  const _OptionalUpdateBanner({required this.update});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        minimum: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  gradient: context.brandGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: context.brandPrimary.withValues(alpha: 0.24),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Icon(
                        Icons.system_update_alt_rounded,
                        color: Colors.white,
                        size: 21,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        _t(
                          context,
                          'Доступно обновление ${update.latestVersion}',
                          '有新版本 ${update.latestVersion}',
                        ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _UpdateActionButton(update: update, compact: true),
                    IconButton(
                      tooltip: _t(context, 'Напомнить позже', '稍后提醒'),
                      onPressed: () => ref
                          .read(appUpdateGateProvider.notifier)
                          .dismissOptional(),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RequiredUpdateScreen extends StatelessWidget {
  final UpdateInfo update;

  const _RequiredUpdateScreen({required this.update});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            const AppBackground(),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.96),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: context.brandPrimary.withValues(alpha: 0.12),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: context.brandPrimary.withValues(alpha: 0.14),
                            blurRadius: 32,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              gradient: context.brandGradient,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: context.brandPrimary.withValues(
                                    alpha: 0.25,
                                  ),
                                  blurRadius: 18,
                                  offset: const Offset(0, 7),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.system_update_rounded,
                              color: Colors.white,
                              size: 38,
                            ),
                          ),
                          const SizedBox(height: 22),
                          Text(
                            _t(
                              context,
                              'Необходимо обновить приложение',
                              '需要更新应用',
                            ),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _t(
                              context,
                              'Эта версия больше не поддерживается. Обновите приложение, чтобы продолжить работу.',
                              '当前版本已停止支持。请更新应用后继续使用。',
                            ),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                              height: 1.45,
                            ),
                          ),
                          if (update.changelog.isNotEmpty) ...[
                            const SizedBox(height: 18),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: context.brandPrimary.withValues(
                                  alpha: 0.07,
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                update.changelog,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 13,
                                  height: 1.45,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 22),
                          SizedBox(
                            width: double.infinity,
                            child: _UpdateActionButton(
                              update: update,
                              compact: false,
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: UpdateService.openSupport,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: context.brandPrimary,
                                side: BorderSide(
                                  color: context.brandPrimary.withValues(
                                    alpha: 0.45,
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              icon: const Icon(
                                Icons.support_agent_rounded,
                                size: 20,
                              ),
                              label: Text(
                                _t(context, 'Связаться с поддержкой', '联系支持'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UpdateActionButton extends StatefulWidget {
  final UpdateInfo update;
  final bool compact;

  const _UpdateActionButton({required this.update, required this.compact});

  @override
  State<_UpdateActionButton> createState() => _UpdateActionButtonState();
}

class _UpdateActionButtonState extends State<_UpdateActionButton> {
  bool _isWorking = false;
  double _progress = 0;
  String? _error;

  Future<void> _startUpdate() async {
    if (_isWorking) return;
    setState(() {
      _isWorking = true;
      _error = null;
      _progress = 0;
    });

    try {
      if (UpdateService.usesExternalStore(widget.update)) {
        final opened = await UpdateService.openExternalUpdate(widget.update);
        if (!opened) throw Exception('update_url_unavailable');
      } else {
        if (widget.update.downloadUrl.isEmpty) {
          throw Exception('download_url_unavailable');
        }
        final filePath = await UpdateService.downloadUpdate(
          widget.update,
          onProgress: (received, total) {
            if (!mounted) return;
            setState(() {
              _progress = total > 0 ? received / total : 0;
            });
          },
        );
        if (!mounted) return;
        await UpdateService.installUpdate(filePath);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = _t(context, 'Не удалось запустить обновление', '无法开始更新');
      });
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = _isWorking
        ? (_progress > 0
              ? '${(_progress * 100).clamp(0, 100).toStringAsFixed(0)}%'
              : _t(context, 'Открываем…', '正在打开…'))
        : widget.compact
        ? _t(context, 'Обновить', '更新')
        : _t(context, 'Обновить приложение', '更新应用');

    final button = FilledButton.icon(
      onPressed: _isWorking ? null : _startUpdate,
      style: FilledButton.styleFrom(
        backgroundColor: widget.compact
            ? Colors.white.withValues(alpha: 0.22)
            : context.brandPrimary,
        disabledBackgroundColor: widget.compact
            ? Colors.white.withValues(alpha: 0.16)
            : context.brandPrimary.withValues(alpha: 0.55),
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(
          horizontal: widget.compact ? 12 : 18,
          vertical: widget.compact ? 8 : 14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(widget.compact ? 20 : 14),
          side: widget.compact
              ? BorderSide(color: Colors.white.withValues(alpha: 0.48))
              : BorderSide.none,
        ),
      ),
      icon: _isWorking
          ? SizedBox.square(
              dimension: 15,
              child: CircularProgressIndicator(
                value: _progress > 0 ? _progress : null,
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Icon(
              UpdateService.usesExternalStore(widget.update)
                  ? Icons.open_in_new_rounded
                  : Icons.download_rounded,
              size: widget.compact ? 16 : 20,
            ),
      label: Text(
        label,
        style: TextStyle(
          fontSize: widget.compact ? 12 : 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    if (_error == null) return button;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        button,
        const SizedBox(height: 6),
        Text(
          _error!,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: widget.compact ? Colors.white : Colors.redAccent,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

String _t(BuildContext context, String ru, String zh) {
  return Localizations.localeOf(context).languageCode == 'zh' ? zh : ru;
}
