// ignore_for_file: deprecated_member_use
import 'dart:async';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:twoalogisticcabineuser/src/core/ui/app_toast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phone_form_field/phone_form_field.dart';
import '../../../core/network/api_config.dart';
import '../../../core/ui/sheet_handle.dart';
import '../../../core/ui/app_colors.dart';
import '../../../core/ui/app_input_decoration.dart';
import '../../../core/ui/phone_input_field.dart';

import '../../../core/ui/app_layout.dart';
import '../../../core/ui/scroll_to_top_button.dart';
import '../../../core/ui/empty_state.dart';
import '../../../core/ui/status_pill.dart';
import '../../../core/ui/status_timeline_sheet.dart';
import '../../../core/utils/error_utils.dart';
import '../../../core/utils/clipboard_helper.dart';
import '../../../core/utils/image_compressor.dart';
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

String _fileNameWithExtension(String fileName, String extension) {
  final cleanExtension = extension.startsWith('.')
      ? extension.substring(1)
      : extension;
  if (cleanExtension.isEmpty) return fileName;

  final dotIndex = fileName.lastIndexOf('.');
  final baseName = dotIndex > 0 ? fileName.substring(0, dotIndex) : fileName;
  return '$baseName.$cleanExtension';
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

Future<void> _copyTrackCode(
  BuildContext context,
  String code, {
  bool compactToast = false,
}) async {
  final copied = await AppClipboard.copyText(code);
  if (!context.mounted) return;
  if (!copied) {
    _showStyledSnackBar(context, 'Не удалось скопировать', isError: true);
    return;
  }

  HapticFeedback.lightImpact();
  if (compactToast) {
    AppToast.showFromSnackBar(
      context,
      const SnackBar(
        content: Text('Трек скопирован'),
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
    return;
  }

  _showStyledSnackBar(context, 'Трек скопирован');
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
  final int? initialTrackId;
  final String? initialTrackCode;
  final int? initialAssemblyId;

  const TracksScreen({
    super.key,
    this.initialTrackId,
    this.initialTrackCode,
    this.initialAssemblyId,
  });

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
  String? _photoRequestStatusCode;
  String? _questionStatusCode;
  ViewMode _viewMode = ViewMode.singles;
  ProductInfoMode _productInfoMode = ProductInfoMode.all;
  DeliveryInfoMode _deliveryInfoMode = DeliveryInfoMode.all;
  TrackSortMode _sortMode = TrackSortMode.createdAt;
  String _query = '';
  bool _isSearchVisible = false;
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
  String? _handledInitialTargetKey;
  String? _filtersInitializedForClientCode;

  @override
  void initState() {
    super.initState();
    if (widget.initialAssemblyId != null) {
      _viewMode = ViewMode.groups;
    }
  }

  @override
  void didUpdateWidget(covariant TracksScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTrackId != widget.initialTrackId ||
        oldWidget.initialTrackCode != widget.initialTrackCode ||
        oldWidget.initialAssemblyId != widget.initialAssemblyId) {
      _handledInitialTargetKey = null;
      if (widget.initialAssemblyId != null) {
        _viewMode = ViewMode.groups;
      }
    }
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
                        Icon(
                          Icons.info_outline,
                          color: Colors.amber.shade700,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Фотоотчёт может быть платным. Ознакомьтесь с тарифами.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.amber.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  AppGradientInputFrame(
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
                        Icon(
                          Icons.info_outline,
                          color: Colors.amber.shade700,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Ответ на вопрос может быть только текстовым',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.amber.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  AppGradientInputFrame(
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
                  AppGradientInputFrame(
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
        _showStyledSnackBar(
          context,
          'Ошибка обновления пожелания',
          isError: true,
        );
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
        ref
            .read(paginatedTracksProvider(clientCode))
            .removeTrackOptimistically(trackId);
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFFFCC80),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.schedule_rounded,
                          size: 18,
                          color: Color(0xFFE65100),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Выберите время возврата с 13:00 до 15:00 по Китаю',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFFE65100),
                              fontWeight: FontWeight.w600,
                            ),
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
                  AppGradientInputFrame(
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
      _showStyledSnackBar(
        context,
        'Возврат оформлен. Склад получит уведомление.',
      );
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
                  AppGradientInputFrame(
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
                  AppGradientInputFrame(
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
              AppGradientInputFrame(
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
    final nameController = TextEditingController(
      text: assembly.recipientName ?? '',
    );
    final cityController = TextEditingController(
      text: assembly.recipientCity ?? '',
    );
    final transportCompanyController = TextEditingController(
      text: assembly.transportCompanyName ?? '',
    );

    final phoneController = PhoneController(
      initialValue:
          PhoneInputField.parse(assembly.recipientPhone) ??
          const PhoneNumber(isoCode: IsoCode.RU, nsn: ''),
    );

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
                              setSheetState(
                                () => selectedMethod = 'self_pickup',
                              );
                            },
                          ),
                          if (selectedMethod == 'self_pickup') ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF3CD),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFFFE69C),
                                ),
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
                              setSheetState(
                                () => selectedMethod = 'transport_company',
                              );
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
                            PhoneInputField(
                              controller: phoneController,
                              isRequired: true,
                              hintText: 'Телефон получателя',
                              textInputAction: TextInputAction.next,
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
                                  final phone = phoneController.value;
                                  if (phone.nsn.trim().isEmpty) {
                                    _showStyledSnackBar(
                                      sheetContext,
                                      'Укажите телефон получателя',
                                      isError: true,
                                    );
                                    return;
                                  }
                                  if (!phone.isValid()) {
                                    _showStyledSnackBar(
                                      sheetContext,
                                      'Введите корректный номер телефона',
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
                                  'recipientPhone':
                                      phoneController.value.international,
                                  'recipientCity': cityController.text.trim(),
                                  'transportCompanyName':
                                      transportCompanyController.text.trim(),
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

    nameController.dispose();
    cityController.dispose();
    transportCompanyController.dispose();
    phoneController.dispose();

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
                              final tempSelected = Set<int>.from(
                                selectedPackingIds,
                              );
                              await showModalBottomSheet<void>(
                                context: sheetContext,
                                useRootNavigator: true,
                                backgroundColor: Colors.white,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(16),
                                  ),
                                ),
                                builder: (ctx) => StatefulBuilder(
                                  builder: (ctx, setModalState) => SafeArea(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const SizedBox(height: 8),
                                        Container(
                                          width: 36,
                                          height: 4,
                                          decoration: BoxDecoration(
                                            color: Colors.black12,
                                            borderRadius: BorderRadius.circular(
                                              2,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        const Text(
                                          'Тип упаковки',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Flexible(
                                          child: ListView(
                                            shrinkWrap: true,
                                            children: packagingTypes.map((p) {
                                              final checked = tempSelected
                                                  .contains(p.id);
                                              return CheckboxListTile(
                                                dense: true,
                                                value: checked,
                                                activeColor:
                                                    context.brandPrimary,
                                                title: Text(
                                                  p.nameRu ?? p.name,
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                  ),
                                                ),
                                                onChanged: (v) {
                                                  setModalState(() {
                                                    if (v == true) {
                                                      tempSelected.add(p.id);
                                                    } else {
                                                      tempSelected.remove(p.id);
                                                    }
                                                  });
                                                },
                                              );
                                            }).toList(),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                            16,
                                            8,
                                            16,
                                            12,
                                          ),
                                          child: SizedBox(
                                            width: double.infinity,
                                            child: FilledButton(
                                              onPressed: () {
                                                Navigator.pop(ctx);
                                                setSheetState(() {
                                                  selectedPackingIds.clear();
                                                  selectedPackingIds.addAll(
                                                    tempSelected,
                                                  );
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0x0A000000),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.inventory_2_outlined,
                                    size: 18,
                                    color: context.brandPrimary,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: selectedPackingIds.isEmpty
                                        ? const Text(
                                            'Выбрать упаковку',
                                            style: TextStyle(
                                              color: Colors.black38,
                                              fontSize: 14,
                                            ),
                                          )
                                        : Wrap(
                                            spacing: 4,
                                            runSpacing: 4,
                                            children: selectedPackingIds.map((
                                              id,
                                            ) {
                                              final p = packagingTypes
                                                  .firstWhere(
                                                    (t) => t.id == id,
                                                  );
                                              return Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 3,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: context.brandPrimary
                                                      .withOpacity(0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  p.nameRu ?? p.name,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    color: context.brandPrimary,
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                  ),
                                  const Icon(
                                    Icons.expand_more,
                                    size: 18,
                                    color: Colors.black38,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Divider(height: 24),
                          // ── Страховка ──
                          Row(
                            children: [
                              Icon(
                                Icons.shield_outlined,
                                size: 18,
                                color: context.brandPrimary,
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'Страховка',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              const Spacer(),
                              Switch.adaptive(
                                value: selectedInsurance == 'yes',
                                activeColor: context.brandPrimary,
                                onChanged: (v) => setSheetState(
                                  () => selectedInsurance = v ? 'yes' : 'no',
                                ),
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
                                gradient:
                                    selectedPackingIds.isNotEmpty &&
                                        selectedTariff != null &&
                                        (selectedInsurance == 'no' ||
                                            (insuranceAmount?.isNotEmpty ==
                                                true))
                                    ? LinearGradient(
                                        colors: [
                                          context.brandPrimary,
                                          context.brandSecondary,
                                        ],
                                      )
                                    : null,
                                color: selectedPackingIds.isEmpty
                                    ? Colors.black12
                                    : null,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                onPressed:
                                    selectedPackingIds.isNotEmpty &&
                                        selectedTariff != null &&
                                        (selectedInsurance == 'no' ||
                                            (selectedInsurance == 'yes' &&
                                                insuranceAmount?.isNotEmpty ==
                                                    true))
                                    ? () => Navigator.of(sheetContext).pop(true)
                                    : null,
                                child: const Text(
                                  'Отправить на сборку',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
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
        while (notifier.state.hasMore &&
            !notifier.state.isLoading &&
            iterations < maxIterations) {
          await notifier.loadMore();
          iterations++;
          if (!context.mounted) return;
          if (notifier.state.error != null) break;
        }
        if (context.mounted) {
          Navigator.of(context, rootNavigator: true).pop(); // Убираем индикатор
        }
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
          return info == null ||
              (info.name == null || info.name!.trim().isEmpty);
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
                          Icon(
                            Icons.assignment_outlined,
                            color: Colors.orange.shade700,
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Требуется информация о товаре',
                            style: Theme.of(sheetCtx).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
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
                                  Icon(
                                    Icons.local_shipping_outlined,
                                    size: 16,
                                    color: Colors.orange.shade600,
                                  ),
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
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.orange.shade700,
                                    ),
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
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.orange.shade700,
                        ),
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
      final clientCodeId =
          trackClientCodeId ?? ref.read(activeClientCodeIdProvider);
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
    final nameController = TextEditingController(
      text: existing?.name ?? track.productInfo?.name ?? '',
    );
    final qtyController = TextEditingController(
      text:
          existing?.quantity?.toString() ??
          track.productInfo?.quantity.toString() ??
          '',
    );

    // Список путей/URL для отображения
    final images = List<String>.from(existing?.images ?? const []);
    if (track.productInfo?.imageUrl != null &&
        track.productInfo!.imageUrl!.isNotEmpty) {
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
                      Builder(
                        builder: (_) {
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
                                _showStyledSnackBar(
                                  context,
                                  'Не удалось открыть галерею: $e',
                                  isError: true,
                                );
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
                                        return Image.memory(
                                          snapshot.data!,
                                          fit: BoxFit.cover,
                                        );
                                      }
                                      return const Center(
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      );
                                    },
                                  )
                                : Image.file(
                                    File(file.path),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) =>
                                        const ColoredBox(color: Colors.black12),
                                  );
                          } else {
                            final path = images.first;
                            final isUrl =
                                path.startsWith('http') || path.startsWith('/');
                            imageWidget = isUrl
                                ? CachedNetworkImage(
                                    imageUrl: ApiConfig.getMediaUrl(path),
                                    memCacheWidth: 320,
                                    memCacheHeight: 240,
                                    maxWidthDiskCache: 640,
                                    maxHeightDiskCache: 480,
                                    fadeInDuration: Duration.zero,
                                    fadeOutDuration: Duration.zero,
                                    useOldImageOnUrlChange: false,
                                    filterQuality: FilterQuality.low,
                                    imageBuilder: (_, imageProvider) =>
                                        DecoratedBox(
                                          decoration: BoxDecoration(
                                            image: DecorationImage(
                                              image: imageProvider,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        ),
                                    placeholder: (_, _) => const Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    errorWidget: (_, _, _) =>
                                        const ColoredBox(color: Colors.black12),
                                  )
                                : (!kIsWeb
                                      ? Image.file(
                                          File(path),
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) =>
                                              const ColoredBox(
                                                color: Colors.black12,
                                              ),
                                        )
                                      : const ColoredBox(
                                          color: Colors.black12,
                                        ));
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
                                      BoxShadow(
                                        color: Color(0x14000000),
                                        blurRadius: 10,
                                        offset: Offset(0, 4),
                                      ),
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
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.swap_horiz,
                                          size: 16,
                                          color: Colors.white,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'Заменить',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
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
                        },
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
      },
    );
    if (result == true) {
      final productName = nameController.text.trim();
      final quantity = int.tryParse(qtyController.text.trim()) ?? 1;

      // Отправляем на сервер
      if (track.id != null) {
        final apiService = ref.read(tracksApiServiceProvider);

        String? uploadedImageUrl;
        var imageUploadFailed = false;

        // Загружаем первое новое изображение
        if (newFiles.isNotEmpty) {
          try {
            final sourceFile = newFiles.first;
            final sourceBytes = await sourceFile.readAsBytes();
            const maxMultipartSafeBytes = 9 * 1024 * 1024;
            var compressed = await ImageCompressor.compressForUpload(
              sourceBytes,
              sourceName: sourceFile.name,
            );
            if (compressed.bytes.lengthInBytes > maxMultipartSafeBytes) {
              compressed = await ImageCompressor.compressForUpload(
                sourceBytes,
                sourceName: sourceFile.name,
                maxSide: 1600,
                quality: 75,
              );
            }
            if (compressed.bytes.lengthInBytes > maxMultipartSafeBytes) {
              throw Exception('фото не удалось сжать до 10 MB');
            }
            final uploadFileName = _fileNameWithExtension(
              sourceFile.name,
              compressed.extension,
            );
            uploadedImageUrl = await apiService.uploadProductInfoImageFromBytes(
              track.id!,
              compressed.bytes,
              uploadFileName,
              mimeType: compressed.mimeType,
            );
            if (uploadedImageUrl == null) {
              throw Exception('сервер не вернул URL изображения');
            }
          } catch (e) {
            imageUploadFailed = true;
            debugPrint('Failed to upload image ${newFiles.first.name}: $e');
          }
        }

        if (imageUploadFailed) {
          if (!context.mounted) return;
          _showStyledSnackBar(
            context,
            'Не удалось загрузить фото товара',
            isError: true,
          );
          return;
        }

        final success = await apiService.updateProductInfo(
          trackId: track.id!,
          productName: productName,
          quantity: quantity,
          imageUrl:
              uploadedImageUrl ?? (images.isNotEmpty ? images.first : null),
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
          _showStyledSnackBar(
            context,
            'Ошибка сохранения на сервере',
            isError: true,
          );
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
    final isAssemblyMode = _viewMode == ViewMode.groups;
    return TracksFilterParams(
      clientCode: clientCode,
      statusCode: isAssemblyMode ? null : _statusCode,
      assemblyStatusCode: isAssemblyMode ? _statusCode : null,
      search: _query.isNotEmpty ? _query : null,
      viewMode: _viewMode == ViewMode.all
          ? 'all'
          : _viewMode == ViewMode.groups
          ? 'groups'
          : 'singles',
      productInfo: isAssemblyMode
          ? null
          : switch (_productInfoMode) {
              ProductInfoMode.all => null,
              ProductInfoMode.filled => 'filled',
              ProductInfoMode.empty => 'empty',
            },
      photoRequestStatus: isAssemblyMode ? null : _photoRequestStatusCode,
      questionStatus: isAssemblyMode ? null : _questionStatusCode,
      assemblyDeliveryInfo: !isAssemblyMode
          ? null
          : switch (_deliveryInfoMode) {
              DeliveryInfoMode.all => null,
              DeliveryInfoMode.filled => 'filled',
              DeliveryInfoMode.empty => 'empty',
            },
      sortBy: _sortMode.queryValue,
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

  void _onSortModeChanged(TrackSortMode mode, String clientCode) {
    setState(() => _sortMode = mode);

    final params = _getFilterParams(clientCode);
    ref.read(paginatedTracksProvider(clientCode)).updateFilters(params);
  }

  void _onDisplayModeChanged(ViewMode mode, String clientCode) {
    if (_viewMode == mode) return;
    setState(() {
      _viewMode = mode;
      // Статусы у треков и сборок разные, поэтому при переключении вкладки
      // сбрасываем выбранный статус, чтобы не применить нерелевантный код.
      _statusCode = null;
    });

    final params = _getFilterParams(clientCode);
    ref.read(paginatedTracksProvider(clientCode)).updateFilters(params);
  }

  void _maybeOpenInitialTarget(List<_GroupBucket> groups) {
    final hasTarget =
        widget.initialTrackId != null ||
        (widget.initialTrackCode?.isNotEmpty ?? false) ||
        widget.initialAssemblyId != null;
    if (!hasTarget || groups.isEmpty) return;

    final targetKey =
        '${widget.initialTrackId}|${widget.initialTrackCode}|${widget.initialAssemblyId}';
    if (_handledInitialTargetKey == targetKey) return;

    _GroupBucket? bucket;
    if (widget.initialAssemblyId != null) {
      for (final group in groups) {
        if (group.assembly?.id == widget.initialAssemblyId) {
          bucket = group;
          break;
        }
      }
    } else {
      for (final group in groups) {
        final hasTrack = group.tracks.any((track) {
          final idMatches =
              widget.initialTrackId != null &&
              track.id == widget.initialTrackId;
          final codeMatches =
              widget.initialTrackCode != null &&
              track.code.toLowerCase() ==
                  widget.initialTrackCode!.toLowerCase();
          return idMatches || codeMatches;
        });
        if (hasTrack) {
          bucket = group;
          break;
        }
      }
    }

    if (bucket == null) return;
    _handledInitialTargetKey = targetKey;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _openDigestTrackSheet(bucket!);
    });
  }

  Future<void> _openDigestTrackSheet(_GroupBucket bucket) async {
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.84,
        minChildSize: 0.45,
        maxChildSize: 0.96,
        expand: false,
        builder: (sheetContext, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            ),
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [const SheetHandle(), _buildTrackGroupCard(bucket)],
            ),
          );
        },
      ),
    );
  }

  _TrackGroupCard _buildTrackGroupCard(
    _GroupBucket group, {
    GlobalKey? tutorialActionsKey,
    GlobalKey? tutorialAssemblyKey,
  }) {
    return _TrackGroupCard(
      assembly: group.assembly,
      tracks: group.tracks,
      trackStatuses: ref.read(trackStatusesProvider).asData?.value ?? const [],
      assemblyStatuses:
          ref.read(assemblyStatusesProvider).asData?.value ?? const [],
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
      onSelectDelivery: (assembly) => _showDeliverySheet(context, assembly),
      onDeleteTrack: (track) => _deleteTrack(track),
      onReturnRequest: (track) => _showReturnSheet(context, track),
      returnRequestedTracks: _returnRequestedTracks,
      tutorialActionsKey: tutorialActionsKey,
      tutorialAssemblyKey: tutorialAssemblyKey,
    );
  }

  Widget _buildHeaderSection(
    BuildContext context, {
    required String clientCode,
    required PaginatedTracksState tracksState,
    required List<TrackStatus> trackStatuses,
    required List<TrackStatus> assemblyStatuses,
    required List<TrackStatus> photoRequestStatuses,
    required List<TrackStatus> questionStatuses,
  }) {
    final isAssemblyMode = _viewMode == ViewMode.groups;
    final activeFilters =
        _statusCode != null ||
        (isAssemblyMode
            ? _deliveryInfoMode != DeliveryInfoMode.all
            : _productInfoMode != ProductInfoMode.all ||
                  _photoRequestStatusCode != null ||
                  _questionStatusCode != null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 36,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Expanded(
                child: Text(
                  'Треки и сборки',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Gilroy',
                    fontSize: 24,
                    height: 29 / 24,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2F2F2F),
                    letterSpacing: 0,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              _HeaderIconButton(
                key: _filtersKey,
                icon: Icons.filter_alt_rounded,
                tooltip: 'Фильтр',
                isActive: activeFilters,
                onTap: () => _showTrackFiltersSheet(
                  clientCode,
                  tracksState.tracks,
                  trackStatuses: trackStatuses,
                  assemblyStatuses: assemblyStatuses,
                  photoRequestStatuses: photoRequestStatuses,
                  questionStatuses: questionStatuses,
                ),
              ),
              const SizedBox(width: 10),
              _HeaderIconButton(
                icon: Icons.swap_vert_rounded,
                tooltip: 'Сортировка',
                isActive: _sortMode != TrackSortMode.createdAt,
                onTap: () => _showSortSheet(clientCode),
              ),
              const SizedBox(width: 10),
              _HeaderIconButton(
                icon: Icons.search_rounded,
                tooltip: 'Поиск',
                isActive: _isSearchVisible || _query.isNotEmpty,
                onTap: () {
                  setState(() => _isSearchVisible = !_isSearchVisible);
                },
              ),
              const SizedBox(width: 10),
              _HeaderAddTrackButton(
                key: _fabKey,
                onTap: () => showAddTracksDialog(context, ref),
              ),
            ],
          ),
        ),
        const SizedBox(height: 15),
        _TracksViewModeSwitch(
          value: _viewMode == ViewMode.groups
              ? ViewMode.groups
              : ViewMode.singles,
          onChanged: (mode) => _onDisplayModeChanged(mode, clientCode),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: (_isSearchVisible || _query.isNotEmpty)
              ? Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: _TracksSearchField(
                    query: _query,
                    onChanged: (value) => _onSearchChanged(value, clientCode),
                    onClear: () {
                      setState(() {
                        _query = '';
                        _isSearchVisible = false;
                      });
                      _onSearchChanged('', clientCode);
                    },
                  ),
                )
              : const SizedBox.shrink(),
        ),
        const SizedBox(height: 15),
      ],
    );
  }

  Future<void> _showSortSheet(String clientCode) async {
    final selected = await showModalBottomSheet<TrackSortMode>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) => _TrackSortSheet(selected: _sortMode),
    );
    if (selected == null || selected == _sortMode || !mounted) return;
    _onSortModeChanged(selected, clientCode);
  }

  Future<void> _showTrackFiltersSheet(
    String clientCode,
    List<TrackItem> tracks, {
    required List<TrackStatus> trackStatuses,
    required List<TrackStatus> assemblyStatuses,
    required List<TrackStatus> photoRequestStatuses,
    required List<TrackStatus> questionStatuses,
  }) async {
    final result = await showModalBottomSheet<_TrackFiltersResult>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) => _TrackFiltersSheet(
        statusCode: _statusCode,
        viewMode: _viewMode,
        tracks: tracks,
        trackStatuses: trackStatuses,
        assemblyStatuses: assemblyStatuses,
        photoRequestStatuses: photoRequestStatuses,
        questionStatuses: questionStatuses,
        productInfoMode: _productInfoMode,
        photoRequestStatusCode: _photoRequestStatusCode,
        questionStatusCode: _questionStatusCode,
        deliveryInfoMode: _deliveryInfoMode,
      ),
    );
    if (result == null || !mounted) return;

    setState(() {
      _statusCode = result.statusCode;
      _productInfoMode = result.productInfoMode;
      _photoRequestStatusCode = result.photoRequestStatusCode;
      _questionStatusCode = result.questionStatusCode;
      _deliveryInfoMode = result.deliveryInfoMode;
    });
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
    if (_filtersInitializedForClientCode != clientCode) {
      _filtersInitializedForClientCode = clientCode;
      final initialFilters = _getFilterParams(clientCode);
      if (tracksState.filters != initialFilters) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ref
              .read(paginatedTracksProvider(clientCode))
              .updateFilters(initialFilters);
        });
      }
    }
    final trackStatuses =
        ref.watch(trackStatusesProvider).asData?.value ?? const <TrackStatus>[];
    final assemblyStatuses =
        ref.watch(assemblyStatusesProvider).asData?.value ??
        const <TrackStatus>[];
    final photoRequestStatuses =
        ref.watch(photoRequestStatusesProvider).asData?.value ??
        const <TrackStatus>[];
    final questionStatuses =
        ref.watch(questionStatusesProvider).asData?.value ??
        const <TrackStatus>[];
    final bottomPad = AppLayout.bottomScrollPadding(context);
    final topPad = AppLayout.topBarTotalHeight(context);
    const bulkButtonExtraPad = 72.0;

    final groups = tracksState.tracks.isNotEmpty
        ? _groupTracks(tracksState.tracks)
        : <_GroupBucket>[];
    _maybeOpenInitialTarget(groups);
    final bottomScrollPad =
        bottomPad + 16 + (_selectedTracks.isEmpty ? 0 : bulkButtonExtraPad + 8);

    return TutorialScreenWrapper(
      screenKey: 'tracks',
      steps: [
        TutorialStep(
          icon: Icons.local_shipping_rounded,
          title: 'Список треков',
          description:
              'Каждая строка — одна посылка. Цветной статус показывает этап: склад в Китае, в пути, склад в России или получено клиентом.',
          targetKey: _tracksListKey,
        ),
        TutorialStep(
          icon: Icons.add_circle_rounded,
          title: 'Добавить трек',
          description:
              'Нажмите кнопку «+» в верхней панели, чтобы добавить трек-номер новой посылки. Мы начнём её отслеживать.',
          targetKey: _fabKey,
        ),
        TutorialStep(
          icon: Icons.filter_list_rounded,
          title: 'Фильтр по статусу',
          description:
              'Нажмите на статус в верхней панели, чтобы показать только посылки на этом этапе. Удобно при большом количестве треков.',
          targetKey: _filtersKey,
        ),
        TutorialStep(
          icon: Icons.touch_app_rounded,
          title: 'Детали посылки',
          description:
              'Нажмите на трек, чтобы развернуть карточку с подробностями: вес, тариф, история статусов и кнопки действий.',
          targetKey: _trackDetailKey,
        ),
        TutorialStep(
          icon: Icons.photo_camera_rounded,
          title: 'Запросить фотоотчёт',
          description:
              'Кнопка «Запросить фотоотчёт» внутри карточки отправляет запрос на склад. Мы сфотографируем посылку и пришлём снимки. Услуга может быть платной.',
          targetKey: _actionsRowKey,
        ),
        TutorialStep(
          icon: Icons.help_outline_rounded,
          title: 'Задать вопрос',
          description:
              'Кнопка «Задать вопрос» открывает форму для обращения к менеджеру по конкретному треку. Ответ придёт в этой же карточке.',
          targetKey: _actionsRowKey,
        ),
        TutorialStep(
          icon: Icons.sticky_note_2_rounded,
          title: 'Комментарий к треку',
          description:
              'В карточке трека есть поле для заметки. Введите текст и нажмите «Сохранить заметку» — заметка видна только вам.',
          targetKey: _actionsRowKey,
        ),
        TutorialStep(
          icon: Icons.assignment_return_rounded,
          title: 'Оформить возврат',
          description:
              '«Оформить возврат» — открывает форму возврата товара. Укажите причину и код — заявка уйдёт на склад в Китае.',
          targetKey: _actionsRowKey,
        ),
        TutorialStep(
          icon: Icons.inventory_2_rounded,
          title: 'Сборка и доставка по РФ',
          description:
              'Блок сборки показывает транспортную компанию, коробки с весами, тариф и упаковку. Нажмите «Выбрать ТК» для настройки доставки.',
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
                  final canLoad =
                      _lastLoadMoreTime == null ||
                      now.difference(_lastLoadMoreTime!).inMilliseconds > 300;
                  if (maxScroll > 0 &&
                      currentScroll >= maxScroll * 0.9 &&
                      !tracksState.isLoading &&
                      tracksState.hasMore &&
                      tracksState.error == null &&
                      canLoad) {
                    _lastLoadMoreTime = now;
                    ref.read(paginatedTracksProvider(clientCode)).loadMore();
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
                    padding: EdgeInsets.fromLTRB(16, topPad * 0.7 + 16, 16, 0),
                    sliver: SliverToBoxAdapter(
                      child: _buildHeaderSection(
                        context,
                        clientCode: clientCode,
                        tracksState: tracksState,
                        trackStatuses: trackStatuses,
                        assemblyStatuses: assemblyStatuses,
                        photoRequestStatuses: photoRequestStatuses,
                        questionStatuses: questionStatuses,
                      ),
                    ),
                  ),
                  // Список треков или состояние (загрузка/ошибка/пусто)
                  ..._buildTracksList(
                    tracksState,
                    clientCode,
                    groups,
                    bottomScrollPad,
                  ),
                ],
              ),
            ),
          ),
          // Нижние кнопки выбора и отправки показываются только когда выбраны треки.
          if (_selectedTracks.isNotEmpty)
            Positioned(
              left: 16,
              right: 16,
              bottom:
                  AppLayout.bottomBarHeight +
                  AppLayout.bottomBarBottomMargin +
                  35, // Минимальный отступ от нижнего меню
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: OutlinedButton(
                      onPressed: () {
                        _selectAll();
                      },
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
              ),
            ),
          ScrollToTopButton(
            controller: _scrollController,
            bottomOffset:
                AppLayout.bottomBarHeight +
                AppLayout.bottomBarBottomMargin +
                37,
          ),
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
          addAutomaticKeepAlives: false,
          addSemanticIndexes: false,
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
            final isFirstAssembly =
                g.assembly != null &&
                groups.sublist(0, index).every((gr) => gr.assembly == null);
            final trackCard = _buildTrackGroupCard(
              g,
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
      bucket.tracks.sort(_compareTracksBySelectedSort);
    }
    list.sort((a, b) {
      final byDate = _latestGroupDate(b).compareTo(_latestGroupDate(a));
      if (byDate != 0) return byDate;
      final aId = a.tracks.isNotEmpty ? a.tracks.first.id ?? 0 : 0;
      final bId = b.tracks.isNotEmpty ? b.tracks.first.id ?? 0 : 0;
      return bId.compareTo(aId);
    });
    return list;
  }

  int _compareTracksBySelectedSort(TrackItem a, TrackItem b) {
    final byDate = _sortDate(b).compareTo(_sortDate(a));
    if (byDate != 0) return byDate;
    return (b.id ?? 0).compareTo(a.id ?? 0);
  }

  DateTime _sortDate(TrackItem track) {
    return _sortMode == TrackSortMode.updatedAt
        ? track.updatedAt
        : track.createdAt;
  }

  DateTime _latestGroupDate(_GroupBucket bucket) {
    var latest = DateTime.fromMillisecondsSinceEpoch(0);
    for (final track in bucket.tracks) {
      final date = _sortDate(track);
      if (date.isAfter(latest)) latest = date;
    }
    return latest;
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
      while (notifier.state.hasMore &&
          !notifier.state.isLoading &&
          iterations < maxIterations) {
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
      AppToast.showFromSnackBar(context, SnackBar(content: Text(text)));
    }
  }
}

enum ViewMode { all, groups, singles }

enum ProductInfoMode { all, filled, empty }

enum DeliveryInfoMode { all, filled, empty }

enum TrackSortMode { createdAt, updatedAt }

extension TrackSortModeX on TrackSortMode {
  String get queryValue => switch (this) {
    TrackSortMode.createdAt => 'createdAt',
    TrackSortMode.updatedAt => 'updatedAt',
  };

  String get label => switch (this) {
    TrackSortMode.createdAt => 'По дате добавления',
    TrackSortMode.updatedAt => 'По дате изменения',
  };
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool isActive;
  final VoidCallback onTap;

  const _HeaderIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? context.brandPrimary : const Color(0xFF2F2F2F);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 36,
            height: 36,
            child: Center(child: Icon(icon, size: 23, color: color)),
          ),
        ),
      ),
    );
  }
}

class _HeaderAddTrackButton extends StatelessWidget {
  final VoidCallback onTap;

  const _HeaderAddTrackButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Добавить треки',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: context.brandPrimary,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: context.brandPrimary.withValues(alpha: 0.28),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.add_box_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}

class _TracksViewModeSwitch extends StatelessWidget {
  final ViewMode value;
  final ValueChanged<ViewMode> onChanged;

  const _TracksViewModeSwitch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 25,
            offset: Offset(3, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _TracksViewModeSegment(
              label: 'Треки',
              selected: value == ViewMode.singles,
              onTap: () => onChanged(ViewMode.singles),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _TracksViewModeSegment(
              label: 'Сборки',
              selected: value == ViewMode.groups,
              onTap: () => onChanged(ViewMode.groups),
            ),
          ),
        ],
      ),
    );
  }
}

