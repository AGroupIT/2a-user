import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:showcaseview/showcaseview.dart';

import '../../../core/services/showcase_service.dart';
import '../../../core/ui/app_colors.dart';
import '../../../core/ui/app_layout.dart';
import '../../../core/ui/empty_state.dart';
import '../../clients/application/client_codes_controller.dart';
import '../../tracks/data/tracks_provider.dart';
import '../data/add_tracks_repository.dart';
import '../domain/add_tracks_result.dart';

class AddTracksScreen extends ConsumerStatefulWidget {
  const AddTracksScreen({super.key});

  @override
  ConsumerState<AddTracksScreen> createState() => _AddTracksScreenState();
}

class _AddTracksScreenState extends ConsumerState<AddTracksScreen> {
  final _ctrl = TextEditingController();
  AddTracksResult? _result;
  String? _error;
  bool _submitting = false;

  // Showcase keys
  final _showcaseKeyInput = GlobalKey();
  final _showcaseKeySubmit = GlobalKey();

  bool _showcaseStarted = false;

  // Хранение контекста Showcase для вызова next()
  BuildContext? _showcaseContext;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _startShowcaseIfNeeded(BuildContext showcaseContext) {
    if (_showcaseStarted) return;
    
    final showcaseState = ref.read(showcaseProvider(ShowcasePage.addTracks));
    if (!showcaseState.shouldShow) return;
    
    _showcaseStarted = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      
      ShowCaseWidget.of(showcaseContext).startShowCase([
        _showcaseKeyInput,
        _showcaseKeySubmit,
      ]);
    });
  }

  void _onShowcaseComplete() {
    ref.read(showcaseNotifierProvider(ShowcasePage.addTracks)).markAsSeen();
  }

  @override
  Widget build(BuildContext context) {
    final clientCode = ref.watch(activeClientCodeProvider);
    if (clientCode == null) {
      return const EmptyState(
        icon: Icons.badge_outlined,
        title: 'Выберите код клиента',
        message:
            'Сначала выберите код клиента в шапке, затем добавляйте треки.',
      );
    }

    final bottomPad = AppLayout.bottomScrollPadding(context);
    final topPad = AppLayout.topBarTotalHeight(context);

    return ShowcaseWrapper(
      onComplete: _onShowcaseComplete,
      child: Builder(
        builder: (showcaseContext) {
          _showcaseContext = showcaseContext;
          _startShowcaseIfNeeded(showcaseContext);

          return ListView(
            padding: EdgeInsets.fromLTRB(16, topPad * 0.7 + 6, 16, 100 + bottomPad),
            children: [
              Text(
                'Добавить треки',
                style: Theme.of(
                  context,
                ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 18),
              Showcase(
                key: _showcaseKeyInput,
                title: 'Поле ввода треков',
                description: 'Введите трек-номера по одному на строку или через запятую. После добавления они отобразятся в разделе "Треки".',
                targetPadding: const EdgeInsets.all(8),
                tooltipPosition: TooltipPosition.bottom,
                onTargetClick: () {
                  if (_showcaseContext != null) {
                    ShowCaseWidget.of(_showcaseContext!).next();
                  }
                },
                disposeOnTap: false,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 24,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
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
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [context.brandPrimary, context.brandSecondary],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.all(1.5),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12.5),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: TextField(
                    controller: _ctrl,
                    minLines: 6,
                    maxLines: 10,
                    decoration: const InputDecoration(
                      hintText:
                          'Пример:\nTRACK123456\nTRACK789012\nTRACK345678',
                      hintStyle: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF999999),
                        fontWeight: FontWeight.w400,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        color: Colors.red.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Showcase(
                key: _showcaseKeySubmit,
                title: 'Кнопка добавления',
                description: 'Нажмите для добавления введённых треков.',
                targetPadding: const EdgeInsets.all(8),
                tooltipPosition: TooltipPosition.top,
                onBarrierClick: () {
                  _onShowcaseComplete();
                },
                onToolTipClick: () {
                  _onShowcaseComplete();
                },
                child: FilledButton(
                  onPressed: _submitting ? null : () => _submit(clientCode),
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Добавить треки'),
                ),
              ),
            ],
          ),
        ),
        ),
        if (_result != null) ...[
          const SizedBox(height: 18),
          _ResultCard(
            result: _result!,
            onClose: () => setState(() => _result = null),
          ),
        ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _submit(String clientCode) async {
    setState(() {
      _error = null;
      _result = null;
      _submitting = true;
    });

    try {
      final raw = _ctrl.text;
      final codes = raw
          .split(RegExp(r'[\n,;]+'))
          .map((s) => s.trim().toUpperCase()) // Приводим к верхнему регистру
          .where((s) => s.isNotEmpty)
          .toSet() // Убираем дубликаты в самом вводе
          .toList();
      if (codes.isEmpty) {
        throw Exception('Введите хотя бы один трек-номер');
      }

      final repo = ref.read(addTracksRepositoryProvider);
      final res = await repo.addTracks(
        clientCode: clientCode,
        trackCodes: codes,
      );
      setState(() {
        _result = res;
        _ctrl.clear();
      });

      // Инвалидируем список треков, чтобы обновить его на странице треков
      if (res.added > 0) {
        // Обновляем пагинированный список
        ref.read(paginatedTracksProvider(clientCode)).refresh();
      }

      // Show success notification
      if (mounted) {
        _showResultNotification(res);
      }
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      setState(() => _submitting = false);
    }
  }

  void _showResultNotification(AddTracksResult result) {
    final hasSkipped = result.skipped.isNotEmpty;
    final message = hasSkipped
        ? 'Добавлено: ${result.added}, не добавлено: ${result.skipped.length}'
        : 'Успешно добавлено ${result.added} треков';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              hasSkipped
                  ? Icons.warning_amber_rounded
                  : Icons.check_circle_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: hasSkipped
            ? Colors.orange.shade700
            : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final AddTracksResult result;
  final VoidCallback onClose;
  const _ResultCard({required this.result, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final hasSkipped = result.skipped.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Success header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: hasSkipped
                    ? [Colors.orange.shade400, Colors.orange.shade600]
                    : [Colors.green.shade400, Colors.green.shade600],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  hasSkipped
                      ? Icons.warning_amber_rounded
                      : Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasSkipped ? 'Частично добавлено' : 'Успешно добавлено!',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${result.added} треков добавлено в систему',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Stats
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _StatBox(
                        icon: Icons.check_rounded,
                        iconColor: Colors.green,
                        label: 'Добавлено',
                        value: '${result.added}',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatBox(
                        icon: Icons.close_rounded,
                        iconColor: Colors.red,
                        label: 'Пропущено',
                        value: '${result.skipped.length}',
                      ),
                    ),
                  ],
                ),
                if (result.skipped.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Не добавленные треки:',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  const SizedBox(height: 10),
                  ...result.skipped
                      .take(10)
                      .map(
                        (s) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.error_outline_rounded,
                                color: Colors.red.shade700,
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      s.code,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      s.reason,
                                      style: TextStyle(
                                        color: Colors.red.shade700,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  if (result.skipped.length > 10)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '…и ещё ${result.skipped.length - 10} треков',
                        style: const TextStyle(
                          color: Color(0xFF666666),
                          fontSize: 13,
                        ),
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

class _StatBox extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _StatBox({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                ),
              ),
              Text(
                label,
                style: const TextStyle(color: Color(0xFF666666), fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
