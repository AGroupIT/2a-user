import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:twoalogisticcabineuser/src/core/ui/app_toast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/ui/app_colors.dart';
import '../../../core/ui/app_input_decoration.dart';
import '../../../core/ui/app_layout.dart';
import '../../../core/ui/app_page_header.dart';
import '../../../core/ui/help_dialog.dart';
import '../../../core/ui/scroll_to_top_button.dart';
import '../../../core/ui/status_pill.dart';
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
    borderRadius: BorderRadius.circular(10),
    boxShadow: const [
      BoxShadow(color: Color(0x1A000000), offset: Offset(3, 4), blurRadius: 25),
    ],
  );
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

/// Экран поиска треков без кода клиента (nocode).
/// Открывается из нижнего меню "Ещё" → "Поиск по трек-номеру без кода".
class TrackSearchNoCodeScreen extends ConsumerStatefulWidget {
  const TrackSearchNoCodeScreen({super.key});

  @override
  ConsumerState<TrackSearchNoCodeScreen> createState() =>
      _TrackSearchNoCodeScreenState();
}

class _TrackSearchNoCodeScreenState
    extends ConsumerState<TrackSearchNoCodeScreen> {
  final _ctrl = TextEditingController();
  final _scrollController = ScrollController();
  bool _hasSearched = false;

  @override
  void dispose() {
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
            AppPageHeader(
              title: 'Поиск по трек-номеру',
              showBack: true,
              actions: [
                AppPageHeaderAction(
                  icon: Icons.help_outline_rounded,
                  tooltip: 'Справка',
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
                        Text(
                          '2) Нажмите «Запросить привязку», если нашли свой трек.',
                        ),
                        SizedBox(height: 8),
                        Text(
                          '3) Приложите скрин логистики (ТТН, накладная и т.п.). Без фото запрос отправить нельзя.',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Container(
              decoration: _searchCardDecoration(),
              padding: const EdgeInsets.all(14),
              child: TextField(
                controller: _ctrl,
                textInputAction: TextInputAction.search,
                style: const TextStyle(
                  color: _searchTextColor,
                  fontFamily: 'Gilroy',
                  fontSize: 15,
                  height: 18 / 15,
                  fontWeight: FontWeight.w600,
                ),
                decoration: appInputDecoration(
                  context,
                  prefixIcon: Icon(
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
                            _ctrl.selection = const TextSelection.collapsed(
                              offset: 0,
                            );
                            _ctrl.clear();
                          }),
                        )
                      : null,
                  hintText: 'Трек-номер (от 3 символов)',
                  hintStyle: const TextStyle(
                    fontFamily: 'Gilroy',
                    fontSize: 14,
                    height: 16 / 14,
                    color: Color(0x662F2F2F),
                    fontWeight: FontWeight.w500,
                  ),
                  fillColor: context.brandPrimary.withValues(alpha: 0.05),
                  borderColor: Colors.grey.shade200,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
                onChanged: (_) => setState(() => _hasSearched = false),
                onSubmitted: (_) => _run(),
              ),
            ),
            const SizedBox(height: 15),
            results.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator()),
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
                        'Поиск идёт только среди треков без привязки к коду клиента.',
                  );
                }
                if (q.length < 3) {
                  return const _SearchStateCard(
                    icon: Icons.info_outline_rounded,
                    title: 'Слишком короткий запрос',
                    message: 'Введите минимум 3 символа.',
                  );
                }
                if (!_hasSearched) {
                  return const _SearchStateCard(
                    icon: Icons.keyboard_return_rounded,
                    title: 'Нажмите Enter для поиска',
                    message: 'Или нажмите «Готово» на клавиатуре.',
                  );
                }
                if (items.isEmpty) {
                  return const _SearchStateCard(
                    icon: Icons.search_off_rounded,
                    title: 'Ничего не найдено',
                    message: 'Проверьте написание или попробуйте позже.',
                  );
                }
                return Column(
                  children: [
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
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 22, color: color),
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
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (message != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    message!,
                    style: const TextStyle(
                      color: _searchMutedTextColor,
                      fontFamily: 'Gilroy',
                      fontSize: 14,
                      height: 18 / 14,
                      fontWeight: FontWeight.w500,
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
    final locale = Localizations.localeOf(context).languageCode;
    final df = DateFormat('dd MMM yyyy', locale);
    final r = widget.result;
    final isZh = locale.toLowerCase().startsWith('zh');
    final activeClientCode = widget.activeClientCode;
    final showBindButton = r.showBindButton && activeClientCode != null;
    final statusColor = _parseColor(r.statusColor);
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
              Expanded(
                child: Text(
                  r.trackCode,
                  style: const TextStyle(
                    color: _searchTextColor,
                    fontFamily: 'Gilroy',
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    height: 20 / 17,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              StatusPill(text: statusText, color: statusColor),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.update_rounded,
                size: 16,
                color: _searchMutedTextColor,
              ),
              const SizedBox(width: 6),
              Text(
                'Дата изменения: ${df.format(r.updatedAt)}',
                style: const TextStyle(
                  color: _searchMutedTextColor,
                  fontFamily: 'Gilroy',
                  fontSize: 13.5,
                  height: 16 / 13.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          if (r.hasPendingQuestion) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
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
                      fontFamily: 'Gilroy',
                      fontSize: 12.5,
                      height: 15 / 12.5,
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
                onPressed: () => _openBindingSheet(context),
                style: FilledButton.styleFrom(
                  backgroundColor: context.brandPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Запросить привязку',
                  style: TextStyle(
                    fontFamily: 'Gilroy',
                    fontSize: 14,
                    height: 17 / 14,
                    fontWeight: FontWeight.w700,
                  ),
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
    showModalBottomSheet<void>(
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
    final ok = await ref
        .read(searchControllerProvider.notifier)
        .requestBinding(
          trackId: widget.result.id,
          trackNumber: widget.result.trackCode,
          clientCode: widget.activeClientCode,
          clientId: widget.clientId,
          clientCodeId: null,
          currentClientCode: widget.result.clientCode,
          photoUrl: url,
        );
    if (!mounted) return;
    setState(() => _sending = false);
    if (ok) {
      Navigator.of(context).pop();
      _showStyledSnackBar(context, 'Запрос на привязку отправлен');
    } else {
      _showStyledSnackBar(
        context,
        'Ошибка при отправке запроса',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final canSend = _photoUrl != null && !_uploading && !_sending;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.fromLTRB(16, 12, 16, 20 + safeBottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              'Запрос привязки трека',
              style: TextStyle(
                color: _searchTextColor,
                fontFamily: 'Gilroy',
                fontSize: 18,
                height: 22 / 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Трек ${widget.result.trackCode} → код ${widget.activeClientCode}',
              style: const TextStyle(
                color: _searchMutedTextColor,
                fontFamily: 'Gilroy',
                fontSize: 13,
                height: 16 / 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Приложите скрин логистики (ТТН, накладную, фото отправления — всё что подтверждает ваше право на этот трек).',
              style: TextStyle(
                color: _searchTextColor,
                fontFamily: 'Gilroy',
                fontSize: 13,
                height: 17 / 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 14),

            // Photo preview / picker
            if (_photoBytes == null)
              InkWell(
                onTap: _pickPhoto,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  height: 160,
                  decoration: BoxDecoration(
                    color: context.brandPrimary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: context.brandPrimary.withValues(alpha: 0.12),
                      style: BorderStyle.solid,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_photo_alternate_outlined,
                        size: 40,
                        color: context.brandPrimary,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Нажмите, чтобы выбрать фото',
                        style: TextStyle(
                          color: _searchTextColor,
                          fontFamily: 'Gilroy',
                          fontSize: 14,
                          height: 18 / 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(
                      _photoBytes!,
                      width: double.infinity,
                      height: 220,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (_uploading) ...[
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Загружаем...',
                          style: TextStyle(
                            color: _searchMutedTextColor,
                            fontFamily: 'Gilroy',
                            fontSize: 12,
                            height: 14 / 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ] else if (_photoUrl != null) ...[
                        const Icon(
                          Icons.check_circle_rounded,
                          color: Color(0xFF4CAF50),
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Фото загружено',
                          style: TextStyle(
                            fontFamily: 'Gilroy',
                            fontSize: 12,
                            height: 14 / 12,
                            color: Color(0xFF4CAF50),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ] else ...[
                        const Icon(
                          Icons.error_outline_rounded,
                          color: Color(0xFFE53935),
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Не удалось загрузить',
                          style: TextStyle(
                            fontFamily: 'Gilroy',
                            fontSize: 12,
                            height: 14 / 12,
                            color: Color(0xFFE53935),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _uploading || _sending ? null : _pickPhoto,
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text(
                          'Заменить',
                          style: TextStyle(
                            fontFamily: 'Gilroy',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            const SizedBox(height: 18),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: canSend ? _send : null,
                style: FilledButton.styleFrom(
                  backgroundColor: context.brandPrimary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: context.brandPrimary.withValues(
                    alpha: 0.35,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
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
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: _sending ? null : () => Navigator.of(context).pop(),
              child: const Text(
                'Отмена',
                style: TextStyle(
                  fontFamily: 'Gilroy',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