class _TracksViewModeSegment extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TracksViewModeSegment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: selected ? context.brandGradient : null,
            color: selected ? null : Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Gilroy',
              fontSize: 17,
              height: 20 / 17,
              fontWeight: FontWeight.w400,
              color: selected ? Colors.white : const Color(0xFF2F2F2F),
              letterSpacing: 0,
            ),
          ),
        ),
      ),
    );
  }
}

class _TracksSearchField extends StatefulWidget {
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _TracksSearchField({
    required this.query,
    required this.onChanged,
    required this.onClear,
  });

  @override
  State<_TracksSearchField> createState() => _TracksSearchFieldState();
}

class _TracksSearchFieldState extends State<_TracksSearchField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.query);
  }

  @override
  void didUpdateWidget(covariant _TracksSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query && _controller.text != widget.query) {
      _controller.text = widget.query;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 25,
            offset: Offset(3, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _controller,
        style: const TextStyle(
          fontFamily: 'Gilroy',
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Color(0xFF2F2F2F),
          letterSpacing: 0,
        ),
        decoration: InputDecoration(
          prefixIcon: Icon(
            Icons.search_rounded,
            color: context.brandPrimary,
            size: 22,
          ),
          suffixIcon: _controller.text.isNotEmpty
              ? IconButton(
                  onPressed: () {
                    _controller.clear();
                    widget.onClear();
                  },
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Color(0xFF8A8A8A),
                    size: 20,
                  ),
                )
              : null,
          hintText: 'Поиск по треку',
          hintStyle: const TextStyle(
            fontFamily: 'Gilroy',
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0x99000000),
            letterSpacing: 0,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          isDense: true,
        ),
        onChanged: (value) {
          setState(() {});
          widget.onChanged(value);
        },
      ),
    );
  }
}

