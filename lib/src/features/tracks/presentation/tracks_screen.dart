// ignore_for_file: deprecated_member_use
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import '../../../core/network/api_config.dart';
import '../../../core/ui/sheet_handle.dart';
import '../../../core/ui/app_colors.dart';

import '../../../core/ui/app_layout.dart';
import '../../../core/ui/scroll_to_top_button.dart';
import '../../../core/ui/empty_state.dart';
import '../../../core/ui/status_pill.dart';
import '../../../core/utils/error_utils.dart';
import '../../../core/utils/locale_text.dart';
import '../../clients/application/client_codes_controller.dart';
import '../../auth/data/auth_provider.dart';
import '../data/tracks_provider.dart';
import '../data/assemblies_provider.dart';
import '../domain/track_item.dart';
import '../../assemblies/domain/box.dart';
import '../../photos/presentation/photo_viewer_screen.dart';
import '../../photos/domain/photo_item.dart';
import '../../../core/ui/tutorial_card.dart';
import 'add_tracks_dialog.dart';

// Alias для authStateProvider
final authStateProvider = authProvider;

/// Парсит HEX цвет из строки (например "#FF5733" или "FF5733")
Color? parseHexColor(String? hexString) {
  if (hexString == null || hexString.isEmpty) return null;
  try {
    String hex = hexString.replaceAll('#', '');
    if (hex.length == 6) {
      hex = 'FF$hex'; // Добавляем альфа-канал
    }
    return Color(int.parse(hex, radix: 16));
  } catch (_) {
    return null;
  }
}

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

/// Форматирует число, убирая лишние нули: 3.5 → "3.5", 5.0 → "5", 5.70 → "5.7"
String _formatDecimal(double value) {
  if (value == value.truncateToDouble()) {
    return value.toInt().toString();
  }
  final s = value.toStringAsFixed(2);
  // Убираем trailing zeros после точки
  if (s.endsWith('0')) return s.substring(0, s.length - 1);
  return s;
}

class TracksScreen extends ConsumerStatefulWidget {
  const TracksScreen({super.key});

  @override
  ConsumerState<TracksScreen> createState() => _TracksScreenState();
}

class _TracksScreenState extends ConsumerState<TracksScreen> {
  final ScrollController _scrollController = ScrollController();

  // Local tracking for photo report requests and their notes
  final Set<String> _requestedPhotoReports = <String>{};
  final Map<String, String> _photoRequestNotes = <String, String>{};
  final Map<String, DateTime> _photoRequestCreatedAt = <String, DateTime>{};
  final Map<String, DateTime> _photoRequestUpdatedAt = <String, DateTime>{};

  // Фильтры - теперь используем код статуса из БД
  String? _statusCode; // null = Все
  ViewMode _viewMode = ViewMode.all;
  String _query = '';
  Timer? _searchDebounce;

  // Текущий notifier для отслеживания изменений состояния
  PaginatedTracksNotifier? _currentNotifier;

  final GlobalKey _tracksListKey = GlobalKey();
  final GlobalKey _fabKey = GlobalKey();
  final GlobalKey _filtersKey = GlobalKey();
  final GlobalKey _trackDetailKey = GlobalKey();
  final GlobalKey _actionsRowKey = GlobalKey();
  final GlobalKey _assemblyKey = GlobalKey();

  // Выбранные треки
  final Set<String> _selectedTracks = <String>{};
  String? _selectedStatus;
  final Set<String> _selectableStatuses = const {
    'На складе',
    'Отправлен',
    'Прибыл на терминал',
    'Сформирован к выдаче',
  };

  // Return request local state
  final Set<String> _returnRequestedTracks = <String>{};

  // Local data stores
  final Map<String, String> _askedQuestions = <String, String>{};
  final Map<String, String> _questionStatus =
      <String, String>{}; // Новый, В работе, Завершен
  final Map<String, String> _questionAnswers = <String, String>{};
  final Map<String, DateTime> _questionCreatedAt = <String, DateTime>{};
  final Map<String, DateTime> _questionUpdatedAt = <String, DateTime>{};
  final Map<String, String> _overrideComments = <String, String>{};
  final Map<String, _ProductInfo> _productInfos = <String, _ProductInfo>{};
  final Map<String, String> _groupComments = <String, String>{};
  final Map<String, String> _groupQuestions = <String, String>{};
  final Map<String, DateTime> _groupQuestionCreatedAt = <String, DateTime>{};
  final Map<String, DateTime> _groupQuestionUpdatedAt = <String, DateTime>{};

