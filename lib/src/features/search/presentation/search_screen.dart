import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:showcaseview/showcaseview.dart';

import '../../../core/services/showcase_service.dart';
import '../../../core/ui/app_colors.dart';
import '../../../core/ui/app_layout.dart';
import '../../../core/ui/empty_state.dart';
import '../../../core/ui/help_dialog.dart';
import '../../../core/ui/status_pill.dart';
import '../../auth/data/auth_provider.dart';
import '../../clients/application/client_codes_controller.dart';
import '../domain/search_result.dart';
import 'search_controller.dart';

void _showStyledSnackBar(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(
    SnackBar(
      content: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => messenger.hideCurrentSnackBar(),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isError
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_outline_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
      behavior: SnackBarBehavior.floating,
      backgroundColor: isError ? const Color(0xFFE53935) : context.brandPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 15),
      duration: const Duration(seconds: 3),
    ),
  );
}

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _ctrl = TextEditingController();
  bool _hasSearched = false;

  // Showcase key
  final _showcaseKeySearch = GlobalKey();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _startShowcase(BuildContext showcaseContext) {
    final showcaseState = ref.read(showcaseProvider(ShowcasePage.search));
    if (!showcaseState.shouldShow) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ShowCaseWidget.of(showcaseContext).startShowCase([_showcaseKeySearch]);
    });
  }

  void _onShowcaseComplete() {
    ref.read(showcaseNotifierProvider(ShowcasePage.search)).markAsSeen();
  }

  @override
  Widget build(BuildContext context) {
    final activeClientCode = ref.watch(activeClientCodeProvider);
    final results = ref.watch(searchControllerProvider);
    final topPad = AppLayout.topBarTotalHeight(context);
    final bottomPad = AppLayout.bottomScrollPadding(context);

    return ShowcaseWrapper(
      onComplete: _onShowcaseComplete,
      child: Builder(
        builder: (showcaseContext) {
          // Запускаем showcase с правильным контекстом
          _startShowcase(showcaseContext);

          return ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              topPad * 0.7 + 6,
              16,
              24 + bottomPad,
            ),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Поиск по трекам',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Справка',
                    onPressed: () => showHelpDialog(
                      context,
                      title: 'Как искать треки',
                      content: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '1) Введите минимум 5 символов трек-номера (можно последние цифры).',
                          ),
                          SizedBox(height: 8),
                          Text(
                            '2) Нажмите «Найти». Появятся карточки со статусом и датой обновления.',
                          ),
                          SizedBox(height: 8),
                          Text(
                            '3) Если трек найден, но не привязан к вашему коду — нажмите «Запросить привязку…».',
                          ),
                        ],
                      ),
                    ),
                    icon: Icon(
                      Icons.help_outline_rounded,
                      color: context.brandPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Showcase(
                key: _showcaseKeySearch,
                title: 'Поиск треков',
                description:
                    'Введите минимум 5 символов трек-номера и нажмите "Найти". Можно искать по любой части номера.',
                targetPadding: const EdgeInsets.all(8),
                tooltipPosition: TooltipPosition.bottom,
                onBarrierClick: () {
                  if (mounted) _onShowcaseComplete();
                },
                onToolTipClick: () {
                  if (mounted) _onShowcaseComplete();
                },
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
                      Builder(
                        builder: (ctx) => Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [ctx.brandPrimary, ctx.brandSecondary],
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
                              textInputAction: TextInputAction.search,
                              decoration: InputDecoration(
                                prefixIcon: Icon(
                                  Icons.search_rounded,
                                  color: ctx.brandPrimary,
                                  size: 20,
                                ),
                                suffixIcon: _ctrl.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(
                                          Icons.close_rounded,
                                          color: Color(0xFF999999),
                                          size: 20,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _ctrl.clear();
                                          });
                                        },
                                      )
                                    : null,
                                hintText: 'Поиск по номеру трека',
                                hintStyle: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF999999),
                                  fontWeight: FontWeight.w500,
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                              onChanged: (_) => setState(() {
                                _hasSearched = false;
                              }),
                              onSubmitted: (_) => _run(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              results.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => EmptyState(
                  icon: Icons.error_outline_rounded,
                  title: 'Ошибка поиска',
                  message: e.toString(),
                ),
                data: (items) {
                  final q = _ctrl.text.trim();
                  if (q.isEmpty) {
                    return const EmptyState(
                      icon: Icons.search_rounded,
                      title: 'Введите трек‑номер',
                      message:
                          'Поиск глобальный и не зависит от выбранного кода клиента.',
                    );
                  }
                  if (q.length < 5) {
                    return const EmptyState(
                      icon: Icons.info_outline_rounded,
                      title: 'Слишком короткий запрос',
                      message: 'Введите минимум 5 символов.',
                    );
                  }
                  if (!_hasSearched) {
                    return const EmptyState(
                      icon: Icons.keyboard_return_rounded,
                      title: 'Нажмите Enter для поиска',
                      message: 'Или нажмите «Готово» на клавиатуре.',
                    );
                  }
                  if (items.isEmpty) {
                    return const EmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'Ничего не найдено',
                      message: 'Проверьте написание или попробуйте позже.',
                    );
                  }

                  return ListView.separated(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) => _SearchResultTile(
                      result: items[i],
                      activeClientCode: activeClientCode,
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _run() {
    FocusScope.of(context).unfocus();
    if (_ctrl.text.trim().length < 5) return;
    setState(() => _hasSearched = true);
    ref.read(searchControllerProvider.notifier).search(_ctrl.text);
  }
}

class _SearchResultTile extends ConsumerStatefulWidget {
  final SearchResult result;
  final String? activeClientCode;

  const _SearchResultTile({
    required this.result,
    required this.activeClientCode,
  });

  @override
  ConsumerState<_SearchResultTile> createState() => _SearchResultTileState();
}

class _SearchResultTileState extends ConsumerState<_SearchResultTile> {
  bool _isLoading = false;

  Color? _parseColor(String? colorStr) {
    if (colorStr == null || colorStr.isEmpty) return null;
    try {
      String hex = colorStr.replaceAll('#', '');
      if (hex.length == 6) hex = 'FF$hex';
      return Color(int.parse(hex, radix: 16));
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd MMM yyyy', 'ru');
    final result = widget.result;
    final activeClientCode = widget.activeClientCode;

    // Используем showBindButton из API, но также проверяем activeClientCode
    final showBindButton = result.showBindButton && activeClientCode != null;

    // Парсим цвет статуса
    final statusColor = _parseColor(result.statusColor);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  result.trackCode,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
              StatusPill(text: result.status, color: statusColor),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Дата изменения: ${df.format(result.updatedAt)}',
            style: const TextStyle(color: Color(0xFF666666), fontSize: 13.5),
          ),
          if (result.clientCode != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  'Код клиента: ${result.clientCode}',
                  style: const TextStyle(
                    color: Color(0xFF666666),
                    fontSize: 13.5,
                  ),
                ),
                if (result.isNocode) ...[
                  const SizedBox(width: 6),
                  Builder(
                    builder: (ctx) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: ctx.brandPrimary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'не привязан',
                        style: TextStyle(
                          color: ctx.brandPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
          if (result.hasPendingQuestion) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.hourglass_top_rounded,
                    size: 16,
                    color: Colors.orange,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Запрос на привязку отправлен',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (showBindButton) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isLoading ? null : () => _requestBind(context),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Запросить привязку'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _requestBind(BuildContext context) async {
    final code = widget.activeClientCode;
    if (code == null) return;

    setState(() => _isLoading = true);

    try {
      final auth = ref.read(authProvider);
      final clientId = auth.clientId;

      if (clientId == null) {
        if (context.mounted) {
          _showStyledSnackBar(
            context,
            'Ошибка: не удалось определить клиента',
            isError: true,
          );
        }
        return;
      }

      final success = await ref
          .read(searchControllerProvider.notifier)
          .requestBinding(
            trackId: widget.result.id,
            trackNumber: widget.result.trackCode,
            clientCode: code,
            clientId: clientId,
            clientCodeId: null, // Будет определён на сервере
          );

      if (context.mounted) {
        if (success) {
          _showStyledSnackBar(context, 'Запрос на привязку отправлен');
        } else {
          _showStyledSnackBar(
            context,
            'Ошибка при отправке запроса',
            isError: true,
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
