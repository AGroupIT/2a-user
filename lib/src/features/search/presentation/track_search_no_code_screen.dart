import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:twoalogisticcabineuser/src/core/ui/app_toast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:twoalogisticcabineuser/src/core/ui/blurred_modal_bottom_sheet.dart';

import '../../../core/ui/app_colors.dart';
import '../../../core/ui/app_input_decoration.dart';
import '../../../core/ui/app_layout.dart';
import '../../../core/ui/help_dialog.dart';
import '../../../core/ui/scroll_to_top_button.dart';
import '../../../core/utils/error_utils.dart';
import '../../auth/data/auth_provider.dart';
import '../../clients/application/client_codes_controller.dart';
import '../domain/search_result.dart';
import 'search_controller.dart';

const _searchTextColor = Color(0xFF2F2F2F);
const _searchMutedTextColor = Color(0x992F2F2F);

BoxDecoration _searchCardDecoration({Color color = Colors.white}) {
  return BoxDecoration(
    color: color,
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
  );
}

BoxDecoration _searchSoftDecoration() {
  return BoxDecoration(
    color: const Color(0xFFF8FAFC),
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: Colors.black.withValues(alpha: 0.025)),
  );
}

Color? _parseSearchColor(String? colorStr) {
  if (colorStr == null || colorStr.isEmpty) return null;
  final buffer = StringBuffer();
  if (colorStr.length == 6 || colorStr.length == 7) buffer.write('ff');
  buffer.write(colorStr.replaceFirst('#', ''));
  final value = int.tryParse(buffer.toString(), radix: 16);
  return value == null ? null : Color(value);
}

void _showStyledSnackBar(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  AppToast.showFromSnackBar(
    context,
    SnackBar(
      content: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: AppToast.hide,
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
                  fontFamily: 'Gilroy',
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
      margin: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        AppLayout.bottomBarObstruction(context) + 12,
      ),
      duration: const Duration(seconds: 3),
    ),
  );
}

class _SearchPageHeader extends StatelessWidget {
  const _SearchPageHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/');
              }
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 46,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.black.withValues(alpha: 0.035),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 18,
                    spreadRadius: -12,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            'Поиск трека',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontFamily: 'Gilroy',
              fontSize: 26,
              height: 1.05,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.35,
            ),
          ),
        ),
        const SizedBox(width: 12),
        _SearchHelpButton(),
      ],
    );
  }
}

class _SearchHelpButton extends StatelessWidget {
  const _SearchHelpButton();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => showHelpDialog(
          context,
          title: 'Как работает этот поиск',
          content: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Здесь собраны только треки, которые пока не привязаны ни к одному коду клиента.',
              ),
              SizedBox(height: 8),
              Text('1) Введите минимум 3 символа трек-номера.'),
              SizedBox(height: 8),
              Text('2) Нажмите «Запросить привязку», если нашли свой трек.'),
              SizedBox(height: 8),
              Text(
                '3) Приложите скрин логистики: ТТН, накладную или другое подтверждение.',
              ),
            ],
          ),
        ),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 46,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black.withValues(alpha: 0.035)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 18,
                spreadRadius: -12,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Icon(
            Icons.help_outline_rounded,
            size: 21,
            color: context.brandPrimary,
          ),
        ),
      ),
    );
  }
}