  bool _isRefreshing = false;
  DateTime? _lastLoadMoreTime;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchDebounce?.cancel();
    _currentNotifier?.removeListener(_onNotifierStateChanged);
    super.dispose();
  }

  void _onNotifierStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _updateNotifierListener(PaginatedTracksNotifier newNotifier) {
    if (_currentNotifier != newNotifier) {
      _currentNotifier?.removeListener(_onNotifierStateChanged);
      _currentNotifier = newNotifier;
      _currentNotifier?.addListener(_onNotifierStateChanged);
    }
  }

  /// Метод для обновления списка треков
  void _refreshTracks() {
    final clientCode = ref.read(activeClientCodeProvider);
    if (clientCode != null) {
      // Обновляем с актуальными фильтрами из UI
      final filterParams = _getFilterParams(clientCode);
      ref.read(paginatedTracksProvider(clientCode)).updateFilters(filterParams);
    }
  }

  /// Очищает оптимистичные Map-записи для треков у которых сервер
  /// уже подтвердил данные. Вызывается после pull-to-refresh.
  void _syncMapsWithServerData(List<TrackItem> serverTracks) {
    bool changed = false;
    for (final track in serverTracks) {
      // Если сервер вернул photo request — оптимистика больше не нужна
      if (track.photoRequests.isNotEmpty &&
          _requestedPhotoReports.contains(track.code)) {
        _requestedPhotoReports.remove(track.code);
        _photoRequestNotes.remove(track.code);
        _photoRequestCreatedAt.remove(track.code);
        _photoRequestUpdatedAt.remove(track.code);
        changed = true;
      }
      // Если сервер вернул вопрос — оптимистика больше не нужна
      if (track.questions.isNotEmpty &&
          _askedQuestions.containsKey(track.code)) {
        _askedQuestions.remove(track.code);
        _questionStatus.remove(track.code);
        _questionAnswers.remove(track.code);
        _questionCreatedAt.remove(track.code);
        _questionUpdatedAt.remove(track.code);
        changed = true;
      }
      // Если сервер вернул productInfo — оптимистика больше не нужна
      if (track.productInfo != null && _productInfos.containsKey(track.code)) {
        _productInfos.remove(track.code);
        changed = true;
      }
    }
    if (changed && mounted) setState(() {});
  }

  Future<bool> _confirmAction(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    final res = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SheetHandle(),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(sheetContext).pop(false),
                        child: const Text('Нет'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.of(sheetContext).pop(true),
                        child: const Text('Да'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    return res ?? false;
  }

  Future<void> _showPhotoRequestSheet(
    BuildContext context,
    TrackItem track,
  ) async {
    final controller = TextEditingController();
    final result = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        final viewInsetsBottom = MediaQuery.viewInsetsOf(sheetContext).bottom;
        return SafeArea(
          child: AnimatedPadding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + viewInsetsBottom),
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SheetHandle(),
                  const SizedBox(height: 12),
                  Text(
                    'Запрос фотоотчёта',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.amber.shade700, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Фотоотчёт может быть платным. Ознакомьтесь с тарифами.',
                            style: TextStyle(fontSize: 12, color: Colors.amber.shade800),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [context.brandPrimary, context.brandSecondary],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: const BorderRadius.all(Radius.circular(14)),
                    ),
                    padding: const EdgeInsets.all(1.5),
                    child: Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.all(Radius.circular(12.5)),
                      ),
                      child: TextField(
                        controller: controller,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          hintText: 'Пожелание для сборщиков…',
                          hintStyle: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF999999),
                            fontWeight: FontWeight.w500,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: () => Navigator.of(sheetContext).pop(true),
                    child: const Text('Запросить фотоотчёт'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (result == true) {
      final now = DateTime.now();
      final wish = controller.text.trim();

      // Получаем данные для API
      final auth = ref.read(authStateProvider);
      final clientId = auth.clientId;
      // Берём clientCodeId из самого трека (правильный код), fallback на первый код клиента
      int? clientCodeId = track.clientCodeId;
      if (clientCodeId == null) {
        final codes = auth.clientData?['codes'] as List<dynamic>?;
        if (codes != null && codes.isNotEmpty) {
          final firstCode = codes.first;
          if (firstCode is Map<String, dynamic>) {
            clientCodeId = firstCode['id'] as int?;
          }
        }
      }

      if (track.id == null || clientId == null) {
        if (!context.mounted) return;
        _showStyledSnackBar(
          context,
          'Ошибка: нет данных для запроса',
          isError: true,
        );
        return;
      }

      // Оптимистичное обновление UI
      setState(() {
        _requestedPhotoReports.add(track.code);
        _photoRequestNotes[track.code] = wish;
        _photoRequestCreatedAt[track.code] = now;
        _photoRequestUpdatedAt[track.code] = now;
      });

      // Отправляем запрос в API
      final apiService = ref.read(tracksApiServiceProvider);
      if (track.id == null) return;
      final success = await apiService.createPhotoRequest(
        clientId: clientId,
        clientCodeId: clientCodeId,
        trackId: track.id!,
        trackNumber: track.code,
        wish: wish.isNotEmpty ? wish : null,
      );

      if (success) {
        if (!context.mounted) return;
        _showStyledSnackBar(context, 'Запрос фотоотчёта отправлен');
        // Обновляем список треков
        _refreshTracks();
      } else {
        // Откатываем изменения
        if (!context.mounted) return;
        setState(() {
          _requestedPhotoReports.remove(track.code);
          _photoRequestNotes.remove(track.code);
          _photoRequestCreatedAt.remove(track.code);
          _photoRequestUpdatedAt.remove(track.code);
        });
        _showStyledSnackBar(context, 'Ошибка отправки запроса', isError: true);
      }
    }
  }

  Future<void> _showAskQuestionSheet(
    BuildContext context,
    TrackItem track,
  ) async {
    final controller = TextEditingController(
      text: _askedQuestions[track.code] ?? '',
    );
    final result = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        final viewInsetsBottom = MediaQuery.viewInsetsOf(sheetContext).bottom;
        return SafeArea(
          child: AnimatedPadding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + viewInsetsBottom),
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SheetHandle(),
                  const SizedBox(height: 12),
                  Text(
                    'Задать вопрос',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Опишите ваш вопрос по треку',
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.amber.shade700, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Ответ на вопрос может быть только текстовым',
                            style: TextStyle(fontSize: 12, color: Colors.amber.shade800),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
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
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12.5),
                      ),
                      child: TextField(
                        controller: controller,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText: 'Опишите ваш вопрос по треку…',
                          hintStyle: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF999999),
                            fontWeight: FontWeight.w500,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: () => Navigator.of(sheetContext).pop(true),
                    child: const Text('Задать вопрос'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (result == true) {
      if (!context.mounted) return;
      final now = DateTime.now();
      final question = controller.text.trim();

      if (question.isEmpty) {
        _showStyledSnackBar(context, 'Введите вопрос', isError: true);
        return;
      }

      // Получаем данные для API
      final auth = ref.read(authStateProvider);
      final clientId = auth.clientId;
      // Берём clientCodeId из самого трека (правильный код), fallback на первый код клиента
      int? clientCodeId = track.clientCodeId;
      if (clientCodeId == null) {
        final codes = auth.clientData?['codes'] as List<dynamic>?;
        if (codes != null && codes.isNotEmpty) {
          final firstCode = codes.first;
          if (firstCode is Map<String, dynamic>) {
            clientCodeId = firstCode['id'] as int?;
          }
        }
      }

      if (track.id == null || clientId == null) {
        _showStyledSnackBar(
          context,
          'Ошибка: нет данных для запроса',
          isError: true,
        );
        return;
      }

      // Оптимистичное обновление UI
      final wasEmpty = (_askedQuestions[track.code] ?? '').trim().isEmpty;
      setState(() {
        _askedQuestions[track.code] = question;
        if (wasEmpty) {
          _questionCreatedAt[track.code] = now;
        }
        _questionUpdatedAt[track.code] = now;
      });

      // Отправляем запрос в API
      final apiService = ref.read(tracksApiServiceProvider);
      if (track.id == null) return;
      final success = await apiService.createTrackQuestion(
        clientId: clientId,
        clientCodeId: clientCodeId,
        trackId: track.id!,
        trackNumber: track.code,
        question: question,
      );

      if (success) {
        if (!context.mounted) return;
        _showStyledSnackBar(context, 'Вопрос отправлен');
        // Обновляем список треков
        _refreshTracks();
      } else {
        // Откатываем изменения при ошибке
        if (!context.mounted) return;
        setState(() {
          if (wasEmpty) {
            _askedQuestions.remove(track.code);
            _questionCreatedAt.remove(track.code);
          }
          _questionUpdatedAt.remove(track.code);
        });
        _showStyledSnackBar(context, 'Ошибка отправки вопроса', isError: true);
      }
    }
  }

  Future<void> _cancelPhotoRequest(TrackItem track) async {
    final confirmed = await _confirmAction(
      context,
      title: 'Отменить запрос фотоотчёта?',
      message: 'Запрос фотоотчёта будет отменён.',
    );

    if (!confirmed) return;
    if (!mounted) return;

    // Если есть активный запрос из API
    final activeRequest = track.activePhotoRequest;
    if (activeRequest != null) {
      final apiService = ref.read(tracksApiServiceProvider);
      final success = await apiService.cancelPhotoRequest(activeRequest.id);

      if (success) {
        if (!mounted) return;
        setState(() {
          _requestedPhotoReports.remove(track.code);
          _photoRequestNotes.remove(track.code);
          _photoRequestCreatedAt.remove(track.code);
          _photoRequestUpdatedAt.remove(track.code);
        });
        _showStyledSnackBar(context, 'Запрос фотоотчёта отменён');
      } else {
        if (!mounted) return;
        _showStyledSnackBar(context, 'Ошибка отмены запроса', isError: true);
      }
    } else {
      if (!mounted) return;
      setState(() {
        _requestedPhotoReports.remove(track.code);
        _photoRequestNotes.remove(track.code);
        _photoRequestCreatedAt.remove(track.code);
        _photoRequestUpdatedAt.remove(track.code);
      });
      _showStyledSnackBar(context, 'Запрос фотоотчёта отменён');
    }
  }

  Future<void> _showEditPhotoWishSheet(
    BuildContext context,
    TrackItem track,
  ) async {
    final activeRequest = track.activePhotoRequest;
    if (activeRequest == null) return;

    final currentWish = activeRequest.wishes ?? '';
    final controller = TextEditingController(text: currentWish);
    final result = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        final viewInsetsBottom = MediaQuery.viewInsetsOf(sheetContext).bottom;
        return SafeArea(
          child: AnimatedPadding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + viewInsetsBottom),
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SheetHandle(),
                  const SizedBox(height: 12),
                  Text(
                    'Пожелание к фотоотчёту',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [context.brandPrimary, context.brandSecondary],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: const BorderRadius.all(Radius.circular(14)),
                    ),
                    padding: const EdgeInsets.all(1.5),
                    child: Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.all(Radius.circular(12.5)),
                      ),
                      child: TextField(
                        controller: controller,
                        maxLines: 4,
                        autofocus: true,
                        decoration: const InputDecoration(
                          hintText: 'Пожелание для сборщиков…',
                          hintStyle: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF999999),
                            fontWeight: FontWeight.w500,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: () => Navigator.of(sheetContext).pop(true),
                    child: const Text('Сохранить'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (result == true) {
      final wish = controller.text.trim();
      final apiService = ref.read(tracksApiServiceProvider);
      final success = await apiService.updatePhotoWish(activeRequest.id, wish);

      if (!context.mounted) return;
      if (success) {
        setState(() {
          _photoRequestNotes[track.code] = wish;
        });
        _refreshTracks();
        _showStyledSnackBar(context, 'Пожелание обновлено');
      } else {
        _showStyledSnackBar(context, 'Ошибка обновления пожелания', isError: true);
      }
    }
  }

  Future<void> _cancelQuestion(TrackItem track) async {
    final confirmed = await _confirmAction(
      context,
      title: 'Отменить вопрос?',
      message: 'Вопрос будет отменён.',
    );

    if (!confirmed) return;
    if (!mounted) return;

    // Если есть активный вопрос из API
    final activeQuestion = track.activeQuestion;
    if (activeQuestion != null) {
      final apiService = ref.read(tracksApiServiceProvider);
      final success = await apiService.cancelTrackQuestion(activeQuestion.id);

      if (success) {
        if (!mounted) return;
        setState(() {
          _askedQuestions.remove(track.code);
          _questionStatus.remove(track.code);
          _questionAnswers.remove(track.code);
          _questionCreatedAt.remove(track.code);
          _questionUpdatedAt.remove(track.code);
        });
        _showStyledSnackBar(context, 'Вопрос отменён');
      } else {
        if (!mounted) return;
        _showStyledSnackBar(context, 'Ошибка отмены вопроса', isError: true);
      }
    } else {
      if (!mounted) return;
      // Удаляем из локального state
      setState(() {
        _askedQuestions.remove(track.code);
        _questionStatus.remove(track.code);
        _questionAnswers.remove(track.code);
        _questionCreatedAt.remove(track.code);
        _questionUpdatedAt.remove(track.code);
      });
      _showStyledSnackBar(context, 'Вопрос отменён');
    }
  }

  Future<void> _deleteTrack(TrackItem track) async {
    final confirmed = await _confirmAction(
      context,
      title: 'Удалить трек?',
      message: 'Трек ${track.code} будет удалён. Это действие нельзя отменить.',
    );
    if (!confirmed || !mounted) return;

    final apiService = ref.read(tracksApiServiceProvider);
    final trackId = track.id;
    if (trackId == null) return;

    final success = await apiService.deleteTrack(trackId);
    if (!mounted) return;

    if (success) {
      // Оптимистично убираем из UI сразу, не ждём перезагрузки
      final clientCode = ref.read(activeClientCodeProvider);
      if (clientCode != null) {
        ref.read(paginatedTracksProvider(clientCode)).removeTrackOptimistically(trackId);
      }
      _refreshTracks();
      _showStyledSnackBar(context, 'Трек ${track.code} удалён');
    } else {
      _showStyledSnackBar(context, 'Ошибка удаления трека', isError: true);
    }
  }

  Future<void> _showReturnSheet(BuildContext context, TrackItem track) async {
    final returnCodeController = TextEditingController();
    final result = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        final viewInsetsBottom = MediaQuery.viewInsetsOf(sheetContext).bottom;
        return SafeArea(
          child: AnimatedPadding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + viewInsetsBottom),
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SheetHandle(),
                  const SizedBox(height: 12),
                  Text(
                    'Оформить возврат',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Time info banner
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFFCC80), width: 1),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.schedule_rounded, size: 18, color: Color(0xFFE65100)),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Выберите время возврата с 13:00 до 15:00 по Китаю',
                            style: TextStyle(fontSize: 13, color: Color(0xFFE65100), fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Код возврата',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
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
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12.5),
                      ),
                      child: TextField(
                        controller: returnCodeController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          hintText: 'Введите код возврата…',
                          hintStyle: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF999999),
                            fontWeight: FontWeight.w500,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Код возврата можно найти в приложении продавца (Taobao/1688)',
                    style: TextStyle(fontSize: 12, color: Colors.black45),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => Navigator.of(sheetContext).pop(true),
                    child: const Text('Оформить возврат'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (result != true || !context.mounted) return;

    final returnCode = returnCodeController.text.trim();
    if (returnCode.isEmpty) {
      _showStyledSnackBar(context, 'Введите код возврата', isError: true);
      return;
    }

    setState(() => _returnRequestedTracks.add(track.code));

    final apiService = ref.read(tracksApiServiceProvider);
    final trackId = track.id;
    if (trackId == null) return;

    final success = await apiService.createTrackReturn(
      trackId: trackId,
      returnCode: returnCode,
    );

    if (!context.mounted) return;

    if (success) {
      _refreshTracks();
      _showStyledSnackBar(context, 'Возврат оформлен. Склад получит уведомление.');
    } else {
      setState(() => _returnRequestedTracks.remove(track.code));
      _showStyledSnackBar(context, 'Ошибка оформления возврата', isError: true);
    }
  }

  Future<void> _showCommentSheet(BuildContext context, TrackItem track) async {
    final existing = _overrideComments[track.code] ?? track.comment ?? '';
    final controller = TextEditingController(text: existing);
    final result = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        final viewInsetsBottom = MediaQuery.viewInsetsOf(sheetContext).bottom;
        return SafeArea(
          child: AnimatedPadding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + viewInsetsBottom),
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SheetHandle(),
                  const SizedBox(height: 12),
                  Text(
                    'Ваша заметка',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
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
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12.5),
                      ),
                      child: TextField(
                        controller: controller,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          hintText: 'Добавьте или отредактируйте заметку…',
                          hintStyle: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF999999),
                            fontWeight: FontWeight.w500,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: () => Navigator.of(sheetContext).pop(true),
                    child: const Text('Сохранить заметку'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (result == true) {
      final comment = controller.text.trim();
      setState(() => _overrideComments[track.code] = comment);

      // Сохраняем в API если есть trackId
      if (track.id != null) {
        final apiService = ref.read(tracksApiServiceProvider);
        final success = await apiService.addTrackComment(
          trackId: track.id!,
          comment: comment,
        );

        if (success) {
          if (!context.mounted) return;
          _showStyledSnackBar(context, 'Заметка сохранена');
        } else {
          if (!context.mounted) return;
          _showStyledSnackBar(
            context,
            'Заметка сохранена локально',
            isError: false,
          );
        }
      } else {
        if (!context.mounted) return;
        _showStyledSnackBar(context, 'Заметка сохранена');
      }
    }
  }

  Future<void> _showGroupCommentSheet(
    BuildContext context,
    TrackAssembly assembly,
  ) async {
    // Используем комментарий из локального кэша или из данных сборки
    final existing =
        _groupComments[assembly.id.toString()] ?? assembly.comment ?? '';
    final controller = TextEditingController(text: existing);
    final result = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        final viewInsetsBottom = MediaQuery.viewInsetsOf(sheetContext).bottom;
        return SafeArea(
          child: AnimatedPadding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + viewInsetsBottom),
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SheetHandle(),
                  const SizedBox(height: 12),
                  Text(
                    'Заметка по сборке',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
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
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12.5),
                      ),
                      child: TextField(
                        controller: controller,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          hintText:
                              'Добавьте или отредактируйте заметку по сборке…',
                          hintStyle: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF999999),
                            fontWeight: FontWeight.w500,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: () => Navigator.of(sheetContext).pop(true),
                    child: const Text('Сохранить заметку'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (result == true) {
      final comment = controller.text.trim();
      setState(() => _groupComments[assembly.id.toString()] = comment);

      // Сохраняем в API
      final apiService = ref.read(assembliesApiServiceProvider);
      final success = await apiService.addAssemblyComment(
        assemblyId: assembly.id,
        comment: comment,
      );

      if (success) {
        if (!context.mounted) return;
        _showStyledSnackBar(context, 'Заметка по сборке сохранена');
      } else {
        if (!context.mounted) return;
        _showStyledSnackBar(
          context,
          'Ошибка сохранения заметки',
          isError: true,
        );
      }
    }
  }

  Future<void> _showGroupQuestionSheet(
    BuildContext context,
    TrackAssembly assembly,
  ) async {
    final controller = TextEditingController(
      text: _groupQuestions[assembly.id.toString()] ?? '',
    );
    final result = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            top: 12,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [const SheetHandle()],
              ),
              const SizedBox(height: 12),
              Text(
                'Задать вопрос по сборке',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                'Введите ваш вопрос',
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [context.brandPrimary, context.brandSecondary],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: const BorderRadius.all(Radius.circular(14)),
                ),
                padding: const EdgeInsets.all(1.5),
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.all(Radius.circular(12.5)),
                  ),
                  child: TextField(
                    controller: controller,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Опишите ваш вопрос по сборке…',
                      hintStyle: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF999999),
                        fontWeight: FontWeight.w500,
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
              const SizedBox(height: 14),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Задать вопрос'),
              ),
            ],
          ),
        );
      },
    );
    if (result == true) {
      if (!context.mounted) return;
      final now = DateTime.now();
      setState(() {
        final wasEmpty = (_groupQuestions[assembly.id.toString()] ?? '')
            .trim()
            .isEmpty;
        _groupQuestions[assembly.id.toString()] = controller.text.trim();
        if (wasEmpty) {
          _groupQuestionCreatedAt[assembly.id.toString()] = now;
        }
        _groupQuestionUpdatedAt[assembly.id.toString()] = now;
      });
      _showStyledSnackBar(context, 'Вопрос по сборке отправлен');
    }
  }

  Future<void> _showDeliverySheet(
    BuildContext context,
    TrackAssembly assembly,
  ) async {
    // Текущий метод доставки
    String? selectedMethod = assembly.deliveryMethod;
    final nameController = TextEditingController(text: assembly.recipientName ?? '');
    final cityController = TextEditingController(text: assembly.recipientCity ?? '');
    final transportCompanyController = TextEditingController(text: assembly.transportCompanyName ?? '');

    // Маска для телефона: +7 (999) 123-45-67
    final phoneMask = MaskTextInputFormatter(
      mask: '+# (###) ###-##-##',
      filter: {'#': RegExp(r'[0-9]')},
      type: MaskAutoCompletionType.lazy,
    );

    // Если уже есть сохраненный телефон, форматируем его
    final phoneController = TextEditingController();
    if (assembly.recipientPhone != null && assembly.recipientPhone!.isNotEmpty) {
      // Убираем все нецифровые символы и форматируем через маску
      final digits = assembly.recipientPhone!.replaceAll(RegExp(r'[^\d]'), '');
      phoneMask.formatEditUpdate(
        const TextEditingValue(text: ''),
        TextEditingValue(text: digits),
      );
      phoneController.text = phoneMask.getMaskedText();
    }

    final result = await showModalBottomSheet<Map<String, dynamic>?>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (sheetContext, scrollController) {
          return StatefulBuilder(
            builder: (sheetContext, setSheetState) {
              return Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  0,
                  16,
                  MediaQuery.viewInsetsOf(sheetContext).bottom + 16,
                ),
                child: Column(
                  children: [
                    const SheetHandle(),
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.only(top: 12),
                        children: [
                          Text(
                            'Способ получения',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 16),
                          // Самовывоз
                          _DeliveryOptionCard(
                            title: 'Самовывоз',
                            subtitle: 'Забрать на терминале',
                            icon: Icons.store_outlined,
                            isSelected: selectedMethod == 'self_pickup',
                            onTap: () {
                              setSheetState(() => selectedMethod = 'self_pickup');
                            },
                          ),
                          if (selectedMethod == 'self_pickup') ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF3CD),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFFFE69C)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.warning_amber_rounded,
                                    color: Color(0xFF856404),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Доступ на терминал платный. Для уточнения условий свяжитесь с поддержкой.',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: const Color(0xFF856404),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          // Транспортная компания
                          _DeliveryOptionCard(
                            title: 'Транспортная компания',
                            subtitle: 'Доставка до двери или пункта выдачи',
                            icon: Icons.local_shipping_outlined,
                            isSelected: selectedMethod == 'transport_company',
                            onTap: () {
                              setSheetState(() => selectedMethod = 'transport_company');
                            },
                          ),
                          if (selectedMethod == 'transport_company') ...[
                            const SizedBox(height: 16),
                            Text(
                              'Транспортная компания',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _outlinedInput(
                              context,
                              transportCompanyController,
                              hint: 'Название ТК (СДЭК, ПЭК, и т.д.)',
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Данные получателя',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _outlinedInput(
                              context,
                              nameController,
                              hint: 'ФИО получателя',
                            ),
                            const SizedBox(height: 10),
                            _outlinedInput(
                              context,
                              phoneController,
                              hint: '+7 (999) 123-45-67',
                              keyboardType: TextInputType.number,
                              inputFormatters: [phoneMask],
                            ),
                            const SizedBox(height: 10),
                            _outlinedInput(
                              context,
                              cityController,
                              hint: 'Город',
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: selectedMethod == null
                            ? null
                            : () {
                                // Валидация для ТК
                                if (selectedMethod == 'transport_company') {
                                  if (nameController.text.trim().isEmpty) {
                                    _showStyledSnackBar(
                                      sheetContext,
                                      'Укажите ФИО получателя',
                                      isError: true,
                                    );
                                    return;
                                  }
                                  // Проверяем что введено минимум 11 цифр
                                  final phoneDigits = phoneMask.getUnmaskedText();
                                  if (phoneDigits.length < 11) {
                                    _showStyledSnackBar(
                                      sheetContext,
                                      'Введите полный номер телефона',
                                      isError: true,
                                    );
                                    return;
                                  }
                                  if (cityController.text.trim().isEmpty) {
                                    _showStyledSnackBar(
                                      sheetContext,
                                      'Укажите город получателя',
                                      isError: true,
                                    );
                                    return;
                                  }
                                }
                                Navigator.of(sheetContext).pop({
                                  'method': selectedMethod,
                                  'recipientName': nameController.text.trim(),
                                  'recipientPhone': phoneMask.getMaskedText(),
                                  'recipientCity': cityController.text.trim(),
                                  'transportCompanyName': transportCompanyController.text.trim(),
                                });
                              },
                        child: const Text('Сохранить'),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );

    if (result != null && context.mounted) {
      final apiService = ref.read(assembliesApiServiceProvider);
      final success = await apiService.updateAssemblyDelivery(
        assemblyId: assembly.id,
        deliveryMethod: result['method'] as String,
        recipientName: result['recipientName'] as String?,
        recipientPhone: result['recipientPhone'] as String?,
        recipientCity: result['recipientCity'] as String?,
        transportCompanyName: result['transportCompanyName'] as String?,
      );

      if (success) {
        if (!context.mounted) return;
        final methodLabel = result['method'] == 'self_pickup'
            ? 'Самовывоз'
            : 'Транспортная компания';
        _showStyledSnackBar(context, 'Способ получения: $methodLabel');
        // Обновляем треки чтобы отобразить изменения
        _refreshTracks();
      } else {
        if (!context.mounted) return;
        _showStyledSnackBar(
          context,
          'Ошибка сохранения способа получения',
          isError: true,
        );
      }
    }
  }

  Future<void> _showCreateGroupSheet(BuildContext context) async {
    final selectedPackingIds = <int>{};
    String selectedInsurance = 'no';
    String? insuranceAmount;

    // Создаём контроллер ДО StatefulBuilder чтобы не терять фокус
    final insuranceAmountController = TextEditingController();

    // Загружаем тарифы и типы упаковки (invalidate чтобы не получить кешированный пустой список при сбое сети)
    ref.invalidate(tariffsProvider);
    ref.invalidate(packagingTypesProvider);
    final tariffs = await ref.read(tariffsProvider.future);
    if (!context.mounted) return;
    final packagingTypes = await ref.read(packagingTypesProvider.future);

    // Выбираем первый тариф по умолчанию
    Tariff? selectedTariff = tariffs.isNotEmpty ? tariffs.first : null;

    if (!context.mounted) return;

    final result = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.55,
        maxChildSize: 0.95,
        expand: false,
        builder: (sheetContext, scrollController) {
          return StatefulBuilder(
            builder: (sheetContext, setSheetState) {
              return Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  0,
                  16,
                  MediaQuery.viewInsetsOf(sheetContext).bottom + 16,
                ),
                child: Column(
                  children: [
                    const SheetHandle(),
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.only(top: 12),
                        children: [
                          Text(
                            'Создать сборку',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Тариф',
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (tariffs.isEmpty)
                            const Text(
                              'Нет доступных тарифов',
                              style: TextStyle(color: Colors.grey),
                            )
                          else
                            Theme(
                              data: Theme.of(context).copyWith(
                                dropdownMenuTheme: DropdownMenuThemeData(
                                  menuStyle: MenuStyle(
                                    backgroundColor: WidgetStateProperty.all(
                                      Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              child: _CustomDropdown<int>(
                                value: selectedTariff!.id,
                                label: 'Тариф',
                                items: tariffs
                                    .map(
                                      (t) => _DropdownItem(
                                        value: t.id,
                                        label: t.name,
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  setSheetState(() {
                                    selectedTariff = tariffs.firstWhere(
                                      (t) => t.id == value,
                                    );
                                  });
                                },
                              ),
                            ),
                          const Divider(height: 24),
                          // ── Тип упаковки ──
                          GestureDetector(
                            onTap: () async {
                              if (packagingTypes.isEmpty) return;
                              final tempSelected = Set<int>.from(selectedPackingIds);
                              await showModalBottomSheet<void>(
                                context: sheetContext,
                                useRootNavigator: true,
                                backgroundColor: Colors.white,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                                ),
                                builder: (ctx) => StatefulBuilder(
                                  builder: (ctx, setModalState) => SafeArea(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const SizedBox(height: 8),
                                        Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(2))),
                                        const SizedBox(height: 12),
                                        const Text('Тип упаковки', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                                        const SizedBox(height: 8),
                                        Flexible(
                                          child: ListView(
                                            shrinkWrap: true,
                                            children: packagingTypes.map((p) {
                                              final checked = tempSelected.contains(p.id);
                                              return CheckboxListTile(
                                                dense: true,
                                                value: checked,
                                                activeColor: context.brandPrimary,
                                                title: Text(p.nameRu ?? p.name, style: const TextStyle(fontSize: 14)),
                                                onChanged: (v) {
                                                  setModalState(() {
                                                    if (v == true) { tempSelected.add(p.id); } else { tempSelected.remove(p.id); }
                                                  });
                                                },
                                              );
                                            }).toList(),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                                          child: SizedBox(
                                            width: double.infinity,
                                            child: FilledButton(
                                              onPressed: () {
                                                Navigator.pop(ctx);
                                                setSheetState(() {
                                                  selectedPackingIds.clear();
                                                  selectedPackingIds.addAll(tempSelected);
                                                });
                                              },
                                              child: const Text('Готово'),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0x0A000000),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.inventory_2_outlined, size: 18, color: context.brandPrimary),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: selectedPackingIds.isEmpty
                                        ? const Text('Выбрать упаковку', style: TextStyle(color: Colors.black38, fontSize: 14))
                                        : Wrap(
                                            spacing: 4,
                                            runSpacing: 4,
                                            children: selectedPackingIds.map((id) {
                                              final p = packagingTypes.firstWhere((t) => t.id == id);
                                              return Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: context.brandPrimary.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  p.nameRu ?? p.name,
                                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.brandPrimary),
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                  ),
                                  const Icon(Icons.expand_more, size: 18, color: Colors.black38),
                                ],
                              ),
                            ),
                          ),
                          const Divider(height: 24),
                          // ── Страховка ──
                          Row(
                            children: [
                              Icon(Icons.shield_outlined, size: 18, color: context.brandPrimary),
                              const SizedBox(width: 10),
                              const Text('Страховка', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87)),
                              const Spacer(),
                              Switch.adaptive(
                                value: selectedInsurance == 'yes',
                                activeColor: context.brandPrimary,
                                onChanged: (v) => setSheetState(() => selectedInsurance = v ? 'yes' : 'no'),
                              ),
                            ],
                          ),
                          if (selectedInsurance == 'yes') ...[
                            const SizedBox(height: 4),
                            _outlinedInput(
                              context,
                              insuranceAmountController,
                              hint: 'Сумма товаров в юанях',
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              onChanged: (value) {
                                setSheetState(() => insuranceAmount = value);
                              },
                            ),
                          ],
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: selectedPackingIds.isNotEmpty &&
                                        selectedTariff != null &&
                                        (selectedInsurance == 'no' || (insuranceAmount?.isNotEmpty == true))
                                    ? LinearGradient(colors: [context.brandPrimary, context.brandSecondary])
                                    : null,
                                color: selectedPackingIds.isEmpty ? Colors.black12 : null,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                onPressed:
                                    selectedPackingIds.isNotEmpty &&
                                        selectedTariff != null &&
                                        (selectedInsurance == 'no' ||
                                            (selectedInsurance == 'yes' &&
                                                insuranceAmount?.isNotEmpty == true))
                                    ? () => Navigator.of(sheetContext).pop(true)
                                    : null,
                                child: const Text('Отправить на сборку', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );

    if (result == true) {
      if (!context.mounted) return;
      // Получаем данные для API
      final auth = ref.read(authStateProvider);
      final clientCode = ref.read(activeClientCodeProvider);
      if (clientCode == null) {
        _showStyledSnackBar(
          context,
          'Ошибка: код клиента не найден',
          isError: true,
        );
        return;
      }

      final clientId = auth.clientId;

      if (clientId == null) {
        _showStyledSnackBar(
          context,
          'Ошибка: нет данных клиента',
          isError: true,
        );
        return;
      }

      // Ensure all pages are loaded so every selected track code can be resolved to an ID
      final notifier = ref.read(paginatedTracksProvider(clientCode));
      if (notifier.state.hasMore) {
        // Показываем индикатор загрузки
        if (context.mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => const Center(child: CircularProgressIndicator()),
          );
        }
        var iterations = 0;
        const maxIterations = 100; // Предохранитель от бесконечного цикла
        while (notifier.state.hasMore && !notifier.state.isLoading && iterations < maxIterations) {
          await notifier.loadMore();
          iterations++;
          if (!context.mounted) return;
          if (notifier.state.error != null) break;
        }
        if (context.mounted) Navigator.of(context, rootNavigator: true).pop(); // Убираем индикатор
      }
      if (!context.mounted) return;
      final tracks = notifier.state.tracks;

      final selectedTracks = tracks
          .where((t) => _selectedTracks.contains(t.code) && t.id != null)
          .toList();

      final selectedTrackIds = selectedTracks.map((t) => t.id!).toList();

      // Проверяем наличие незавершённых задач (вопросы/фотоотчёты)
      final tracksWithActiveTasks = selectedTracks.where((t) {
        final hasActivePhoto = t.activePhotoRequest?.isActive == true;
        final hasActiveQ = t.activeQuestion?.isActive == true;
        return hasActivePhoto || hasActiveQ;
      }).toList();

      if (tracksWithActiveTasks.isNotEmpty) {
        if (!context.mounted) return;
        final proceed = await showModalBottomSheet<bool>(
          context: context,
          useRootNavigator: true,
          backgroundColor: Colors.white,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (sheetCtx) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SheetHandle(),
                    const SizedBox(height: 12),
                    Text(
                      'Незавершённые задачи',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Есть треки (${tracksWithActiveTasks.length} шт.) с невыполненными задачами '
                      '(вопросы/фотоотчёты). Если вы создадите сборку, эти задачи будут отменены.',
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(sheetCtx).pop(false),
                            child: const Text('Отменить'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => Navigator.of(sheetCtx).pop(true),
                            child: const Text('Создать сборку'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );

        if (proceed != true) return;
        if (!context.mounted) return;

        // Отменяем незавершённые задачи
        final tracksApi = ref.read(tracksApiServiceProvider);
        for (final t in tracksWithActiveTasks) {
          if (t.activePhotoRequest?.isActive == true) {
            await tracksApi.cancelPhotoRequest(t.activePhotoRequest!.id);
          }
          if (t.activeQuestion?.isActive == true) {
            await tracksApi.cancelTrackQuestion(t.activeQuestion!.id);
          }
        }
      }

      // Проверяем наличие информации о товаре если тариф требует её
      if (selectedTariff?.requiresProductInfo == true) {
        final tracksWithoutProductInfo = selectedTracks.where((t) {
          final info = t.productInfo;
          return info == null || (info.name == null || info.name!.trim().isEmpty);
        }).toList();

        if (tracksWithoutProductInfo.isNotEmpty) {
          if (!context.mounted) return;
          await showModalBottomSheet<void>(
            context: context,
            useRootNavigator: true,
            backgroundColor: Colors.white,
            isScrollControlled: true,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (sheetCtx) {
              return SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SheetHandle(),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.assignment_outlined, color: Colors.orange.shade700, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            'Требуется информация о товаре',
                            style: Theme.of(sheetCtx).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Тариф «${selectedTariff!.name}» требует заполнения информации о товаре. '
                        'Пожалуйста, заполните данные для следующих треков (${tracksWithoutProductInfo.length} шт.):',
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(sheetCtx).size.height * 0.3,
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: tracksWithoutProductInfo.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final t = tracksWithoutProductInfo[i];
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Row(
                                children: [
                                  Icon(Icons.local_shipping_outlined, size: 16, color: Colors.orange.shade600),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      t.code,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    'нет данных о товаре',
                                    style: TextStyle(fontSize: 12, color: Colors.orange.shade700),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => Navigator.of(sheetCtx).pop(),
                        style: FilledButton.styleFrom(backgroundColor: Colors.orange.shade700),
                        child: const Text('Понятно, заполню информацию'),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
          return; // Прерываем создание сборки
        }
      }

      // Создаём сборку через API
      final apiService = ref.read(assembliesApiServiceProvider);
      // Берём clientCodeId из выбранных треков, а не из dropdown (чтобы не привязать к NOCODE)
      final trackClientCodeId = selectedTracks.firstOrNull?.clientCodeId;
      final clientCodeId = trackClientCodeId ?? ref.read(activeClientCodeIdProvider);
      final assembly = await apiService.createAssembly(
        clientId: clientId,
        clientCodeId: clientCodeId,
        clientCode: clientCodeId == null ? clientCode : null,
        tariffId: selectedTariff?.id,
        packagingTypeIds: selectedPackingIds.toList(),
        hasInsurance: selectedInsurance == 'yes',
        insuranceAmount: selectedInsurance == 'yes' && insuranceAmount != null
            ? double.tryParse(insuranceAmount!)
            : null,
        trackIds: selectedTrackIds,
      );

      if (assembly != null) {
        if (!context.mounted) return;
        _showStyledSnackBar(context, 'Сборка ${assembly.number} создана');
        setState(() {
          _selectedTracks.clear();
          _selectedStatus = null;
        });
        // Обновляем список треков
        _refreshTracks();
        ref.invalidate(assembliesListProvider(clientCode));
      } else {
        if (!context.mounted) return;
        _showStyledSnackBar(context, 'Ошибка создания сборки', isError: true);
      }
    }
  }

  Future<void> _showAboutProductSheet(
    BuildContext context,
    TrackItem track,
  ) async {
    final existing = _productInfos[track.code];
    final nameController = TextEditingController(text: existing?.name ?? track.productInfo?.name ?? '');
    final qtyController = TextEditingController(
      text: existing?.quantity?.toString() ?? track.productInfo?.quantity.toString() ?? '',
    );

    // Список путей/URL для отображения
    final images = List<String>.from(existing?.images ?? const []);
    if (track.productInfo?.imageUrl != null && track.productInfo!.imageUrl!.isNotEmpty) {
      if (!images.contains(track.productInfo!.imageUrl)) {
        images.insert(0, track.productInfo!.imageUrl!);
      }
    }

    // Новые выбранные файлы (XFile)
    final List<XFile> newFiles = [];
    final result = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        final viewInsetsBottom = MediaQuery.viewInsetsOf(sheetContext).bottom;
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return SafeArea(
              child: AnimatedPadding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + viewInsetsBottom),
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SheetHandle(),
                      const SizedBox(height: 12),
                      Text(
                        'О товаре',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Название товара',
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _outlinedInput(
                        context,
                        nameController,
                        hint: 'например: кроссовки Nuke Air Max',
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Количество',
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _outlinedInput(
                        context,
                        qtyController,
                        hint: 'например: 2',
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Одно изображение товара — можно заменить
                      Builder(builder: (_) {
                        // Определяем текущее изображение: новое > существующее
                        final hasNew = newFiles.isNotEmpty;
                        final hasExisting = images.isNotEmpty;
                        final hasImage = hasNew || hasExisting;

                        Future<void> pickImage() async {
                          try {
                            final picker = ImagePicker();
                            final picked = await picker.pickImage(
                              source: ImageSource.gallery,
                              imageQuality: 85,
                            );
                            if (picked != null) {
                              setSheetState(() {
                                newFiles.clear();
                                newFiles.add(picked);
                              });
                            }
                          } catch (e) {
                            if (context.mounted) {
                              _showStyledSnackBar(context, 'Не удалось открыть галерею: $e', isError: true);
                            }
                          }
                        }

                        if (!hasImage) {
                          return SizedBox(
                            width: double.infinity,
                            child: _ActionChipButton(
                              icon: Icons.add_photo_alternate_rounded,
                              label: 'Добавить фото товара',
                              onPressed: pickImage,
                            ),
                          );
                        }

                        Widget imageWidget;
                        if (hasNew) {
                          final file = newFiles.first;
                          imageWidget = kIsWeb
                              ? FutureBuilder<Uint8List>(
                                  future: file.readAsBytes(),
                                  builder: (context, snapshot) {
                                    if (snapshot.hasData) {
                                      return Image.memory(snapshot.data!, fit: BoxFit.cover);
                                    }
                                    return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                                  },
                                )
                              : Image.file(File(file.path), fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => const ColoredBox(color: Colors.black12));
                        } else {
                          final path = images.first;
                          final isUrl = path.startsWith('http') || path.startsWith('/');
                          imageWidget = isUrl
                              ? CachedNetworkImage(
                                  imageUrl: ApiConfig.getMediaUrl(path),
                                  memCacheWidth: 400,
                                  imageBuilder: (_, imageProvider) => DecoratedBox(
                                    decoration: BoxDecoration(
                                      image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
                                    ),
                                  ),
                                  placeholder: (_, _) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                  errorWidget: (_, _, _) => const ColoredBox(color: Colors.black12),
                                )
                              : (!kIsWeb
                                  ? Image.file(File(path), fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => const ColoredBox(color: Colors.black12))
                                  : const ColoredBox(color: Colors.black12));
                        }

                        return Stack(
                          children: [
                            GestureDetector(
                              onTap: pickImage,
                              child: Container(
                                width: double.infinity,
                                height: 160,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: const [
                                    BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, 4)),
                                  ],
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: imageWidget,
                              ),
                            ),
                            Positioned(
                              right: 6,
                              bottom: 6,
                              child: GestureDetector(
                                onTap: pickImage,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.swap_horiz, size: 16, color: Colors.white),
                                      SizedBox(width: 4),
                                      Text('Заменить', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              right: 6,
                              top: 6,
                              child: GestureDetector(
                                onTap: () => setSheetState(() {
                                  images.clear();
                                  newFiles.clear();
                                }),
                                child: const CircleAvatar(
                                  radius: 14,
                                  backgroundColor: Colors.white,
                                  child: Icon(Icons.close_rounded, size: 18),
                                ),
                              ),
                            ),
                          ],
                        );
                      }),
                      const SizedBox(height: 14),
                      FilledButton(
                        onPressed: () => Navigator.of(sheetContext).pop(true),
                        child: const Text('Сохранить'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    if (result == true) {
      final productName = nameController.text.trim();
      final quantity = int.tryParse(qtyController.text.trim()) ?? 1;

      // Отправляем на сервер
      if (track.id != null) {
        final apiService = ref.read(tracksApiServiceProvider);

        File? imageFile;
        String? uploadedImageUrl;

        // Загружаем первое новое изображение
        if (newFiles.isNotEmpty) {
          try {
            if (kIsWeb) {
              final bytes = await newFiles.first.readAsBytes();
              uploadedImageUrl = await apiService.uploadImageFromBytes(
                bytes,
                newFiles.first.name,
                'product-info',
              );
            } else {
              imageFile = File(newFiles.first.path);
            }
          } catch (e) {
            debugPrint('Failed to upload image ${newFiles.first.name}: $e');
          }
        }

        final success = await apiService.updateProductInfo(
          trackId: track.id!,
          productName: productName,
          quantity: quantity,
          imageFile: imageFile,
          imageUrl: uploadedImageUrl,
        );

        if (success) {
          // После успешного сохранения — обновляем треки с сервера,
          // чтобы получить актуальные URL изображений
          _refreshTracks();
          if (!context.mounted) return;
          _showStyledSnackBar(context, 'Информация о товаре сохранена');
        } else {
          // Сохраняем локально как fallback
          setState(() {
            _productInfos[track.code] = _ProductInfo(
              name: productName,
              quantity: quantity,
              images: images,
            );
          });
          if (!context.mounted) return;
          _showStyledSnackBar(context, 'Ошибка сохранения на сервере', isError: true);
        }
      } else {
        setState(() {
          _productInfos[track.code] = _ProductInfo(
            name: productName,
            quantity: quantity,
            images: images,
          );
        });
        if (!context.mounted) return;
        _showStyledSnackBar(context, 'Информация о товаре сохранена локально');
      }
    }
  }

  /// Получить текущие параметры фильтрации
  TracksFilterParams _getFilterParams(String clientCode) {
    return TracksFilterParams(
      clientCode: clientCode,
      statusCode: _statusCode,
      search: _query.isNotEmpty ? _query : null,
      viewMode: _viewMode == ViewMode.all
          ? 'all'
          : _viewMode == ViewMode.groups
          ? 'groups'
          : 'singles',
    );
  }

  /// Обработчик изменения поиска с debounce
  void _onSearchChanged(String value, String clientCode) {
    setState(() => _query = value);

    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      final params = _getFilterParams(clientCode);
      ref.read(paginatedTracksProvider(clientCode)).updateFilters(params);
    });
  }

  /// Обработчик изменения статуса
  void _onStatusChanged(String? statusCode, String clientCode) {
    setState(() => _statusCode = statusCode);

    final params = _getFilterParams(clientCode);
    ref.read(paginatedTracksProvider(clientCode)).updateFilters(params);
  }

  /// Обработчик изменения режима просмотра
  void _onViewModeChanged(ViewMode mode, String clientCode) {
    setState(() => _viewMode = mode);

    final params = _getFilterParams(clientCode);
    ref.read(paginatedTracksProvider(clientCode)).updateFilters(params);
  }

  @override
  Widget build(BuildContext context) {
    final clientCode = ref.watch(activeClientCodeProvider);
    if (clientCode == null) {
      return const EmptyState(
        icon: Icons.badge_outlined,
        title: 'Выберите код клиента',
        message:
            'Чтобы увидеть треки, сначала выберите или добавьте код клиента.',
      );
    }

    // Получаем notifier и состояние пагинированного списка
    final tracksNotifier = ref.watch(paginatedTracksProvider(clientCode));
    // Подписываемся на изменения состояния notifier
    _updateNotifierListener(tracksNotifier);

    final tracksState = tracksNotifier.state;
    final bottomPad = AppLayout.bottomScrollPadding(context);
    final topPad = AppLayout.topBarTotalHeight(context);
    const bulkButtonExtraPad = 72.0;

    final groups = tracksState.tracks.isNotEmpty
        ? _groupTracks(tracksState.tracks)
        : <_GroupBucket>[];
    final bottomScrollPad = bottomPad +
        16 +
        (_selectedTracks.isEmpty ? 0 : bulkButtonExtraPad + 8);

    return TutorialScreenWrapper(
      screenKey: 'tracks',
      steps: [
        TutorialStep(
          icon: Icons.local_shipping_rounded,
          title: 'Список треков',
          description: 'Каждая строка — одна посылка. Цветной статус показывает этап: склад в Китае, в пути, склад в России или получено клиентом.',
          targetKey: _tracksListKey,
        ),
        TutorialStep(
          icon: Icons.add_circle_rounded,
          title: 'Добавить трек',
          description: 'Нажмите кнопку «+» в правом нижнем углу, чтобы добавить трек-номер новой посылки. Мы начнём её отслеживать.',
          targetKey: _fabKey,
        ),
        TutorialStep(
          icon: Icons.filter_list_rounded,
          title: 'Фильтр по статусу',
          description: 'Нажмите на статус в верхней панели, чтобы показать только посылки на этом этапе. Удобно при большом количестве треков.',
          targetKey: _filtersKey,
        ),
        TutorialStep(
          icon: Icons.touch_app_rounded,
          title: 'Детали посылки',
          description: 'Нажмите на трек, чтобы развернуть карточку с подробностями: вес, тариф, история статусов и кнопки действий.',
          targetKey: _trackDetailKey,
        ),
        TutorialStep(
          icon: Icons.photo_camera_rounded,
          title: 'Запросить фотоотчёт',
          description: 'Кнопка «Запросить фотоотчёт» внутри карточки отправляет запрос на склад. Мы сфотографируем посылку и пришлём снимки. Услуга может быть платной.',
          targetKey: _actionsRowKey,
        ),
        TutorialStep(
          icon: Icons.help_outline_rounded,
          title: 'Задать вопрос',
          description: 'Кнопка «Задать вопрос» открывает форму для обращения к менеджеру по конкретному треку. Ответ придёт в этой же карточке.',
          targetKey: _actionsRowKey,
        ),
        TutorialStep(
          icon: Icons.sticky_note_2_rounded,
          title: 'Комментарий к треку',
          description: 'В карточке трека есть поле для заметки. Введите текст и нажмите «Сохранить заметку» — заметка видна только вам.',
          targetKey: _actionsRowKey,
        ),
        TutorialStep(
          icon: Icons.assignment_return_rounded,
          title: 'Оформить возврат',
          description: '«Оформить возврат» — открывает форму возврата товара. Укажите причину и код — заявка уйдёт на склад в Китае.',
          targetKey: _actionsRowKey,
        ),
        TutorialStep(
          icon: Icons.inventory_2_rounded,
          title: 'Сборка и доставка по РФ',
          description: 'Блок сборки показывает транспортную компанию, коробки с весами, тариф и упаковку. Нажмите «Выбрать ТК» для настройки доставки.',
          targetKey: _assemblyKey,
        ),
      ],
      child: Stack(
            children: [
              RefreshIndicator(
                onRefresh: () async {
                  if (_isRefreshing) return;
                  _isRefreshing = true;
                  try {
                    // Обновляем с актуальными фильтрами из UI
                    final filterParams = _getFilterParams(clientCode);
                    await ref
                        .read(paginatedTracksProvider(clientCode))
                        .updateFilters(filterParams);
                    ref.invalidate(assembliesListProvider(clientCode));
                    // Очищаем оптимистичные Map-записи для треков у которых
                    // сервер уже подтвердил данные (вопросы, фото-запросы)
                    _syncMapsWithServerData(
                      ref.read(paginatedTracksProvider(clientCode)).state.tracks,
                    );
                  } finally {
                    _isRefreshing = false;
                  }
                },
                color: context.brandPrimary,
                child: NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    // Проверяем нужна ли подгрузка при скролле
                    if (notification is ScrollUpdateNotification) {
                      final metrics = notification.metrics;
                      final maxScroll = metrics.maxScrollExtent;
                      final currentScroll = metrics.pixels;
                      // Загружаем ещё когда до конца осталось ~10% списка.
                      // Throttle: не чаще 1 раза в 300мс, не пробуем если уже грузим или нет страниц.
                      final now = DateTime.now();
                      final canLoad = _lastLoadMoreTime == null ||
                          now.difference(_lastLoadMoreTime!).inMilliseconds > 300;
                      if (maxScroll > 0 &&
                          currentScroll >= maxScroll * 0.9 &&
                          !tracksState.isLoading &&
                          tracksState.hasMore &&
                          tracksState.error == null &&
                          canLoad) {
                        _lastLoadMoreTime = now;
                        ref
                            .read(paginatedTracksProvider(clientCode))
                            .loadMore();
                      }
                    }
                    return false;
                  },
                  child: CustomScrollView(
                    controller: _scrollController,
                    key: _tracksListKey,
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      // Заголовок + фильтры
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(16, topPad * 0.7 + 6, 16, 0),
                        sliver: SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Треки',
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 18),
                              Container(
                                key: _filtersKey,
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
                                child: _FiltersNew(
                                  statusCode: _statusCode,
                                  tracks: tracksState.tracks,
                                  viewMode: _viewMode,
                                  query: _query,
                                  onStatusChanged: (v) =>
                                      _onStatusChanged(v, clientCode),
                                  onViewModeChanged: (v) =>
                                      _onViewModeChanged(v, clientCode),
                                  onQueryChanged: (v) =>
                                      _onSearchChanged(v, clientCode),
                                ),
                              ),
                              const SizedBox(height: 18),
                              if (tracksState.total > 0)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Text(
                                    'Показано ${tracksState.tracks.length} из ${tracksState.total}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      // Список треков или состояние (загрузка/ошибка/пусто)
                      ..._buildTracksList(tracksState, clientCode, groups, bottomScrollPad),
                    ],
                  ),
                ),
              ),
              // Нижние кнопки: "Отправка на сборку" (если выбраны треки) + FAB "Добавить треки"
              Positioned(
                left: 16,
                right: 16,
                bottom: AppLayout.bottomBarHeight +
                    AppLayout.bottomBarBottomMargin +
                    35, // Минимальный отступ от нижнего меню
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end, // FAB справа по умолчанию
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Кнопки выбора и действия (показываются только когда выбраны треки)
                    if (_selectedTracks.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: OutlinedButton(
                          onPressed: () { _selectAll(); },
                          child: const Text('Все'),
                        ),
                      ),
                      Flexible(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 16),
                          child: FilledButton(
                            onPressed: _selectedStatus == null
                                ? null
                                : () => _bulkAction(context),
                            child: Text(
                              _actionLabel(),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                    ],
                    // FAB кнопка для добавления треков (всегда справа)
                    FloatingActionButton(
                      key: _fabKey,
                      onPressed: () => showAddTracksDialog(context, ref),
                      backgroundColor: context.brandPrimary,
                      foregroundColor: Colors.white,
                      elevation: 8,
                      child: const Icon(Icons.add_box_rounded, size: 28),
                    ),
                  ],
                ),
              ),
              ScrollToTopButton(controller: _scrollController),
            ],
          ),
    );
  }

  /// Построить список треков как slivers (ленивый рендеринг через SliverList.builder)
  List<Widget> _buildTracksList(
    PaginatedTracksState tracksState,
    String clientCode,
    List<_GroupBucket> groups,
    double bottomPad,
  ) {
    // Показываем загрузку при первоначальной загрузке
    if (tracksState.isLoading && tracksState.tracks.isEmpty) {
      return [
        const SliverFillRemaining(
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }

    // Показываем ошибку
    if (tracksState.error != null && tracksState.tracks.isEmpty) {
      final errorInfo = ErrorUtils.getErrorInfo(tracksState.error!);
      return [
        SliverFillRemaining(
          child: EmptyState(
            icon: errorInfo.icon,
            title: errorInfo.getTitle(context),
            message: errorInfo.getMessage(context),
          ),
        ),
      ];
    }

    // Пустой список
    if (tracksState.tracks.isEmpty) {
      return [
        const SliverFillRemaining(
          child: EmptyState(
            icon: Icons.local_shipping_outlined,
            title: 'Ничего не найдено',
            message: 'Попробуйте изменить фильтры или строку поиска.',
          ),
        ),
      ];
    }

    // SliverList.builder — ленивый рендеринг: только видимые карточки строятся
    return [
      SliverPadding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPad),
        sliver: SliverList.builder(
          itemCount: groups.length + 1, // +1 для footer
          itemBuilder: (context, index) {
            // Footer: индикатор загрузки, ошибка или "все загружены"
            if (index == groups.length) {
              if (tracksState.isLoading && tracksState.tracks.isNotEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (tracksState.error != null && tracksState.tracks.isNotEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      'Не удалось загрузить все треки. Потяните вниз для обновления.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                    ),
                  ),
                );
              }
              if (!tracksState.hasMore && tracksState.tracks.isNotEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      'Все треки загружены',
                      style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            }

            final g = groups[index];
            final isFirstAssembly = g.assembly != null &&
                groups.sublist(0, index).every((gr) => gr.assembly == null);
            final trackCard = _TrackGroupCard(
              assembly: g.assembly,
              tracks: g.tracks,
              selectedTrackCodes: _selectedTracks,
              selectedStatus: _selectedStatus,
              onToggle: _toggleTrack,
              requestedPhotoReports: _requestedPhotoReports,
              onPhotoRequest: (track) => _showPhotoRequestSheet(context, track),
              onCancelPhotoRequest: (track) => _cancelPhotoRequest(track),
              onEditPhotoWish: (track) => _showEditPhotoWishSheet(context, track),
              photoRequestCreatedAt: _photoRequestCreatedAt,
              photoRequestUpdatedAt: _photoRequestUpdatedAt,
              photoRequestNotes: _photoRequestNotes,
              overrideComments: _overrideComments,
              onAskQuestion: (track) => _showAskQuestionSheet(context, track),
              onCancelQuestion: (track) => _cancelQuestion(track),
              onEditComment: (track) => _showCommentSheet(context, track),
              onEditProduct: (track) => _showAboutProductSheet(context, track),
              askedQuestions: _askedQuestions,
              questionCreatedAt: _questionCreatedAt,
              questionUpdatedAt: _questionUpdatedAt,
              questionStatus: _questionStatus,
              questionAnswers: _questionAnswers,
              productInfos: _productInfos,
              groupComments: _groupComments,
              groupQuestions: _groupQuestions,
              groupQuestionCreatedAt: _groupQuestionCreatedAt,
              groupQuestionUpdatedAt: _groupQuestionUpdatedAt,
              onEditGroupComment: (assembly) =>
                  _showGroupCommentSheet(context, assembly),
              onAskGroupQuestion: (assembly) =>
                  _showGroupQuestionSheet(context, assembly),
              onSelectDelivery: (assembly) =>
                  _showDeliverySheet(context, assembly),
              onDeleteTrack: (track) => _deleteTrack(track),
              onReturnRequest: (track) => _showReturnSheet(context, track),
              returnRequestedTracks: _returnRequestedTracks,
              tutorialActionsKey: index == 0 ? _actionsRowKey : null,
              tutorialAssemblyKey: isFirstAssembly ? _assemblyKey : null,
            );

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: index == 0
                  ? KeyedSubtree(key: _trackDetailKey, child: trackCard)
                  : trackCard,
            );
          },
        ),
      ),
    ];
  }

  List<_GroupBucket> _groupTracks(List<TrackItem> tracks) {
    final byKey = <String, _GroupBucket>{};
    for (final t in tracks) {
      final key = t.groupId ?? '__${t.code}';
      byKey[key] =
          (byKey[key] ?? _GroupBucket(assembly: t.assembly, tracks: []))
            ..tracks.add(t);
    }
    final list = byKey.values.toList(growable: false);
    for (final bucket in list) {
      bucket.tracks.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    list.sort((a, b) => b.latestDate.compareTo(a.latestDate));
    return list;
  }

  void _toggleTrack(TrackItem track) {
    final status = track.status;
    if (!_selectableStatuses.contains(status)) return;

    setState(() {
      if (_selectedTracks.contains(track.code)) {
        _selectedTracks.remove(track.code);
        if (_selectedTracks.isEmpty) _selectedStatus = null;
      } else {
        if (_selectedStatus == null) {
          _selectedStatus = status;
        } else if (_selectedStatus != status) {
          return;
        }
        _selectedTracks.add(track.code);
      }
    });
  }

  Future<void> _selectAll() async {
    if (_selectedStatus == null) return;
    final clientCode = ref.read(activeClientCodeProvider);
    if (clientCode == null) return;

    final notifier = ref.read(paginatedTracksProvider(clientCode));

    // Load all remaining pages so we select every track, not just the loaded page
    if (notifier.state.hasMore) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      var iterations = 0;
      const maxIterations = 100;
      while (notifier.state.hasMore && !notifier.state.isLoading && iterations < maxIterations) {
        await notifier.loadMore();
        iterations++;
        if (!mounted) return;
        if (notifier.state.error != null) break;
      }
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    }

    final allWithStatus = notifier.state.tracks
        .where((t) => t.status == _selectedStatus)
        .map((t) => t.code)
        .toSet();

    if (!mounted) return;
    setState(() {
      _selectedTracks.addAll(allWithStatus);
    });
    _showStyledSnackBar(
      context,
      'Рекомендуем проверить все трек-номера перед передачей на сборку, '
      'так как будут отправлены именно те трек-номера которые были выбраны.',
    );
  }

  String _actionLabel() {
    final count = _selectedTracks.length;
    return switch (_selectedStatus) {
      'На складе' => 'Отправка на сборку ($count)',
      'Прибыл на терминал' => 'Сформировать к выдаче ($count)',
      'Сформирован к выдаче' => 'Груз получен ($count)',
      _ => 'Действие ($count)',
    };
  }

  void _bulkAction(BuildContext context) {
    final status = _selectedStatus;
    if (status == null) return;

    if (status == 'На складе') {
      _showCreateGroupSheet(context);
    } else {
      final text = switch (status) {
        'Прибыл на терминал' =>
          'Перевод в «Сформирован к выдаче» добавим следующим шагом.',
        'Сформирован к выдаче' =>
          'Подтверждение «Получен» добавим следующим шагом.',
        _ => 'Действие добавим следующим шагом.',
      };
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }
}

enum ViewMode { all, groups, singles }

class _Filters extends StatefulWidget {
  final String status;
  final List<String> statuses;
  final ViewMode viewMode;
  final String query;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<ViewMode> onViewModeChanged;
  final ValueChanged<String> onQueryChanged;

  const _Filters({
    required this.status,
    required this.statuses,
    required this.viewMode,
    required this.query,
    required this.onStatusChanged,
    required this.onViewModeChanged,
    required this.onQueryChanged,
  });

  @override
  State<_Filters> createState() => _FiltersState();
}

class _FiltersState extends State<_Filters> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.query);
  }

  @override
  void didUpdateWidget(covariant _Filters oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query &&
        _searchController.text != widget.query) {
      _searchController.text = widget.query;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
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
              controller: _searchController,
              decoration: InputDecoration(
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: context.brandPrimary,
                  size: 20,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Color(0xFF999999),
                          size: 20,
                        ),
                        onPressed: () {
                          _searchController.selection = const TextSelection.collapsed(offset: 0);
                          _searchController.clear();
                          widget.onQueryChanged('');
                        },
                      )
                    : null,
                hintText: 'Поиск по треку',
                hintStyle: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF999999),
                  fontWeight: FontWeight.w500,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onChanged: (value) {
                setState(() {});
                widget.onQueryChanged(value);
              },
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _CustomDropdown<ViewMode>(
                value: widget.viewMode,
                label: 'Вид',
                items: const [
                  _DropdownItem(value: ViewMode.all, label: 'Все'),
                  _DropdownItem(value: ViewMode.groups, label: 'Сборки'),
                  _DropdownItem(value: ViewMode.singles, label: 'Одиночные'),
                ],
                onChanged: (v) =>
                    v != null ? widget.onViewModeChanged(v) : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _CustomDropdown<String>(
                value: widget.status,
                label: 'Статус',
                items: widget.statuses
                    .map((s) => _DropdownItem(value: s, label: s))
                    .toList(),
                onChanged: (v) => v != null ? widget.onStatusChanged(v) : null,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Новый виджет фильтров со статусами из БД
class _FiltersNew extends StatefulWidget {
  final String? statusCode; // null = Все
  final List<TrackItem> tracks; // Извлекаем статусы из треков
  final ViewMode viewMode;
  final String query;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<ViewMode> onViewModeChanged;
  final ValueChanged<String> onQueryChanged;
  const _FiltersNew({
    required this.statusCode,
    required this.tracks,
    required this.viewMode,
    required this.query,
    required this.onStatusChanged,
    required this.onViewModeChanged,
    required this.onQueryChanged,
  });

  @override
  State<_FiltersNew> createState() => _FiltersNewState();
}

class _FiltersNewState extends State<_FiltersNew> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.query);
  }

  @override
  void didUpdateWidget(covariant _FiltersNew oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query &&
        _searchController.text != widget.query) {
      _searchController.text = widget.query;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Извлекаем уникальные статусы из загруженных треков
    final uniqueStatuses = <String, String>{};
    for (final track in widget.tracks) {
      if (track.statusCode.isNotEmpty &&
          !uniqueStatuses.containsKey(track.statusCode)) {
        uniqueStatuses[track.statusCode] = track.status;
      }
    }

    // Формируем список статусов для dropdown
    final statusItems = <_DropdownItem<String?>>[
      const _DropdownItem(value: null, label: 'Все'),
      ...uniqueStatuses.entries.map(
        (e) => _DropdownItem(value: e.key, label: e.value),
      ),
    ];

    return Row(
      children: [
        // Поиск — занимает оставшееся место
        Expanded(
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0x0F000000),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: context.brandPrimary,
                  size: 18,
                ),
                prefixIconConstraints: const BoxConstraints(minWidth: 36),
                suffixIcon: _searchController.text.isNotEmpty
                    ? GestureDetector(
                        onTap: () {
                          _searchController.selection = const TextSelection.collapsed(offset: 0);
                          _searchController.clear();
                          widget.onQueryChanged('');
                        },
                        child: const Icon(Icons.close_rounded, color: Color(0xFF999999), size: 18),
                      )
                    : null,
                suffixIconConstraints: const BoxConstraints(minWidth: 36),
                hintText: 'Поиск по треку',
                hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF999999)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                isDense: true,
              ),
              onChanged: (value) {
                setState(() {});
                widget.onQueryChanged(value);
              },
            ),
          ),
        ),
        ),
        const SizedBox(width: 6),
        // Вид
        _MiniDropdown<ViewMode>(
          value: widget.viewMode,
          items: const [
            _DropdownItem(value: ViewMode.all, label: 'Все'),
            _DropdownItem(value: ViewMode.groups, label: 'Сборки'),
            _DropdownItem(value: ViewMode.singles, label: 'Одиночные'),
          ],
          onChanged: (v) => v != null ? widget.onViewModeChanged(v) : null,
        ),
        const SizedBox(width: 6),
        // Статус
        _MiniDropdown<String?>(
          value: widget.statusCode,
          items: statusItems,
          onChanged: (v) => widget.onStatusChanged(v),
        ),
      ],
    );
  }
}

class _TrackGroupCard extends StatefulWidget {
  final TrackAssembly? assembly;
  final List<TrackItem> tracks;
  final Set<String> selectedTrackCodes;
  final String? selectedStatus;
  final ValueChanged<TrackItem> onToggle;
  final Set<String> requestedPhotoReports;
  final ValueChanged<TrackItem> onPhotoRequest;
  final ValueChanged<TrackItem> onCancelPhotoRequest;
  final ValueChanged<TrackItem> onEditPhotoWish;
  final Map<String, DateTime> photoRequestCreatedAt;
  final Map<String, DateTime> photoRequestUpdatedAt;
  final Map<String, String> photoRequestNotes;
  final Map<String, String> overrideComments;
  final ValueChanged<TrackItem> onAskQuestion;
  final ValueChanged<TrackItem> onCancelQuestion;
  final ValueChanged<TrackItem> onEditComment;
  final ValueChanged<TrackItem> onEditProduct;
  final Map<String, String> askedQuestions;
  final Map<String, DateTime> questionCreatedAt;
  final Map<String, DateTime> questionUpdatedAt;
  final Map<String, String> questionStatus;
  final Map<String, String> questionAnswers;
  final Map<String, _ProductInfo> productInfos;
  final Map<String, String> groupComments;
  final Map<String, String> groupQuestions;
  final Map<String, DateTime> groupQuestionCreatedAt;
  final Map<String, DateTime> groupQuestionUpdatedAt;
  final ValueChanged<TrackAssembly> onEditGroupComment;
  final ValueChanged<TrackAssembly> onAskGroupQuestion;
  final ValueChanged<TrackAssembly> onSelectDelivery;
  final ValueChanged<TrackItem> onDeleteTrack;
  final ValueChanged<TrackItem> onReturnRequest;
  final Set<String> returnRequestedTracks;
  final GlobalKey? tutorialActionsKey;
  final GlobalKey? tutorialAssemblyKey;

  const _TrackGroupCard({
    required this.assembly,
    required this.tracks,
    required this.selectedTrackCodes,
    required this.selectedStatus,
    required this.onToggle,
    required this.requestedPhotoReports,
    required this.onPhotoRequest,
    required this.onCancelPhotoRequest,
    required this.onEditPhotoWish,
    required this.photoRequestCreatedAt,
    required this.photoRequestUpdatedAt,
    required this.photoRequestNotes,
    required this.overrideComments,
    required this.onAskQuestion,
    required this.onCancelQuestion,
    required this.onEditComment,
    required this.onEditProduct,
    required this.askedQuestions,
    required this.questionCreatedAt,
    required this.questionUpdatedAt,
    required this.questionStatus,
    required this.questionAnswers,
    required this.productInfos,
    required this.groupComments,
    required this.groupQuestions,
    required this.groupQuestionCreatedAt,
    required this.groupQuestionUpdatedAt,
    required this.onEditGroupComment,
    required this.onAskGroupQuestion,
    required this.onSelectDelivery,
    required this.onDeleteTrack,
    required this.onReturnRequest,
    required this.returnRequestedTracks,
    this.tutorialActionsKey,
    this.tutorialAssemblyKey,
  });

  @override
  State<_TrackGroupCard> createState() => _TrackGroupCardState();
}

class _TrackGroupCardState extends State<_TrackGroupCard> {
  bool _showAssemblyDetails = false;
  bool _showBoxes = false;
  bool _showTracks = true;

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd MMM yyyy', 'ru');
    // Используем комментарий из локального кэша или из данных сборки
    final groupComment = widget.assembly != null
        ? (widget.groupComments[widget.assembly!.id.toString()] ?? widget.assembly!.comment ?? '')
        : '';
    final groupQuestion = widget.assembly != null
        ? (widget.groupQuestions[widget.assembly!.id.toString()] ?? '')
        : '';
    final groupQuestionCreated = widget.assembly != null
        ? widget.groupQuestionCreatedAt[widget.assembly!.id.toString()]
        : null;
    final groupQuestionUpdated = widget.assembly != null
        ? widget.groupQuestionUpdatedAt[widget.assembly!.id.toString()]
        : null;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.assembly != null) ...[
            Padding(
              key: widget.tutorialAssemblyKey,
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Сборка ${widget.assembly!.number}',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                      StatusPill(
                        text: widget.assembly!.statusName ?? widget.assembly!.status,
                        color: parseHexColor(widget.assembly!.statusColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (widget.assembly!.name != null && widget.assembly!.name!.isNotEmpty)
                    Text(
                      widget.assembly!.name!,
                      style: const TextStyle(color: Colors.black54),
                    ),
                  // Отображение тарифа, упаковки, страховки и доставки
                  if (widget.assembly!.tariffName != null ||
                      widget.assembly!.packagingTypes.isNotEmpty ||
                      widget.assembly!.hasInsurance ||
                      widget.assembly!.deliveryMethod != null) ...[
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _showAssemblyDetails = !_showAssemblyDetails;
                        });
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.settings_outlined, size: 16, color: Colors.black54),
                              const SizedBox(width: 6),
                              const Text(
                                'Детали сборки',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              const Spacer(),
                              Icon(
                                _showAssemblyDetails ? Icons.expand_less : Icons.expand_more,
                                size: 20,
                                color: Colors.black54,
                              ),
                            ],
                          ),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeInOut,
                            alignment: Alignment.topCenter,
                            child: _showAssemblyDetails ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                              const SizedBox(height: 8),
                              if (widget.assembly!.tariffName != null) ...[
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.local_shipping_outlined,
                                      size: 16,
                                      color: Colors.black54,
                                    ),
                                    const SizedBox(width: 6),
                                    const Text(
                                      'Тариф: ',
                                      style: TextStyle(
                                        color: Colors.black54,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Flexible(
                                      child: Text(
                                        widget.assembly!.tariffName!,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if (widget.assembly!.packagingTypes.isNotEmpty) ...[
                                if (widget.assembly!.tariffName != null)
                                  const SizedBox(height: 8),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.inventory_2_outlined,
                                      size: 16,
                                      color: Colors.black54,
                                    ),
                                    const SizedBox(width: 6),
                                    const Text(
                                      'Упаковка: ',
                                      style: TextStyle(
                                        color: Colors.black54,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Expanded(
                                      child: Text.rich(
                                        TextSpan(
                                          children: [
                                            TextSpan(
                                              text: widget.assembly!.packagingTypes.join(', '),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if (widget.assembly!.hasInsurance) ...[
                                if (widget.assembly!.tariffName != null ||
                                    widget.assembly!.packagingTypes.isNotEmpty)
                                  const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.verified_user_outlined,
                                      size: 16,
                                      color: Colors.blue,
                                    ),
                                    const SizedBox(width: 6),
                                    const Text(
                                      'Страховка: ',
                                      style: TextStyle(
                                        color: Colors.black54,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      widget.assembly!.insuranceAmount != null
                                          ? 'от ${_formatDecimal(widget.assembly!.insuranceAmount!)} ¥'
                                          : 'Да',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                        color: Colors.blue,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              // Доставка
                              if (widget.assembly!.deliveryMethod != null) ...[
                                const SizedBox(height: 8),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      widget.assembly!.deliveryMethod == 'self_pickup'
                                          ? Icons.store_outlined
                                          : Icons.local_shipping_outlined,
                                      size: 16,
                                      color: Colors.orange,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            widget.assembly!.deliveryMethod == 'self_pickup'
                                                ? 'Самовывоз'
                                                : widget.assembly!.transportCompanyName != null && widget.assembly!.transportCompanyName!.isNotEmpty
                                                    ? 'ТК: ${widget.assembly!.transportCompanyName}'
                                                    : 'Транспортная компания',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                              color: Colors.orange,
                                            ),
                                          ),
                                          if (widget.assembly!.deliveryMethod == 'transport_company' &&
                                              widget.assembly!.recipientName != null) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              '${widget.assembly!.recipientName}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.black87,
                                              ),
                                            ),
                                            if (widget.assembly!.recipientPhone != null)
                                              Text(
                                                widget.assembly!.recipientPhone!,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.black54,
                                                ),
                                              ),
                                            if (widget.assembly!.recipientCity != null)
                                              Text(
                                                widget.assembly!.recipientCity!,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.black54,
                                                ),
                                              ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                        ) : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (groupComment.trim().isNotEmpty ||
                      groupQuestion.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0x0F000000),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (groupComment.trim().isNotEmpty) ...[
                            const Text(
                              'Заметка',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              groupComment,
                              style: const TextStyle(color: Colors.black54),
                            ),
                            if (groupQuestion.trim().isNotEmpty)
                              const SizedBox(height: 10),
                          ],
                          if (groupQuestion.trim().isNotEmpty) ...[
                            const Text(
                              'Вопрос',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              groupQuestion,
                              style: const TextStyle(color: Colors.black54),
                            ),
                            if (groupQuestionCreated != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                'Создан: ${df.format(groupQuestionCreated)}',
                                style: const TextStyle(color: Colors.black45),
                              ),
                            ],
                            if (groupQuestionUpdated != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                'Обновлён: ${df.format(groupQuestionUpdated)}',
                                style: const TextStyle(color: Colors.black45),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ],
                  // Коробки
                  if (widget.assembly!.boxes.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _showBoxes = !_showBoxes;
                        });
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                const Icon(Icons.inventory_2_outlined, size: 16, color: Colors.black54),
                                const SizedBox(width: 6),
                                Text(
                                  tr(context, ru: 'Коробки (${widget.assembly!.boxes.length})', zh: '箱子 (${widget.assembly!.boxes.length})'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                const Spacer(),
                                Icon(
                                  _showBoxes ? Icons.expand_less : Icons.expand_more,
                                  size: 20,
                                  color: Colors.black54,
                                ),
                              ],
                            ),
                          ),
                          // Отображаем каждую коробку
                          if (_showBoxes)
                            ...widget.assembly!.boxes.map((box) => _buildBoxCard(context, box)),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _ActionChipButton(
                        label: 'Добавить заметку',
                        onPressed: () => widget.onEditGroupComment(widget.assembly!),
                      ),
                      _ActionChipButton(
                        icon: Icons.local_shipping_outlined,
                        label: 'Доставка',
                        onPressed: () => widget.onSelectDelivery(widget.assembly!),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Заголовок «Треки (N)» — сворачиваемый
            GestureDetector(
              onTap: () => setState(() => _showTracks = !_showTracks),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                child: Row(
                  children: [
                    const Icon(Icons.local_shipping_outlined, size: 16, color: Colors.black54),
                    const SizedBox(width: 6),
                    Text(
                      'Треки (${widget.tracks.length})',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const Spacer(),
                    Icon(
                      _showTracks ? Icons.expand_less : Icons.expand_more,
                      size: 20,
                      color: Colors.black54,
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (_showTracks || widget.assembly == null)
          ...widget.tracks.asMap().entries.map((entry) {
            final index = entry.key;
            final track = entry.value;
            final canSelect = track.status == 'На складе';
            final allowedByStatus =
                widget.selectedStatus == null || widget.selectedStatus == track.status;
            final isSelected = widget.selectedTrackCodes.contains(track.code);

            final canAskQuestion = track.status == 'В ожидании' || track.status == 'На складе';
            final canRequestReturn = track.status == 'На складе' &&
                track.statusCode == 'in_warehouse' &&
                !widget.returnRequestedTracks.contains(track.code);
            final availableFillInfo =
                track.status == 'В ожидании' ||
                track.status == 'На складе' ||
                track.status == 'На сборке' ||
                track.status == 'Отправлен';
            final activePhoto = track.activePhotoRequest;
            final visibleQuestions = track.questions
                .where((q) => q.status != 'cancelled')
                .toList();
            final isPhotoRequested =
                activePhoto != null ||
                widget.requestedPhotoReports.contains(track.code);
            // Запросить можно только если трек в статусе «В ожидании» и ещё не запрошен
            final canRequestPhoto =
                track.status == 'В ожидании' && !isPhotoRequested;
            // Отменить можно только если статус запроса «new»
            final canCancelPhoto = activePhoto?.status == 'new';
            final commentText = widget.overrideComments[track.code] ?? track.comment;
            final pendingLocalQuestion = (widget.askedQuestions[track.code] ?? '').trim();
            final hasQuestion =
                visibleQuestions.isNotEmpty || pendingLocalQuestion.isNotEmpty;
            final photoCreated =
                activePhoto?.createdAt ?? widget.photoRequestCreatedAt[track.code];
            final photoUpdated =
                activePhoto?.completedAt ?? widget.photoRequestUpdatedAt[track.code];
            // Используем productInfo из API или локальной карты
            final apiProductInfo = track.productInfo;
            final localProductInfo = widget.productInfos[track.code];
            // Объединяем данные: приоритет у API, затем локальные данные
            final productInfoName =
                apiProductInfo?.name ?? localProductInfo?.name ?? '';
            final productInfoQuantity =
                apiProductInfo?.quantity ?? localProductInfo?.quantity;
            // Локальные изображения (после загрузки, до обновления страницы)
            // После обновления страницы — используем imageUrl из API как fallback
            final productInfoImages = (localProductInfo?.images.isNotEmpty == true)
                ? localProductInfo!.images
                : (apiProductInfo?.imageUrl?.isNotEmpty == true
                    ? [apiProductInfo!.imageUrl!]
                    : <String>[]);
            final hasProductInfo =
                productInfoName.isNotEmpty ||
                productInfoQuantity != null ||
                productInfoImages.isNotEmpty;

            final photoStatusLabel = activePhoto?.statusLabel ?? 'Новый';

            final List<Widget> infoSections = [];
            final commentValue = (commentText ?? '').trim();
            if (commentValue.isNotEmpty) {
              infoSections.add(
                _CollapsibleNote(
                  text: commentValue,
                  onEdit: () => widget.onEditComment(track),
                ),
              );
            }

            if (activePhoto != null || isPhotoRequested) {
              final photoNote = activePhoto?.wishes?.trim().isNotEmpty == true
                  ? activePhoto!.wishes!
                  : widget.photoRequestNotes[track.code] ?? '';

              // Собираем все фото/видео из разных источников (без дублей)
              final allMediaUrls = <String>[];
              final seenUrls = <String>{};
              if (activePhoto?.mediaUrls != null && activePhoto!.mediaUrls.isNotEmpty) {
                for (final url in activePhoto.mediaUrls) {
                  if (seenUrls.add(url)) allMediaUrls.add(url);
                }
              }
              if (track.photoReportUrls.isNotEmpty) {
                for (final url in track.photoReportUrls) {
                  if (seenUrls.add(url)) allMediaUrls.add(url);
                }
              }

              infoSections.add(
                _CollapsiblePhotoReport(
                  statusLabel: photoStatusLabel,
                  photoNote: photoNote,
                  canCancel: canCancelPhoto,
                  warehouseComment: activePhoto?.warehouseComment,
                  createdAt: photoCreated != null ? df.format(photoCreated) : null,
                  updatedAt: photoUpdated != null ? df.format(photoUpdated) : null,
                  mediaUrls: allMediaUrls,
                  trackCode: track.code,
                  photoCreatedDate: photoCreated,
                  onEditWish: () => widget.onEditPhotoWish(track),
                  onCancel: () => widget.onCancelPhotoRequest(track),
                ),
              );
            }

            if (hasQuestion) {
              // Показываем все видимые вопросы (из API)
              for (var i = 0; i < visibleQuestions.length; i++) {
                final q = visibleQuestions[i];
                final statusColor = q.hasAnswer
                    ? Colors.green
                    : q.status == 'cancelled'
                        ? Colors.red
                        : Colors.orange;
                infoSections.add(
                  _CollapsibleQuestion(
                    title: visibleQuestions.length > 1 ? 'Вопрос ${i + 1}' : 'Вопрос',
                    statusLabel: q.statusLabel,
                    statusColor: statusColor,
                    question: q.question,
                    answer: q.hasAnswer ? q.answer : null,
                    createdAt: df.format(q.createdAt),
                    answeredAt: q.answeredAt != null ? df.format(q.answeredAt!) : null,
                    canCancel: q.isActive,
                    onCancel: () => widget.onCancelQuestion(track),
                  ),
                );
              }
              // Показываем локально добавленный вопрос (ещё не сохранён в API)
              if (pendingLocalQuestion.isNotEmpty && visibleQuestions.isEmpty) {
                infoSections.add(
                  _CollapsibleQuestion(
                    title: 'Вопрос',
                    statusLabel: widget.questionStatus[track.code] ?? 'Новый',
                    statusColor: Colors.orange,
                    question: pendingLocalQuestion,
                    answer: null,
                    createdAt: df.format(DateTime.now()),
                    answeredAt: null,
                    canCancel: true,
                    onCancel: () => widget.onCancelQuestion(track),
                  ),
                );
              }
            }


            return Column(
              children: [
                if (index > 0)
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: Color(0x11000000),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (canSelect && allowedByStatus) ...[
                            Transform.translate(
                              offset: const Offset(-5, 0),
                              child: Checkbox(
                                value: isSelected,
                                onChanged: (_) => widget.onToggle(track),
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                            const SizedBox(width: 2),
                          ],
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: track.code));
                                HapticFeedback.lightImpact();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Трек скопирован'),
                                    duration: Duration(seconds: 1),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Text(
                                  track.code,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ),
                          ),
                          if (track.status != 'На сборке')
                            StatusPill(
                              text: track.status,
                              color: parseHexColor(track.statusColor),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        df.format(track.date),
                        style: const TextStyle(color: Colors.black54),
                      ),
                      if (hasProductInfo) ...[
                        const SizedBox(height: 8),
                        _ProductInfoInline(
                          name: productInfoName,
                          quantity: productInfoQuantity,
                          imageUrls: productInfoImages,
                          trackCode: track.code,
                          onEdit: () => widget.onEditProduct(track),
                        ),
                      ],
                      if (infoSections.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: const Color(0x0F000000),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (int i = 0; i < infoSections.length; i++) ...[
                                if (i > 0) const SizedBox(height: 10),
                                infoSections[i],
                              ],
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Wrap(
                        key: index == 0 ? widget.tutorialActionsKey : null,
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (canRequestPhoto)
                            _ActionChipButton(
                              label: 'Фотоотчёт',
                              icon: Icons.photo_camera_outlined,
                              onPressed: () => widget.onPhotoRequest(track),
                            ),
                          if (canAskQuestion && !hasQuestion)
                            _ActionChipButton(
                              label: 'Вопрос',
                              icon: Icons.help_outline_rounded,
                              onPressed: () => widget.onAskQuestion(track),
                            ),
                          if (commentValue.isEmpty)
                            _ActionChipButton(
                              label: 'Заметка',
                              icon: Icons.edit_note_rounded,
                              onPressed: () => widget.onEditComment(track),
                            ),
                          if (availableFillInfo && !hasProductInfo)
                            _ActionChipButton(
                              label: 'О товаре',
                              icon: Icons.inventory_2_outlined,
                              onPressed: () => widget.onEditProduct(track),
                            ),
                          if (canRequestReturn)
                            _ActionChipButton(
                              label: 'Возврат',
                              icon: Icons.assignment_return_outlined,
                              onPressed: () => widget.onReturnRequest(track),
                            ),
                          if (track.status == 'В ожидании')
                            _ActionChipButton(
                              label: 'Удалить',
                              icon: Icons.delete_outline_rounded,
                              isDestructive: true,
                              onPressed: () => widget.onDeleteTrack(track),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildBoxCard(BuildContext context, Box box) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Заголовок с номером коробки
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: context.brandPrimary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '#${box.number}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: context.brandPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                box.displayName(context),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Параметры коробки
          _buildBoxParam(context, icon: Icons.straighten, label: tr(context, ru: 'Габариты', zh: '尺寸'), value: box.dimensionsDisplay),
          const SizedBox(height: 6),
          _buildBoxParam(context, icon: Icons.scale, label: tr(context, ru: 'Вес', zh: '重量'), value: box.weightDisplay),
          const SizedBox(height: 6),
          _buildBoxParam(context, icon: Icons.inventory_2_outlined, label: tr(context, ru: 'Объём', zh: '体积'), value: box.volumeDisplay),
          const SizedBox(height: 6),
          _buildBoxParam(context, icon: Icons.compress, label: tr(context, ru: 'Плотность', zh: '密度'), value: box.densityDisplay),

          // Тариф и упаковка коробки (если отличаются от сборки)
          if (box.tariffName != null || box.packagingTypes.isNotEmpty || box.orderNumber != null) ...[
            const SizedBox(height: 8),
            if (box.orderNumber != null && box.orderNumber!.isNotEmpty)
              _buildBoxParam(context, icon: Icons.tag, label: tr(context, ru: 'Заказ', zh: '单号'), value: box.orderNumber!),
            if (box.orderNumber != null && box.orderNumber!.isNotEmpty && (box.tariffName != null || box.packagingTypes.isNotEmpty))
              const SizedBox(height: 6),
            if (box.tariffName != null)
              _buildBoxParam(context, icon: Icons.local_shipping_outlined, label: tr(context, ru: 'Тариф', zh: '费率'), value: box.tariffName!),
            if (box.tariffName != null && box.packagingTypes.isNotEmpty)
              const SizedBox(height: 6),
            if (box.packagingTypes.isNotEmpty)
              _buildBoxParam(context, icon: Icons.inventory_2_outlined, label: tr(context, ru: 'Упаковка', zh: '包装'), value: box.packagingTypes.join(', ')),
          ],
          // Фото на весах — одно большое
          if (box.photos.isNotEmpty) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () {
                final allPhotos = box.photos.map((p) => PhotoItem(
                  url: p.url,
                  date: DateTime.now(),
                )).toList();
                Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute<void>(
                    fullscreenDialog: true,
                    builder: (_) => PhotoViewerScreen(
                      item: allPhotos.first,
                      allPhotos: allPhotos,
                      initialIndex: 0,
                    ),
                  ),
                );
              },
              child: Container(
                width: double.infinity,
                height: 140,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: CachedNetworkImage(
                  imageUrl: ApiConfig.getMediaUrl(box.photos.first.url),
                  memCacheWidth: 400,
                  imageBuilder: (_, imageProvider) => DecoratedBox(
                    decoration: BoxDecoration(
                      image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
                    ),
                  ),
                  placeholder: (_, _) => const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  errorWidget: (_, _, _) => const Center(
                    child: Icon(Icons.broken_image_outlined, size: 24),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBoxParam(BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.black45),
        const SizedBox(width: 8),
        Text(
          '$label:',
          style: const TextStyle(
            fontSize: 13,
            color: Colors.black54,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        ),
      ],
    );
  }

}

class _DropdownItem<T> {
  final T value;
  final String label;

  const _DropdownItem({required this.value, required this.label});
}

/// Компактный dropdown-чип для фильтров в одну строку
class _MiniDropdown<T> extends StatelessWidget {
  final T value;
  final List<_DropdownItem<T>> items;
  final ValueChanged<T?> onChanged;

  const _MiniDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selected = items.firstWhere(
      (i) => i.value == value,
      orElse: () => items.first,
    );
    return GestureDetector(
      onTap: () {
        showModalBottomSheet<T>(
          context: context,
          useRootNavigator: true,
          backgroundColor: Colors.white,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          builder: (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 12),
                for (final item in items)
                  ListTile(
                    dense: true,
                    title: Text(
                      item.label,
                      style: TextStyle(
                        fontWeight: item.value == value ? FontWeight.w700 : FontWeight.w500,
                        color: item.value == value ? context.brandPrimary : Colors.black87,
                        fontSize: 14,
                      ),
                    ),
                    trailing: item.value == value
                        ? Icon(Icons.check_rounded, size: 18, color: context.brandPrimary)
                        : null,
                    onTap: () {
                      Navigator.pop(ctx);
                      onChanged(item.value);
                    },
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: const Color(0x0A000000),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              selected.label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54),
            ),
            const SizedBox(width: 2),
            const Icon(Icons.expand_more, size: 16, color: Colors.black38),
          ],
        ),
      ),
    );
  }
}

class _CustomDropdown<T> extends StatefulWidget {
  final T value;
  final String label;
  final List<_DropdownItem<T>> items;
  final ValueChanged<T?> onChanged;

  const _CustomDropdown({
    required this.value,
    required this.label,
    required this.items,
    required this.onChanged,
  });

  @override
  State<_CustomDropdown<T>> createState() => _CustomDropdownState<T>();
}

class _CustomDropdownState<T> extends State<_CustomDropdown<T>> {
  late T _selectedValue;
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();
  final GlobalKey _targetKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _selectedValue = widget.value;
  }

  @override
  void didUpdateWidget(_CustomDropdown<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _selectedValue = widget.value;
    }
  }

  void _showMenu() {
    final renderBox =
        _targetKey.currentContext?.findRenderObject() as RenderBox?;
    final double menuWidth = renderBox?.size.width ?? 200;
    _overlayEntry = OverlayEntry(
      builder: (context) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _hideMenu,
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              child: CompositedTransformFollower(
                link: _layerLink,
                showWhenUnlinked: false,
                offset: const Offset(0, 50),
                child: GestureDetector(
                  onTap: () {},
                  child: Material(
                    elevation: 8,
                    borderRadius: BorderRadius.circular(14),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: menuWidth,
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * 0.4, // 40% of screen height
                        ),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                        ),
                        child: ListView(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          physics: const ClampingScrollPhysics(),
                          children: widget.items.asMap().entries.map((entry) {
                          final index = entry.key;
                          final item = entry.value;
                          final isFirst = index == 0;
                          final isLast = index == widget.items.length - 1;

                          return InkWell(
                            onTap: () {
                              setState(() {
                                _selectedValue = item.value;
                              });
                              widget.onChanged(item.value);
                              _overlayEntry?.remove();
                              _overlayEntry = null;
                            },
                            // Добавляем borderRadius для InkWell эффекта
                            borderRadius: BorderRadius.vertical(
                              top: isFirst ? const Radius.circular(14) : Radius.zero,
                              bottom: isLast ? const Radius.circular(14) : Radius.zero,
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: _selectedValue == item.value
                                    ? context.brandPrimary.withValues(
                                        alpha: 0.1,
                                      )
                                    : Colors.transparent,
                                // Добавляем borderRadius для первого/последнего элемента
                                borderRadius: BorderRadius.vertical(
                                  top: isFirst ? const Radius.circular(14) : Radius.zero,
                                  bottom: isLast ? const Radius.circular(14) : Radius.zero,
                                ),
                              ),
                              child: Text(
                                item.label,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: _selectedValue == item.value
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  color: _selectedValue == item.value
                                      ? context.brandPrimary
                                      : Colors.black87,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                        ),
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
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideMenu() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    _hideMenu();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedLabel = widget.items
        .firstWhere(
          (item) => item.value == _selectedValue,
          orElse: () => _DropdownItem(value: _selectedValue, label: 'N/A'),
        )
        .label;

    return CompositedTransformTarget(
      link: _layerLink,
      child: GestureDetector(
        onTap: () {
          if (_overlayEntry == null) {
            _showMenu();
          } else {
            _hideMenu();
          }
        },
        child: Container(
          key: _targetKey,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade300, width: 1),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.label,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF999999),
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      selectedLabel,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
              Icon(
                _overlayEntry != null
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                color: context.brandPrimary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionChipButton extends StatelessWidget {
  final IconData? icon;
  final String? label;
  final VoidCallback? onPressed;
  final bool isDestructive;

  const _ActionChipButton({
    this.icon,
    this.label,
    required this.onPressed,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final gradient = context.brandGradient;
    final destructiveGradient = const LinearGradient(
      colors: [Color(0xFFFF5252), Color(0xFFD32F2F)],
    );
    final activeGradient = isDestructive ? destructiveGradient : gradient;
    final activeColor = isDestructive ? const Color(0xFFD32F2F) : context.brandPrimary;
    final isDisabled = onPressed == null;

    // Icon-only button (circular) — fallback if no label
    if (label == null && icon != null) {
      return Opacity(
        opacity: isDisabled ? 0.45 : 1,
        child: Container(
          decoration: BoxDecoration(gradient: activeGradient, shape: BoxShape.circle),
          padding: const EdgeInsets.all(1.5),
          child: Material(
            color: Colors.white,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onPressed,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(icon, size: 18, color: activeColor),
              ),
            ),
          ),
        ),
      );
    }

    // Text-only or text+icon button — compact chip style
    return Opacity(
      opacity: isDisabled ? 0.45 : 1,
      child: Material(
        color: isDestructive
            ? const Color(0x14FF5252)
            : const Color(0x0A000000),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 14, color: activeColor.withOpacity(0.7)),
                  const SizedBox(width: 4),
                ],
                if (label != null)
                  Text(
                    label!,
                    style: TextStyle(
                      color: isDestructive ? activeColor : Colors.black54,
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
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

class _GroupBucket {
  final TrackAssembly? assembly;
  final List<TrackItem> tracks;

  _GroupBucket({required this.assembly, required this.tracks});

  DateTime get latestDate {
    var latest = DateTime.fromMillisecondsSinceEpoch(0);
    for (final t in tracks) {
      if (t.date.isAfter(latest)) latest = t.date;
    }
    return latest;
  }
}

Widget _outlinedInput(
  BuildContext context,
  TextEditingController controller, {
  String? hint,
  TextInputType? keyboardType,
  List<TextInputFormatter>? inputFormatters,
  ValueChanged<String>? onChanged,
}) {
  return Container(
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
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.5),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            fontSize: 14,
            color: Color(0xFF999999),
            fontWeight: FontWeight.w500,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
        ),
      ),
    ),
  );
}

class _ProductInfo {
  final String name;
  final int? quantity;
  final List<String> images;

  _ProductInfo({
    required this.name,
    required this.quantity,
    required this.images,
  });
}

class _DeliveryOptionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _DeliveryOptionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? context.brandPrimary.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? context.brandPrimary : const Color(0xFFE0E0E0),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? context.brandPrimary.withValues(alpha: 0.15)
                    : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: isSelected ? context.brandPrimary : Colors.black54,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: isSelected ? context.brandPrimary : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: context.brandPrimary,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }
}

/// Определяет, является ли URL видео-файлом
bool _isVideoUrl(String url) {
  final lower = url.toLowerCase();
  return lower.endsWith('.mp4') ||
      lower.endsWith('.m4v') ||
      lower.endsWith('.webm') ||
      lower.endsWith('.mov');
}

/// Сворачиваемый блок «Заметка»
class _CollapsibleNote extends StatefulWidget {
  final String text;
  final VoidCallback? onEdit;

  const _CollapsibleNote({required this.text, this.onEdit});

  @override
  State<_CollapsibleNote> createState() => _CollapsibleNoteState();
}

class _CollapsibleNoteState extends State<_CollapsibleNote> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          behavior: HitTestBehavior.opaque,
          child: Row(
            children: [
              Icon(
                _expanded ? Icons.expand_less : Icons.expand_more,
                size: 20,
                color: Colors.black54,
              ),
              const SizedBox(width: 4),
              const Text(
                'Заметка',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: Colors.black87,
                ),
              ),
              if (widget.onEdit != null) ...[
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: widget.onEdit,
                  child: const Icon(Icons.edit_outlined, size: 16, color: Colors.black45),
                ),
              ],
              if (!_expanded) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black38,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: _expanded
              ? Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    widget.text,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

/// Инлайн блок «О товаре» — всегда развёрнут, под датой трека
class _ProductInfoInline extends StatelessWidget {
  final String name;
  final int? quantity;
  final List<String> imageUrls;
  final String trackCode;
  final VoidCallback? onEdit;

  const _ProductInfoInline({
    required this.name,
    this.quantity,
    required this.imageUrls,
    required this.trackCode,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final hasImages = imageUrls.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Название + количество + карандаш
        Row(
          children: [
            if (name.isNotEmpty)
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            if (quantity != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$quantity шт',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue,
                  ),
                ),
              ),
            ],
            if (onEdit != null) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onEdit,
                child: const Icon(Icons.edit_outlined,
                    size: 16, color: Colors.black45),
              ),
            ],
          ],
        ),
        if (hasImages) ...[
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () {
              final photo = PhotoItem(
                url: imageUrls.first,
                date: DateTime.now(),
                trackingNumber: trackCode,
              );
              Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute<void>(
                  fullscreenDialog: true,
                  builder: (_) => PhotoViewerScreen(
                    item: photo,
                    allPhotos: [photo],
                    initialIndex: 0,
                  ),
                ),
              );
            },
            child: Container(
              width: double.infinity,
              height: 120,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: CachedNetworkImage(
                imageUrl: ApiConfig.getMediaUrl(imageUrls.first),
                memCacheWidth: 400,
                imageBuilder: (_, imageProvider) => DecoratedBox(
                  decoration: BoxDecoration(
                    image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
                  ),
                ),
                placeholder: (_, _) => const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                errorWidget: (_, _, _) => const Center(
                  child: Icon(Icons.broken_image_outlined, size: 24),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Сворачиваемый блок фотоотчёта по треку
class _CollapsiblePhotoReport extends StatefulWidget {
  final String statusLabel;
  final String photoNote;
  final bool canCancel;
  final String? warehouseComment;
  final String? createdAt;
  final String? updatedAt;
  final List<String> mediaUrls;
  final String trackCode;
  final DateTime? photoCreatedDate;
  final VoidCallback onEditWish;
  final VoidCallback onCancel;

  const _CollapsiblePhotoReport({
    required this.statusLabel,
    required this.photoNote,
    required this.canCancel,
    this.warehouseComment,
    this.createdAt,
    this.updatedAt,
    required this.mediaUrls,
    required this.trackCode,
    this.photoCreatedDate,
    required this.onEditWish,
    required this.onCancel,
  });

  @override
  State<_CollapsiblePhotoReport> createState() => _CollapsiblePhotoReportState();
}

class _CollapsiblePhotoReportState extends State<_CollapsiblePhotoReport> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final statusColor = widget.statusLabel == 'Выполнен'
        ? Colors.green
        : widget.statusLabel == 'Отменён'
            ? Colors.red
            : Colors.orange;
    final hasPhotos = widget.mediaUrls.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Заголовок
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          behavior: HitTestBehavior.opaque,
          child: Row(
            children: [
              Icon(
                _expanded ? Icons.expand_less : Icons.expand_more,
                size: 20,
                color: Colors.black54,
              ),
              const SizedBox(width: 4),
              const Text(
                'Фотоотчёт',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: Colors.black87,
                ),
              ),
              if (hasPhotos) ...[
                const SizedBox(width: 6),
                Text(
                  '${widget.mediaUrls.length}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.black45,
                  ),
                ),
                const Icon(Icons.photo_outlined, size: 14, color: Colors.black45),
              ],
              if (widget.canCancel) ...[
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: widget.onEditWish,
                  child: const Icon(Icons.edit_outlined, size: 16, color: Colors.black45),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: widget.onCancel,
                  child: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                ),
              ],
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  widget.statusLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Раскрытый контент
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: _expanded
              ? Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Пожелание
                      if (widget.photoNote.isNotEmpty || widget.canCancel)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                widget.photoNote.isNotEmpty
                                    ? widget.photoNote
                                    : 'Пожелание не указано',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: widget.photoNote.isNotEmpty
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  color: widget.photoNote.isNotEmpty
                                      ? Colors.black87
                                      : Colors.black38,
                                ),
                              ),
                            ),
                            if (widget.canCancel)
                              GestureDetector(
                                onTap: widget.onEditWish,
                                child: const Icon(Icons.edit_outlined,
                                    size: 16, color: Colors.black45),
                              ),
                          ],
                        ),
                      // Комментарий от склада
                      if (widget.warehouseComment != null &&
                          widget.warehouseComment!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF8E1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: const Color(0xFFFFE082), width: 1),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Комментарий от склада',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFF57F17),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.warehouseComment!,
                                style: const TextStyle(
                                    fontSize: 13, color: Colors.black87),
                              ),
                            ],
                          ),
                        ),
                      ],
                      // Фото/видео — сетка 3 в ряду
                      if (hasPhotos) ...[
                        const SizedBox(height: 4),
                        GridView.builder(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 4,
                            mainAxisSpacing: 4,
                            childAspectRatio: 1,
                          ),
                          itemCount: widget.mediaUrls.length,
                          itemBuilder: (context, i) {
                            final fullUrl = ApiConfig.getMediaUrl(widget.mediaUrls[i]);
                            final isVideo = _isVideoUrl(fullUrl);
                            return GestureDetector(
                              onTap: () {
                                final allPhotos = widget.mediaUrls
                                    .map((url) => PhotoItem(
                                          url: url,
                                          date: widget.photoCreatedDate ?? DateTime.now(),
                                          trackingNumber: widget.trackCode,
                                        ))
                                    .toList();
                                Navigator.of(context, rootNavigator: true).push(
                                  MaterialPageRoute<void>(
                                    fullscreenDialog: true,
                                    builder: (_) => PhotoViewerScreen(
                                      item: allPhotos[i],
                                      allPhotos: allPhotos,
                                      initialIndex: i,
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                clipBehavior: Clip.antiAlias,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  color: Colors.black.withValues(alpha: 0.06),
                                ),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    CachedNetworkImage(
                                      imageUrl: fullUrl,
                                      memCacheWidth: 200,
                                      memCacheHeight: 200,
                                      imageBuilder: (context, imageProvider) => DecoratedBox(
                                        decoration: BoxDecoration(
                                          image: DecorationImage(
                                            image: imageProvider,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                      placeholder: (_, _) => const Center(
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                      errorWidget: (_, _, _) => const Center(
                                        child: Icon(Icons.broken_image_outlined, size: 20),
                                      ),
                                    ),
                                    if (isVideo)
                                      Center(
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(alpha: 0.6),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.play_arrow_rounded,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                      // Даты
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (widget.createdAt != null)
                            Text(
                              widget.createdAt!,
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.black38),
                            ),
                          if (widget.updatedAt != null) ...[
                            const Spacer(),
                            Text(
                              widget.updatedAt!,
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.black38),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

/// Сворачиваемый блок вопроса по треку
class _CollapsibleQuestion extends StatefulWidget {
  final String title;
  final String statusLabel;
  final Color statusColor;
  final String question;
  final String? answer;
  final String createdAt;
  final String? answeredAt;
  final bool canCancel;
  final VoidCallback? onCancel;

  const _CollapsibleQuestion({
    required this.title,
    required this.statusLabel,
    required this.statusColor,
    required this.question,
    this.answer,
    required this.createdAt,
    this.answeredAt,
    this.canCancel = false,
    this.onCancel,
  });

  @override
  State<_CollapsibleQuestion> createState() => _CollapsibleQuestionState();
}

class _CollapsibleQuestionState extends State<_CollapsibleQuestion>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Заголовок: тап для раскрытия
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          behavior: HitTestBehavior.opaque,
          child: Row(
            children: [
              Icon(
                _expanded ? Icons.expand_less : Icons.expand_more,
                size: 20,
                color: Colors.black54,
              ),
              const SizedBox(width: 4),
              Text(
                widget.title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: Colors.black87,
                ),
              ),
              if (widget.canCancel) ...[
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: widget.onCancel,
                  child: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                ),
              ],
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: widget.statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  widget.statusLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: widget.statusColor,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Раскрытый контент
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: _expanded
              ? Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.question.isNotEmpty)
                        Text(
                          widget.question,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: Colors.black87,
                          ),
                        ),
                      if (widget.answer != null &&
                          widget.answer!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          widget.answer!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            widget.createdAt,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.black38,
                            ),
                          ),
                          if (widget.answeredAt != null) ...[
                            const Spacer(),
                            Text(
                              widget.answeredAt!,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.black38,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
