import 'package:flutter/material.dart';
import 'package:twoalogisticcabineuser/src/core/ui/app_toast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/app_colors.dart';
import '../../../core/ui/app_input_decoration.dart';
import '../../clients/application/client_codes_controller.dart';
import '../../add_tracks/data/add_tracks_repository.dart';
import '../../add_tracks/domain/add_tracks_result.dart';
import '../data/tracks_provider.dart';

/// Модальное окно для добавления треков
Future<void> showAddTracksDialog(BuildContext context, WidgetRef ref) async {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
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
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomPadding + 80),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Шапка с заголовком и кнопкой закрытия
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Добавить треки',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFF5F5F5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (clientCode != null) ...[
              // Поле ввода
              const Text(
                'Введите трек-номера',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              const SizedBox(height: 4),
              const Text(
                'По одному в строке или через запятую',
                style: TextStyle(color: Color(0xFF999999), fontSize: 13),
              ),
              const SizedBox(height: 12),
              AppGradientInputFrame(
                fillColor: const Color(0xFFF8F9FA),
                child: TextField(
                  controller: _ctrl,
                  maxLines: 8,
                  enabled: !_submitting,
                  style: const TextStyle(fontSize: 14, fontFamily: 'monospace'),
                  decoration: const InputDecoration(
                    hintText: 'ABC123456789\nDEF987654321\n...',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    contentPadding: EdgeInsets.all(14),
                  ),
                  onChanged: (_) {
                    if (_error != null || _result != null) {
                      setState(() {
                        _error = null;
                        _result = null;
                      });
                    }
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Результат
              if (_result != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _result!.added > 0
                        ? const Color(0xFFE8F5E9)
                        : const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _result!.added > 0
                                ? Icons.check_circle
                                : Icons.warning,
                            color: _result!.added > 0
                                ? const Color(0xFF4CAF50)
                                : const Color(0xFFFF9800),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _result!.added > 0
                                ? 'Добавлено: ${_result!.added}'
                                : 'Ничего не добавлено',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: _result!.added > 0
                                  ? const Color(0xFF4CAF50)
                                  : const Color(0xFFFF9800),
                            ),
                          ),
                        ],
                      ),
                      if (_result!.skipped.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Пропущено: ${_result!.skipped.length}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF666666),
                          ),
                        ),
                        const SizedBox(height: 4),
                        ...(_result!.skipped
                            .take(3)
                            .map(
                              (item) => Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  '• ${item.code}: ${item.reason}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF999999),
                                  ),
                                ),
                              ),
                            )),
                        if (_result!.skipped.length > 3)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              '... ещё ${_result!.skipped.length - 3}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF999999),
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Ошибка
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Color(0xFFE53935),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            color: Color(0xFFE53935),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Кнопка отправки
              ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.brandPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Добавить',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ] else ...[
              const Text(
                'Сначала выберите код клиента в шапке',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF999999), fontSize: 14),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