class _TrackSortSheet extends StatelessWidget {
  final TrackSortMode selected;

  const _TrackSortSheet({required this.selected});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHandle(),
            const SizedBox(height: 12),
            const Text(
              'Сортировка',
              style: TextStyle(
                fontFamily: 'Gilroy',
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2F2F2F),
              ),
            ),
            const SizedBox(height: 12),
            for (final mode in TrackSortMode.values)
              _SheetOptionTile(
                title: mode.label,
                selected: mode == selected,
                onTap: () => Navigator.pop(context, mode),
              ),
          ],
        ),
      ),
    );
  }
}

class _TrackFiltersResult {
  final String? statusCode;
  final ProductInfoMode productInfoMode;
  final String? photoRequestStatusCode;
  final String? questionStatusCode;
  final DeliveryInfoMode deliveryInfoMode;

  const _TrackFiltersResult({
    required this.statusCode,
    required this.productInfoMode,
    required this.photoRequestStatusCode,
    required this.questionStatusCode,
    required this.deliveryInfoMode,
  });
}

class _StatusOption {
  final String? code;
  final String label;

  const _StatusOption({required this.code, required this.label});
}

class _TrackFiltersSheet extends StatefulWidget {
  final String? statusCode;
  final ViewMode viewMode;
  final List<TrackItem> tracks;
  final List<TrackStatus> trackStatuses;
  final List<TrackStatus> assemblyStatuses;
  final List<TrackStatus> photoRequestStatuses;
  final List<TrackStatus> questionStatuses;
  final ProductInfoMode productInfoMode;
  final String? photoRequestStatusCode;
  final String? questionStatusCode;
  final DeliveryInfoMode deliveryInfoMode;

  const _TrackFiltersSheet({
    required this.statusCode,
    required this.viewMode,
    required this.tracks,
    required this.trackStatuses,
    required this.assemblyStatuses,
    required this.photoRequestStatuses,
    required this.questionStatuses,
    required this.productInfoMode,
    required this.photoRequestStatusCode,
    required this.questionStatusCode,
    required this.deliveryInfoMode,
  });

  @override
  State<_TrackFiltersSheet> createState() => _TrackFiltersSheetState();
}

class _TrackFiltersSheetState extends State<_TrackFiltersSheet> {
  static const _noneStatusCode = 'none';

  late String? _statusCode = widget.statusCode;
  late ProductInfoMode _productInfoMode = widget.productInfoMode;
  late String? _photoRequestStatusCode = widget.photoRequestStatusCode;
  late String? _questionStatusCode = widget.questionStatusCode;
  late DeliveryInfoMode _deliveryInfoMode = widget.deliveryInfoMode;

