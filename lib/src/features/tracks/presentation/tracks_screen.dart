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
import 'package:image_picker/image_picker.dart';
import 'package:phone_form_field/phone_form_field.dart';
import 'package:twoalogisticcabineuser/src/core/ui/blurred_modal_bottom_sheet.dart';
import '../../../core/network/api_config.dart';
import '../../../core/ui/app_cached_media_image.dart';
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

const _unknownTrackQuestionType = 'unknown_track_check';
const _clientCodeTransferQuestionType = 'client_code_transfer';
const _unknownTrackQuestionText =
    'Не знаю что это за трек номер, могли бы проверить и код клиента и трек номер';

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

class _ClientCodeOption {
  final int id;
  final String code;

  const _ClientCodeOption({required this.id, required this.code});
}

class _PackagingBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _PackagingBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
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
  final String? initialClientCode;

  const TracksScreen({
    super.key,
    this.initialTrackId,
    this.initialTrackCode,
    this.initialAssemblyId,
    this.initialClientCode,
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
  String? _initialClientSwitchTarget;
  String? _filtersInitializedForClientCode;
  bool _loadingInitialTargetIntoList = false;
  String? _highlightedGroupKey;
  Timer? _highlightTimer;
  final Map<String, GlobalKey> _targetGroupKeys = <String, GlobalKey>{};

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
        oldWidget.initialAssemblyId != widget.initialAssemblyId ||
        oldWidget.initialClientCode != widget.initialClientCode) {
      _handledInitialTargetKey = null;
      _initialClientSwitchTarget = null;
      if (widget.initialAssemblyId != null) {
        _viewMode = ViewMode.groups;
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchDebounce?.cancel();
    _highlightTimer?.cancel();
    _currentNotifier?.removeListener(_onNotifierStateChanged);
    super.dispose();
  }

  void _disposeAfterBottomSheetClose(Iterable<VoidCallback> disposers) {
    // showBlurredModalBottomSheet completes when the route is popped, while the sheet
    // subtree can still rebuild during the closing animation. Disposing field
    // controllers immediately may make TextField rebuild with an already
    // disposed controller.
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 500)).then((_) {
        for (final dispose in disposers) {
          dispose();
        }
      }),
    );
  }

  void _onNotifierStateChanged() {
    if (mounted) {
      final tracks = _currentNotifier?.state.tracks ?? const <TrackItem>[];
      _syncMapsWithServerData(tracks);
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

  /// Очищает оптимистичные Map-записи для треков, у которых сервер
  /// уже подтвердил данные после pull-to-refresh или silent refresh.
  bool _syncMapsWithServerData(List<TrackItem> serverTracks) {
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
    return changed;
  }

  Future<bool> _confirmAction(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    final res = await showBlurredModalBottomSheet<bool>(
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
    final result = await showBlurredModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.22),
      builder: (sheetContext) {
        return _TrackSheetSurface(
          icon: Icons.add_photo_alternate_rounded,
          title: 'Фотоотчёт',
          subtitle: 'Склад сделает снимки по треку ${track.code}',
          keyboardAware: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TrackSheetNoticeCard(
                icon: Icons.info_outline_rounded,
                text:
                    'Фотоотчёт может быть платным. Ознакомьтесь с тарифами перед запросом.',
                color: Colors.amber.shade800,
              ),
              const SizedBox(height: 12),
              _TrackFilterSectionCard(
                icon: Icons.edit_note_rounded,
                title: 'Пожелание для склада',
                child: AppGradientInputFrame(
                  child: TextField(
                    controller: controller,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'Например: сфотографировать бирку и размер…',
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
              _TrackSheetPrimaryButton(
                label: 'Запросить фотоотчёт',
                icon: Icons.check_rounded,
                onTap: () => Navigator.of(sheetContext).pop(true),
              ),
            ],
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
    final result = await showBlurredModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.22),
      builder: (sheetContext) {
        return _TrackSheetSurface(
          icon: Icons.help_rounded,
          title: 'Вопрос складу',
          subtitle: 'Проверим трек ${track.code} и код клиента',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TrackSheetMetaCard(
                icon: Icons.lock_outline_rounded,
                title: 'Текст задачи',
                value: _unknownTrackQuestionText,
                valueMaxLines: 4,
              ),
              const SizedBox(height: 12),
              _TrackSheetNoticeCard(
                icon: Icons.task_alt_rounded,
                text: 'Склад получит задачу и ответит прямо в карточке трека.',
                color: Colors.green.shade700,
              ),
              const SizedBox(height: 14),
              _TrackSheetPrimaryButton(
                label: 'Отправить на склад',
                icon: Icons.send_rounded,
                onTap: () => Navigator.of(sheetContext).pop(true),
              ),
            ],
          ),
        );
      },
    );
    if (result == true) {
      if (!context.mounted) return;
      final now = DateTime.now();
      const question = _unknownTrackQuestionText;

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
        questionType: _unknownTrackQuestionType,
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

  List<_ClientCodeOption> _clientCodeOptionsFromAuth() {
    final auth = ref.read(authStateProvider);
    final rawCodes = auth.clientData?['codes'] as List<dynamic>?;
    if (rawCodes == null) return const [];

    return rawCodes
        .whereType<Map<String, dynamic>>()
        .map((json) {
          final id = json['id'];
          final code = json['code']?.toString();
          final parsedId = id is int ? id : int.tryParse(id?.toString() ?? '');
          if (parsedId == null || code == null || code.trim().isEmpty) {
            return null;
          }
          return _ClientCodeOption(id: parsedId, code: code.trim());
        })
        .whereType<_ClientCodeOption>()
        .toList(growable: false);
  }

  Future<void> _showClientCodeTransferSheet(
    BuildContext context,
    TrackItem track,
  ) async {
    final trackId = track.id;
    if (trackId == null) {
      _showStyledSnackBar(context, 'Ошибка: трек не найден', isError: true);
      return;
    }

    final options = _clientCodeOptionsFromAuth()
        .where((code) => code.id != track.clientCodeId)
        .toList(growable: false);
    if (options.isEmpty) {
      _showStyledSnackBar(
        context,
        'Нет другого кода клиента для переноса',
        isError: true,
      );
      return;
    }

    var selected = options.first;
    final confirmed = await showBlurredModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.22),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final codeListHeight = (options.length * 78.0)
                .clamp(78.0, MediaQuery.sizeOf(sheetContext).height * 0.38)
                .toDouble();

            return _TrackSheetSurface(
              icon: Icons.switch_account_rounded,
              title: 'Перенос кода',
              subtitle:
                  'Склад переложит трек ${track.code} после выполнения задачи',
              footer: _TrackSheetPrimaryButton(
                label: 'Создать задачу складу',
                icon: Icons.task_alt_rounded,
                onTap: () => Navigator.of(sheetContext).pop(true),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _TrackSheetMetaCard(
                    icon: Icons.qr_code_rounded,
                    title: 'Текущий трек',
                    value: track.code,
                  ),
                  const SizedBox(height: 12),
                  _TrackFilterSectionCard(
                    icon: Icons.badge_rounded,
                    title: 'Новый код клиента',
                    child: SizedBox(
                      height: codeListHeight,
                      child: ListView.separated(
                        padding: EdgeInsets.zero,
                        itemCount: options.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          return _SheetOptionTile(
                            icon: Icons.badge_outlined,
                            title: options[i].code,
                            subtitle: 'Создать задачу на перенос',
                            selected: selected.id == options[i].id,
                            onTap: () =>
                                setSheetState(() => selected = options[i]),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (confirmed != true || !context.mounted) return;

    final apiService = ref.read(tracksApiServiceProvider);
    final success = await apiService.requestClientCodeTransfer(
      trackId: trackId,
      targetClientCodeId: selected.id,
    );
    if (!context.mounted) return;

    if (success) {
      _showStyledSnackBar(context, 'Задача на перенос создана');
      _refreshTracks();
    } else {
      _showStyledSnackBar(
        context,
        'Не удалось создать задачу на перенос',
        isError: true,
      );
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
    final result = await showBlurredModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.22),
      builder: (sheetContext) {
        return _TrackSheetSurface(
          icon: Icons.photo_camera_rounded,
          title: 'Пожелание',
          subtitle: 'Уточните задачу по фотоотчёту ${track.code}',
          keyboardAware: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TrackFilterSectionCard(
                icon: Icons.edit_note_rounded,
                title: 'Комментарий для склада',
                child: AppGradientInputFrame(
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
              _TrackSheetPrimaryButton(
                label: 'Сохранить',
                icon: Icons.check_rounded,
                onTap: () => Navigator.of(sheetContext).pop(true),
              ),
            ],
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
    try {
      final result = await showBlurredModalBottomSheet<bool>(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withValues(alpha: 0.22),
        builder: (sheetContext) {
          return StatefulBuilder(
            builder: (sheetContext, setSheetState) {
              final canSubmit = returnCodeController.text.trim().isNotEmpty;

              return _TrackSheetSurface(
                icon: Icons.assignment_return_rounded,
                title: 'Возврат товара',
                subtitle: 'Оформим возврат по треку ${track.code}',
                keyboardAware: true,
                footer: _TrackSheetPrimaryButton(
                  label: 'Оформить возврат',
                  icon: Icons.assignment_return_rounded,
                  onTap: canSubmit
                      ? () => Navigator.of(sheetContext).pop(true)
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TrackSheetNoticeCard(
                      icon: Icons.schedule_rounded,
                      text:
                          'Возврат можно оформить в окно с 13:00 до 15:00 по Китаю. Склад получит задачу и код возврата.',
                      color: Colors.orange.shade800,
                    ),
                    const SizedBox(height: 12),
                    _TrackFilterSectionCard(
                      icon: Icons.qr_code_2_rounded,
                      title: 'Код возврата',
                      child: AppGradientInputFrame(
                        child: TextField(
                          controller: returnCodeController,
                          textCapitalization: TextCapitalization.characters,
                          onChanged: (_) => setSheetState(() {}),
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
                    const SizedBox(height: 12),
                    _TrackSheetMetaCard(
                      icon: Icons.storefront_rounded,
                      title: 'Где взять код',
                      value:
                          'Код возврата можно найти в приложении продавца: Taobao, 1688 или другом магазине.',
                      valueMaxLines: 3,
                    ),
                  ],
                ),
              );
            },
          );
        },
      );

      if (result != true || !context.mounted) return;

      final returnCode = returnCodeController.text.trim();
      if (returnCode.isEmpty) {
        _showStyledSnackBar(context, 'Введите код возврата', isError: true);
        return;
      }

      final trackId = track.id;
      if (trackId == null) return;

      setState(() => _returnRequestedTracks.add(track.code));

      final apiService = ref.read(tracksApiServiceProvider);
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
        _showStyledSnackBar(
          context,
          'Ошибка оформления возврата',
          isError: true,
        );
      }
    } finally {
      _disposeAfterBottomSheetClose([returnCodeController.dispose]);
    }
  }

  Future<void> _showCommentSheet(BuildContext context, TrackItem track) async {
    final existing = _overrideComments[track.code] ?? track.comment ?? '';
    final controller = TextEditingController(text: existing);
    final result = await showBlurredModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.22),
      builder: (sheetContext) {
        return _TrackSheetSurface(
          icon: Icons.sticky_note_2_rounded,
          title: 'Заметка',
          subtitle: 'Личный комментарий к треку ${track.code}',
          keyboardAware: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TrackFilterSectionCard(
                icon: Icons.edit_note_rounded,
                title: 'Текст заметки',
                child: AppGradientInputFrame(
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
              _TrackSheetPrimaryButton(
                label: 'Сохранить заметку',
                icon: Icons.check_rounded,
                onTap: () => Navigator.of(sheetContext).pop(true),
              ),
            ],
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
    final result = await showBlurredModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.22),
      builder: (sheetContext) {
        return _TrackSheetSurface(
          icon: Icons.sticky_note_2_rounded,
          title: 'Заметка по сборке',
          subtitle: 'Комментарий к сборке ${assembly.number}',
          keyboardAware: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TrackFilterSectionCard(
                icon: Icons.edit_note_rounded,
                title: 'Текст заметки',
                child: AppGradientInputFrame(
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
              _TrackSheetPrimaryButton(
                label: 'Сохранить заметку',
                icon: Icons.check_rounded,
                onTap: () => Navigator.of(sheetContext).pop(true),
              ),
            ],
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
    final result = await showBlurredModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.22),
      builder: (ctx) {
        return _TrackSheetSurface(
          icon: Icons.help_rounded,
          title: 'Вопрос по сборке',
          subtitle: 'Склад ответит по сборке ${assembly.number}',
          keyboardAware: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TrackFilterSectionCard(
                icon: Icons.edit_note_rounded,
                title: 'Текст вопроса',
                child: AppGradientInputFrame(
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
              _TrackSheetPrimaryButton(
                label: 'Задать вопрос',
                icon: Icons.send_rounded,
                onTap: () => Navigator.of(ctx).pop(true),
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

    final result = await showBlurredModalBottomSheet<Map<String, dynamic>?>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.22),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final selectedDeliveryLabel = selectedMethod == 'self_pickup'
                ? 'Самовывоз'
                : selectedMethod == 'transport_company'
                ? 'Транспортная компания'
                : 'Не выбран';

            void submit() {
              final method = selectedMethod;
              if (method == null) return;

              // Валидация для ТК
              if (method == 'transport_company') {
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
                'method': method,
                'recipientName': nameController.text.trim(),
                'recipientPhone': phoneController.value.international,
                'recipientCity': cityController.text.trim(),
                'transportCompanyName': transportCompanyController.text.trim(),
              });
            }

            return _TrackSheetSurface(
              icon: Icons.local_shipping_rounded,
              title: 'Способ получения',
              subtitle: 'Настройте выдачу сборки ${assembly.number}',
              keyboardAware: true,
              pinnedChild: _TrackSheetMetaCard(
                icon: Icons.inventory_2_rounded,
                title: 'Текущий выбор',
                value: selectedDeliveryLabel,
              ),
              footer: Row(
                children: [
                  Expanded(
                    child: _TrackSheetSecondaryButton(
                      label: 'Отмена',
                      onTap: () => Navigator.of(sheetContext).pop(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _TrackSheetPrimaryButton(
                      label: 'Сохранить',
                      icon: Icons.check_rounded,
                      onTap: selectedMethod == null ? null : submit,
                    ),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _TrackFilterSectionCard(
                    icon: Icons.delivery_dining_rounded,
                    title: 'Вариант получения',
                    child: Column(
                      children: [
                        _DeliveryOptionCard(
                          title: 'Самовывоз',
                          subtitle: 'Забрать груз на терминале склада',
                          icon: Icons.storefront_rounded,
                          isSelected: selectedMethod == 'self_pickup',
                          onTap: () => setSheetState(
                            () => selectedMethod = 'self_pickup',
                          ),
                        ),
                        const SizedBox(height: 10),
                        _DeliveryOptionCard(
                          title: 'Транспортная компания',
                          subtitle: 'Передадим груз выбранной ТК',
                          icon: Icons.local_shipping_rounded,
                          isSelected: selectedMethod == 'transport_company',
                          onTap: () => setSheetState(
                            () => selectedMethod = 'transport_company',
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (selectedMethod == 'self_pickup') ...[
                    const SizedBox(height: 12),
                    _TrackSheetNoticeCard(
                      icon: Icons.warning_amber_rounded,
                      text:
                          'Доступ на терминал платный. Для уточнения условий свяжитесь с поддержкой.',
                      color: Colors.amber.shade800,
                    ),
                    const SizedBox(height: 12),
                    _TrackSheetMetaCard(
                      icon: Icons.support_agent_rounded,
                      title: 'После сохранения',
                      value:
                          'Поддержка увидит выбранный способ и поможет согласовать получение на терминале.',
                      valueMaxLines: 3,
                    ),
                  ],
                  if (selectedMethod == 'transport_company') ...[
                    const SizedBox(height: 12),
                    _TrackSheetNoticeCard(
                      icon: Icons.info_outline_rounded,
                      text:
                          'Заполните данные получателя. Склад использует их для передачи груза транспортной компании.',
                      color: context.brandPrimary,
                    ),
                    const SizedBox(height: 12),
                    _TrackFilterSectionCard(
                      icon: Icons.apartment_rounded,
                      title: 'Транспортная компания',
                      child: _outlinedInput(
                        context,
                        transportCompanyController,
                        hint: 'Название ТК (СДЭК, ПЭК, и т.д.)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    _TrackFilterSectionCard(
                      icon: Icons.person_rounded,
                      title: 'Данные получателя',
                      child: Column(
                        children: [
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
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );

    _disposeAfterBottomSheetClose([
      nameController.dispose,
      cityController.dispose,
      transportCompanyController.dispose,
      phoneController.dispose,
    ]);

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
    bool hasFragileGoods = false;
    String? placePreference;
    String selectedInsurance = 'no';
    String? insuranceAmount;

    // Создаём контроллер ДО StatefulBuilder чтобы не терять фокус
    final insuranceAmountController = TextEditingController();
    final createAssemblyScrollController = ScrollController();
    int currentStep = 0;

    // Загружаем тарифы и типы упаковки (invalidate чтобы не получить кешированный пустой список при сбое сети)
    ref.invalidate(tariffsProvider);
    ref.invalidate(packagingTypesProvider);
    final tariffs = await ref.read(tariffsProvider.future);
    if (!context.mounted) return;
    final packagingTypes = await ref.read(packagingTypesProvider.future);

    // Выбираем первый тариф по умолчанию
    Tariff? selectedTariff = tariffs.isNotEmpty ? tariffs.first : null;

    if (!context.mounted) return;

    final result = await showBlurredModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.22),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            const stepTitles = ['Груз', 'Упаковка', 'Тариф', 'Итог'];
            final primaryPackagingTypes = packagingTypes
                .where((p) => p.isPrimary)
                .toList();
            final addonPackagingTypes = packagingTypes
                .where((p) => p.isAddon)
                .toList();
            final primaryPackagingIds = primaryPackagingTypes
                .map((p) => p.id)
                .toSet();
            PackagingType? selectedPrimaryPackaging;
            for (final p in primaryPackagingTypes) {
              if (selectedPackingIds.contains(p.id)) {
                selectedPrimaryPackaging = p;
                break;
              }
            }
            final hasPrimaryPackaging = selectedPrimaryPackaging != null;
            final selectedPackagingNames = [
              if (selectedPrimaryPackaging != null)
                selectedPrimaryPackaging.displayName,
              ...addonPackagingTypes
                  .where((p) => selectedPackingIds.contains(p.id))
                  .map((p) => p.displayName),
            ];
            final hasSuitableAddonPackaging = addonPackagingTypes.any(
              (p) =>
                  selectedPackingIds.contains(p.id) &&
                  p.suitableForFragileGoods,
            );
            final showFragileAddonRecommendation =
                hasFragileGoods &&
                addonPackagingTypes.isNotEmpty &&
                !hasSuitableAddonPackaging;
            final selectedUnsuitableFragilePackagingNames = packagingTypes
                .where(
                  (p) =>
                      selectedPackingIds.contains(p.id) &&
                      !p.suitableForFragileGoods,
                )
                .map((p) => p.displayName)
                .toList();
            final showFragilePackagingRisk =
                hasFragileGoods &&
                selectedUnsuitableFragilePackagingNames.isNotEmpty;
            final canSubmit =
                placePreference != null &&
                hasPrimaryPackaging &&
                selectedTariff != null &&
                (selectedInsurance == 'no' ||
                    (selectedInsurance == 'yes' &&
                        insuranceAmount?.isNotEmpty == true));
            final canContinue = switch (currentStep) {
              0 => placePreference != null,
              1 => hasPrimaryPackaging,
              2 =>
                selectedTariff != null &&
                    (selectedInsurance == 'no' ||
                        (selectedInsurance == 'yes' &&
                            insuranceAmount?.isNotEmpty == true)),
              _ => canSubmit,
            };

            void goToStep(int value) {
              setSheetState(() => currentStep = value.clamp(0, 3).toInt());
              if (createAssemblyScrollController.hasClients) {
                createAssemblyScrollController.animateTo(
                  0,
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                );
              }
            }

            Widget placePreferenceChip({
              required String value,
              required String label,
            }) {
              final selected = placePreference == value;
              return ChoiceChip(
                selected: selected,
                showCheckmark: selected,
                checkmarkColor: Colors.white,
                selectedColor: context.brandPrimary,
                backgroundColor: Colors.white,
                side: BorderSide(
                  color: selected
                      ? context.brandPrimary
                      : context.brandPrimary.withValues(alpha: 0.36),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
                labelPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                label: Text(label),
                labelStyle: TextStyle(
                  color: selected ? Colors.white : context.brandPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
                onSelected: (_) => setSheetState(() => placePreference = value),
              );
            }

            Widget packagingOptionTile(
              PackagingType packaging, {
              required bool selected,
              required bool primary,
            }) {
              final warning =
                  hasFragileGoods && !packaging.suitableForFragileGoods;
              return InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  setSheetState(() {
                    if (primary) {
                      selectedPackingIds.removeWhere(
                        primaryPackagingIds.contains,
                      );
                      selectedPackingIds.add(packaging.id);
                      return;
                    }
                    if (selected) {
                      selectedPackingIds.remove(packaging.id);
                    } else {
                      selectedPackingIds.add(packaging.id);
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: selected
                        ? context.brandPrimary.withValues(alpha: 0.08)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected
                          ? context.brandPrimary
                          : const Color(0xFFE8EAEE),
                      width: selected ? 1.2 : 1,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        primary
                            ? (selected
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked)
                            : (selected
                                  ? Icons.check_box
                                  : Icons.check_box_outline_blank),
                        color: selected ? context.brandPrimary : Colors.black45,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              packaging.displayName,
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                _PackagingBadge(
                                  label: primary
                                      ? 'Основная упаковка'
                                      : 'Доп. защита',
                                  color: primary
                                      ? context.brandPrimary
                                      : Colors.blue.shade700,
                                ),
                                if (packaging.suitableForFragileGoods)
                                  _PackagingBadge(
                                    label: 'Для хрупкого',
                                    color: Colors.green.shade700,
                                  ),
                                if (warning)
                                  _PackagingBadge(
                                    label: 'Не для хрупкого',
                                    color: Colors.red.shade700,
                                  ),
                              ],
                            ),
                            if (packaging.baseCost > 0) ...[
                              const SizedBox(height: 5),
                              Text(
                                '\$${packaging.baseCost.toStringAsFixed(2)} / ${packaging.unitLabel}',
                                style: const TextStyle(
                                  color: Colors.black54,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                            if (warning) ...[
                              const SizedBox(height: 5),
                              const Text(
                                'Для хрупких товаров лучше выбрать более надежную упаковку.',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            Widget tariffOptionTile(Tariff tariff, {required bool selected}) {
              return InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => setSheetState(() => selectedTariff = tariff),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: selected
                        ? context.brandPrimary.withValues(alpha: 0.08)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected
                          ? context.brandPrimary
                          : const Color(0xFFE8EAEE),
                      width: selected ? 1.2 : 1,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        selected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: selected ? context.brandPrimary : Colors.black45,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tariff.name,
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                _PackagingBadge(
                                  label: 'Тариф доставки',
                                  color: context.brandPrimary,
                                ),
                                if (tariff.requiresProductInfo)
                                  _PackagingBadge(
                                    label: 'Нужны данные о товаре',
                                    color: Colors.orange.shade700,
                                  ),
                              ],
                            ),
                            if (tariff.baseCost > 0) ...[
                              const SizedBox(height: 5),
                              Text(
                                '\$${tariff.baseCost.toStringAsFixed(2)} / кг',
                                style: const TextStyle(
                                  color: Colors.black54,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                            if (tariff.requiresProductInfo) ...[
                              const SizedBox(height: 5),
                              const Text(
                                'Для этого тарифа нужно заполнить информацию о товаре по трекам.',
                                style: TextStyle(
                                  color: Colors.black54,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            Widget buildStepIndicator() {
              return Row(
                children: [
                  for (var i = 0; i < stepTitles.length; i++) ...[
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: i <= currentStep
                              ? context.brandPrimary.withValues(
                                  alpha: i == currentStep ? 0.16 : 0.08,
                                )
                              : const Color(0xFFF1F2F4),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: i == currentStep
                                ? context.brandPrimary.withValues(alpha: 0.45)
                                : Colors.transparent,
                          ),
                        ),
                        child: Text(
                          '${i + 1}. ${stepTitles[i]}',
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: i <= currentStep
                                ? context.brandPrimary
                                : Colors.black45,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    if (i != stepTitles.length - 1) const SizedBox(width: 6),
                  ],
                ],
              );
            }

            Widget buildWizardFooter() {
              Widget? notice;
              if (currentStep == 1) {
                notice = _TrackSheetNoticeCard(
                  icon: Icons.info_outline_rounded,
                  text:
                      'Более надежная упаковка может увеличить вес и размер, но снижает риск повреждений.',
                  color: Colors.orange.shade800,
                );
              } else if (currentStep == 3 && showFragilePackagingRisk) {
                notice = _TrackSheetNoticeCard(
                  icon: Icons.warning_amber_rounded,
                  text:
                      'Некоторые выбранные материалы не подходят для хрупких товаров. Рекомендуем выбрать более надежную упаковку или добавить защиту.',
                  color: Colors.deepOrange.shade700,
                );
              } else if (currentStep == 3 && showFragileAddonRecommendation) {
                notice = _TrackSheetNoticeCard(
                  icon: Icons.info_outline_rounded,
                  text:
                      'Для хрупкого груза лучше добавить подходящую защиту, чтобы снизить риск повреждений.',
                  color: Colors.orange.shade800,
                );
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (notice != null) ...[notice, const SizedBox(height: 10)],
                  Row(
                    children: [
                      if (currentStep > 0) ...[
                        Expanded(
                          child: _TrackSheetSecondaryButton(
                            label: 'Назад',
                            onTap: () => goToStep(currentStep - 1),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        flex: currentStep > 0 ? 1 : 2,
                        child: _TrackSheetPrimaryButton(
                          label: currentStep < 3
                              ? 'Далее'
                              : 'Отправить на сборку',
                          icon: currentStep < 3
                              ? Icons.arrow_forward_rounded
                              : Icons.inventory_2_rounded,
                          onTap: canContinue
                              ? () {
                                  if (currentStep < 3) {
                                    goToStep(currentStep + 1);
                                    return;
                                  }
                                  Navigator.of(sheetContext).pop(true);
                                }
                              : null,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            }

            return _TrackSheetSurface(
              icon: Icons.inventory_2_rounded,
              title: 'Создать сборку',
              subtitle:
                  'Настройте упаковку, тариф и отправку ${_selectedTracks.length} треков',
              keyboardAware: true,
              scrollController: createAssemblyScrollController,
              pinnedChild: buildStepIndicator(),
              footer: buildWizardFooter(),
              contentPadding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (currentStep == 0)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F8FA),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE8EAEE)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.inventory_2_outlined,
                                size: 18,
                                color: context.brandPrimary,
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  '1. Особенности груза',
                                  style: TextStyle(
                                    color: Colors.black87,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            value: hasFragileGoods,
                            activeColor: context.brandPrimary,
                            title: const Text(
                              'Есть хрупкие товары',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: const Text(
                              'Склад увидит это перед упаковкой.',
                              style: TextStyle(fontSize: 12),
                            ),
                            onChanged: (value) =>
                                setSheetState(() => hasFragileGoods = value),
                          ),
                          const Divider(height: 18),
                          const Text(
                            'Количество мест',
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              placePreferenceChip(
                                value: 'single_if_possible',
                                label: 'По возможности 1 место',
                              ),
                              placePreferenceChip(
                                value: 'split_allowed',
                                label: 'Можно разделить',
                              ),
                            ],
                          ),
                          if (placePreference == null) ...[
                            const SizedBox(height: 8),
                            const Text(
                              'Выберите один из вариантов, чтобы склад понимал как упаковывать груз.',
                              style: TextStyle(
                                color: Colors.black45,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          if (placePreference == 'single_if_possible') ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 18,
                                    color: Colors.orange.shade800,
                                  ),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      'Так мест может быть меньше, но материалов может потребоваться больше. Стоимость упаковки считается по фактическому расходу: коробки, мешки и доп. защита.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  if (currentStep == 2) ...[
                    const Text(
                      '3. Тариф и страховка',
                      style: TextStyle(
                        color: Colors.black54,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (tariffs.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F8FA),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE8EAEE)),
                        ),
                        child: const Text(
                          'Нет доступных тарифов',
                          style: TextStyle(
                            color: Colors.black45,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F8FA),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE8EAEE)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Тариф доставки',
                              style: TextStyle(
                                color: Colors.black87,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Выберите один тариф для этой сборки.',
                              style: TextStyle(
                                color: Colors.black54,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 10),
                            ...tariffs.map(
                              (t) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: tariffOptionTile(
                                  t,
                                  selected: selectedTariff?.id == t.id,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const Divider(height: 24),
                  ],
                  // ── Тип упаковки ──
                  if (currentStep == 1) ...[
                    const Text(
                      '2. Упаковка',
                      style: TextStyle(
                        color: Colors.black54,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F8FA),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE8EAEE)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Основная упаковка',
                            style: TextStyle(
                              color: Colors.black87,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Выберите один вариант. Без основной упаковки сборку создать нельзя.',
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (primaryPackagingTypes.isEmpty)
                            const Text(
                              'Нет доступной основной упаковки',
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            )
                          else
                            ...primaryPackagingTypes.map(
                              (p) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: packagingOptionTile(
                                  p,
                                  selected: selectedPackingIds.contains(p.id),
                                  primary: true,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE8EAEE)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Дополнительная защита',
                            style: TextStyle(
                              color: Colors.black87,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Можно выбрать несколько вариантов или оставить без доп. защиты.',
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (hasFragileGoods &&
                              addonPackagingTypes.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: context.brandPrimary.withValues(
                                  alpha: 0.07,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: context.brandPrimary.withValues(
                                    alpha: 0.18,
                                  ),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.health_and_safety_outlined,
                                    color: context.brandPrimary,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      'Для хрупких товаров рекомендуем добавить дополнительную защиту даже при надежной основной упаковке. Это может немного увеличить вес и стоимость упаковки, но снижает риск повреждений в пути.',
                                      style: TextStyle(
                                        color: Colors.black87,
                                        fontSize: 12,
                                        height: 1.25,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          if (addonPackagingTypes.isEmpty)
                            const Text(
                              'Дополнительная защита недоступна',
                              style: TextStyle(
                                color: Colors.black45,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          else
                            ...addonPackagingTypes.map(
                              (p) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: packagingOptionTile(
                                  p,
                                  selected: selectedPackingIds.contains(p.id),
                                  primary: false,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  if (currentStep == 2) ...[
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
                  ],
                  const SizedBox(height: 16),
                  if (currentStep == 3)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: context.brandPrimary.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: context.brandPrimary.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            '4. Подтверждение',
                            style: TextStyle(
                              color: Colors.black87,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _SummaryLine(
                            label: 'Хрупкий груз',
                            value: hasFragileGoods ? 'Да' : 'Нет',
                          ),
                          _SummaryLine(
                            label: 'Места',
                            value: switch (placePreference) {
                              'single_if_possible' => 'По возможности 1 место',
                              'split_allowed' => 'Можно разделить',
                              _ => 'Не выбрано',
                            },
                          ),
                          _SummaryLine(
                            label: 'Тариф',
                            value: selectedTariff?.name ?? 'Не выбран',
                          ),
                          _SummaryLine(
                            label: 'Упаковка',
                            value: selectedPackagingNames.isEmpty
                                ? 'Не выбрана'
                                : selectedPackagingNames.join(', '),
                          ),
                          _SummaryLine(
                            label: 'Страховка',
                            value: selectedInsurance == 'yes'
                                ? 'Да, ${insuranceAmount ?? ''} ¥'
                                : 'Нет',
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
        final proceed = await showBlurredModalBottomSheet<bool>(
          context: context,
          useRootNavigator: true,
          backgroundColor: Colors.transparent,
          barrierColor: Colors.black.withValues(alpha: 0.22),
          builder: (sheetCtx) {
            return _TrackSheetSurface(
              icon: Icons.task_alt_rounded,
              title: 'Незавершённые задачи',
              subtitle: 'Перед созданием сборки нужно подтвердить действие',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _TrackSheetNoticeCard(
                    icon: Icons.info_outline_rounded,
                    text:
                        'Есть треки (${tracksWithActiveTasks.length} шт.) с невыполненными задачами: вопросы или фотоотчёты. Если создать сборку, эти задачи будут отменены.',
                    color: Colors.orange.shade800,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _TrackSheetSecondaryButton(
                          label: 'Отменить',
                          onTap: () => Navigator.of(sheetCtx).pop(false),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _TrackSheetPrimaryButton(
                          label: 'Создать',
                          icon: Icons.inventory_2_rounded,
                          onTap: () => Navigator.of(sheetCtx).pop(true),
                        ),
                      ),
                    ],
                  ),
                ],
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
          await showBlurredModalBottomSheet<void>(
            context: context,
            useRootNavigator: true,
            backgroundColor: Colors.transparent,
            barrierColor: Colors.black.withValues(alpha: 0.22),
            isScrollControlled: true,
            builder: (sheetCtx) {
              return _TrackSheetSurface(
                icon: Icons.assignment_outlined,
                title: 'О товаре',
                subtitle: 'Тариф «${selectedTariff!.name}» требует данные',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TrackSheetNoticeCard(
                      icon: Icons.info_outline_rounded,
                      text:
                          'Заполните информацию о товаре для треков (${tracksWithoutProductInfo.length} шт.), иначе сборку с этим тарифом создать нельзя.',
                      color: Colors.orange.shade800,
                    ),
                    const SizedBox(height: 12),
                    _TrackFilterSectionCard(
                      icon: Icons.local_shipping_rounded,
                      title: 'Треки без данных',
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(sheetCtx).size.height * 0.3,
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: tracksWithoutProductInfo.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final t = tracksWithoutProductInfo[i];
                            return _TrackSheetMetaCard(
                              icon: Icons.local_shipping_outlined,
                              title: 'Нет данных о товаре',
                              value: t.code,
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _TrackSheetPrimaryButton(
                      label: 'Понятно',
                      icon: Icons.check_rounded,
                      onTap: () => Navigator.of(sheetCtx).pop(),
                    ),
                  ],
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
        hasFragileGoods: hasFragileGoods,
        placePreference: placePreference!,
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
    final result = await showBlurredModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.22),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return _TrackSheetSurface(
              icon: Icons.inventory_2_rounded,
              title: 'О товаре',
              subtitle: 'Данные по треку ${track.code}',
              keyboardAware: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
                            ? AppCachedMediaImage(
                                url: path,
                                thumbnailSize: 480,
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
                  _TrackSheetPrimaryButton(
                    label: 'Сохранить',
                    icon: Icons.check_rounded,
                    onTap: () => Navigator.of(sheetContext).pop(true),
                  ),
                ],
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

  String? _initialTargetKey() {
    final hasTarget =
        widget.initialTrackId != null ||
        (widget.initialTrackCode?.isNotEmpty ?? false) ||
        widget.initialAssemblyId != null;
    if (!hasTarget) return null;
    return [
      widget.initialClientCode ?? '',
      widget.initialTrackId?.toString() ?? '',
      widget.initialTrackCode ?? '',
      widget.initialAssemblyId?.toString() ?? '',
    ].join('|');
  }

  String? _clientCodeSwitchTarget(String activeCode) {
    final requested = widget.initialClientCode?.trim();
    if (requested == null || requested.isEmpty) return null;
    if (requested.toUpperCase() == activeCode.toUpperCase()) return null;

    final codesState = ref.watch(clientCodesControllerProvider).asData?.value;
    if (codesState == null) return null;
    for (final code in codesState.codes) {
      if (code.toUpperCase() == requested.toUpperCase()) return code;
    }
    return null;
  }

  void _scheduleInitialClientSwitch(String targetCode) {
    if (_initialClientSwitchTarget == targetCode) return;
    _initialClientSwitchTarget = targetCode;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await ref
          .read(clientCodesControllerProvider.notifier)
          .selectClient(targetCode);
    });
  }

  int? _findInitialBucketIndex(List<_GroupBucket> groups) {
    if (widget.initialAssemblyId != null) {
      for (var i = 0; i < groups.length; i++) {
        final group = groups[i];
        if (group.assembly?.id == widget.initialAssemblyId) {
          return i;
        }
      }
      return null;
    }

    for (var i = 0; i < groups.length; i++) {
      final group = groups[i];
      final hasTrack = group.tracks.any((track) {
        final idMatches =
            widget.initialTrackId != null && track.id == widget.initialTrackId;
        final codeMatches =
            widget.initialTrackCode != null &&
            track.code.toLowerCase() == widget.initialTrackCode!.toLowerCase();
        return idMatches || codeMatches;
      });
      if (hasTrack) return i;
    }
    return null;
  }

  String _groupTargetKey(_GroupBucket bucket) {
    final assemblyId = bucket.assembly?.id;
    if (assemblyId != null) return 'assembly:$assemblyId';
    final track = bucket.tracks.firstOrNull;
    return 'track:${track?.id ?? track?.code ?? bucket.hashCode}';
  }

  GlobalKey _keyForGroup(_GroupBucket bucket) {
    final key = _groupTargetKey(bucket);
    return _targetGroupKeys.putIfAbsent(key, GlobalKey.new);
  }

  void _maybeOpenInitialTarget(
    List<_GroupBucket> groups,
    String clientCode, {
    required bool isLoading,
  }) {
    final targetKey = _initialTargetKey();
    if (targetKey == null) return;
    if (_handledInitialTargetKey == targetKey) return;

    final bucketIndex = _findInitialBucketIndex(groups);
    if (bucketIndex == null) {
      if (!isLoading) _loadInitialTargetIntoList(targetKey, clientCode);
      return;
    }

    final bucket = groups[bucketIndex];
    _handledInitialTargetKey = targetKey;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusInitialTarget(bucket, bucketIndex);
    });
  }

  void _focusInitialTarget(_GroupBucket bucket, int index) {
    final groupKey = _groupTargetKey(bucket);
    _highlightTimer?.cancel();
    setState(() => _highlightedGroupKey = groupKey);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      if (_scrollController.hasClients) {
        final maxScroll = _scrollController.position.maxScrollExtent;
        // Approximation first brings virtualized sliver item close enough to
        // build, then ensureVisible below aligns it precisely.
        final estimatedOffset = (260.0 + index * 180.0)
            .clamp(0.0, maxScroll)
            .toDouble();
        await _scrollController.animateTo(
          estimatedOffset,
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
        );
      }

      if (!mounted) return;
      await Future<void>.delayed(const Duration(milliseconds: 80));
      if (!mounted) return;

      final contextForTarget = _keyForGroup(bucket).currentContext;
      if (contextForTarget != null) {
        await Scrollable.ensureVisible(
          // ignore: use_build_context_synchronously
          contextForTarget,
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
          alignment: 0.18,
        );
      }

      _highlightTimer = Timer(const Duration(milliseconds: 1800), () {
        if (!mounted) return;
        setState(() => _highlightedGroupKey = null);
      });
    });
  }

  void _loadInitialTargetIntoList(String targetKey, String clientCode) {
    if (_loadingInitialTargetIntoList) return;
    _loadingInitialTargetIntoList = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final notifier = ref.read(paginatedTracksProvider(clientCode));
        var iterations = 0;
        const maxIterations = 60;

        while (mounted &&
            _initialTargetKey() == targetKey &&
            notifier.state.hasMore &&
            !notifier.state.isLoading &&
            _findInitialBucketIndex(_groupTracks(notifier.state.tracks)) ==
                null &&
            iterations < maxIterations) {
          await notifier.loadMore();
          iterations++;
        }

        if (!mounted || _initialTargetKey() != targetKey) return;
        final groups = _groupTracks(notifier.state.tracks);
        final index = _findInitialBucketIndex(groups);
        if (index != null) {
          _handledInitialTargetKey = targetKey;
          _focusInitialTarget(groups[index], index);
          return;
        }

        _handledInitialTargetKey = targetKey;
      } finally {
        _loadingInitialTargetIntoList = false;
      }
    });
  }

  _TrackGroupCard _buildTrackGroupCard(
    _GroupBucket group, {
    GlobalKey? tutorialActionsKey,
    GlobalKey? tutorialAssemblyKey,
    List<TrackStatus>? trackStatuses,
    List<TrackStatus>? assemblyStatuses,
  }) {
    return _TrackGroupCard(
      assembly: group.assembly,
      tracks: group.tracks,
      trackStatuses:
          trackStatuses ??
          ref.read(trackStatusesProvider).asData?.value ??
          const [],
      assemblyStatuses:
          assemblyStatuses ??
          ref.read(assemblyStatusesProvider).asData?.value ??
          const [],
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
      onTransferClientCode: (track) =>
          _showClientCodeTransferSheet(context, track),
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
        const _TracksHeroHeader(),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.black.withValues(alpha: 0.045)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.045),
                blurRadius: 18,
                spreadRadius: -9,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TracksViewModeSwitch(
                value: _viewMode == ViewMode.groups
                    ? ViewMode.groups
                    : ViewMode.singles,
                onChanged: (mode) => _onDisplayModeChanged(mode, clientCode),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _TracksSearchField(
                      query: _query,
                      onChanged: (value) => _onSearchChanged(value, clientCode),
                      onClear: () => _onSearchChanged('', clientCode),
                    ),
                  ),
                  const SizedBox(width: 8),
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
                  const SizedBox(width: 8),
                  _HeaderIconButton(
                    icon: Icons.swap_vert_rounded,
                    tooltip: 'Сортировка',
                    isActive: _sortMode != TrackSortMode.createdAt,
                    onTap: () => _showSortSheet(clientCode),
                  ),
                  const SizedBox(width: 8),
                  _HeaderAddTrackButton(
                    key: _fabKey,
                    onTap: () => showAddTracksDialog(context, ref),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Future<void> _showSortSheet(String clientCode) async {
    final selected = await showBlurredModalBottomSheet<TrackSortMode>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.22),
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
    final result = await showBlurredModalBottomSheet<_TrackFiltersResult>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.22),
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
    final switchTarget = _clientCodeSwitchTarget(clientCode);
    if (switchTarget != null) {
      _scheduleInitialClientSwitch(switchTarget);
      return const Center(child: CircularProgressIndicator());
    }

    // Получаем notifier и состояние пагинированного списка
    final tracksNotifier = ref.watch(paginatedTracksProvider(clientCode));
    // Подписываемся на изменения состояния notifier
    _updateNotifierListener(tracksNotifier);

    final tracksState = tracksNotifier.state;
    final currentFilters = _getFilterParams(clientCode);
    if (_filtersInitializedForClientCode != clientCode) {
      _filtersInitializedForClientCode = clientCode;
      if (tracksState.filters != currentFilters) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ref
              .read(paginatedTracksProvider(clientCode))
              .updateFilters(currentFilters);
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
    const bulkButtonExtraPad = 110.0;

    final groups = tracksState.tracks.isNotEmpty
        ? _groupTracks(tracksState.tracks)
        : <_GroupBucket>[];
    if (tracksState.filters == currentFilters) {
      _maybeOpenInitialTarget(
        groups,
        clientCode,
        isLoading: tracksState.isLoading,
      );
    }
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
                final changed = _syncMapsWithServerData(
                  ref.read(paginatedTracksProvider(clientCode)).state.tracks,
                );
                if (changed && mounted) setState(() {});
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
                  72,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 86,
                    child: _TrackSheetSecondaryButton(
                      label: 'Все',
                      onTap: _selectAll,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: _TrackSheetPrimaryButton(
                      label: _actionLabel(),
                      icon: Icons.inventory_2_rounded,
                      onTap: _selectedStatus == null
                          ? null
                          : () => _bulkAction(context),
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
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: _TracksLoadingState(),
          ),
        ),
      ];
    }

    // Показываем ошибку
    if (tracksState.error != null && tracksState.tracks.isEmpty) {
      final errorInfo = ErrorUtils.getErrorInfo(tracksState.error!);
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _TracksStateCard(
              icon: errorInfo.icon,
              title: errorInfo.getTitle(context),
              message: errorInfo.getMessage(context),
              iconColor: Colors.redAccent,
              actionLabel: 'Повторить',
              onAction: () {
                final params = _getFilterParams(clientCode);
                ref
                    .read(paginatedTracksProvider(clientCode))
                    .updateFilters(params);
              },
            ),
          ),
        ),
      ];
    }

    // Пустой список
    if (tracksState.tracks.isEmpty) {
      return [
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: _TracksStateCard(
              icon: Icons.local_shipping_outlined,
              title: 'Ничего не найдено',
              message: 'Попробуйте изменить фильтры или строку поиска.',
            ),
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
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: _TracksEndCard(
                    text:
                        'Не удалось загрузить всё. Потяните вниз для обновления.',
                    icon: Icons.cloud_off_rounded,
                  ),
                );
              }
              if (!tracksState.hasMore && tracksState.tracks.isNotEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: _TracksEndCard(
                    text: 'Все треки загружены',
                    icon: Icons.done_all_rounded,
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
            final groupTargetKey = _groupTargetKey(g);
            final highlighted = _highlightedGroupKey == groupTargetKey;

            return KeyedSubtree(
              key: _keyForGroup(g),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _TargetHighlightFrame(
                  highlighted: highlighted,
                  child: index == 0
                      ? KeyedSubtree(key: _trackDetailKey, child: trackCard)
                      : trackCard,
                ),
              ),
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
    final selectedStatus = _selectedStatus;
    if (selectedStatus == null) return;
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
        .where((t) => t.status == selectedStatus)
        .map((t) => t.code)
        .toSet();

    if (allWithStatus.isEmpty) return;

    if (!mounted) return;
    final allAlreadySelected = allWithStatus.every(_selectedTracks.contains);
    setState(() {
      if (allAlreadySelected) {
        _selectedTracks.clear();
        _selectedStatus = null;
      } else {
        _selectedTracks.addAll(allWithStatus);
      }
    });
    if (allAlreadySelected) {
      _showStyledSnackBar(context, 'Выделение треков снято');
      return;
    }
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

class _TracksLoadingState extends StatelessWidget {
  const _TracksLoadingState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _tracksPremiumCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: context.brandPrimary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.local_shipping_rounded,
                  color: context.brandPrimary,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Загружаем треки и сборки',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontFamily: 'Gilroy',
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        height: 1.1,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Подготовим актуальные статусы и задачи',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontFamily: 'Gilroy',
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const _TrackSkeletonLine(widthFactor: 0.86),
          const SizedBox(height: 10),
          const _TrackSkeletonLine(widthFactor: 0.62),
          const SizedBox(height: 10),
          const _TrackSkeletonLine(widthFactor: 0.74),
        ],
      ),
    );
  }
}

class _TrackSkeletonLine extends StatelessWidget {
  final double widthFactor;

  const _TrackSkeletonLine({required this.widthFactor});

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: widthFactor,
      child: Container(
        height: 14,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F3F7),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class _TracksStateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Color? iconColor;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _TracksStateCard({
    required this.icon,
    required this.title,
    required this.message,
    this.iconColor,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? context.brandPrimary;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _tracksPremiumCardDecoration(context),
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontFamily: 'Gilroy',
              fontWeight: FontWeight.w900,
              fontSize: 17,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontFamily: 'Gilroy',
              fontWeight: FontWeight.w600,
              fontSize: 13,
              height: 1.25,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(actionLabel!),
                style: FilledButton.styleFrom(
                  backgroundColor: context.brandPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: const TextStyle(
                    fontFamily: 'Gilroy',
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TracksEndCard extends StatelessWidget {
  final String text;
  final IconData icon;

  const _TracksEndCard({required this.text, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: context.brandPrimary, size: 16),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontFamily: 'Gilroy',
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

BoxDecoration _tracksPremiumCardDecoration(
  BuildContext context, {
  double radius = 22,
  bool selected = false,
}) {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: selected
          ? context.brandPrimary.withValues(alpha: 0.32)
          : Colors.black.withValues(alpha: 0.045),
      width: selected ? 1.3 : 1,
    ),
    boxShadow: [
      BoxShadow(
        color: selected
            ? context.brandPrimary.withValues(alpha: 0.13)
            : Colors.black.withValues(alpha: 0.045),
        blurRadius: selected ? 24 : 18,
        spreadRadius: -9,
        offset: const Offset(0, 12),
      ),
    ],
  );
}

class _TargetHighlightFrame extends StatelessWidget {
  final bool highlighted;
  final Widget child;

  const _TargetHighlightFrame({required this.highlighted, required this.child});

  @override
  Widget build(BuildContext context) {
    final accent = context.brandPrimary;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: highlighted ? const EdgeInsets.all(3) : EdgeInsets.zero,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        border: highlighted
            ? Border.all(color: accent.withValues(alpha: 0.38), width: 1.4)
            : null,
        boxShadow: highlighted
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: 0.20),
                  blurRadius: 26,
                  spreadRadius: -8,
                  offset: const Offset(0, 14),
                ),
              ]
            : null,
      ),
      child: child,
    );
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

class _TracksHeroHeader extends StatelessWidget {
  const _TracksHeroHeader();

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(24);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: context.brandGradient,
        borderRadius: radius,
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
        borderRadius: radius,
        child: Stack(
          children: [
            const Positioned.fill(child: _TracksHeaderGlowBackdrop()),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(17),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.22),
                      ),
                    ),
                    child: const Icon(
                      Icons.local_shipping_rounded,
                      color: Colors.white,
                      size: 25,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Треки и сборки',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'Gilroy',
                            fontWeight: FontWeight.w900,
                            fontSize: 24,
                            height: 1.04,
                            letterSpacing: -0.35,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Управляйте посылками, сборками и задачами склада',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Color(0xE6FFFFFF),
                            fontFamily: 'Gilroy',
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            height: 1.18,
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

class _TracksHeaderGlowBackdrop extends StatefulWidget {
  const _TracksHeaderGlowBackdrop();

  @override
  State<_TracksHeaderGlowBackdrop> createState() =>
      _TracksHeaderGlowBackdropState();
}

class _TracksHeaderGlowBackdropState extends State<_TracksHeaderGlowBackdrop>
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
                    child: _TracksHeaderGlowCircle(
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
                    child: _TracksHeaderGlowCircle(
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
                    child: _TracksHeaderGlowCircle(
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

class _TracksHeaderGlowCircle extends StatelessWidget {
  final double size;
  final Color color;

  const _TracksHeaderGlowCircle({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
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
    final accent = context.brandPrimary;
    final color = isActive ? accent : AppColors.textSecondary;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isActive
                  ? accent.withValues(alpha: 0.10)
                  : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isActive
                    ? accent.withValues(alpha: 0.18)
                    : Colors.black.withValues(alpha: 0.035),
              ),
            ),
            child: Center(child: Icon(icon, size: 21, color: color)),
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
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: context.brandGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: context.brandPrimary.withValues(alpha: 0.20),
                  blurRadius: 14,
                  spreadRadius: -7,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Center(
              child: Icon(Icons.add_rounded, color: Colors.white, size: 24),
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
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.035)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TracksViewModeSegment(
              icon: Icons.local_shipping_rounded,
              label: 'Треки',
              selected: value == ViewMode.singles,
              onTap: () => onChanged(ViewMode.singles),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _TracksViewModeSegment(
              icon: Icons.inventory_2_rounded,
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
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TracksViewModeSegment({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: selected ? context.brandGradient : null,
            color: selected ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(15),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: context.brandPrimary.withValues(alpha: 0.18),
                      blurRadius: 12,
                      spreadRadius: -7,
                      offset: const Offset(0, 7),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 17,
                color: selected ? Colors.white : AppColors.textSecondary,
              ),
              const SizedBox(width: 7),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Gilroy',
                  fontSize: 14,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  color: selected ? Colors.white : AppColors.textPrimary,
                  letterSpacing: -0.05,
                ),
              ),
            ],
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
    return AppOutlinedInputFrame(
      height: 48,
      radius: 16,
      fillColor: const Color(0xFFF8FAFC),
      borderColor: const Color(0xFFE3E7EE),
      builder: (context, focusNode) => TextField(
        focusNode: focusNode,
        controller: _controller,
        style: const TextStyle(
          fontFamily: 'Gilroy',
          fontSize: 14.5,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          letterSpacing: 0,
        ),
        decoration: InputDecoration(
          prefixIcon: focusNode.hasFocus
              ? null
              : Icon(
                  Icons.search_rounded,
                  color: context.brandPrimary,
                  size: 22,
                ),
          suffixIcon: _controller.text.isNotEmpty
              ? IconButton(
                  onPressed: () {
                    _controller.clear();
                    setState(() {});
                    widget.onClear();
                  },
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                )
              : null,
          hintText: 'Поиск по трек-номеру',
          hintStyle: const TextStyle(
            fontFamily: 'Gilroy',
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
            letterSpacing: 0,
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.fromLTRB(
            focusNode.hasFocus ? 16 : 0,
            14,
            12,
            14,
          ),
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

class _TrackSheetSurface extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? pinnedChild;
  final Widget? footer;
  final EdgeInsetsGeometry contentPadding;
  final bool keyboardAware;
  final ScrollController? scrollController;

  const _TrackSheetSurface({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
    this.pinnedChild,
    this.footer,
    this.contentPadding = const EdgeInsets.fromLTRB(16, 0, 16, 16),
    this.keyboardAware = false,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final keyboardInset = keyboardAware
        ? MediaQuery.viewInsetsOf(context).bottom
        : 0.0;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.9,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SheetHandle(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: _TrackSheetHeader(
                  icon: icon,
                  title: title,
                  subtitle: subtitle,
                ),
              ),
              if (pinnedChild != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  child: pinnedChild,
                ),
              Flexible(
                child: SingleChildScrollView(
                  controller: scrollController,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: Padding(padding: contentPadding, child: child),
                ),
              ),
              if (footer != null)
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 12 + bottomPadding),
                  child: footer,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrackSheetHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _TrackSheetHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

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
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
            ),
            child: Icon(icon, color: Colors.white, size: 23),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Gilroy',
                    fontSize: 21,
                    height: 1.05,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.25,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xE6FFFFFF),
                    fontFamily: 'Gilroy',
                    fontSize: 12.8,
                    height: 1.15,
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

class _TrackSortSheet extends StatelessWidget {
  final TrackSortMode selected;

  const _TrackSortSheet({required this.selected});

  @override
  Widget build(BuildContext context) {
    return _TrackSheetSurface(
      icon: Icons.swap_vert_rounded,
      title: 'Сортировка',
      subtitle: 'Выберите порядок отображения треков и сборок',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final mode in TrackSortMode.values) ...[
            _SheetOptionTile(
              icon: mode == TrackSortMode.createdAt
                  ? CupertinoIcons.plus_circle
                  : CupertinoIcons.arrow_2_circlepath_circle,
              title: mode.label,
              subtitle: mode == TrackSortMode.createdAt
                  ? 'Сначала недавно добавленные посылки'
                  : 'Сначала недавно изменённые статусы',
              selected: mode == selected,
              onTap: () => Navigator.pop(context, mode),
            ),
            if (mode != TrackSortMode.values.last) const SizedBox(height: 8),
          ],
        ],
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

    return _TrackSheetSurface(
      icon: Icons.filter_alt_rounded,
      title: 'Фильтр',
      subtitle: isAssemblyMode
          ? 'Настройте статусы и заполненность доставки'
          : 'Быстро отберите треки по статусу, товару и задачам',
      contentPadding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      footer: Row(
        children: [
          Expanded(
            child: _TrackSheetSecondaryButton(
              label: 'Сбросить',
              onTap: () => Navigator.pop(
                context,
                const _TrackFiltersResult(
                  statusCode: null,
                  productInfoMode: ProductInfoMode.all,
                  photoRequestStatusCode: null,
                  questionStatusCode: null,
                  deliveryInfoMode: DeliveryInfoMode.all,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _TrackSheetPrimaryButton(
              label: 'Применить',
              icon: Icons.check_rounded,
              onTap: () => Navigator.pop(
                context,
                _TrackFiltersResult(
                  statusCode: _statusCode,
                  productInfoMode: _productInfoMode,
                  photoRequestStatusCode: _photoRequestStatusCode,
                  questionStatusCode: _questionStatusCode,
                  deliveryInfoMode: _deliveryInfoMode,
                ),
              ),
            ),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TrackFilterSectionCard(
            icon: Icons.flag_rounded,
            title: 'Статус',
            child: Wrap(
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
          ),
          const SizedBox(height: 10),
          if (isAssemblyMode)
            _TrackFilterSectionCard(
              icon: Icons.local_shipping_rounded,
              title: 'Данные доставки',
              child: Wrap(
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
            )
          else ...[
            _TrackFilterSectionCard(
              icon: Icons.inventory_2_rounded,
              title: 'О товаре',
              child: Wrap(
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
            ),
            const SizedBox(height: 10),
            _TrackFilterSectionCard(
              icon: Icons.photo_camera_rounded,
              title: 'Фотоотчёт',
              child: Wrap(
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
            ),
            const SizedBox(height: 10),
            _TrackFilterSectionCard(
              icon: Icons.help_rounded,
              title: 'Вопросы',
              child: Wrap(
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
            ),
          ],
        ],
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

class _TrackFilterSectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _TrackFilterSectionCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.035)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: context.brandPrimary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: context.brandPrimary, size: 17),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontFamily: 'Gilroy',
                    fontSize: 14.5,
                    height: 1.05,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.05,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _TrackSheetNoticeCard extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _TrackSheetNoticeCard({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color.withValues(alpha: 0.92),
                fontFamily: 'Gilroy',
                fontSize: 12.8,
                height: 1.22,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackSheetMetaCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final int valueMaxLines;

  const _TrackSheetMetaCard({
    required this.icon,
    required this.title,
    required this.value,
    this.valueMaxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.035)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: context.brandPrimary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: context.brandPrimary, size: 19),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontFamily: 'Gilroy',
                    fontSize: 12.2,
                    height: 1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  value,
                  maxLines: valueMaxLines,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontFamily: 'Gilroy',
                    fontSize: 15.5,
                    height: 1.05,
                    fontWeight: FontWeight.w900,
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
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            gradient: selected ? context.brandGradient : null,
            color: selected ? null : Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? context.brandPrimary.withValues(alpha: 0.18)
                  : Colors.black.withValues(alpha: 0.045),
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: context.brandPrimary.withValues(alpha: 0.16),
                      blurRadius: 12,
                      spreadRadius: -8,
                      offset: const Offset(0, 7),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Gilroy',
              fontSize: 12.8,
              height: 1,
              fontWeight: FontWeight.w900,
              color: selected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetOptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _SheetOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = context.brandPrimary;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected
                ? accent.withValues(alpha: 0.10)
                : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? accent.withValues(alpha: 0.22)
                  : Colors.black.withValues(alpha: 0.035),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: selected
                      ? accent.withValues(alpha: 0.13)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  icon,
                  color: selected ? accent : AppColors.textSecondary,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected ? accent : AppColors.textPrimary,
                        fontFamily: 'Gilroy',
                        fontSize: 15,
                        height: 1.05,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontFamily: 'Gilroy',
                        fontSize: 12.5,
                        height: 1.15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: selected ? accent : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected
                        ? accent
                        : Colors.black.withValues(alpha: 0.08),
                  ),
                ),
                child: selected
                    ? const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 18,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrackSheetPrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  const _TrackSheetPrimaryButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          height: 48,
          decoration: BoxDecoration(
            gradient: onTap == null ? null : context.brandGradient,
            color: onTap == null ? const Color(0xFFE8EAEE) : null,
            borderRadius: BorderRadius.circular(16),
            boxShadow: onTap == null
                ? null
                : [
                    BoxShadow(
                      color: context.brandPrimary.withValues(alpha: 0.18),
                      blurRadius: 14,
                      spreadRadius: -8,
                      offset: const Offset(0, 8),
                    ),
                  ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: onTap == null ? AppColors.textSecondary : Colors.white,
                size: 19,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: onTap == null
                        ? AppColors.textSecondary
                        : Colors.white,
                    fontFamily: 'Gilroy',
                    fontSize: 14,
                    height: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrackSheetSecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _TrackSheetSecondaryButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: context.brandPrimary.withValues(alpha: 0.24),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: context.brandPrimary,
              fontFamily: 'Gilroy',
              fontSize: 14,
              height: 1,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
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
  final ValueChanged<TrackItem> onTransferClientCode;
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
    required this.onTransferClientCode,
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
      clipBehavior: Clip.antiAlias,
      decoration: _tracksPremiumCardDecoration(context),
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
                      widget.assembly!.hasFragileGoods ||
                      widget.assembly!.placePreference != 'unspecified' ||
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
                                      if (widget.assembly!.hasFragileGoods ||
                                          widget.assembly!.placePreference !=
                                              'unspecified') ...[
                                        if (widget.assembly!.tariffName !=
                                                null ||
                                            widget
                                                .assembly!
                                                .packagingTypes
                                                .isNotEmpty)
                                          const SizedBox(height: 8),
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Icon(
                                              Icons.inventory_2_outlined,
                                              size: 16,
                                              color: context.brandPrimary,
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                [
                                                  if (widget
                                                      .assembly!
                                                      .hasFragileGoods)
                                                    'Хрупкий груз',
                                                  if (widget
                                                          .assembly!
                                                          .placePreference ==
                                                      'single_if_possible')
                                                    'По возможности 1 место',
                                                  if (widget
                                                          .assembly!
                                                          .placePreference ==
                                                      'split_allowed')
                                                    'Можно разделить',
                                                ].join(' • '),
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 13,
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
                                                .isNotEmpty ||
                                            widget.assembly!.hasFragileGoods ||
                                            widget.assembly!.placePreference !=
                                                'unspecified')
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
              final hasActiveTransferRequest = visibleQuestions.any(
                (q) =>
                    q.questionType == _clientCodeTransferQuestionType &&
                    q.isActive,
              );
              final canTransferClientCode =
                  widget.assembly == null &&
                  track.assembly == null &&
                  !hasActiveTransferRequest &&
                  (track.statusCode == 'pending' ||
                      track.statusCode == 'in_warehouse');
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
                  final statusColor = q.hasResponse
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
                      answerPhotoUrls: q.answerPhotoUrls,
                      trackCode: track.code,
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
                      answerPhotoUrls: const [],
                      trackCode: track.code,
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
                        if (track.spItems.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          _TrackSpItemsBlock(items: track.spItems),
                        ],
                        if (infoSections.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          _TrackInfoSectionsSurface(children: infoSections),
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
                            if (canTransferClientCode)
                              _ActionChipButton(
                                label: 'Перенести',
                                icon: Icons.swap_horiz_rounded,
                                onPressed: () =>
                                    widget.onTransferClientCode(track),
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
    final hasActiveTransferRequest = visibleQuestions.any(
      (q) => q.questionType == _clientCodeTransferQuestionType && q.isActive,
    );
    final canTransferClientCode =
        !embeddedInAssembly &&
        track.assembly == null &&
        !hasActiveTransferRequest &&
        (track.statusCode == 'pending' || track.statusCode == 'in_warehouse');
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
        final statusColor = q.hasResponse
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
            answerPhotoUrls: q.answerPhotoUrls,
            trackCode: track.code,
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
            answerPhotoUrls: const [],
            trackCode: track.code,
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
      if (canTransferClientCode)
        _TrackCardAction(
          label: 'Перенести',
          onTap: () => widget.onTransferClientCode(track),
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
        activeQuestion?.hasResponse == true ||
        activeQuestion?.status == 'completed';
    final questionPending = activeQuestion != null && !questionDone;
    final photoDone =
        photoMediaUrls.isNotEmpty || activePhoto?.status == 'completed';
    final photoPending = activePhoto != null && !photoDone;
    final statusColor = parseHexColor(track.statusColor);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: _tracksPremiumCardDecoration(context, selected: isSelected),
      child: Padding(
        padding: const EdgeInsets.all(14),
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
            if (track.spItems.isNotEmpty) ...[
              const SizedBox(height: 12),
              _TrackSpItemsBlock(items: track.spItems),
            ],
            if (infoSections.isNotEmpty) ...[
              const SizedBox(height: 12),
              _TrackInfoSectionsSurface(children: infoSections),
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
      decoration: _tracksPremiumCardDecoration(context),
      child: Padding(
        padding: const EdgeInsets.all(14),
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
            if (assembly.tariffName != null ||
                assembly.packagingTypes.isNotEmpty ||
                assembly.hasFragileGoods ||
                assembly.placePreference != 'unspecified') ...[
              const SizedBox(height: 15),
              _buildAssemblyPackingBlock(context, assembly),
            ],
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
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (createdAt != null)
                    _TrackDateMeta(
                      icon: CupertinoIcons.plus_circle,
                      value: dateFormat.format(createdAt),
                    ),
                  if (updatedAt != null)
                    _TrackDateMeta(
                      icon: CupertinoIcons.arrow_2_circlepath_circle,
                      value: dateFormat.format(updatedAt),
                    ),
                ],
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

  Widget _buildAssemblyPackingBlock(
    BuildContext context,
    TrackAssembly assembly,
  ) {
    final placePreference = switch (assembly.placePreference) {
      'single_if_possible' => 'По возможности 1 место',
      'split_allowed' => 'Можно разделить',
      _ => 'Не важно',
    };
    final lines = [
      if (assembly.tariffName != null) 'Тариф: ${assembly.tariffName}',
      if (assembly.packagingTypes.isNotEmpty)
        'Упаковка: ${assembly.packagingTypes.join(', ')}',
      if (assembly.hasFragileGoods) 'Хрупкий груз: Да',
      if (assembly.placePreference != 'unspecified') 'Места: $placePreference',
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _AssemblySectionHeader(
          title: 'Упаковка и тариф',
          isExpanded: true,
          onTap: null,
        ),
        const SizedBox(height: 7),
        for (var i = 0; i < lines.length; i++) ...[
          if (i > 0) const SizedBox(height: 5),
          _AssemblyPlainText(lines[i]),
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
                : AppCachedMediaImage(
                    url: photos.first,
                    thumbnailSize: 480,
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
    if (box.packagingUsages.isNotEmpty) {
      return box.packagingUsages.map((usage) => usage.displayValue).join(', ');
    }
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
    await showBlurredModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.22),
      builder: (sheetContext) => _TrackSheetSurface(
        icon: Icons.photo_library_rounded,
        title: 'Фотоотчёт',
        subtitle: track.code,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: _TaskStatusBadge(text: statusLabel, color: statusColor),
            ),
            const SizedBox(height: 12),
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
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              GridView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                addAutomaticKeepAlives: false,
                addSemanticIndexes: false,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
                          if (isVideo)
                            DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.black.withValues(alpha: 0.45),
                                    Colors.black.withValues(alpha: 0.18),
                                  ],
                                ),
                              ),
                            )
                          else
                            AppCachedMediaImage(
                              url: mediaUrls[index],
                              thumbnailSize: 360,
                              memCacheWidth: 160,
                              memCacheHeight: 160,
                              maxWidthDiskCache: 320,
                              maxHeightDiskCache: 320,
                              imageBuilder: (_, imageProvider) => DecoratedBox(
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
          track.code,
        ),
      if (pendingLocalQuestion.isNotEmpty && visibleQuestions.isEmpty)
        _QuestionDetailsItem(
          title: 'Вопрос',
          statusLabel: widget.questionStatus[track.code] ?? 'Новый',
          statusColor: Colors.orange,
          question: pendingLocalQuestion,
          answer: null,
          answerPhotoUrls: const [],
          trackCode: track.code,
          createdAt: widget.questionCreatedAt[track.code] ?? DateTime.now(),
          answeredAt: null,
          canCancel: true,
        ),
    ];
    if (items.isEmpty) return;
    final canCancelAny = items.any((item) => item.canCancel);

    await showBlurredModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.22),
      builder: (sheetContext) => _TrackSheetSurface(
        icon: Icons.help_rounded,
        title: 'Вопрос по треку',
        subtitle: track.code,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        _TrackDateMeta(
                          icon: CupertinoIcons.plus_circle,
                          value: dateFormat.format(track.createdAt),
                        ),
                        _TrackDateMeta(
                          icon: CupertinoIcons.arrow_2_circlepath_circle,
                          value: dateFormat.format(track.updatedAt),
                        ),
                      ],
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
                    child: _HorizontalScrollHint(
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
              box.packagingUsages.isNotEmpty ||
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
                (box.tariffName != null ||
                    box.packagingTypes.isNotEmpty ||
                    box.packagingUsages.isNotEmpty))
              const SizedBox(height: 6),
            if (box.tariffName != null)
              _buildBoxParam(
                context,
                icon: Icons.local_shipping_outlined,
                label: tr(context, ru: 'Тариф', zh: '费率'),
                value: box.tariffName!,
              ),
            if (box.tariffName != null &&
                (box.packagingTypes.isNotEmpty ||
                    box.packagingUsages.isNotEmpty))
              const SizedBox(height: 6),
            if (box.packagingTypes.isNotEmpty || box.packagingUsages.isNotEmpty)
              _buildBoxParam(
                context,
                icon: Icons.inventory_2_outlined,
                label: tr(context, ru: 'Упаковка', zh: '包装'),
                value: box.packagingUsages.isNotEmpty
                    ? box.packagingUsages
                          .map((usage) => usage.displayValue)
                          .join(', ')
                    : box.packagingTypes.join(', '),
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
                child: AppCachedMediaImage(
                  url: box.photos.first.url,
                  thumbnailSize: 720,
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
    final isLight = color.computeLuminance() > 0.58;
    final textColor = isLight ? AppColors.textPrimary : color;
    final bg = isLight
        ? color.withValues(alpha: 0.42)
        : color.withValues(alpha: 0.12);

    return Container(
      constraints: const BoxConstraints(minHeight: 28),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: textColor,
          fontFamily: 'Gilroy',
          fontSize: 12.5,
          height: 1,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _AssemblySectionHeader extends StatelessWidget {
  final String title;
  final bool isExpanded;
  final VoidCallback? onTap;

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
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 24),
        child: Row(
          children: [
            Text(
              title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontFamily: 'Gilroy',
                fontSize: 15,
                height: 1.1,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.05,
              ),
            ),
            const Spacer(),
            if (onTap != null)
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  isExpanded
                      ? CupertinoIcons.chevron_up
                      : CupertinoIcons.chevron_down,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
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
        color: AppColors.textPrimary,
        fontFamily: 'Gilroy',
        fontSize: 12.5,
        height: 1.25,
        fontWeight: FontWeight.w600,
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
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ],
      ),
      softWrap: true,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontFamily: 'Gilroy',
        fontSize: 12.5,
        height: 1.25,
        fontWeight: FontWeight.w600,
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
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: value ? accent : Colors.white,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: value ? accent : Colors.black.withValues(alpha: 0.18),
          ),
          boxShadow: value
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.18),
                    blurRadius: 10,
                    spreadRadius: -6,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: value
            ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
            : null,
      ),
    );
  }
}

class _TrackDateMeta extends StatelessWidget {
  final IconData icon;
  final String value;

  const _TrackDateMeta({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(width: 1),
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontFamily: 'Gilroy',
            fontSize: 12,
            height: 1.1,
            fontWeight: FontWeight.w700,
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
    final accent = color ?? context.brandPrimary;
    final isLight = accent.computeLuminance() > 0.58;
    final bg = isLight
        ? accent.withValues(alpha: 0.42)
        : accent.withValues(alpha: 0.12);
    final textColor = isLight ? AppColors.textPrimary : accent;

    return Container(
      constraints: const BoxConstraints(minHeight: 28, maxWidth: 150),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.20)),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: textColor,
          fontFamily: 'Gilroy',
          fontSize: 12.5,
          height: 1,
          fontWeight: FontWeight.w900,
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
    final child = Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(child: Icon(icon, size: 17, color: color)),
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
    final textColor = _taskReadableColor(color);
    return Container(
      constraints: const BoxConstraints(minHeight: 28),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: textColor,
          fontFamily: 'Gilroy',
          fontSize: 12.2,
          height: 1,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

Color _taskReadableColor(Color color) {
  return color.computeLuminance() > 0.58 ? AppColors.textPrimary : color;
}

class _TrackTaskIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _TrackTaskIconButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: color.withValues(alpha: 0.12)),
          ),
          child: Icon(icon, size: 17, color: color),
        ),
      ),
    );
  }
}

class _TrackTaskChevronButton extends StatelessWidget {
  final bool expanded;

  const _TrackTaskChevronButton({required this.expanded});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: Colors.black.withValues(alpha: 0.035)),
      ),
      child: Icon(
        expanded ? CupertinoIcons.chevron_up : CupertinoIcons.chevron_down,
        size: 15,
        color: AppColors.textSecondary,
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
  final List<String> answerPhotoUrls;
  final String trackCode;
  final DateTime createdAt;
  final DateTime? answeredAt;
  final bool canCancel;

  const _QuestionDetailsItem({
    required this.title,
    required this.statusLabel,
    required this.statusColor,
    required this.question,
    required this.answer,
    required this.answerPhotoUrls,
    required this.trackCode,
    required this.createdAt,
    required this.answeredAt,
    required this.canCancel,
  });

  factory _QuestionDetailsItem.fromQuestion(
    TrackQuestion question,
    String title,
    String trackCode,
  ) {
    return _QuestionDetailsItem(
      title: title,
      statusLabel: question.statusLabel,
      statusColor: question.hasResponse
          ? const Color(0xFF27C47A)
          : question.status == 'cancelled'
          ? Colors.redAccent
          : Colors.orange,
      question: question.question,
      answer: question.hasAnswer ? question.answer : null,
      answerPhotoUrls: question.answerPhotoUrls,
      trackCode: trackCode,
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
          if (item.answerPhotoUrls.isNotEmpty) ...[
            const SizedBox(height: 10),
            _QuestionAnswerPhotoGrid(
              urls: item.answerPhotoUrls,
              trackCode: item.trackCode,
            ),
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
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      alignment: Alignment.center,
      child: Icon(CupertinoIcons.question_circle_fill, size: 18, color: color),
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
    final textColor = _taskReadableColor(color);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: textColor),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textColor,
                fontFamily: 'Gilroy',
                fontSize: 11.5,
                height: 1,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionAnswerPhotoGrid extends StatelessWidget {
  final List<String> urls;
  final String trackCode;

  const _QuestionAnswerPhotoGrid({required this.urls, required this.trackCode});

  void _open(BuildContext context, int index) {
    final photos = urls
        .map(
          (url) => PhotoItem(
            url: url,
            date: DateTime.now(),
            trackingNumber: trackCode,
          ),
        )
        .toList();
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => PhotoViewerScreen(
          item: photos[index],
          allPhotos: photos,
          initialIndex: index,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Фото склада',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontFamily: 'Gilroy',
            fontSize: 12.5,
            height: 1,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 6,
            mainAxisSpacing: 6,
            childAspectRatio: 1,
          ),
          itemCount: urls.length,
          itemBuilder: (context, index) {
            return GestureDetector(
              onTap: () => _open(context, index),
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.black.withValues(alpha: 0.035),
                  ),
                ),
                child: AppCachedMediaImage(
                  url: urls[index],
                  thumbnailSize: 360,
                  fit: BoxFit.cover,
                  memCacheWidth: 180,
                  memCacheHeight: 180,
                  maxWidthDiskCache: 360,
                  maxHeightDiskCache: 360,
                  fadeInDuration: Duration.zero,
                  fadeOutDuration: Duration.zero,
                  placeholder: (_, _) => const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  errorWidget: (_, _, _) => Container(
                    color: Colors.black.withValues(alpha: 0.06),
                    child: const Icon(Icons.broken_image_outlined, size: 20),
                  ),
                ),
              ),
            );
          },
        ),
      ],
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: muted ? const Color(0xFFF6FBF8) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: 0.035)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontFamily: 'Gilroy',
              fontSize: 12.2,
              height: 1,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            text,
            style: TextStyle(
              color: muted ? AppColors.textSecondary : AppColors.textPrimary,
              fontFamily: 'Gilroy',
              fontSize: 13.5,
              height: 1.28,
              fontWeight: FontWeight.w600,
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
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: action.onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: accent.withValues(alpha: 0.16)),
          ),
          alignment: Alignment.center,
          child: Text(
            action.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: accent,
              fontFamily: 'Gilroy',
              fontSize: 12.5,
              height: 1,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _HorizontalScrollHint extends StatefulWidget {
  final Widget child;

  const _HorizontalScrollHint({required this.child});

  @override
  State<_HorizontalScrollHint> createState() => _HorizontalScrollHintState();
}

class _HorizontalScrollHintState extends State<_HorizontalScrollHint> {
  final ScrollController _controller = ScrollController();
  bool _showLeadingHint = false;
  bool _showTrailingHint = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updateHints);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateHints());
  }

  @override
  void didUpdateWidget(covariant _HorizontalScrollHint oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateHints());
  }

  @override
  void dispose() {
    _controller.removeListener(_updateHints);
    _controller.dispose();
    super.dispose();
  }

  void _updateHints() {
    if (!mounted || !_controller.hasClients) return;
    final position = _controller.position;
    if (!position.hasContentDimensions) return;

    final canScroll = position.maxScrollExtent > 1;
    final showLeading = canScroll && position.pixels > 1;
    final showTrailing =
        canScroll && position.pixels < position.maxScrollExtent - 1;

    if (_showLeadingHint == showLeading && _showTrailingHint == showTrailing) {
      return;
    }

    setState(() {
      _showLeadingHint = showLeading;
      _showTrailingHint = showTrailing;
    });
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateHints());

    return Stack(
      fit: StackFit.expand,
      children: [
        SingleChildScrollView(
          controller: _controller,
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: widget.child,
        ),
        if (_showLeadingHint)
          Positioned.fill(
            right: null,
            child: _HorizontalScrollEdgeHint(
              alignment: Alignment.centerLeft,
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              icon: CupertinoIcons.chevron_left,
            ),
          ),
        if (_showTrailingHint)
          Positioned.fill(
            left: null,
            child: _HorizontalScrollEdgeHint(
              alignment: Alignment.centerRight,
              begin: Alignment.centerRight,
              end: Alignment.centerLeft,
              icon: CupertinoIcons.chevron_right,
            ),
          ),
      ],
    );
  }
}

class _HorizontalScrollEdgeHint extends StatelessWidget {
  final Alignment alignment;
  final Alignment begin;
  final Alignment end;
  final IconData icon;

  const _HorizontalScrollEdgeHint({
    required this.alignment,
    required this.begin,
    required this.end,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: 34,
        alignment: alignment,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: begin,
            end: end,
            colors: const [Colors.white, Color(0x00FFFFFF)],
          ),
        ),
        child: Icon(
          icon,
          size: 14,
          color: context.brandPrimary.withValues(alpha: 0.75),
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
                  ? AppCachedMediaImage(
                      url: imageUrls.first,
                      thumbnailSize: 480,
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
                        if (_isVideoUrl(ApiConfig.getMediaUrl(visibleUrls[i])))
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.black.withValues(alpha: 0.45),
                                  Colors.black.withValues(alpha: 0.18),
                                ],
                              ),
                            ),
                          )
                        else
                          AppCachedMediaImage(
                            url: visibleUrls[i],
                            thumbnailSize: 360,
                            memCacheWidth: 180,
                            memCacheHeight: 180,
                            maxWidthDiskCache: 360,
                            maxHeightDiskCache: 360,
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
                              child: Icon(
                                Icons.broken_image_outlined,
                                size: 20,
                              ),
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
        showBlurredModalBottomSheet<T>(
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
    final accent = context.brandPrimary;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? accent.withValues(alpha: 0.10)
                : const Color(0xFFFFFFFF),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected
                  ? accent.withValues(alpha: 0.24)
                  : Colors.black.withValues(alpha: 0.045),
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.12),
                      blurRadius: 14,
                      spreadRadius: -8,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isSelected
                      ? accent.withValues(alpha: 0.14)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  icon,
                  color: isSelected ? accent : AppColors.textSecondary,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isSelected ? accent : AppColors.textPrimary,
                        fontFamily: 'Gilroy',
                        fontSize: 15,
                        height: 1.05,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontFamily: 'Gilroy',
                        fontSize: 12.5,
                        height: 1.15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isSelected ? accent : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? accent
                        : Colors.black.withValues(alpha: 0.08),
                  ),
                ),
                child: isSelected
                    ? const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 18,
                      )
                    : null,
              ),
            ],
          ),
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

class _TrackInfoSectionsSurface extends StatelessWidget {
  final List<Widget> children;

  const _TrackInfoSectionsSurface({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.035)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            children[i],
          ],
        ],
      ),
    );
  }
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
    final accent = context.brandPrimary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 14,
            spreadRadius: -8,
            offset: const Offset(0, 8),
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
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: accent.withValues(alpha: 0.14)),
                  ),
                  child: Icon(
                    Icons.sticky_note_2_rounded,
                    size: 18,
                    color: accent,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Заметка',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontFamily: 'Gilroy',
                          fontWeight: FontWeight.w900,
                          fontSize: 14.5,
                          height: 1.05,
                          letterSpacing: -0.05,
                        ),
                      ),
                      if (!_expanded) ...[
                        const SizedBox(height: 4),
                        Text(
                          widget.text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontFamily: 'Gilroy',
                            fontWeight: FontWeight.w600,
                            fontSize: 12.5,
                            height: 1.15,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (widget.onEdit != null) ...[
                  const SizedBox(width: 8),
                  _TrackTaskIconButton(
                    icon: Icons.edit_outlined,
                    color: accent,
                    onTap: widget.onEdit!,
                  ),
                ],
                const SizedBox(width: 6),
                _TrackTaskChevronButton(expanded: _expanded),
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.black.withValues(alpha: 0.035),
                        ),
                      ),
                      child: Text(
                        widget.text,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontFamily: 'Gilroy',
                          fontSize: 13.5,
                          height: 1.28,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _TrackSpItemsBlock extends StatelessWidget {
  final List<TrackSpItem> items;

  const _TrackSpItemsBlock({required this.items});

  @override
  Widget build(BuildContext context) {
    final accent = context.brandPrimary;
    final visibleItems = items.take(3).toList();
    final firstPurchase = items
        .map((item) => item.purchase?.title.trim())
        .whereType<String>()
        .where((title) => title.isNotEmpty)
        .firstOrNull;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.86),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: accent.withValues(alpha: 0.12)),
                ),
                child: Icon(Icons.groups_2_rounded, color: accent, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      firstPurchase ?? 'Совместная покупка',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontFamily: 'Gilroy',
                        fontSize: 14.5,
                        height: 1.05,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      items.length == 1
                          ? 'Трек привязан к товару СП'
                          : 'Трек привязан к товарам СП: ${items.length}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontFamily: 'Gilroy',
                        fontSize: 12.5,
                        height: 1.1,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < visibleItems.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            _TrackSpItemRow(item: visibleItems[i]),
          ],
          if (items.length > visibleItems.length) ...[
            const SizedBox(height: 8),
            Text(
              '+ ещё ${items.length - visibleItems.length} товар(а)',
              style: TextStyle(
                color: accent,
                fontFamily: 'Gilroy',
                fontSize: 12.5,
                height: 1.1,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TrackSpItemRow extends StatelessWidget {
  final TrackSpItem item;

  const _TrackSpItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final accent = context.brandPrimary;
    final thumbnailUrl = item.media
        .map(
          (media) => (media.thumbnailUrl?.isNotEmpty == true)
              ? media.thumbnailUrl!
              : media.url,
        )
        .where((url) => url.trim().isNotEmpty)
        .firstOrNull;
    final customerName = item.customer?.fullName.trim();
    final priceLabel = _formatSpItemMoney(item);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.035)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TrackSpItemPreview(url: thumbnailUrl, trackTitle: item.title),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontFamily: 'Gilroy',
                    fontSize: 13.5,
                    height: 1.12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 5,
                  runSpacing: 5,
                  children: [
                    if (customerName != null && customerName.isNotEmpty)
                      _TrackSpMiniPill(
                        icon: Icons.person_outline_rounded,
                        label: customerName,
                      ),
                    _TrackSpMiniPill(
                      icon: Icons.inventory_2_outlined,
                      label: '${item.quantity} шт',
                    ),
                    _TrackSpMiniPill(
                      icon: Icons.verified_outlined,
                      label: _spItemStatusLabel(item.status),
                    ),
                    if (priceLabel != null)
                      _TrackSpMiniPill(
                        icon: Icons.payments_outlined,
                        label: priceLabel,
                        highlighted: true,
                      ),
                  ],
                ),
                if ((item.linkComment ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Text(
                    item.linkComment!.trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontFamily: 'Gilroy',
                      fontSize: 12,
                      height: 1.18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if ((item.sourceUrl ?? '').trim().isNotEmpty) ...[
            const SizedBox(width: 8),
            Icon(
              Icons.link_rounded,
              color: accent.withValues(alpha: 0.72),
              size: 18,
            ),
          ],
        ],
      ),
    );
  }
}

class _TrackSpItemPreview extends StatelessWidget {
  final String? url;
  final String trackTitle;

  const _TrackSpItemPreview({this.url, required this.trackTitle});

  @override
  Widget build(BuildContext context) {
    final accent = context.brandPrimary;
    final imageUrl = url?.trim();
    if (imageUrl == null || imageUrl.isEmpty) {
      return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Icon(Icons.shopping_bag_outlined, color: accent, size: 22),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        final photo = PhotoItem(
          url: imageUrl,
          date: DateTime.now(),
          trackingNumber: trackTitle,
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
        width: 48,
        height: 48,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(15),
        ),
        child: AppCachedMediaImage(
          url: imageUrl,
          thumbnailSize: 240,
          memCacheWidth: 120,
          memCacheHeight: 120,
          maxWidthDiskCache: 240,
          maxHeightDiskCache: 240,
          fadeInDuration: Duration.zero,
          fadeOutDuration: Duration.zero,
          filterQuality: FilterQuality.low,
          imageBuilder: (_, imageProvider) => DecoratedBox(
            decoration: BoxDecoration(
              image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
            ),
          ),
          placeholder: (_, _) => Center(
            child: Icon(Icons.shopping_bag_outlined, color: accent, size: 20),
          ),
          errorWidget: (_, _, _) => Center(
            child: Icon(Icons.broken_image_outlined, color: accent, size: 20),
          ),
        ),
      ),
    );
  }
}

class _TrackSpMiniPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool highlighted;

  const _TrackSpMiniPill({
    required this.icon,
    required this.label,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = context.brandPrimary;
    final color = highlighted ? accent : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        color: highlighted
            ? accent.withValues(alpha: 0.10)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: highlighted
              ? accent.withValues(alpha: 0.14)
              : Colors.black.withValues(alpha: 0.035),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontFamily: 'Gilroy',
                fontSize: 11.5,
                height: 1,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String? _formatSpItemMoney(TrackSpItem item) {
  final rubTotal =
      (item.clientPriceRub ?? 0) +
      (item.shippingCostRub ?? 0) +
      (item.additionalExpensesRub ?? 0);
  if (rubTotal > 0) {
    return '${_compactAmount(rubTotal)} ₽';
  }
  if ((item.clientPriceYuan ?? 0) > 0) {
    return '¥${_compactAmount(item.clientPriceYuan!)}';
  }
  return null;
}

String _compactAmount(double value) {
  final formatter = value % 1 == 0
      ? NumberFormat('#,##0', 'ru')
      : NumberFormat('#,##0.##', 'ru');
  return formatter.format(value);
}

String _spItemStatusLabel(String status) {
  switch (status) {
    case 'requested':
      return 'Запрошен';
    case 'need_info':
      return 'Нужны данные';
    case 'approved':
      return 'Подтверждён';
    case 'purchased':
      return 'Выкуплен';
    case 'not_purchased':
      return 'Не выкуплен';
    case 'cancelled':
      return 'Отменён';
    case 'in_transit':
      return 'В пути';
    case 'arrived':
      return 'Прибыл';
    case 'sorted':
      return 'Разобран';
    case 'ready_to_ship':
      return 'Готов к отправке';
    case 'sent_to_customer':
      return 'Отправлен клиенту';
    case 'delivered':
      return 'Доставлен';
    default:
      return status.isEmpty ? 'СП' : status;
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
              child: AppCachedMediaImage(
                url: imageUrls.first,
                thumbnailSize: 480,
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
  final List<String> answerPhotoUrls;
  final String trackCode;
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
    this.answerPhotoUrls = const [],
    required this.trackCode,
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
    final accent = widget.statusColor;
    final preview = widget.question.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 14,
            spreadRadius: -8,
            offset: const Offset(0, 8),
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
                _QuestionBadge(color: accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontFamily: 'Gilroy',
                                fontWeight: FontWeight.w900,
                                fontSize: 14.5,
                                height: 1.05,
                                letterSpacing: -0.05,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 116),
                            child: _TaskStatusBadge(
                              text: widget.statusLabel,
                              color: accent,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _QuestionMetaPill(
                            icon: CupertinoIcons.clock,
                            text: widget.createdAt,
                            color: AppColors.textSecondary,
                          ),
                          if (widget.answeredAt != null)
                            _QuestionMetaPill(
                              icon: CupertinoIcons.checkmark_alt_circle,
                              text: widget.answeredAt!,
                              color: const Color(0xFF27C47A),
                            ),
                        ],
                      ),
                      if (!_expanded && preview.isNotEmpty) ...[
                        const SizedBox(height: 7),
                        Text(
                          preview,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontFamily: 'Gilroy',
                            fontWeight: FontWeight.w600,
                            fontSize: 12.5,
                            height: 1.18,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (widget.canCancel) ...[
                  const SizedBox(width: 8),
                  _TrackTaskIconButton(
                    icon: Icons.delete_outline_rounded,
                    color: Colors.redAccent,
                    onTap: widget.onCancel,
                  ),
                ],
                const SizedBox(width: 6),
                _TrackTaskChevronButton(expanded: _expanded),
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.only(top: 12),
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
                            title: 'Ответ склада',
                            text: widget.answer!.trim(),
                            muted: true,
                          ),
                        ],
                        if (widget.answerPhotoUrls.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _QuestionAnswerPhotoGrid(
                            urls: widget.answerPhotoUrls,
                            trackCode: widget.trackCode,
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