class _SearchHeroCard extends StatelessWidget {
  const _SearchHeroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            const Positioned.fill(child: _SearchHeaderGlowBackdrop()),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.22),
                      ),
                    ),
                    child: const Icon(
                      Icons.manage_search_rounded,
                      color: Colors.white,
                      size: 31,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Трек без кода клиента',
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'Gilroy',
                            fontSize: 22,
                            height: 1.04,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.25,
                          ),
                        ),
                        SizedBox(height: 7),
                        Text(
                          'Найдите посылку, которую склад ещё не привязал к вашему коду, и отправьте запрос с подтверждением.',
                          style: TextStyle(
                            color: Color(0xE6FFFFFF),
                            fontFamily: 'Gilroy',
                            fontSize: 13,
                            height: 1.2,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchHeaderGlowBackdrop extends StatefulWidget {
  const _SearchHeaderGlowBackdrop();

  @override
  State<_SearchHeaderGlowBackdrop> createState() =>
      _SearchHeaderGlowBackdropState();
}

class _SearchHeaderGlowBackdropState extends State<_SearchHeaderGlowBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final wave = Curves.easeInOutCubic.transform(_controller.value);
            final shift = (wave * 2) - 1;

            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  right: -62,
                  top: -58,
                  child: Transform.translate(
                    offset: Offset(-10 * shift, 6 * shift),
                    child: _SearchGlowCircle(
                      size: 154,
                      color: Colors.white.withValues(alpha: 0.13),
                    ),
                  ),
                ),
                Positioned(
                  right: 22,
                  bottom: -68,
                  child: Transform.translate(
                    offset: Offset(9 * shift, -7 * shift),
                    child: _SearchGlowCircle(
                      size: 152,
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                ),
                Positioned(
                  right: -14,
                  bottom: 16,
                  child: Transform.translate(
                    offset: Offset(5 * shift, -4 * shift),
                    child: _SearchGlowCircle(
                      size: 82,
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
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

class _SearchGlowCircle extends StatelessWidget {
  final double size;
  final Color color;

  const _SearchGlowCircle({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

/// Экран поиска треков без кода клиента (nocode).
/// Открывается из нижнего меню "Ещё" → "Поиск по трек-номеру без кода".
class TrackSearchNoCodeScreen extends ConsumerStatefulWidget {
  const TrackSearchNoCodeScreen({super.key, this.initialQuery});

  final String? initialQuery;

  @override
  ConsumerState<TrackSearchNoCodeScreen> createState() =>
      _TrackSearchNoCodeScreenState();
}

class _TrackSearchNoCodeScreenState
    extends ConsumerState<TrackSearchNoCodeScreen> {
  final _ctrl = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (!mounted) return;
      setState(() {});
    });
    final initialQuery = widget.initialQuery?.trim();
    if (initialQuery == null || initialQuery.isEmpty) return;

    _ctrl.text = initialQuery;
    _ctrl.selection = TextSelection.collapsed(offset: initialQuery.length);

    if (initialQuery.length >= 3) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _run();
      });
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _scrollController.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  void _run() {
    FocusScope.of(context).unfocus();
    if (_ctrl.text.trim().length < 3) return;
    setState(() => _hasSearched = true);
    ref.read(searchControllerProvider.notifier).search(_ctrl.text);
  }

  @override
  Widget build(BuildContext context) {
    final activeClientCode = ref.watch(activeClientCodeProvider);
    final results = ref.watch(searchControllerProvider);
    final topPad = AppLayout.topBarTotalHeight(context);
    final bottomPad = AppLayout.bottomScrollPadding(context);

    return Stack(
      children: [
        ListView(
          controller: _scrollController,
          padding: EdgeInsets.fromLTRB(
            16,
            topPad * 0.7 + 16,
            16,
            bottomPad + 16,
          ),
          children: [
            const _SearchPageHeader(),
            const SizedBox(height: 12),
            const _SearchHeroCard(),
            const SizedBox(height: 14),
            Container(
              decoration: _searchCardDecoration(),
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      focusNode: _focusNode,
                      textInputAction: TextInputAction.search,
                      style: const TextStyle(
                        color: _searchTextColor,
                        fontFamily: 'Gilroy',
                        fontSize: 15,
                        height: 18 / 15,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: appInputDecoration(
                        context,
                        prefixIcon: _focusNode.hasFocus
                            ? null
                            : Icon(
                                Icons.search_rounded,
                                color: context.brandPrimary,
                                size: 22,
                              ),
                        suffixIcon: _ctrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(
                                  Icons.close_rounded,
                                  color: _searchMutedTextColor,
                                  size: 20,
                                ),
                                onPressed: () => setState(() {
                                  _ctrl.selection =
                                      const TextSelection.collapsed(offset: 0);
                                  _ctrl.clear();
                                  _hasSearched = false;
                                }),
                              )
                            : null,
                        hintText: 'Введите трек-номер',
                        hintStyle: const TextStyle(
                          fontFamily: 'Gilroy',
                          fontSize: 14,
                          height: 16 / 14,
                          color: Color(0x662F2F2F),
                          fontWeight: FontWeight.w600,
                        ),
                        fillColor: const Color(0xFFF8FAFC),
                        borderColor: const Color(0xFFE1E5ED),
                        focusedBorderColor: context.brandPrimary,
                        focusedWidth: 1.6,
                        radius: 18,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 13,
                        ),
                      ),
                      onChanged: (_) => setState(() => _hasSearched = false),
                      onSubmitted: (_) => _run(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 54,
                    height: 54,
                    child: FilledButton(
                      onPressed: _run,
                      style: FilledButton.styleFrom(
                        backgroundColor: context.brandPrimary,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        elevation: 0,
                      ),
                      child: const Icon(Icons.arrow_forward_rounded, size: 24),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.black.withValues(alpha: 0.025),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: context.brandPrimary,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Поиск работает только по трекам без привязки. Для запроса понадобится фото подтверждения.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontFamily: 'Gilroy',
                        fontSize: 12.5,
                        height: 1.18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            results.when(
              loading: () => Container(
                decoration: _searchCardDecoration(),
                padding: const EdgeInsets.symmetric(vertical: 26),
                child: Center(
                  child: CircularProgressIndicator(color: context.brandPrimary),
                ),
              ),
              error: (e, _) {
                final info = ErrorUtils.getErrorInfo(e);
                return _SearchStateCard(
                  icon: info.icon,
                  title: info.title,
                  message: info.message,
                  isError: true,
                );
              },
              data: (items) {
                final q = _ctrl.text.trim();
                if (q.isEmpty) {
                  return const _SearchStateCard(
                    icon: Icons.search_rounded,
                    title: 'Введите трек-номер',
                    message:
                        'Мы проверим только посылки, которые ещё не привязаны к коду клиента.',
                  );
                }
                if (q.length < 3) {
                  return const _SearchStateCard(
                    icon: Icons.info_outline_rounded,
                    title: 'Слишком короткий запрос',
                    message: 'Введите минимум 3 символа трек-номера.',
                  );
                }
                if (!_hasSearched) {
                  return const _SearchStateCard(
                    icon: Icons.keyboard_return_rounded,
                    title: 'Запустите поиск',
                    message:
                        'Нажмите оранжевую кнопку или «Готово» на клавиатуре.',
                  );
                }
                if (items.isEmpty) {
                  return const _SearchStateCard(
                    icon: Icons.search_off_rounded,
                    title: 'Ничего не найдено',
                    message:
                        'Проверьте трек-номер или попробуйте позже: склад мог ещё не добавить посылку.',
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ResultsHeader(count: items.length),
                    const SizedBox(height: 10),
                    for (var i = 0; i < items.length; i++) ...[
                      if (i > 0) const SizedBox(height: 10),
                      _NoCodeResultTile(
                        result: items[i],
                        activeClientCode: activeClientCode,
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
        ScrollToTopButton(controller: _scrollController),
      ],
    );
  }
}

class _ResultsHeader extends StatelessWidget {
  final int count;

  const _ResultsHeader({required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: context.brandPrimary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(
            Icons.manage_search_rounded,
            color: context.brandPrimary,
            size: 22,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Найдено: $count',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontFamily: 'Gilroy',
              fontSize: 18,
              height: 1.1,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.15,
            ),
          ),
        ),
      ],
    );
  }
}

class _SearchStateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final bool isError;

  const _SearchStateCard({
    required this.icon,
    required this.title,
    this.message,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isError ? const Color(0xFFE53935) : context.brandPrimary;

    return Container(
      decoration: _searchCardDecoration(),
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, size: 24, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _searchTextColor,
                    fontFamily: 'Gilroy',
                    fontSize: 18,
                    height: 22 / 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.1,
                  ),
                ),
                if (message != null) ...[
                  const SizedBox(height: 5),
                  Text(
                    message!,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontFamily: 'Gilroy',
                      fontSize: 13.5,
                      height: 18 / 13.5,
                      fontWeight: FontWeight.w700,
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

class _NoCodeResultTile extends ConsumerStatefulWidget {
  final SearchResult result;
  final String? activeClientCode;

  const _NoCodeResultTile({
    required this.result,
    required this.activeClientCode,
  });

  @override
  ConsumerState<_NoCodeResultTile> createState() => _NoCodeResultTileState();
}

class _NoCodeResultTileState extends ConsumerState<_NoCodeResultTile> {
  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    final df = DateFormat('dd.MM.yyyy', locale);
    final r = widget.result;
    final isZh = locale.toLowerCase().startsWith('zh');
    final activeClientCode = widget.activeClientCode;
    final showBindButton = r.showBindButton && activeClientCode != null;
    final statusColor =
        _parseSearchColor(r.statusColor) ?? context.brandPrimary;
    final statusText = (isZh && (r.statusZh?.isNotEmpty ?? false))
        ? r.statusZh!
        : r.status;

    return Container(
      decoration: _searchCardDecoration(),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  Icons.local_shipping_rounded,
                  color: statusColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Трек-номер',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontFamily: 'Gilroy',
                        fontWeight: FontWeight.w800,
                        fontSize: 11.5,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      r.trackCode,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _searchTextColor,
                        fontFamily: 'Gilroy',
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        height: 1.08,
                        letterSpacing: -0.15,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: _searchSoftDecoration(),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _SearchStatusPill(text: statusText, color: statusColor),
                _SearchFactChip(
                  icon: Icons.update_rounded,
                  label: 'Обновлён ${df.format(r.updatedAt)}',
                ),
                _SearchFactChip(
                  icon: Icons.qr_code_2_rounded,
                  label: r.clientCode?.isNotEmpty == true
                      ? 'Код ${r.clientCode}'
                      : 'Без кода клиента',
                  color: context.brandPrimary,
                ),
              ],
            ),
          ),
          if (r.hasPendingQuestion) ...[
            const SizedBox(height: 10),
            _PendingRequestBanner(color: Colors.orange.shade700),
          ] else if (showBindButton) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.brandPrimary.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: context.brandPrimary.withValues(alpha: 0.10),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.verified_user_rounded,
                    color: context.brandPrimary,
                    size: 20,
                  ),
                  const SizedBox(width: 9),
                  const Expanded(
                    child: Text(
                      'Если это ваша посылка, отправьте запрос на привязку к текущему коду клиента.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontFamily: 'Gilroy',
                        fontSize: 12.5,
                        height: 1.18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (showBindButton) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => _openBindingSheet(context),
                style: FilledButton.styleFrom(
                  backgroundColor: context.brandPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  elevation: 0,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.link_rounded, size: 19),
                    SizedBox(width: 8),
                    Text(
                      'Запросить привязку',
                      style: TextStyle(
                        fontFamily: 'Gilroy',
                        fontSize: 14,
                        height: 17 / 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _openBindingSheet(BuildContext context) {
    final code = widget.activeClientCode;
    if (code == null) return;
    final auth = ref.read(authProvider);
    final clientId = auth.clientId;
    if (clientId == null) {
      _showStyledSnackBar(
        context,
        'Ошибка: не удалось определить клиента',
        isError: true,
      );
      return;
    }
    showBlurredModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RequestBindingSheet(
        result: widget.result,
        activeClientCode: code,
        clientId: clientId,
      ),
    );
  }
}

class _SearchStatusPill extends StatelessWidget {
  final String text;
  final Color color;

  const _SearchStatusPill({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontFamily: 'Gilroy',
          fontSize: 12,
          height: 1,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _SearchFactChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _SearchFactChip({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final accent = color ?? AppColors.textSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black.withValues(alpha: 0.035)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: accent),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: accent,
              fontFamily: 'Gilroy',
              fontSize: 11.5,
              height: 1,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingRequestBanner extends StatelessWidget {
  final Color color;

  const _PendingRequestBanner({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.13)),
      ),
      child: Row(
        children: [
          Icon(Icons.hourglass_top_rounded, size: 19, color: color),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              'Запрос на привязку уже отправлен. Склад проверит подтверждение и привяжет трек к вашему коду.',
              style: TextStyle(
                color: color,
                fontFamily: 'Gilroy',
                fontSize: 12.5,
                height: 1.18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet "Запрос привязки" — загрузка скрина логистики и отправка.
class _RequestBindingSheet extends ConsumerStatefulWidget {
  final SearchResult result;
  final String activeClientCode;
  final int clientId;

  const _RequestBindingSheet({
    required this.result,
    required this.activeClientCode,
    required this.clientId,
  });

  @override
  ConsumerState<_RequestBindingSheet> createState() =>
      _RequestBindingSheetState();
}

class _RequestBindingSheetState extends ConsumerState<_RequestBindingSheet> {
  Uint8List? _photoBytes;
  String? _photoFileName;
  String? _photoUrl;
  bool _uploading = false;
  bool _sending = false;

  Future<void> _pickPhoto() async {
    try {
      final picker = ImagePicker();
      final img = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (img == null) return;
      final bytes = await img.readAsBytes();
      if (!mounted) return;
      setState(() {
        _photoBytes = bytes;
        _photoFileName = img.name;
        _photoUrl = null; // сбрасываем прошлый upload
      });
      await _upload();
    } catch (e) {
      if (!mounted) return;
      _showStyledSnackBar(
        context,
        'Не удалось выбрать фото: $e',
        isError: true,
      );
    }
  }

  Future<void> _upload() async {
    final bytes = _photoBytes;
    final name = _photoFileName;
    if (bytes == null || name == null) return;
    setState(() => _uploading = true);
    final url = await ref
        .read(searchControllerProvider.notifier)
        .uploadBindingPhoto(bytes, name);
    if (!mounted) return;
    setState(() {
      _uploading = false;
      _photoUrl = url;
    });
    if (url == null) {
      _showStyledSnackBar(
        context,
        'Не удалось загрузить фото. Попробуйте ещё раз.',
        isError: true,
      );
    }
  }

  Future<void> _send() async {
    final url = _photoUrl;
    if (url == null) return;
    setState(() => _sending = true);
    final result = await ref
        .read(searchControllerProvider.notifier)
        .requestBinding(
          trackId: widget.result.id,
          trackNumber: widget.result.trackCode,
          clientCode: widget.activeClientCode,
          clientId: widget.clientId,
          clientCodeId: ref.read(activeClientCodeIdProvider),
          currentClientCode: widget.result.clientCode,
          photoUrl: url,
        );
    if (!mounted) return;
    setState(() => _sending = false);
    if (result.isSuccess) {
      Navigator.of(context).pop();
      _showStyledSnackBar(context, 'Запрос на привязку отправлен');
    } else {
      _showStyledSnackBar(
        context,
        trackBindingRequestErrorMessage(
          result.errorCode,
          isZh: Localizations.localeOf(context).languageCode == 'zh',
        ),
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final canSend = _photoUrl != null && !_uploading && !_sending;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: viewInsets),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.88,
            ),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 58,
                      height: 5,
                      margin: const EdgeInsets.only(top: 10, bottom: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0E0E0),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              gradient: context.brandGradient,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.22,
                                      ),
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.link_rounded,
                                    color: Colors.white,
                                    size: 27,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Запрос привязки',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontFamily: 'Gilroy',
                                          fontSize: 22,
                                          height: 1.04,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -0.25,
                                        ),
                                      ),
                                      const SizedBox(height: 7),
                                      Text(
                                        '${widget.result.trackCode} → ${widget.activeClientCode}',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Color(0xE6FFFFFF),
                                          fontFamily: 'Gilroy',
                                          fontSize: 13,
                                          height: 1.2,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: _searchSoftDecoration(),
                            child: const Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.verified_user_rounded,
                                  size: 20,
                                  color: AppColors.textSecondary,
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Приложите скрин логистики, ТТН, накладную или другое подтверждение, что этот трек относится к вашему заказу.',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontFamily: 'Gilroy',
                                      fontSize: 13,
                                      height: 1.25,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          if (_photoBytes == null)
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _pickPhoto,
                                borderRadius: BorderRadius.circular(24),
                                child: Container(
                                  height: 176,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: context.brandPrimary.withValues(
                                      alpha: 0.06,
                                    ),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: context.brandPrimary.withValues(
                                        alpha: 0.12,
                                      ),
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 56,
                                        height: 56,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.add_photo_alternate_outlined,
                                          size: 30,
                                          color: context.brandPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      const Text(
                                        'Выбрать фото',
                                        style: TextStyle(
                                          color: _searchTextColor,
                                          fontFamily: 'Gilroy',
                                          fontSize: 16,
                                          height: 1.1,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      const Text(
                                        'JPG, PNG, WEBP или HEIC',
                                        style: TextStyle(
                                          color: AppColors.textSecondary,
                                          fontFamily: 'Gilroy',
                                          fontSize: 12.5,
                                          height: 1,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: _searchSoftDecoration(),
                              child: Column(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(20),
                                    child: Container(
                                      height: 220,
                                      width: double.infinity,
                                      color: Colors.white,
                                      child: Image.memory(
                                        _photoBytes!,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      if (_uploading) ...[
                                        SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: context.brandPrimary,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        const Text(
                                          'Загружаем фото...',
                                          style: TextStyle(
                                            color: AppColors.textSecondary,
                                            fontFamily: 'Gilroy',
                                            fontSize: 12.5,
                                            height: 1,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ] else if (_photoUrl != null) ...[
                                        const Icon(
                                          Icons.check_circle_rounded,
                                          color: Color(0xFF2EAD57),
                                          size: 18,
                                        ),
                                        const SizedBox(width: 7),
                                        const Text(
                                          'Фото загружено',
                                          style: TextStyle(
                                            fontFamily: 'Gilroy',
                                            fontSize: 12.5,
                                            height: 1,
                                            color: Color(0xFF2EAD57),
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ] else ...[
                                        const Icon(
                                          Icons.error_outline_rounded,
                                          color: Color(0xFFE53935),
                                          size: 18,
                                        ),
                                        const SizedBox(width: 7),
                                        const Text(
                                          'Не удалось загрузить',
                                          style: TextStyle(
                                            fontFamily: 'Gilroy',
                                            fontSize: 12.5,
                                            height: 1,
                                            color: Color(0xFFE53935),
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                      const Spacer(),
                                      TextButton.icon(
                                        onPressed: _uploading || _sending
                                            ? null
                                            : _pickPhoto,
                                        icon: const Icon(
                                          Icons.refresh_rounded,
                                          size: 16,
                                        ),
                                        label: const Text(
                                          'Заменить',
                                          style: TextStyle(
                                            fontFamily: 'Gilroy',
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.fromLTRB(18, 12, 18, 12 + safeBottom),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        top: BorderSide(
                          color: Colors.black.withValues(alpha: 0.035),
                        ),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: canSend ? _send : null,
                            style: FilledButton.styleFrom(
                              backgroundColor: context.brandPrimary,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: context.brandPrimary
                                  .withValues(alpha: 0.35),
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              elevation: 0,
                            ),
                            child: _sending
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Отправить запрос',
                                    style: TextStyle(
                                      fontFamily: 'Gilroy',
                                      fontSize: 14,
                                      height: 17 / 14,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            onPressed: _sending
                                ? null
                                : () => Navigator.of(context).pop(),
                            child: const Text(
                              'Отмена',
                              style: TextStyle(
                                fontFamily: 'Gilroy',
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
