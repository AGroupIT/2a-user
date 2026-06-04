import 'package:flutter/material.dart';
import 'package:twoalogisticcabineuser/src/core/ui/app_toast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:twoalogisticcabineuser/src/core/ui/blurred_modal_bottom_sheet.dart';

import '../../../core/ui/app_colors.dart';
import '../../../core/ui/app_input_decoration.dart';
import '../../../core/ui/sheet_handle.dart';
import '../../clients/application/client_codes_controller.dart';
import '../../add_tracks/data/add_tracks_repository.dart';
import '../../add_tracks/domain/add_tracks_result.dart';
import '../data/tracks_provider.dart';

/// Модальное окно для добавления треков
Future<void> showAddTracksDialog(BuildContext context, WidgetRef ref) async {
  return showBlurredModalBottomSheet(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.22),
    builder: (context) => _AddTracksDialog(),
  );
}

class _AddTracksDialog extends ConsumerStatefulWidget {
  @override
  ConsumerState<_AddTracksDialog> createState() => _AddTracksDialogState();
}

class _AddTracksDialogState extends ConsumerState<_AddTracksDialog> {
  final _ctrl = TextEditingController();
  AddTracksResult? _result;
  String? _error;
  bool _submitting = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!mounted) return;

    final clientCode = ref.read(activeClientCodeProvider);
    if (clientCode == null) {
      setState(() {
        _error = 'Выберите код клиента';
      });
      return;
    }

    final txt = _ctrl.text.trim();
    if (txt.isEmpty) {
      setState(() {
        _error = 'Введите трек-номера';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
      _result = null;
    });

    try {
      debugPrint('📦 Adding tracks from dialog for client $clientCode');

      final repo = ref.read(addTracksRepositoryProvider);

      // Парсим текст в список трек-номеров
      final trackNumbers = txt
          .split(RegExp(r'[,\n;]'))
          .map((t) => t.trim().toUpperCase())
          .where((t) => t.isNotEmpty)
          .toSet() // Убираем дубликаты
          .toList();

      if (trackNumbers.isEmpty) {
        throw Exception('Введите хотя бы один трек-номер');
      }

      debugPrint('📦 Parsed ${trackNumbers.length} track numbers');

      final result = await repo.addTracks(
        clientCode: clientCode,
        trackCodes: trackNumbers,
      );

      if (!mounted) return;

      debugPrint(
        '✅ Tracks added from dialog: ${result.added}, skipped: ${result.skipped.length}',
      );

      setState(() {
        _submitting = false;
        _result = result;
        if (result.added > 0) {
          _ctrl.clear();
        }
      });

      // Обновляем список треков
      try {
        ref.invalidate(paginatedTracksProvider(clientCode));
      } catch (e) {
        debugPrint('⚠️ Error invalidating tracks list: $e');
        // Не критично
      }

      // Если успешно - закрываем диалог через 1.5 секунды
      // Используем route-aware проверку чтобы не закрыть чужой диалог
      if (result.added > 0 && mounted) {
        final route = ModalRoute.of(context);
        await Future.delayed(const Duration(milliseconds: 1500));
        if (mounted && route != null && route.isCurrent) {
          Navigator.of(context).pop();
        }
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error adding tracks from dialog: $e');
      debugPrint('Stack trace: $stackTrace');

      if (!mounted) return;

      final errorMessage = e.toString().replaceFirst('Exception: ', '');
      setState(() {
        _submitting = false;
        _error = errorMessage;
      });

      // Показать SnackBar с ошибкой
      if (mounted) {
        AppToast.showFromSnackBar(
          context,
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Ошибка: $errorMessage',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    try {
      return _buildContent(context);
    } catch (e, stackTrace) {
      debugPrint('❌ Error building AddTracksDialog: $e');
      debugPrint('Stack trace: $stackTrace');

      return Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.red,
              size: 48,
            ),
            const SizedBox(height: 16),
            const Text(
              'Ошибка загрузки',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Произошла ошибка при загрузке формы добавления треков.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF666666), fontSize: 14),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Закрыть'),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildContent(BuildContext context) {
    final clientCode = ref.watch(activeClientCodeProvider);
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;
    final bottomPadding = mediaQuery.padding.bottom;

    return Container(
      constraints: BoxConstraints(maxHeight: mediaQuery.size.height * 0.9),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          const SheetHandle(),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 18 + bottomPadding),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _AddTracksHeader(clientCode: clientCode),
                  const SizedBox(height: 14),
                  if (clientCode != null) ...[
                    const _AddTracksHintCard(),
                    const SizedBox(height: 12),
                    _AddTracksInputCard(
                      controller: _ctrl,
                      enabled: !_submitting,
                      onChanged: () {
                        if (_error != null || _result != null) {
                          setState(() {
                            _error = null;
                            _result = null;
                          });
                        }
                      },
                    ),
                    if (_result != null) ...[
                      const SizedBox(height: 12),
                      _AddTracksResultCard(result: _result!),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      _AddTracksFeedbackCard(
                        icon: Icons.error_outline_rounded,
                        title: 'Не удалось добавить',
                        message: _error!,
                        color: Colors.redAccent,
                      ),
                    ],
                    const SizedBox(height: 14),
                    _AddTracksPrimaryButton(
                      loading: _submitting,
                      onTap: _submitting ? null : _submit,
                    ),
                  ] else ...[
                    const _AddTracksFeedbackCard(
                      icon: Icons.badge_outlined,
                      title: 'Код клиента не выбран',
                      message: 'Сначала выберите код клиента в верхнем меню.',
                      color: AppColors.textSecondary,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddTracksHeader extends StatelessWidget {
  final String? clientCode;

  const _AddTracksHeader({required this.clientCode});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: context.brandGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: context.brandPrimary.withValues(alpha: 0.18),
            blurRadius: 22,
            spreadRadius: -12,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
            ),
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Добавить треки',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Gilroy',
                    fontSize: 21,
                    height: 1.05,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.25,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Вставьте один или несколько номеров — мы начнём отслеживание',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Color(0xE6FFFFFF),
                    fontFamily: 'Gilroy',
                    fontSize: 12.8,
                    height: 1.15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (clientCode != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.22),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.badge_outlined,
                          color: Colors.white,
                          size: 15,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Код $clientCode',
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'Gilroy',
                            fontSize: 12.5,
                            height: 1,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddTracksHintCard extends StatelessWidget {
  const _AddTracksHintCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.035)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: context.brandPrimary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.content_paste_rounded,
              color: context.brandPrimary,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Как вставлять номера',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontFamily: 'Gilroy',
                    fontSize: 14,
                    height: 1.05,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'По одному в строке или через запятую. Дубликаты автоматически уберём.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontFamily: 'Gilroy',
                    fontSize: 12.5,
                    height: 1.2,
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

class _AddTracksInputCard extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onChanged;

  const _AddTracksInputCard({
    required this.controller,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AppOutlinedInputFrame(
      radius: 18,
      fillColor: const Color(0xFFF8FAFC),
      borderColor: const Color(0xFFE3E7EE),
      enabled: enabled,
      builder: (context, focusNode) => TextField(
        focusNode: focusNode,
        controller: controller,
        maxLines: 8,
        enabled: enabled,
        textCapitalization: TextCapitalization.characters,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 14,
          height: 1.35,
          fontFamily: 'monospace',
          fontWeight: FontWeight.w700,
        ),
        decoration: InputDecoration(
          hintText: 'ABC123456789\nDEF987654321\n...',
          hintStyle: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
            height: 1.35,
            fontFamily: 'monospace',
            fontWeight: FontWeight.w600,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Icon(
              Icons.local_shipping_rounded,
              color: context.brandPrimary,
              size: 22,
            ),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 44,
            minHeight: 44,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          contentPadding: const EdgeInsets.fromLTRB(0, 14, 14, 14),
        ),
        onChanged: (_) => onChanged(),
      ),
    );
  }
}

class _AddTracksResultCard extends StatelessWidget {
  final AddTracksResult result;

  const _AddTracksResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final success = result.added > 0;
    final color = success ? const Color(0xFF27C47A) : Colors.orangeAccent;

    return _AddTracksFeedbackCard(
      icon: success ? Icons.check_circle_rounded : Icons.warning_rounded,
      title: success ? 'Добавлено: ${result.added}' : 'Ничего не добавлено',
      message: _message,
      color: color,
    );
  }

  String get _message {
    if (result.skipped.isEmpty) return 'Список треков обновится автоматически.';
    final skippedPreview = result.skipped
        .take(3)
        .map((item) => '${item.code}: ${item.reason}')
        .join('\n');
    final tail = result.skipped.length > 3
        ? '\n... ещё ${result.skipped.length - 3}'
        : '';
    return 'Пропущено: ${result.skipped.length}\n$skippedPreview$tail';
  }
}

class _AddTracksFeedbackCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Color color;

  const _AddTracksFeedbackCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = color.computeLuminance() > 0.58
        ? AppColors.textPrimary
        : color;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: textColor, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: textColor,
                    fontFamily: 'Gilroy',
                    fontSize: 14,
                    height: 1.05,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  message,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontFamily: 'Gilroy',
                    fontSize: 12.5,
                    height: 1.2,
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

class _AddTracksPrimaryButton extends StatelessWidget {
  final bool loading;
  final VoidCallback? onTap;

  const _AddTracksPrimaryButton({required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          height: 52,
          decoration: BoxDecoration(
            gradient: onTap == null ? null : context.brandGradient,
            color: onTap == null ? const Color(0xFFE5E7EB) : null,
            borderRadius: BorderRadius.circular(18),
            boxShadow: onTap == null
                ? null
                : [
                    BoxShadow(
                      color: context.brandPrimary.withValues(alpha: 0.20),
                      blurRadius: 16,
                      spreadRadius: -9,
                      offset: const Offset(0, 9),
                    ),
                  ],
          ),
          child: Center(
            child: loading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_rounded, color: Colors.white, size: 21),
                      SizedBox(width: 7),
                      Text(
                        'Добавить треки',
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'Gilroy',
                          fontSize: 15,
                          height: 1,
                          fontWeight: FontWeight.w900,
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
