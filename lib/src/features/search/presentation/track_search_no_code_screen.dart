import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/ui/app_colors.dart';
import '../../../core/ui/app_layout.dart';
import '../../../core/ui/empty_state.dart';
import '../../../core/ui/help_dialog.dart';
import '../../../core/ui/status_pill.dart';
import '../../../core/utils/error_utils.dart';
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
                isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
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

/// Экран поиска треков без кода клиента (nocode).
/// Открывается из нижнего меню "Ещё" → "Поиск по трек-номеру без кода".
class TrackSearchNoCodeScreen extends ConsumerStatefulWidget {
  const TrackSearchNoCodeScreen({super.key});

  @override
  ConsumerState<TrackSearchNoCodeScreen> createState() => _TrackSearchNoCodeScreenState();
}

class _TrackSearchNoCodeScreenState extends ConsumerState<TrackSearchNoCodeScreen> {
  final _ctrl = TextEditingController();
  bool _hasSearched = false;

  @override
  void dispose() {
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
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return ListView(
      padding: EdgeInsets.fromLTRB(16, topPad * 0.7 + 16, 16, 24 + bottomPad),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Поиск по трек-номеру без кода',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
            IconButton(
              tooltip: 'Справка',
              onPressed: () => showHelpDialog(
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
                      '3) Приложите скрин логистики (ТТН, накладная и т.п.). Без фото запрос отправить нельзя.',
                    ),
                  ],
                ),
              ),
              icon: Icon(Icons.help_outline_rounded, color: context.brandPrimary),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(color: Color(0x14000000), blurRadius: 24, offset: Offset(0, 10)),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Builder(
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
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12.5)),
                clipBehavior: Clip.antiAlias,
                child: TextField(
                  controller: _ctrl,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded, color: ctx.brandPrimary, size: 20),
                    suffixIcon: _ctrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, color: Color(0xFF999999), size: 20),
                            onPressed: () => setState(() {
                              _ctrl.selection = const TextSelection.collapsed(offset: 0);
                              _ctrl.clear();
                            }),
                          )
                        : null,
                    hintText: 'Трек-номер (от 3 символов)',
                    hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF999999), fontWeight: FontWeight.w500),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: (_) => setState(() => _hasSearched = false),
                  onSubmitted: (_) => _run(),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        results.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) {
            final info = ErrorUtils.getErrorInfo(e);
            return EmptyState(icon: info.icon, title: info.title, message: info.message);
          },
          data: (items) {
            final q = _ctrl.text.trim();
            if (q.isEmpty) {
              return const EmptyState(
                icon: Icons.search_rounded,
                title: 'Введите трек-номер',
                message: 'Поиск идёт только среди треков без привязки к коду клиента.',
              );
            }
            if (q.length < 3) {
              return const EmptyState(
                icon: Icons.info_outline_rounded,
                title: 'Слишком короткий запрос',
                message: 'Введите минимум 3 символа.',
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
            return Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  _NoCodeResultTile(result: items[i], activeClientCode: activeClientCode),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _NoCodeResultTile extends ConsumerStatefulWidget {
  final SearchResult result;
  final String? activeClientCode;

  const _NoCodeResultTile({required this.result, required this.activeClientCode});

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
    final statusText = (isZh && (r.statusZh?.isNotEmpty ?? false)) ? r.statusZh! : r.status;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x12000000), blurRadius: 18, offset: Offset(0, 8))],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(r.trackCode, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              ),
              StatusPill(text: statusText, color: statusColor),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Дата изменения: ${df.format(r.updatedAt)}',
            style: const TextStyle(color: Color(0xFF666666), fontSize: 13.5),
          ),
          if (r.hasPendingQuestion) ...[
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
                  Icon(Icons.hourglass_top_rounded, size: 16, color: Colors.orange),
                  SizedBox(width: 6),
                  Text(
                    'Запрос на привязку отправлен',
                    style: TextStyle(color: Colors.orange, fontSize: 12.5, fontWeight: FontWeight.w600),
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
                child: const Text('Запросить привязку'),
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
      _showStyledSnackBar(context, 'Ошибка: не удалось определить клиента', isError: true);
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
  ConsumerState<_RequestBindingSheet> createState() => _RequestBindingSheetState();
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
      _showStyledSnackBar(context, 'Не удалось выбрать фото: $e', isError: true);
    }
  }

  Future<void> _upload() async {
    final bytes = _photoBytes;
    final name = _photoFileName;
    if (bytes == null || name == null) return;
    setState(() => _uploading = true);
    final url = await ref.read(searchControllerProvider.notifier).uploadBindingPhoto(bytes, name);
    if (!mounted) return;
    setState(() {
      _uploading = false;
      _photoUrl = url;
    });
    if (url == null) {
      _showStyledSnackBar(context, 'Не удалось загрузить фото. Попробуйте ещё раз.', isError: true);
    }
  }

  Future<void> _send() async {
    final url = _photoUrl;
    if (url == null) return;
    setState(() => _sending = true);
    final ok = await ref.read(searchControllerProvider.notifier).requestBinding(
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
      _showStyledSnackBar(context, 'Ошибка при отправке запроса', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final canSend = _photoUrl != null && !_uploading && !_sending;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
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
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Трек ${widget.result.trackCode} → код ${widget.activeClientCode}',
              style: const TextStyle(fontSize: 13, color: Color(0xFF666666)),
            ),
            const SizedBox(height: 16),
            const Text(
              'Приложите скрин логистики (ТТН, накладную, фото отправления — всё что подтверждает ваше право на этот трек).',
              style: TextStyle(fontSize: 13, color: Color(0xFF444444), height: 1.4),
            ),
            const SizedBox(height: 14),

            // Photo preview / picker
            if (_photoBytes == null)
              InkWell(
                onTap: _pickPhoto,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  height: 160,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F7F8),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE0E0E0), style: BorderStyle.solid),
                  ),
                  alignment: Alignment.center,
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate_outlined, size: 40, color: Color(0xFF999999)),
                      SizedBox(height: 8),
                      Text(
                        'Нажмите, чтобы выбрать фото',
                        style: TextStyle(color: Color(0xFF666666), fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              )
            else
              Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.memory(_photoBytes!, width: double.infinity, height: 220, fit: BoxFit.cover),
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
                        const Text('Загружаем...', style: TextStyle(fontSize: 12, color: Color(0xFF666666))),
                      ] else if (_photoUrl != null) ...[
                        const Icon(Icons.check_circle_rounded, color: Color(0xFF4CAF50), size: 16),
                        const SizedBox(width: 6),
                        const Text(
                          'Фото загружено',
                          style: TextStyle(fontSize: 12, color: Color(0xFF4CAF50), fontWeight: FontWeight.w600),
                        ),
                      ] else ...[
                        const Icon(Icons.error_outline_rounded, color: Color(0xFFE53935), size: 16),
                        const SizedBox(width: 6),
                        const Text(
                          'Не удалось загрузить',
                          style: TextStyle(fontSize: 12, color: Color(0xFFE53935), fontWeight: FontWeight.w600),
                        ),
                      ],
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _uploading || _sending ? null : _pickPhoto,
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Заменить'),
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
                child: _sending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Отправить запрос'),
              ),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: _sending ? null : () => Navigator.of(context).pop(),
              child: const Text('Отмена'),
            ),
          ],
        ),
      ),
    );
  }
}