  @override
  Widget build(BuildContext context) {
    final isAssemblyMode = widget.viewMode == ViewMode.groups;
    final statusOptions = _buildStatusOptions();
    final photoRequestOptions = _buildTaskStatusOptions(
      widget.photoRequestStatuses,
      _fallbackPhotoRequestStatuses(),
      noneLabel: 'Без запроса',
    );
    final questionOptions = _buildTaskStatusOptions(
      widget.questionStatuses,
      _fallbackQuestionStatuses(),
      noneLabel: 'Без вопроса',
    );

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHandle(),
            const SizedBox(height: 12),
            const Text(
              'Фильтр',
              style: TextStyle(
                fontFamily: 'Gilroy',
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2F2F2F),
              ),
            ),
            const SizedBox(height: 18),
            const _FilterSectionTitle('Статус'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in statusOptions)
                  _FilterChipButton(
                    label: option.label,
                    selected: option.code == _statusCode,
                    onTap: () => setState(() => _statusCode = option.code),
                  ),
              ],
            ),
            if (isAssemblyMode) ...[
              const SizedBox(height: 18),
              const _FilterSectionTitle('Данные доставки'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _FilterChipButton(
                    label: 'Все',
                    selected: _deliveryInfoMode == DeliveryInfoMode.all,
                    onTap: () => setState(
                      () => _deliveryInfoMode = DeliveryInfoMode.all,
                    ),
                  ),
                  _FilterChipButton(
                    label: 'Заполнены',
                    selected: _deliveryInfoMode == DeliveryInfoMode.filled,
                    onTap: () => setState(
                      () => _deliveryInfoMode = DeliveryInfoMode.filled,
                    ),
                  ),
                  _FilterChipButton(
                    label: 'Не заполнены',
                    selected: _deliveryInfoMode == DeliveryInfoMode.empty,
                    onTap: () => setState(
                      () => _deliveryInfoMode = DeliveryInfoMode.empty,
                    ),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 18),
              const _FilterSectionTitle('О товаре'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _FilterChipButton(
                    label: 'Все',
                    selected: _productInfoMode == ProductInfoMode.all,
                    onTap: () =>
                        setState(() => _productInfoMode = ProductInfoMode.all),
                  ),
                  _FilterChipButton(
                    label: 'Заполнено',
                    selected: _productInfoMode == ProductInfoMode.filled,
                    onTap: () => setState(
                      () => _productInfoMode = ProductInfoMode.filled,
                    ),
                  ),
                  _FilterChipButton(
                    label: 'Пусто',
                    selected: _productInfoMode == ProductInfoMode.empty,
                    onTap: () => setState(
                      () => _productInfoMode = ProductInfoMode.empty,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const _FilterSectionTitle('Фотоотчет'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final option in photoRequestOptions)
                    _FilterChipButton(
                      label: option.label,
                      selected: option.code == _photoRequestStatusCode,
                      onTap: () =>
                          setState(() => _photoRequestStatusCode = option.code),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              const _FilterSectionTitle('Вопросы'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final option in questionOptions)
                    _FilterChipButton(
                      label: option.label,
                      selected: option.code == _questionStatusCode,
                      onTap: () =>
                          setState(() => _questionStatusCode = option.code),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(
                      context,
                      const _TrackFiltersResult(
                        statusCode: null,
                        productInfoMode: ProductInfoMode.all,
                        photoRequestStatusCode: null,
                        questionStatusCode: null,
                        deliveryInfoMode: DeliveryInfoMode.all,
                      ),
                    ),
                    child: const Text('Сбросить'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: context.brandPrimary,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => Navigator.pop(
                      context,
                      _TrackFiltersResult(
                        statusCode: _statusCode,
                        productInfoMode: _productInfoMode,
                        photoRequestStatusCode: _photoRequestStatusCode,
                        questionStatusCode: _questionStatusCode,
                        deliveryInfoMode: _deliveryInfoMode,
                      ),
                    ),
                    child: const Text('Применить'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<_StatusOption> _buildStatusOptions() {
    final options = <_StatusOption>[
      const _StatusOption(code: null, label: 'Все'),
    ];
    final added = <String>{};
    final isAssemblyMode = widget.viewMode == ViewMode.groups;
    final statuses = isAssemblyMode
        ? widget.assemblyStatuses
        : widget.trackStatuses;

    for (final status in statuses) {
      if (status.code.isEmpty || added.contains(status.code)) continue;
      added.add(status.code);
      options.add(_StatusOption(code: status.code, label: status.nameRu));
    }

    for (final track in widget.tracks) {
      if (isAssemblyMode) {
        final assembly = track.assembly;
        if (assembly == null ||
            assembly.status.isEmpty ||
            added.contains(assembly.status)) {
          continue;
        }
        added.add(assembly.status);
        options.add(
          _StatusOption(
            code: assembly.status,
            label: assembly.statusName?.isNotEmpty == true
                ? assembly.statusName!
                : assembly.status,
          ),
        );
      } else {
        if (track.statusCode.isEmpty || added.contains(track.statusCode)) {
          continue;
        }
        added.add(track.statusCode);
        options.add(_StatusOption(code: track.statusCode, label: track.status));
      }
    }

    return options;
  }

  List<_StatusOption> _buildTaskStatusOptions(
    List<TrackStatus> statuses,
    Map<String, String> fallbackStatuses, {
    required String noneLabel,
  }) {
    final options = <_StatusOption>[
      const _StatusOption(code: null, label: 'Все'),
      _StatusOption(code: _noneStatusCode, label: noneLabel),
    ];
    final added = <String>{_noneStatusCode};

    for (final status in statuses) {
      if (status.code.isEmpty || added.contains(status.code)) continue;
      added.add(status.code);
      options.add(_StatusOption(code: status.code, label: status.nameRu));
    }

    for (final entry in fallbackStatuses.entries) {
      if (entry.key.isEmpty || added.contains(entry.key)) continue;
      added.add(entry.key);
      options.add(_StatusOption(code: entry.key, label: entry.value));
    }

    return options;
  }

  Map<String, String> _fallbackPhotoRequestStatuses() {
    final statuses = <String, String>{
      'new': 'Новый',
      'at_warehouse': 'На складе',
      'in_progress': 'Передан в работу',
      'assigned': 'Назначен ответственный',
      'completed': 'Выполнен',
      'cancelled': 'Отменён',
    };
    for (final track in widget.tracks) {
      for (final request in track.photoRequests) {
        statuses[request.status] = request.statusLabel;
      }
    }
    return statuses;
  }

  Map<String, String> _fallbackQuestionStatuses() {
    final statuses = <String, String>{
      'new': 'Новый',
      'at_warehouse': 'На складе',
      'in_progress': 'Передан в работу',
      'assigned': 'Назначен ответственный',
      'completed': 'Отвечен',
      'cancelled': 'Отменён',
    };
    for (final track in widget.tracks) {
      for (final question in track.questions) {
        statuses[question.status] = question.statusLabel;
      }
    }
    return statuses;
  }
}

class _FilterSectionTitle extends StatelessWidget {
  final String title;

  const _FilterSectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontFamily: 'Gilroy',
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Color(0xFF2F2F2F),
      ),
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChipButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? context.brandPrimary.withValues(alpha: 0.12)
              : const Color(0x0A000000),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? context.brandPrimary : const Color(0x00000000),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Gilroy',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? context.brandPrimary : const Color(0xB3000000),
          ),
        ),
      ),
    );
  }
}

class _SheetOptionTile extends StatelessWidget {
  final String title;
  final bool selected;
  final VoidCallback onTap;

  const _SheetOptionTile({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        style: TextStyle(
          fontFamily: 'Gilroy',
          fontSize: 15,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          color: selected ? context.brandPrimary : const Color(0xFF2F2F2F),
        ),
      ),
      trailing: selected
          ? Icon(Icons.check_rounded, color: context.brandPrimary)
          : null,
      onTap: onTap,
    );
  }
}

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
        AppGradientInputFrame(
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              prefixIcon: Icon(
                Icons.search_rounded,
                color: context.brandPrimary,
                size: 22,
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Color(0xFF999999),
                        size: 20,
                      ),
                      onPressed: () {
                        _searchController.selection =
                            const TextSelection.collapsed(offset: 0);
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
  final ProductInfoMode productInfoMode;
  final String query;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<ViewMode> onViewModeChanged;
  final ValueChanged<ProductInfoMode> onProductInfoModeChanged;
  final ValueChanged<String> onQueryChanged;
  const _FiltersNew({
    required this.statusCode,
    required this.tracks,
    required this.viewMode,
    required this.productInfoMode,
    required this.query,
    required this.onStatusChanged,
    required this.onViewModeChanged,
    required this.onProductInfoModeChanged,
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Поиск — занимает оставшееся место
        Container(
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
                  size: 20,
                ),
                prefixIconConstraints: const BoxConstraints(minWidth: 36),
                suffixIcon: _searchController.text.isNotEmpty
                    ? GestureDetector(
                        onTap: () {
                          _searchController.selection =
                              const TextSelection.collapsed(offset: 0);
                          _searchController.clear();
                          widget.onQueryChanged('');
                        },
                        child: const Icon(
                          Icons.close_rounded,
                          color: Color(0xFF999999),
                          size: 18,
                        ),
                      )
                    : null,
                suffixIconConstraints: const BoxConstraints(minWidth: 36),
                hintText: 'Поиск по треку',
                hintStyle: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF999999),
                ),
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
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // Вид
              _MiniDropdown<ViewMode>(
                value: widget.viewMode,
                items: const [
                  _DropdownItem(value: ViewMode.all, label: 'Все'),
                  _DropdownItem(value: ViewMode.groups, label: 'Сборки'),
                  _DropdownItem(value: ViewMode.singles, label: 'Одиночные'),
                ],
                onChanged: (v) =>
                    v != null ? widget.onViewModeChanged(v) : null,
              ),
              const SizedBox(width: 6),
              // Статус
              _MiniDropdown<String?>(
                value: widget.statusCode,
                items: statusItems,
                onChanged: (v) => widget.onStatusChanged(v),
              ),
              const SizedBox(width: 6),
              _MiniDropdown<ProductInfoMode>(
                value: widget.productInfoMode,
                items: const [
                  _DropdownItem(
                    value: ProductInfoMode.all,
                    label: 'О товаре: все',
                  ),
                  _DropdownItem(
                    value: ProductInfoMode.filled,
                    label: 'О товаре: заполнено',
                  ),
                  _DropdownItem(
                    value: ProductInfoMode.empty,
                    label: 'О товаре: пусто',
                  ),
                ],
                onChanged: (v) =>
                    v != null ? widget.onProductInfoModeChanged(v) : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TrackGroupCard extends StatefulWidget {
  final TrackAssembly? assembly;
  final List<TrackItem> tracks;
  final List<TrackStatus> trackStatuses;
  final List<TrackStatus> assemblyStatuses;
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
    required this.trackStatuses,
    required this.assemblyStatuses,
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
  bool _showDelivery = false;
  bool _showBoxes = false;
  bool _showTracks = false;
  bool _showAssemblyDetails = false;

  List<StatusTimelineStatus> _timelineStatuses(List<TrackStatus> statuses) {
    return statuses
        .map(
          (status) => StatusTimelineStatus(
            code: status.code,
            name: status.nameRu.isNotEmpty ? status.nameRu : status.code,
            color: parseHexColor(status.color),
            sortOrder: status.sortOrder,
          ),
        )
        .toList(growable: false);
  }

  void _showTrackStatusTimeline(BuildContext context, TrackItem track) {
    showStatusTimelineSheet(
      context: context,
      title: 'Статус трека',
      currentStatusCode: track.statusCode,
      currentStatusName: track.status,
      currentStatusColor: parseHexColor(track.statusColor),
      history: track.statusHistory,
      statuses: _timelineStatuses(widget.trackStatuses),
    );
  }

  void _showAssemblyStatusTimeline(
    BuildContext context,
    TrackAssembly assembly,
  ) {
    showStatusTimelineSheet(
      context: context,
      title: 'Статус сборки',
      currentStatusCode: assembly.status,
      currentStatusName: assembly.statusName?.isNotEmpty == true
          ? assembly.statusName!
          : assembly.status,
      currentStatusColor: parseHexColor(assembly.statusColor),
      history: assembly.statusHistory,
      statuses: _timelineStatuses(widget.assemblyStatuses),
    );
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd MMM yyyy', 'ru');
    // Используем комментарий из локального кэша или из данных сборки
    final groupComment = widget.assembly != null
        ? (widget.groupComments[widget.assembly!.id.toString()] ??
              widget.assembly!.comment ??
              '')
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
    if (widget.assembly == null && widget.tracks.length == 1) {
      return _buildTrackCard(context, df, widget.tracks.first);
    }
    if (widget.assembly != null) {
      return _buildAssemblyCard(context);
    }

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(10)),
        boxShadow: [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 26,
            offset: Offset(3, 4),
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
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _showAssemblyStatusTimeline(
                          context,
                          widget.assembly!,
                        ),
                        child: StatusPill(
                          text:
                              widget.assembly!.statusName ??
                              widget.assembly!.status,
                          color: parseHexColor(widget.assembly!.statusColor),
                          truncate: false,
                          textStyle: const TextStyle(
                            fontFamily: 'Gilroy',
                            fontSize: 14,
                            height: 16 / 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (widget.assembly!.name != null &&
                      widget.assembly!.name!.isNotEmpty)
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
                              const Icon(
                                Icons.settings_outlined,
                                size: 16,
                                color: Colors.black54,
                              ),
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
                                _showAssemblyDetails
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                                size: 20,
                                color: Colors.black54,
                              ),
                            ],
                          ),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeInOut,
                            alignment: Alignment.topCenter,
                            child: _showAssemblyDetails
                                ? Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 8),
                                      if (widget.assembly!.tariffName !=
                                          null) ...[
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
                                      if (widget
                                          .assembly!
                                          .packagingTypes
                                          .isNotEmpty) ...[
                                        if (widget.assembly!.tariffName != null)
                                          const SizedBox(height: 8),
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
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
                                                      text: widget
                                                          .assembly!
                                                          .packagingTypes
                                                          .join(', '),
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
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
                                        if (widget.assembly!.tariffName !=
                                                null ||
                                            widget
                                                .assembly!
                                                .packagingTypes
                                                .isNotEmpty)
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
                                              widget
                                                          .assembly!
                                                          .insuranceAmount !=
                                                      null
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
                                      if (widget.assembly!.deliveryMethod !=
                                          null) ...[
                                        const SizedBox(height: 8),
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Icon(
                                              widget.assembly!.deliveryMethod ==
                                                      'self_pickup'
                                                  ? Icons.store_outlined
                                                  : Icons
                                                        .local_shipping_outlined,
                                              size: 16,
                                              color: Colors.orange,
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    widget
                                                                .assembly!
                                                                .deliveryMethod ==
                                                            'self_pickup'
                                                        ? 'Самовывоз'
                                                        : widget
                                                                      .assembly!
                                                                      .transportCompanyName !=
                                                                  null &&
                                                              widget
                                                                  .assembly!
                                                                  .transportCompanyName!
                                                                  .isNotEmpty
                                                        ? 'ТК: ${widget.assembly!.transportCompanyName}'
                                                        : 'Транспортная компания',
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 13,
                                                      color: Colors.orange,
                                                    ),
                                                  ),
                                                  if (widget
                                                              .assembly!
                                                              .deliveryMethod ==
                                                          'transport_company' &&
                                                      widget
                                                              .assembly!
                                                              .recipientName !=
                                                          null) ...[
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      '${widget.assembly!.recipientName}',
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.black87,
                                                      ),
                                                    ),
                                                    if (widget
                                                            .assembly!
                                                            .recipientPhone !=
                                                        null)
                                                      Text(
                                                        widget
                                                            .assembly!
                                                            .recipientPhone!,
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                          color: Colors.black54,
                                                        ),
                                                      ),
                                                    if (widget
                                                            .assembly!
                                                            .recipientCity !=
                                                        null)
                                                      Text(
                                                        widget
                                                            .assembly!
                                                            .recipientCity!,
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
                                  )
                                : const SizedBox.shrink(),
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
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.96),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.orange.withValues(alpha: 0.22),
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x0A000000),
                                    offset: Offset(0, 3),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const _QuestionBadge(
                                        color: Colors.orange,
                                      ),
                                      const SizedBox(width: 9),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Вопрос по сборке',
                                              style: TextStyle(
                                                fontFamily: 'Gilroy',
                                                fontWeight: FontWeight.w800,
                                                fontSize: 14,
                                                color: Color(0xFF2F2F2F),
                                              ),
                                            ),
                                            if (groupQuestionCreated !=
                                                null) ...[
                                              const SizedBox(height: 3),
                                              Text(
                                                'Создан: ${df.format(groupQuestionCreated)}',
                                                style: const TextStyle(
                                                  fontFamily: 'Gilroy',
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.black45,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const _TaskStatusBadge(
                                        text: 'Новый',
                                        color: Colors.orange,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  _QuestionTextPanel(
                                    title: 'Вопрос',
                                    text: groupQuestion,
                                  ),
                                  if (groupQuestionUpdated != null) ...[
                                    const SizedBox(height: 8),
                                    _QuestionMetaPill(
                                      icon: CupertinoIcons.clock,
                                      text:
                                          'Обновлён: ${df.format(groupQuestionUpdated)}',
                                      color: Colors.black54,
                                    ),
                                  ],
                                ],
                              ),
                            ),
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
                                const Icon(
                                  Icons.inventory_2_outlined,
                                  size: 16,
                                  color: Colors.black54,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  tr(
                                    context,
                                    ru: 'Коробки (${widget.assembly!.boxes.length})',
                                    zh: '箱子 (${widget.assembly!.boxes.length})',
                                  ),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                const Spacer(),
                                Icon(
                                  _showBoxes
                                      ? Icons.expand_less
                                      : Icons.expand_more,
                                  size: 20,
                                  color: Colors.black54,
                                ),
                              ],
                            ),
                          ),
                          // Отображаем каждую коробку
                          if (_showBoxes)
                            ...widget.assembly!.boxes.map(
                              (box) => _buildBoxCard(context, box),
                            ),
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
                        onPressed: () =>
                            widget.onEditGroupComment(widget.assembly!),
                      ),
                      _ActionChipButton(
                        icon: Icons.local_shipping_outlined,
                        label: 'Доставка',
                        onPressed: () =>
                            widget.onSelectDelivery(widget.assembly!),
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
                    const Icon(
                      Icons.local_shipping_outlined,
                      size: 16,
                      color: Colors.black54,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      // Используем реальное количество треков в сборке с бэка
                      // (не зависит от пагинации и загруженной страницы).
                      'Треки (${widget.assembly?.trackCount ?? widget.tracks.length})',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
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
                  widget.selectedStatus == null ||
                  widget.selectedStatus == track.status;
              final isSelected = widget.selectedTrackCodes.contains(track.code);

              final canAskQuestion =
                  track.status == 'В ожидании' || track.status == 'На складе';
              final canRequestReturn =
                  track.status == 'На складе' &&
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
              final commentText =
                  widget.overrideComments[track.code] ?? track.comment;
              final pendingLocalQuestion =
                  (widget.askedQuestions[track.code] ?? '').trim();
              final hasQuestion =
                  visibleQuestions.isNotEmpty ||
                  pendingLocalQuestion.isNotEmpty;
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
              final productInfoImages =
                  (localProductInfo?.images.isNotEmpty == true)
                  ? localProductInfo!.images
                  : (apiProductInfo?.imageUrl?.isNotEmpty == true
                        ? [apiProductInfo!.imageUrl!]
                        : <String>[]);
              final hasProductInfo =
                  productInfoName.isNotEmpty ||
                  productInfoQuantity != null ||
                  productInfoImages.isNotEmpty;

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
                      title: visibleQuestions.length > 1
                          ? 'Вопрос ${i + 1}'
                          : 'Вопрос',
                      statusLabel: q.statusLabel,
                      statusColor: statusColor,
                      question: q.question,
                      answer: q.hasAnswer ? q.answer : null,
                      createdAt: df.format(q.createdAt),
                      answeredAt: q.answeredAt != null
                          ? df.format(q.answeredAt!)
                          : null,
                      canCancel: q.isActive,
                      onCancel: () => widget.onCancelQuestion(track),
                    ),
                  );
                }
                // Показываем локально добавленный вопрос (ещё не сохранён в API)
                if (pendingLocalQuestion.isNotEmpty &&
                    visibleQuestions.isEmpty) {
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
                                onTap: () => _copyTrackCode(
                                  context,
                                  track.code,
                                  compactToast: true,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Text(
                                    track.code,
                                    style: const TextStyle(
                                      fontFamily: 'Gilroy',
                                      fontSize: 16,
                                      height: 24 / 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              ),
                            ),
                            if (track.status != 'На сборке')
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () =>
                                    _showTrackStatusTimeline(context, track),
                                child: StatusPill(
                                  text: track.status,
                                  color: parseHexColor(track.statusColor),
                                  truncate: false,
                                  textStyle: const TextStyle(
                                    fontFamily: 'Gilroy',
                                    fontSize: 14,
                                    height: 16 / 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
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
                                for (
                                  int i = 0;
                                  i < infoSections.length;
                                  i++
                                ) ...[
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

  Widget _buildTrackCard(
    BuildContext context,
    DateFormat df,
    TrackItem track, {
    bool embeddedInAssembly = false,
  }) {
    final canSelect = track.status == 'На складе';
    final allowedByStatus =
        widget.selectedStatus == null || widget.selectedStatus == track.status;
    final canShowCheckbox = !embeddedInAssembly && canSelect && allowedByStatus;
    final isSelected = widget.selectedTrackCodes.contains(track.code);

    final canAskQuestion =
        track.status == 'В ожидании' || track.status == 'На складе';
    final canRequestReturn =
        track.status == 'На складе' &&
        track.statusCode == 'in_warehouse' &&
        !widget.returnRequestedTracks.contains(track.code);
    final availableFillInfo =
        track.status == 'В ожидании' ||
        track.status == 'На складе' ||
        track.status == 'На сборке' ||
        track.status == 'Отправлен';
    final canEditProductInfo = embeddedInAssembly || availableFillInfo;

    final activePhoto = track.activePhotoRequest;
    final visibleQuestions = track.questions
        .where((q) => q.status != 'cancelled')
        .toList();
    final isPhotoRequested =
        activePhoto != null ||
        widget.requestedPhotoReports.contains(track.code);
    final canRequestPhoto = track.status == 'В ожидании' && !isPhotoRequested;
    final canCancelPhoto = activePhoto?.status == 'new';

    final commentText = widget.overrideComments[track.code] ?? track.comment;
    final commentValue = (commentText ?? '').trim();
    final pendingLocalQuestion = (widget.askedQuestions[track.code] ?? '')
        .trim();
    final hasQuestion =
        visibleQuestions.isNotEmpty || pendingLocalQuestion.isNotEmpty;

    final photoCreated =
        activePhoto?.createdAt ?? widget.photoRequestCreatedAt[track.code];
    final photoUpdated =
        activePhoto?.completedAt ?? widget.photoRequestUpdatedAt[track.code];
    final photoStatusLabel = activePhoto?.statusLabel ?? 'Новый';
    final photoMediaUrls = _collectPhotoMediaUrls(track, activePhoto);

    final apiProductInfo = track.productInfo;
    final localProductInfo = widget.productInfos[track.code];
    final productInfoName =
        apiProductInfo?.name ?? localProductInfo?.name ?? '';
    final productInfoQuantity =
        apiProductInfo?.quantity ?? localProductInfo?.quantity;
    final productInfoImages = (localProductInfo?.images.isNotEmpty == true)
        ? localProductInfo!.images
        : (apiProductInfo?.imageUrl?.isNotEmpty == true
              ? [apiProductInfo!.imageUrl!]
              : <String>[]);
    final hasProductInfo =
        productInfoName.isNotEmpty ||
        productInfoQuantity != null ||
        productInfoImages.isNotEmpty;

    final infoSections = <Widget>[];
    if (commentValue.isNotEmpty) {
      infoSections.add(
        _CollapsibleNote(
          text: commentValue,
          onEdit: () => widget.onEditComment(track),
        ),
      );
    }
    if (hasQuestion) {
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
            canCancel: !embeddedInAssembly && q.isActive,
            onCancel: () => widget.onCancelQuestion(track),
          ),
        );
      }
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
            canCancel: !embeddedInAssembly,
            onCancel: () => widget.onCancelQuestion(track),
          ),
        );
      }
    }

    final actions = <_TrackCardAction>[
      if (!embeddedInAssembly && canRequestPhoto)
        _TrackCardAction(
          label: 'Фотоотчет',
          onTap: () => widget.onPhotoRequest(track),
        ),
      if (!embeddedInAssembly && canAskQuestion && !hasQuestion)
        _TrackCardAction(
          label: 'Вопрос',
          onTap: () => widget.onAskQuestion(track),
        ),
      if (commentValue.isEmpty)
        _TrackCardAction(
          label: 'Заметка',
          onTap: () => widget.onEditComment(track),
        ),
      if (canEditProductInfo && !hasProductInfo)
        _TrackCardAction(
          label: 'О товаре',
          onTap: () => widget.onEditProduct(track),
        ),
      if (!embeddedInAssembly && canRequestReturn)
        _TrackCardAction(
          label: 'Возврат',
          onTap: () => widget.onReturnRequest(track),
        ),
    ];

    final activeQuestion = track.activeQuestion;
    final questionDone =
        activeQuestion?.hasAnswer == true ||
        activeQuestion?.status == 'completed';
    final questionPending = activeQuestion != null && !questionDone;
    final photoDone =
        photoMediaUrls.isNotEmpty || activePhoto?.status == 'completed';
    final photoPending = activePhoto != null && !photoDone;
    final statusColor = parseHexColor(track.statusColor);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            offset: Offset(3, 4),
            blurRadius: 26,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTrackCardHeader(
              context,
              track: track,
              canShowCheckbox: canShowCheckbox,
              isSelected: isSelected,
              statusColor: statusColor,
              photoDone: photoDone,
              photoPending: photoPending,
              questionDone: questionDone,
              questionPending: questionPending,
              hasProductInfo: hasProductInfo,
              actions: actions,
              canDelete: !embeddedInAssembly && track.status == 'В ожидании',
              showStatusAndMarkers: !embeddedInAssembly,
              onPhotoMarkerTap: () => _handlePhotoMarkerTap(
                context,
                track: track,
                activePhoto: activePhoto,
                mediaUrls: photoMediaUrls,
                statusLabel: photoStatusLabel,
                createdAt: photoCreated,
                updatedAt: photoUpdated,
                canRequestPhoto: canRequestPhoto,
                canCancelPhoto: canCancelPhoto,
              ),
              onProductMarkerTap: () => _handleProductMarkerTap(
                context,
                track: track,
                canEdit: canEditProductInfo || hasProductInfo,
              ),
              onQuestionMarkerTap: () => _handleQuestionMarkerTap(
                context,
                track: track,
                canAskQuestion: canAskQuestion,
                visibleQuestions: visibleQuestions,
                pendingLocalQuestion: pendingLocalQuestion,
              ),
            ),
            if (hasProductInfo || photoMediaUrls.isNotEmpty) ...[
              const SizedBox(height: 15),
              _buildTrackCardMediaSection(
                context,
                track: track,
                productName: productInfoName,
                productQuantity: productInfoQuantity,
                productImageUrls: productInfoImages,
                photoMediaUrls: photoMediaUrls,
                hasProductInfo: hasProductInfo,
              ),
            ],
            if (infoSections.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0x0F000000),
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.all(10),
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
          ],
        ),
      ),
    );
  }

  Widget _buildAssemblyCard(BuildContext context) {
    final assembly = widget.assembly!;
    final statusColor = parseHexColor(assembly.statusColor);
    final createdAt = _assemblyCreatedAt();
    final updatedAt = _assemblyUpdatedAt();

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            offset: Offset(3, 4),
            blurRadius: 26,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildAssemblyHeader(
              context,
              assembly: assembly,
              createdAt: createdAt,
              updatedAt: updatedAt,
              statusColor: statusColor,
            ),
            const SizedBox(height: 15),
            _buildAssemblyActions(context, assembly),
            const SizedBox(height: 15),
            _buildAssemblyDeliveryBlock(context, assembly),
            if (assembly.boxes.isNotEmpty) ...[
              const SizedBox(height: 15),
              _buildAssemblyBoxesBlock(context, assembly),
            ],
            if (widget.tracks.isNotEmpty) ...[
              const SizedBox(height: 15),
              _buildAssemblyTracksBlock(context, assembly),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAssemblyHeader(
    BuildContext context, {
    required TrackAssembly assembly,
    required DateTime? createdAt,
    required DateTime? updatedAt,
    required Color? statusColor,
  }) {
    final dateFormat = DateFormat('dd.MM.yy', 'ru');
    final dateColor = const Color(0xFF2F2F2F).withValues(alpha: 0.5);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                assembly.number,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF2F2F2F),
                  fontFamily: 'Gilroy',
                  fontSize: 16,
                  height: 24 / 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 5),
              Opacity(
                opacity: 0.5,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 2,
                  children: [
                    if (createdAt != null)
                      _TrackDateMeta(
                        icon: CupertinoIcons.plus_circle,
                        value: dateFormat.format(createdAt),
                        color: dateColor,
                      ),
                    if (updatedAt != null)
                      _TrackDateMeta(
                        icon: CupertinoIcons.arrow_2_circlepath_circle,
                        value: dateFormat.format(updatedAt),
                        color: dateColor,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _showAssemblyStatusTimeline(context, assembly),
          child: _AssemblyStatusPill(
            text: assembly.statusName?.isNotEmpty == true
                ? assembly.statusName!
                : assembly.status,
            color: statusColor ?? const Color(0xFFB8E1C8),
          ),
        ),
      ],
    );
  }

  Widget _buildAssemblyActions(BuildContext context, TrackAssembly assembly) {
    final accent = context.brandPrimary;
    return SizedBox(
      height: 24,
      child: Row(
        children: [
          Row(
            children: [
              _TrackCardActionChip(
                action: _TrackCardAction(
                  label: 'Заметка',
                  onTap: () => widget.onEditGroupComment(assembly),
                ),
                accent: accent,
              ),
              const SizedBox(width: 5),
              _TrackCardActionChip(
                action: _TrackCardAction(
                  label: 'Доставка',
                  onTap: () => widget.onSelectDelivery(assembly),
                ),
                accent: accent,
              ),
            ],
          ),
          const Spacer(),
          _TrackDeleteButton(
            onTap: () {
              HapticFeedback.lightImpact();
              _showStyledSnackBar(
                context,
                'Удаление сборки недоступно',
                isError: true,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAssemblyDeliveryBlock(
    BuildContext context,
    TrackAssembly assembly,
  ) {
    final lines = _assemblyDeliveryLines(assembly);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _AssemblySectionHeader(
          title: 'Доставка',
          isExpanded: _showDelivery,
          onTap: () => setState(() => _showDelivery = !_showDelivery),
        ),
        if (_showDelivery) ...[
          const SizedBox(height: 3),
          Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: 237,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < lines.length; i++) ...[
                    if (i > 0) const SizedBox(height: 5),
                    _AssemblyPlainText(lines[i]),
                  ],
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAssemblyBoxesBlock(
    BuildContext context,
    TrackAssembly assembly,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _AssemblySectionHeader(
          title: 'Коробки (${assembly.boxes.length})',
          isExpanded: _showBoxes,
          onTap: () => setState(() => _showBoxes = !_showBoxes),
        ),
        if (_showBoxes) ...[
          const SizedBox(height: 7),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < assembly.boxes.length; i++) ...[
                if (i > 0) const SizedBox(height: 15),
                _buildAssemblyBoxRow(context, assembly, assembly.boxes[i]),
              ],
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildAssemblyTracksBlock(
    BuildContext context,
    TrackAssembly assembly,
  ) {
    final df = DateFormat('dd MMM yyyy', 'ru');
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _AssemblySectionHeader(
          title: 'Трек-номера (${assembly.trackCount ?? widget.tracks.length})',
          isExpanded: _showTracks,
          onTap: () => setState(() => _showTracks = !_showTracks),
        ),
        if (_showTracks) ...[
          const SizedBox(height: 7),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < widget.tracks.length; i++) ...[
                if (i > 0) const SizedBox(height: 20),
                _buildTrackCard(
                  context,
                  df,
                  widget.tracks[i],
                  embeddedInAssembly: true,
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildAssemblyBoxRow(
    BuildContext context,
    TrackAssembly assembly,
    Box box,
  ) {
    final photos = box.photos.map((photo) => photo.url).where((url) {
      return url.trim().isNotEmpty;
    }).toList();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: photos.isEmpty
              ? null
              : () => _openAssemblyMediaViewer(context, photos),
          child: Container(
            width: 154,
            height: 124,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: const Color(0xFFC4C4C4),
              borderRadius: BorderRadius.circular(10),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1A000000),
                  offset: Offset(3, 4),
                  blurRadius: 25,
                ),
              ],
            ),
            child: photos.isEmpty
                ? const SizedBox.shrink()
                : CachedNetworkImage(
                    imageUrl: ApiConfig.getMediaUrl(photos.first),
                    memCacheWidth: 220,
                    memCacheHeight: 220,
                    maxWidthDiskCache: 440,
                    maxHeightDiskCache: 440,
                    fadeInDuration: Duration.zero,
                    fadeOutDuration: Duration.zero,
                    useOldImageOnUrlChange: false,
                    filterQuality: FilterQuality.low,
                    imageBuilder: (_, imageProvider) => DecoratedBox(
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
                      child: Icon(Icons.broken_image_outlined, size: 22),
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AssemblyInvoiceText(
                value: (box.orderNumber ?? assembly.number).trim(),
              ),
              const SizedBox(height: 3),
              _AssemblyPlainText('Габариты: ${_boxDimensionsForDesign(box)}'),
              const SizedBox(height: 3),
              _AssemblyPlainText('Вес: ${_formatDecimal(box.weight)} кг'),
              const SizedBox(height: 3),
              _AssemblyPlainText('Объём: ${box.volume.toStringAsFixed(4)} м³'),
              const SizedBox(height: 3),
              _AssemblyPlainText(
                'Плотность: ${box.density.toStringAsFixed(0)} кг/м3',
              ),
              const SizedBox(height: 3),
              _AssemblyPlainText(
                'Тариф: ${box.tariffName ?? assembly.tariffName ?? '—'}',
              ),
              const SizedBox(height: 3),
              _AssemblyPlainText(
                'Упаковка: ${_boxPackagingForDesign(box, assembly)}',
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<String> _assemblyDeliveryLines(TrackAssembly assembly) {
    final isTransport = assembly.deliveryMethod == 'transport_company';
    final deliveryType = assembly.deliveryMethod == null
        ? '—'
        : isTransport
        ? ((assembly.transportCompanyName ?? '').trim().isNotEmpty
              ? assembly.transportCompanyName!.trim()
              : 'Транспортная компания')
        : 'Самовывоз';
    return [
      'Тип доставки: $deliveryType',
      'ФИО получателя: ${_emptyDash(assembly.recipientName)}',
      'Телефон: ${_emptyDash(assembly.recipientPhone)}',
      'Адрес доставки: ${_emptyDash(assembly.recipientCity)}',
    ];
  }

  String _boxDimensionsForDesign(Box box) {
    return '${box.height.toStringAsFixed(0)}x${box.width.toStringAsFixed(0)}x${box.length.toStringAsFixed(0)} см';
  }

  String _boxPackagingForDesign(Box box, TrackAssembly assembly) {
    final values = box.packagingTypes.isNotEmpty
        ? box.packagingTypes
        : assembly.packagingTypes;
    return values.isEmpty ? '—' : values.join(', ');
  }

  String _emptyDash(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? '—' : trimmed;
  }

  DateTime? _assemblyCreatedAt() {
    DateTime? result;
    for (final track in widget.tracks) {
      final value = track.createdAt;
      if (result == null || value.isBefore(result)) result = value;
    }
    return result;
  }

  DateTime? _assemblyUpdatedAt() {
    DateTime? result;
    for (final track in widget.tracks) {
      final value = track.updatedAt;
      if (result == null || value.isAfter(result)) result = value;
    }
    return result;
  }

  void _openAssemblyMediaViewer(
    BuildContext context,
    List<String> mediaUrls, {
    int initialIndex = 0,
  }) {
    if (mediaUrls.isEmpty) return;
    final safeInitialIndex = initialIndex
        .clamp(0, mediaUrls.length - 1)
        .toInt();
    final photos = mediaUrls
        .map((url) => PhotoItem(url: url, date: DateTime.now()))
        .toList();
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => PhotoViewerScreen(
          item: photos[safeInitialIndex],
          allPhotos: photos,
          initialIndex: safeInitialIndex,
        ),
      ),
    );
  }

  void _handlePhotoMarkerTap(
    BuildContext context, {
    required TrackItem track,
    required PhotoRequest? activePhoto,
    required List<String> mediaUrls,
    required String statusLabel,
    required DateTime? createdAt,
    required DateTime? updatedAt,
    required bool canRequestPhoto,
    required bool canCancelPhoto,
  }) {
    HapticFeedback.selectionClick();
    final hasRequestedPhoto =
        activePhoto != null ||
        widget.requestedPhotoReports.contains(track.code) ||
        mediaUrls.isNotEmpty;
    if (hasRequestedPhoto) {
      final note = activePhoto?.wishes?.trim().isNotEmpty == true
          ? activePhoto!.wishes!.trim()
          : widget.photoRequestNotes[track.code]?.trim() ?? '';
      _showPhotoRequestDetailsSheet(
        context,
        track: track,
        statusLabel: activePhoto == null && mediaUrls.isNotEmpty
            ? 'Выполнен'
            : statusLabel,
        note: note,
        warehouseComment: activePhoto?.warehouseComment,
        createdAt: createdAt,
        updatedAt: updatedAt,
        mediaUrls: mediaUrls,
        canEdit: canCancelPhoto && activePhoto != null,
        canCancel: canCancelPhoto,
      );
      return;
    }

    if (canRequestPhoto) {
      widget.onPhotoRequest(track);
      return;
    }

    _showStyledSnackBar(
      context,
      'Фотоотчёт недоступен для этого статуса',
      isError: true,
    );
  }

  void _handleProductMarkerTap(
    BuildContext context, {
    required TrackItem track,
    required bool canEdit,
  }) {
    HapticFeedback.selectionClick();
    if (canEdit) {
      widget.onEditProduct(track);
      return;
    }

    _showStyledSnackBar(
      context,
      'Информация о товаре недоступна для этого статуса',
      isError: true,
    );
  }

  void _handleQuestionMarkerTap(
    BuildContext context, {
    required TrackItem track,
    required bool canAskQuestion,
    required List<TrackQuestion> visibleQuestions,
    required String pendingLocalQuestion,
  }) {
    HapticFeedback.selectionClick();
    if (visibleQuestions.isNotEmpty || pendingLocalQuestion.isNotEmpty) {
      _showQuestionDetailsSheet(
        context,
        track: track,
        visibleQuestions: visibleQuestions,
        pendingLocalQuestion: pendingLocalQuestion,
      );
      return;
    }

    if (canAskQuestion) {
      widget.onAskQuestion(track);
      return;
    }

    _showStyledSnackBar(
      context,
      'Вопрос недоступен для этого статуса',
      isError: true,
    );
  }

  Future<void> _showPhotoRequestDetailsSheet(
    BuildContext context, {
    required TrackItem track,
    required String statusLabel,
    required String note,
    required String? warehouseComment,
    required DateTime? createdAt,
    required DateTime? updatedAt,
    required List<String> mediaUrls,
    required bool canEdit,
    required bool canCancel,
  }) async {
    final df = DateFormat('dd.MM.yyyy', 'ru');
    final statusColor = _taskStatusColor(statusLabel);
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SheetHandle(),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Фотоотчёт',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    _TaskStatusBadge(text: statusLabel, color: statusColor),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  track.code,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                _TaskDetailBlock(
                  title: 'Пожелание',
                  text: note.isNotEmpty ? note : 'Пожелание не указано',
                  muted: note.isEmpty,
                ),
                if (warehouseComment?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 10),
                  _TaskDetailBlock(
                    title: 'Комментарий склада',
                    text: warehouseComment!.trim(),
                  ),
                ],
                if (mediaUrls.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Фото и видео',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  GridView.builder(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    physics: const NeverScrollableScrollPhysics(),
                    addAutomaticKeepAlives: false,
                    addSemanticIndexes: false,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 6,
                          mainAxisSpacing: 6,
                          childAspectRatio: 1,
                        ),
                    itemCount: mediaUrls.length,
                    itemBuilder: (itemContext, index) {
                      final fullUrl = ApiConfig.getMediaUrl(mediaUrls[index]);
                      final isVideo = _isVideoUrl(fullUrl);
                      return GestureDetector(
                        onTap: () {
                          Navigator.of(sheetContext).pop();
                          _openMediaViewer(context, mediaUrls, track, index);
                        },
                        child: Container(
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              CachedNetworkImage(
                                imageUrl: fullUrl,
                                memCacheWidth: 160,
                                memCacheHeight: 160,
                                maxWidthDiskCache: 320,
                                maxHeightDiskCache: 320,
                                fadeInDuration: Duration.zero,
                                fadeOutDuration: Duration.zero,
                                useOldImageOnUrlChange: false,
                                filterQuality: FilterQuality.low,
                                imageBuilder: (_, imageProvider) =>
                                    DecoratedBox(
                                      decoration: BoxDecoration(
                                        image: DecorationImage(
                                          image: imageProvider,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                placeholder: (_, _) => const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                errorWidget: (_, _, _) => const Center(
                                  child: Icon(
                                    Icons.broken_image_outlined,
                                    size: 20,
                                  ),
                                ),
                              ),
                              if (isVideo)
                                Center(
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(
                                        alpha: 0.6,
                                      ),
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
                if (createdAt != null || updatedAt != null) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    children: [
                      if (createdAt != null)
                        _TaskDateLabel(
                          label: 'Создан',
                          value: df.format(createdAt),
                        ),
                      if (updatedAt != null)
                        _TaskDateLabel(
                          label: 'Обновлён',
                          value: df.format(updatedAt),
                        ),
                    ],
                  ),
                ],
                if (canEdit || canCancel) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      if (canEdit)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.of(sheetContext).pop();
                              widget.onEditPhotoWish(track);
                            },
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            label: const Text('Изменить'),
                          ),
                        ),
                      if (canEdit && canCancel) const SizedBox(width: 10),
                      if (canCancel)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.of(sheetContext).pop();
                              widget.onCancelPhotoRequest(track);
                            },
                            icon: const Icon(Icons.delete_outline, size: 18),
                            label: const Text('Отменить'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showQuestionDetailsSheet(
    BuildContext context, {
    required TrackItem track,
    required List<TrackQuestion> visibleQuestions,
    required String pendingLocalQuestion,
  }) async {
    final df = DateFormat('dd.MM.yyyy', 'ru');
    final items = <_QuestionDetailsItem>[
      for (var i = 0; i < visibleQuestions.length; i++)
        _QuestionDetailsItem.fromQuestion(
          visibleQuestions[i],
          visibleQuestions.length > 1 ? 'Вопрос ${i + 1}' : 'Вопрос',
        ),
      if (pendingLocalQuestion.isNotEmpty && visibleQuestions.isEmpty)
        _QuestionDetailsItem(
          title: 'Вопрос',
          statusLabel: widget.questionStatus[track.code] ?? 'Новый',
          statusColor: Colors.orange,
          question: pendingLocalQuestion,
          answer: null,
          createdAt: widget.questionCreatedAt[track.code] ?? DateTime.now(),
          answeredAt: null,
          canCancel: true,
        ),
    ];
    if (items.isEmpty) return;
    final canCancelAny = items.any((item) => item.canCancel);

    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SheetHandle(),
                const SizedBox(height: 12),
                Text(
                  'Вопрос по треку',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  track.code,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const SizedBox(height: 12),
                  _QuestionDetailsCard(item: items[i], dateFormat: df),
                ],
                if (canCancelAny) ...[
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      widget.onCancelQuestion(track);
                    },
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Отменить вопрос'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _taskStatusColor(String statusLabel) {
    final normalized = statusLabel.toLowerCase();
    if (normalized.contains('выполн') || normalized.contains('отвеч')) {
      return const Color(0xFF27C47A);
    }
    if (normalized.contains('отмен')) return Colors.redAccent;
    return context.brandPrimary;
  }

  Widget _buildTrackCardHeader(
    BuildContext context, {
    required TrackItem track,
    required bool canShowCheckbox,
    required bool isSelected,
    required Color? statusColor,
    required bool photoDone,
    required bool photoPending,
    required bool questionDone,
    required bool questionPending,
    required bool hasProductInfo,
    required List<_TrackCardAction> actions,
    required bool canDelete,
    required VoidCallback onPhotoMarkerTap,
    required VoidCallback onProductMarkerTap,
    required VoidCallback onQuestionMarkerTap,
    required bool showStatusAndMarkers,
  }) {
    final dateFormat = DateFormat('dd.MM.yy', 'ru');
    final accent = context.brandPrimary;
    final dateColor = const Color(0xFF2F2F2F).withValues(alpha: 0.5);

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 76),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (canShowCheckbox) ...[
                          _TrackCheckbox(
                            value: isSelected,
                            accent: accent,
                            onTap: () => widget.onToggle(track),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Flexible(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _copyTrackCode(context, track.code),
                            child: Text(
                              track.code,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF2F2F2F),
                                fontFamily: 'Gilroy',
                                fontSize: 16,
                                height: 24 / 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Opacity(
                      opacity: 0.5,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 2,
                        children: [
                          _TrackDateMeta(
                            icon: CupertinoIcons.plus_circle,
                            value: dateFormat.format(track.createdAt),
                            color: dateColor,
                          ),
                          _TrackDateMeta(
                            icon: CupertinoIcons.arrow_2_circlepath_circle,
                            value: dateFormat.format(track.updatedAt),
                            color: dateColor,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (showStatusAndMarkers) ...[
                const SizedBox(width: 10),
                IntrinsicWidth(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _showTrackStatusTimeline(context, track),
                        child: _TrackCardStatusPill(
                          text: track.status,
                          color: statusColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 24,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _TrackMarkerIcon(
                              icon: CupertinoIcons.camera_circle,
                              color: _trackMarkerColor(
                                context,
                                done: photoDone,
                                pending: photoPending,
                              ),
                              tooltip: 'Фотоотчёт',
                              onTap: onPhotoMarkerTap,
                            ),
                            const SizedBox(width: 5),
                            _TrackMarkerIcon(
                              icon: CupertinoIcons.info_circle,
                              color: _trackMarkerColor(
                                context,
                                done: hasProductInfo,
                                pending: false,
                              ),
                              tooltip: 'О товаре',
                              onTap: onProductMarkerTap,
                            ),
                            const SizedBox(width: 5),
                            _TrackMarkerIcon(
                              icon: CupertinoIcons.question_circle,
                              color: _trackMarkerColor(
                                context,
                                done: questionDone,
                                pending: questionPending,
                              ),
                              tooltip: 'Вопрос',
                              onTap: onQuestionMarkerTap,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          if (actions.isNotEmpty || canDelete) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 24,
              child: Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          for (var i = 0; i < actions.length; i++) ...[
                            if (i > 0) const SizedBox(width: 5),
                            _TrackCardActionChip(
                              action: actions[i],
                              accent: accent,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (canDelete) ...[
                    const SizedBox(width: 10),
                    _TrackDeleteButton(
                      onTap: () => widget.onDeleteTrack(track),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTrackCardMediaSection(
    BuildContext context, {
    required TrackItem track,
    required String productName,
    required int? productQuantity,
    required List<String> productImageUrls,
    required List<String> photoMediaUrls,
    required bool hasProductInfo,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final canUseRow =
            hasProductInfo &&
            photoMediaUrls.isNotEmpty &&
            constraints.maxWidth >= 330;
        if (canUseRow) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TrackProductPreview(
                name: productName,
                quantity: productQuantity,
                imageUrls: productImageUrls,
                trackCode: track.code,
                onEdit: () => widget.onEditProduct(track),
                onTap: productImageUrls.isNotEmpty
                    ? () => _openMediaViewer(context, productImageUrls, track)
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TrackPhotoGrid(
                  mediaUrls: photoMediaUrls,
                  track: track,
                  onTap: (index) =>
                      _openMediaViewer(context, photoMediaUrls, track, index),
                ),
              ),
            ],
          );
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasProductInfo)
              _TrackProductPreview(
                name: productName,
                quantity: productQuantity,
                imageUrls: productImageUrls,
                trackCode: track.code,
                onEdit: () => widget.onEditProduct(track),
                onTap: productImageUrls.isNotEmpty
                    ? () => _openMediaViewer(context, productImageUrls, track)
                    : null,
              ),
            if (hasProductInfo && photoMediaUrls.isNotEmpty)
              const SizedBox(height: 10),
            if (photoMediaUrls.isNotEmpty)
              _TrackPhotoGrid(
                mediaUrls: photoMediaUrls,
                track: track,
                onTap: (index) =>
                    _openMediaViewer(context, photoMediaUrls, track, index),
              ),
          ],
        );
      },
    );
  }

  List<String> _collectPhotoMediaUrls(
    TrackItem track,
    PhotoRequest? activePhoto,
  ) {
    final urls = <String>[];
    final seen = <String>{};
    if (activePhoto?.mediaUrls.isNotEmpty == true) {
      for (final url in activePhoto!.mediaUrls) {
        if (seen.add(url)) urls.add(url);
      }
    }
    for (final url in track.photoReportUrls) {
      if (seen.add(url)) urls.add(url);
    }
    return urls;
  }

  Color _trackMarkerColor(
    BuildContext context, {
    required bool done,
    required bool pending,
  }) {
    if (done) return const Color(0xFF27C47A);
    if (pending) return context.brandPrimary;
    return const Color(0xFF2F2F2F).withValues(alpha: 0.28);
  }

  void _openMediaViewer(
    BuildContext context,
    List<String> mediaUrls,
    TrackItem track, [
    int initialIndex = 0,
  ]) {
    if (mediaUrls.isEmpty) return;
    final safeInitialIndex = initialIndex
        .clamp(0, mediaUrls.length - 1)
        .toInt();
    final photos = mediaUrls
        .map(
          (url) => PhotoItem(
            url: url,
            date: DateTime.now(),
            trackingNumber: track.code,
          ),
        )
        .toList();
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => PhotoViewerScreen(
          item: photos[safeInitialIndex],
          allPhotos: photos,
          initialIndex: safeInitialIndex,
        ),
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
          _buildBoxParam(
            context,
            icon: Icons.straighten,
            label: tr(context, ru: 'Габариты', zh: '尺寸'),
            value: box.dimensionsDisplay,
          ),
          const SizedBox(height: 6),
          _buildBoxParam(
            context,
            icon: Icons.scale,
            label: tr(context, ru: 'Вес', zh: '重量'),
            value: box.weightDisplay,
          ),
          const SizedBox(height: 6),
          _buildBoxParam(
            context,
            icon: Icons.inventory_2_outlined,
            label: tr(context, ru: 'Объём', zh: '体积'),
            value: box.volumeDisplay,
          ),
          const SizedBox(height: 6),
          _buildBoxParam(
            context,
            icon: Icons.compress,
            label: tr(context, ru: 'Плотность', zh: '密度'),
            value: box.densityDisplay,
          ),

          // Тариф и упаковка коробки (если отличаются от сборки)
          if (box.tariffName != null ||
              box.packagingTypes.isNotEmpty ||
              box.orderNumber != null) ...[
            const SizedBox(height: 8),
            if (box.orderNumber != null && box.orderNumber!.isNotEmpty)
              _buildBoxParam(
                context,
                icon: Icons.tag,
                label: tr(context, ru: 'Заказ', zh: '单号'),
                value: box.orderNumber!,
              ),
            if (box.orderNumber != null &&
                box.orderNumber!.isNotEmpty &&
                (box.tariffName != null || box.packagingTypes.isNotEmpty))
              const SizedBox(height: 6),
            if (box.tariffName != null)
              _buildBoxParam(
                context,
                icon: Icons.local_shipping_outlined,
                label: tr(context, ru: 'Тариф', zh: '费率'),
                value: box.tariffName!,
              ),
            if (box.tariffName != null && box.packagingTypes.isNotEmpty)
              const SizedBox(height: 6),
            if (box.packagingTypes.isNotEmpty)
              _buildBoxParam(
                context,
                icon: Icons.inventory_2_outlined,
                label: tr(context, ru: 'Упаковка', zh: '包装'),
                value: box.packagingTypes.join(', '),
              ),
          ],
          // Фото на весах — одно большое
          if (box.photos.isNotEmpty) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () {
                final allPhotos = box.photos
                    .map((p) => PhotoItem(url: p.url, date: DateTime.now()))
                    .toList();
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
                  memCacheWidth: 360,
                  memCacheHeight: 240,
                  maxWidthDiskCache: 720,
                  maxHeightDiskCache: 480,
                  fadeInDuration: Duration.zero,
                  fadeOutDuration: Duration.zero,
                  useOldImageOnUrlChange: false,
                  filterQuality: FilterQuality.low,
                  imageBuilder: (_, imageProvider) => DecoratedBox(
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

  Widget _buildBoxParam(
    BuildContext context, {
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

class _TrackCardAction {
  final String label;
  final VoidCallback onTap;

  const _TrackCardAction({required this.label, required this.onTap});
}

class _AssemblyStatusPill extends StatelessWidget {
  final String text;
  final Color color;

  const _AssemblyStatusPill({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        maxLines: 1,
        softWrap: false,
        style: const TextStyle(
          color: Colors.black,
          fontFamily: 'Gilroy',
          fontSize: 14,
          height: 16 / 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _AssemblySectionHeader extends StatelessWidget {
  final String title;
  final bool isExpanded;
  final VoidCallback onTap;

  const _AssemblySectionHeader({
    required this.title,
    required this.isExpanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: 18,
        child: Row(
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF2F2F2F),
                fontFamily: 'Gilroy',
                fontSize: 15,
                height: 18 / 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Icon(
              isExpanded
                  ? CupertinoIcons.chevron_up
                  : CupertinoIcons.chevron_down,
              size: 16,
              color: const Color(0xFF2F2F2F),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssemblyPlainText extends StatelessWidget {
  final String text;

  const _AssemblyPlainText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      softWrap: true,
      style: const TextStyle(
        color: Color(0xFF2F2F2F),
        fontFamily: 'Gilroy',
        fontSize: 12,
        height: 14.508 / 12,
        fontWeight: FontWeight.w400,
      ),
    );
  }
}

class _AssemblyInvoiceText extends StatelessWidget {
  final String value;

  const _AssemblyInvoiceText({required this.value});

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          const TextSpan(text: 'Накладная: '),
          TextSpan(
            text: value.isEmpty ? '—' : value,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
      softWrap: true,
      style: const TextStyle(
        color: Color(0xFF2F2F2F),
        fontFamily: 'Gilroy',
        fontSize: 12,
        height: 14.508 / 12,
        fontWeight: FontWeight.w400,
      ),
    );
  }
}

class _TrackCheckbox extends StatelessWidget {
  final bool value;
  final Color accent;
  final VoidCallback onTap;

  const _TrackCheckbox({
    required this.value,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: value ? accent : Colors.white,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
            color: value ? Colors.white : const Color(0xFF2F2F2F),
          ),
        ),
        child: value
            ? const Icon(Icons.check_rounded, size: 12, color: Colors.white)
            : null,
      ),
    );
  }
}

class _TrackDateMeta extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color color;

  const _TrackDateMeta({
    required this.icon,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 24, color: color),
        const SizedBox(width: 5),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontFamily: 'Gilroy',
            fontSize: 16,
            height: 24 / 16,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

class _TrackCardStatusPill extends StatelessWidget {
  final String text;
  final Color? color;

  const _TrackCardStatusPill({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    final bg = color ?? const Color(0xFFB8E1C8);
    return Container(
      constraints: const BoxConstraints(minWidth: 89),
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        maxLines: 1,
        softWrap: false,
        style: const TextStyle(
          color: Color(0xFF2F2F2F),
          fontFamily: 'Gilroy',
          fontSize: 14,
          height: 16 / 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _TrackMarkerIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback? onTap;

  const _TrackMarkerIcon({
    required this.icon,
    required this.color,
    required this.tooltip,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final child = SizedBox(
      width: 24,
      height: 24,
      child: Center(child: Icon(icon, size: 24, color: color)),
    );
    if (onTap == null) return child;

    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: child,
      ),
    );
  }
}

class _TaskStatusBadge extends StatelessWidget {
  final String text;
  final Color color;

  const _TaskStatusBadge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontFamily: 'Gilroy',
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _TaskDetailBlock extends StatelessWidget {
  final String title;
  final String text;
  final bool muted;

  const _TaskDetailBlock({
    required this.title,
    required this.text,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0x0A000000),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.black54,
              fontFamily: 'Gilroy',
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            text,
            style: TextStyle(
              color: muted ? Colors.black38 : const Color(0xFF2F2F2F),
              fontFamily: 'Gilroy',
              fontSize: 14,
              height: 18 / 14,
              fontWeight: muted ? FontWeight.w500 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskDateLabel extends StatelessWidget {
  final String label;
  final String value;

  const _TaskDateLabel({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Text(
      '$label: $value',
      style: const TextStyle(
        color: Colors.black45,
        fontFamily: 'Gilroy',
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _QuestionDetailsItem {
  final String title;
  final String statusLabel;
  final Color statusColor;
  final String question;
  final String? answer;
  final DateTime createdAt;
  final DateTime? answeredAt;
  final bool canCancel;

  const _QuestionDetailsItem({
    required this.title,
    required this.statusLabel,
    required this.statusColor,
    required this.question,
    required this.answer,
    required this.createdAt,
    required this.answeredAt,
    required this.canCancel,
  });

  factory _QuestionDetailsItem.fromQuestion(
    TrackQuestion question,
    String title,
  ) {
    return _QuestionDetailsItem(
      title: title,
      statusLabel: question.statusLabel,
      statusColor: question.hasAnswer
          ? const Color(0xFF27C47A)
          : question.status == 'cancelled'
          ? Colors.redAccent
          : Colors.orange,
      question: question.question,
      answer: question.hasAnswer ? question.answer : null,
      createdAt: question.createdAt,
      answeredAt: question.answeredAt,
      canCancel: question.isActive,
    );
  }
}

class _QuestionDetailsCard extends StatelessWidget {
  final _QuestionDetailsItem item;
  final DateFormat dateFormat;

  const _QuestionDetailsCard({required this.item, required this.dateFormat});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: item.statusColor.withValues(alpha: 0.24)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            offset: Offset(0, 4),
            blurRadius: 14,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _QuestionBadge(color: item.statusColor),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        color: Color(0xFF2F2F2F),
                        fontFamily: 'Gilroy',
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    _TaskDateLabel(
                      label: 'Создан',
                      value: dateFormat.format(item.createdAt),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 132),
                child: _TaskStatusBadge(
                  text: item.statusLabel,
                  color: item.statusColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _TaskDetailBlock(title: 'Вопрос', text: item.question),
          if (item.answer?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 10),
            _TaskDetailBlock(title: 'Ответ', text: item.answer!.trim()),
          ],
          if (item.answeredAt != null) ...[
            const SizedBox(height: 10),
            _QuestionMetaPill(
              icon: CupertinoIcons.checkmark_alt_circle,
              text: 'Отвечен: ${dateFormat.format(item.answeredAt!)}',
              color: const Color(0xFF27C47A),
            ),
          ],
        ],
      ),
    );
  }
}

class _QuestionBadge extends StatelessWidget {
  final Color color;

  const _QuestionBadge({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      alignment: Alignment.center,
      child: Icon(CupertinoIcons.question_circle, size: 17, color: color),
    );
  }
}

class _QuestionMetaPill extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _QuestionMetaPill({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontFamily: 'Gilroy',
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionTextPanel extends StatelessWidget {
  final String title;
  final String text;
  final bool muted;

  const _QuestionTextPanel({
    required this.title,
    required this.text,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0x08000000),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.black45,
              fontFamily: 'Gilroy',
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            text,
            style: TextStyle(
              color: muted ? Colors.black54 : const Color(0xFF2F2F2F),
              fontFamily: 'Gilroy',
              fontSize: 14,
              height: 18 / 14,
              fontWeight: muted ? FontWeight.w500 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackCardActionChip extends StatelessWidget {
  final _TrackCardAction action;
  final Color accent;

  const _TrackCardActionChip({required this.action, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: action.onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 24,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: accent, width: 0.5),
          ),
          alignment: Alignment.center,
          child: Text(
            action.label,
            style: const TextStyle(
              color: Color(0xFF2F2F2F),
              fontFamily: 'Gilroy',
              fontSize: 14,
              height: 16 / 14,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

class _TrackDeleteButton extends StatelessWidget {
  final VoidCallback onTap;

  const _TrackDeleteButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 26,
        height: 23,
        decoration: BoxDecoration(
          color: const Color(0xFFFE1A1A),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: const Icon(CupertinoIcons.trash, size: 12, color: Colors.white),
      ),
    );
  }
}

class _TrackProductPreview extends StatelessWidget {
  final String name;
  final int? quantity;
  final List<String> imageUrls;
  final String trackCode;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;

  const _TrackProductPreview({
    required this.name,
    required this.quantity,
    required this.imageUrls,
    required this.trackCode,
    this.onTap,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrls.isNotEmpty;
    final title = name.trim().isNotEmpty ? name.trim() : 'О товаре';
    final countText = quantity != null ? 'Количество: $quantity шт' : null;

    return SizedBox(
      width: 124,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onTap,
            child: Container(
              width: 124,
              height: 115,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: const Color(0xFFC4C4C4),
                borderRadius: BorderRadius.circular(10),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1A000000),
                    offset: Offset(3, 4),
                    blurRadius: 25,
                  ),
                ],
              ),
              child: hasImage
                  ? CachedNetworkImage(
                      imageUrl: ApiConfig.getMediaUrl(imageUrls.first),
                      memCacheWidth: 220,
                      memCacheHeight: 220,
                      maxWidthDiskCache: 440,
                      maxHeightDiskCache: 440,
                      fadeInDuration: Duration.zero,
                      fadeOutDuration: Duration.zero,
                      useOldImageOnUrlChange: false,
                      filterQuality: FilterQuality.low,
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
                        child: Icon(Icons.broken_image_outlined, size: 24),
                      ),
                    )
                  : const Center(
                      child: Icon(
                        Icons.inventory_2_outlined,
                        size: 28,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onEdit,
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF2F2F2F),
                fontFamily: 'Gilroy',
                fontSize: 16,
                height: 19 / 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (countText != null)
            Text(
              countText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF2F2F2F),
                fontFamily: 'Gilroy',
                fontSize: 14,
                height: 16 / 14,
                fontWeight: FontWeight.w400,
              ),
            ),
        ],
      ),
    );
  }
}

class _TrackPhotoGrid extends StatelessWidget {
  final List<String> mediaUrls;
  final TrackItem track;
  final ValueChanged<int> onTap;

  const _TrackPhotoGrid({
    required this.mediaUrls,
    required this.track,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final visibleUrls = mediaUrls.take(6).toList(growable: false);
    return LayoutBuilder(
      builder: (context, constraints) {
        final gridWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth.clamp(0.0, 246.0).toDouble()
            : 246.0;
        final tileSize = ((gridWidth - 20) / 3).clamp(54.0, 75.5).toDouble();
        return SizedBox(
          width: gridWidth,
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (var i = 0; i < visibleUrls.length; i++)
                GestureDetector(
                  onTap: () => onTap(i),
                  child: Container(
                    width: tileSize,
                    height: tileSize,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: const Color(0xFFC4C4C4),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x1A000000),
                          offset: Offset(3, 4),
                          blurRadius: 25,
                        ),
                      ],
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CachedNetworkImage(
                          imageUrl: ApiConfig.getMediaUrl(visibleUrls[i]),
                          memCacheWidth: 180,
                          memCacheHeight: 180,
                          maxWidthDiskCache: 360,
                          maxHeightDiskCache: 360,
                          fadeInDuration: Duration.zero,
                          fadeOutDuration: Duration.zero,
                          useOldImageOnUrlChange: false,
                          filterQuality: FilterQuality.low,
                          imageBuilder: (context, imageProvider) =>
                              DecoratedBox(
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
                        if (_isVideoUrl(ApiConfig.getMediaUrl(visibleUrls[i])))
                          Center(
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.55),
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
                ),
            ],
          ),
        );
      },
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
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                for (final item in items)
                  ListTile(
                    dense: true,
                    title: Text(
                      item.label,
                      style: TextStyle(
                        fontWeight: item.value == value
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: item.value == value
                            ? context.brandPrimary
                            : Colors.black87,
                        fontSize: 14,
                      ),
                    ),
                    trailing: item.value == value
                        ? Icon(
                            Icons.check_rounded,
                            size: 18,
                            color: context.brandPrimary,
                          )
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
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
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
                          maxHeight:
                              MediaQuery.of(context).size.height *
                              0.4, // 40% of screen height
                        ),
                        decoration: const BoxDecoration(color: Colors.white),
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
                                top: isFirst
                                    ? const Radius.circular(14)
                                    : Radius.zero,
                                bottom: isLast
                                    ? const Radius.circular(14)
                                    : Radius.zero,
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
                                    top: isFirst
                                        ? const Radius.circular(14)
                                        : Radius.zero,
                                    bottom: isLast
                                        ? const Radius.circular(14)
                                        : Radius.zero,
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
    final activeColor = isDestructive
        ? const Color(0xFFD32F2F)
        : context.brandPrimary;
    final isDisabled = onPressed == null;

    // Icon-only button (circular) — fallback if no label
    if (label == null && icon != null) {
      return Opacity(
        opacity: isDisabled ? 0.45 : 1,
        child: Container(
          decoration: BoxDecoration(
            gradient: activeGradient,
            shape: BoxShape.circle,
          ),
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
                      fontSize: 14,
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
  return AppGradientInputFrame(
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
          color: isSelected
              ? context.brandPrimary.withValues(alpha: 0.1)
              : Colors.white,
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
                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: context.brandPrimary, size: 24),
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
                  child: const Icon(
                    Icons.edit_outlined,
                    size: 16,
                    color: Colors.black45,
                  ),
                ),
              ],
              if (!_expanded) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Colors.black38),
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
                    style: const TextStyle(fontSize: 13, color: Colors.black54),
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
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onEdit,
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
                child: const Icon(
                  Icons.edit_outlined,
                  size: 16,
                  color: Colors.black45,
                ),
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
                memCacheWidth: 320,
                memCacheHeight: 240,
                maxWidthDiskCache: 640,
                maxHeightDiskCache: 480,
                fadeInDuration: Duration.zero,
                fadeOutDuration: Duration.zero,
                useOldImageOnUrlChange: false,
                filterQuality: FilterQuality.low,
                imageBuilder: (_, imageProvider) => DecoratedBox(
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: widget.statusColor.withValues(alpha: 0.22)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            offset: Offset(0, 3),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            behavior: HitTestBehavior.opaque,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _QuestionBadge(color: widget.statusColor),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          fontFamily: 'Gilroy',
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: Color(0xFF2F2F2F),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Создан: ${widget.createdAt}',
                        style: const TextStyle(
                          fontFamily: 'Gilroy',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.black45,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 120),
                  child: _TaskStatusBadge(
                    text: widget.statusLabel,
                    color: widget.statusColor,
                  ),
                ),
                if (widget.canCancel) ...[
                  const SizedBox(width: 6),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.onCancel,
                    child: const Padding(
                      padding: EdgeInsets.all(2),
                      child: Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: Colors.redAccent,
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 4),
                Icon(
                  _expanded
                      ? CupertinoIcons.chevron_up
                      : CupertinoIcons.chevron_down,
                  size: 18,
                  color: Colors.black45,
                ),
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.question.isNotEmpty)
                          _QuestionTextPanel(
                            title: 'Вопрос',
                            text: widget.question,
                          ),
                        if (widget.answer?.trim().isNotEmpty == true) ...[
                          const SizedBox(height: 8),
                          _QuestionTextPanel(
                            title: 'Ответ',
                            text: widget.answer!.trim(),
                            muted: true,
                          ),
                        ],
                        if (widget.answeredAt != null) ...[
                          const SizedBox(height: 8),
                          _QuestionMetaPill(
                            icon: CupertinoIcons.checkmark_alt_circle,
                            text: 'Отвечен: ${widget.answeredAt!}',
                            color: const Color(0xFF27C47A),
                          ),
                        ],
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
