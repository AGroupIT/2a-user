import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:excel/excel.dart' as xls;
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../../core/ui/sheet_handle.dart';

import '../../../core/ui/app_layout.dart';
import '../../../core/ui/empty_state.dart';
import '../../../core/ui/status_pill.dart';
import '../../clients/application/client_codes_controller.dart';
import '../data/fake_tracks_repository.dart';
import '../domain/track_item.dart';

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
      backgroundColor: isError
          ? const Color(0xFFE53935)
          : const Color(0xFFfe3301),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 15 ),
      duration: const Duration(seconds: 3),
    ),
  );
}

class TracksScreen extends ConsumerStatefulWidget {
  const TracksScreen({super.key});

  @override
  ConsumerState<TracksScreen> createState() => _TracksScreenState();
}

class _TracksScreenState extends ConsumerState<TracksScreen> {
  bool _isExporting = false;
  // Local tracking for photo report requests and their notes
  final Set<String> _requestedPhotoReports = <String>{};
  final Map<String, String> _photoRequestNotes = <String, String>{};
  final Map<String, DateTime> _photoRequestCreatedAt = <String, DateTime>{};
  final Map<String, DateTime> _photoRequestUpdatedAt = <String, DateTime>{};
  String _status = 'Все';
  final List<String> _allStatuses = const [
    'Все',
    'На складе',
    'Отправлен',
    'Прибыл на терминал',
    'Сформирован к выдаче',
  ];
  ViewMode _viewMode = ViewMode.all;
  String _query = '';
  final Set<String> _selectedTracks = <String>{};
  String? _selectedStatus;
  final Set<String> _selectableStatuses = const {
    'На складе',
    'Отправлен',
    'Прибыл на терминал',
    'Сформирован к выдаче',
  };

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

  // Packaging options
  static const List<String> _packagingOptions = [
    'Коробка',
    'Картонные уголки',
    'Пенопласт',
    'Пузырчатая пленка',
    'Деревянная обвязка',
    'Паллет',
    'Запросить помощь менеджера',
  ];

  static const List<String> _cargoCategories = [
    'Сборный груз',
    'Хоз.товары/текстиль',
    'Одежда',
    'Обувь',
    'Продукты питания',
    'Спец.тариф',
    'Крупный опт',
  ];

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
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFfe3301), Color(0xFFff5f02)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.all(Radius.circular(14)),
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
      setState(() {
        _requestedPhotoReports.add(track.code);
        _photoRequestNotes[track.code] = controller.text.trim();
        _photoRequestCreatedAt[track.code] = now;
        _photoRequestUpdatedAt[track.code] = now;
      });
      _showStyledSnackBar(context, 'Запрос фотоотчёта отправлен');
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
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFfe3301), Color(0xFFff5f02)],
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
      final now = DateTime.now();
      setState(() {
        final wasEmpty = (_askedQuestions[track.code] ?? '').trim().isEmpty;
        _askedQuestions[track.code] = controller.text.trim();
        if (wasEmpty) {
          _questionCreatedAt[track.code] = now;
        }
        _questionUpdatedAt[track.code] = now;
      });
      _showStyledSnackBar(context, 'Вопрос отправлен');
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
                      gradient: const LinearGradient(
                        colors: [Color(0xFFfe3301), Color(0xFFff5f02)],
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
      setState(() => _overrideComments[track.code] = controller.text.trim());
      _showStyledSnackBar(context, 'Заметка сохранена');
    }
  }

  Future<void> _showGroupCommentSheet(
    BuildContext context,
    TrackGroup group,
  ) async {
    final existing = _groupComments[group.id] ?? '';
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
                'Заметка по сборке',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFfe3301), Color(0xFFff5f02)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.all(Radius.circular(14)),
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
                child: const Text('Сохранить заметку'),
              ),
            ],
          ),
        );
      },
    );
    if (result == true) {
      setState(() => _groupComments[group.id] = controller.text.trim());
      _showStyledSnackBar(context, 'Заметка по сборке сохранена');
    }
  }

  Future<void> _showGroupQuestionSheet(
    BuildContext context,
    TrackGroup group,
  ) async {
    final controller = TextEditingController(
      text: _groupQuestions[group.id] ?? '',
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
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFfe3301), Color(0xFFff5f02)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.all(Radius.circular(14)),
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
      final now = DateTime.now();
      setState(() {
        final wasEmpty = (_groupQuestions[group.id] ?? '').trim().isEmpty;
        _groupQuestions[group.id] = controller.text.trim();
        if (wasEmpty) {
          _groupQuestionCreatedAt[group.id] = now;
        }
        _groupQuestionUpdatedAt[group.id] = now;
      });
      _showStyledSnackBar(context, 'Вопрос по сборке отправлен');
    }
  }

  Future<void> _showCreateGroupSheet(BuildContext context) async {
    final selectedPacking = <String>{};
    String? selectedInsurance;
    String? insuranceAmount;
    String? selectedCategory;

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
                            'Категория груза',
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Theme(
                            data: Theme.of(context).copyWith(
                              dropdownMenuTheme: DropdownMenuThemeData(
                                menuStyle: MenuStyle(
                                  backgroundColor: MaterialStateProperty.all(
                                    Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            child: _CustomDropdown<String>(
                              value: selectedCategory ?? 'Выберите категорию',
                              label: 'Категория груза',
                              items: _cargoCategories
                                  .map(
                                    (cat) =>
                                        _DropdownItem(value: cat, label: cat),
                                  )
                                  .toList(),
                              onChanged: (value) =>
                                  setSheetState(() => selectedCategory = value),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Тип упаковки',
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          GridView.count(
                            crossAxisCount: 2,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            childAspectRatio: 4.5,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            children: _packagingOptions
                                .where(
                                  (opt) => opt != 'Запросить помощь менеджера',
                                )
                                .map((option) {
                                  final isSelected = selectedPacking.contains(
                                    option,
                                  );

                                  return GestureDetector(
                                    onTap: () {
                                      setSheetState(() {
                                        if (isSelected) {
                                          selectedPacking.remove(option);
                                        } else {
                                          selectedPacking.add(option);
                                          // Сбрасываем помощь менеджера если выбран обычный тип
                                          selectedPacking.remove(
                                            'Запросить помощь менеджера',
                                          );
                                        }
                                      });
                                    },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: isSelected
                                            ? const LinearGradient(
                                                colors: [
                                                  Color(0xFFfe3301),
                                                  Color(0xFFff5f02),
                                                ],
                                                begin: Alignment.centerLeft,
                                                end: Alignment.centerRight,
                                              )
                                            : null,
                                        color: isSelected ? null : Colors.white,
                                        border: Border.all(
                                          color: isSelected
                                              ? Colors.transparent
                                              : Colors.grey.shade300,
                                          width: 1,
                                        ),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 10,
                                      ),
                                      child: Center(
                                        child: Text(
                                          option,
                                          style: TextStyle(
                                            color: isSelected
                                                ? Colors.white
                                                : Colors.black87,
                                            fontWeight: isSelected
                                                ? FontWeight.w600
                                                : FontWeight.w500,
                                            fontSize: 13,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                  );
                                })
                                .toList(),
                          ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () {
                              setSheetState(() {
                                final isSelected = selectedPacking.contains(
                                  'Запросить помощь менеджера',
                                );
                                if (isSelected) {
                                  selectedPacking.remove(
                                    'Запросить помощь менеджера',
                                  );
                                } else {
                                  selectedPacking.clear();
                                  selectedPacking.add(
                                    'Запросить помощь менеджера',
                                  );
                                }
                              });
                            },
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                gradient:
                                    selectedPacking.contains(
                                      'Запросить помощь менеджера',
                                    )
                                    ? const LinearGradient(
                                        colors: [
                                          Color(0xFFfe3301),
                                          Color(0xFFff5f02),
                                        ],
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                      )
                                    : null,
                                color:
                                    selectedPacking.contains(
                                      'Запросить помощь менеджера',
                                    )
                                    ? null
                                    : Colors.white,
                                border: Border.all(
                                  color:
                                      selectedPacking.contains(
                                        'Запросить помощь менеджера',
                                      )
                                      ? Colors.transparent
                                      : Colors.grey.shade300,
                                  width: 1,
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              child: Center(
                                child: Text(
                                  'Запросить помощь менеджера',
                                  style: TextStyle(
                                    color:
                                        selectedPacking.contains(
                                          'Запросить помощь менеджера',
                                        )
                                        ? Colors.white
                                        : Colors.black87,
                                    fontWeight:
                                        selectedPacking.contains(
                                          'Запросить помощь менеджера',
                                        )
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                    fontSize: 13,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Страховка',
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setSheetState(
                                    () => selectedInsurance = 'yes',
                                  ),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: selectedInsurance == 'yes'
                                          ? const LinearGradient(
                                              colors: [
                                                Color(0xFFfe3301),
                                                Color(0xFFff5f02),
                                              ],
                                              begin: Alignment.centerLeft,
                                              end: Alignment.centerRight,
                                            )
                                          : null,
                                      color: selectedInsurance == 'yes'
                                          ? null
                                          : Colors.white,
                                      border: Border.all(
                                        color: selectedInsurance == 'yes'
                                            ? Colors.transparent
                                            : Colors.grey.shade300,
                                        width: 1,
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Да',
                                        style: TextStyle(
                                          color: selectedInsurance == 'yes'
                                              ? Colors.white
                                              : Colors.black87,
                                          fontWeight: selectedInsurance == 'yes'
                                              ? FontWeight.w600
                                              : FontWeight.w500,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setSheetState(
                                    () => selectedInsurance = 'no',
                                  ),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: selectedInsurance == 'no'
                                          ? const LinearGradient(
                                              colors: [
                                                Color(0xFFfe3301),
                                                Color(0xFFff5f02),
                                              ],
                                              begin: Alignment.centerLeft,
                                              end: Alignment.centerRight,
                                            )
                                          : null,
                                      color: selectedInsurance == 'no'
                                          ? null
                                          : Colors.white,
                                      border: Border.all(
                                        color: selectedInsurance == 'no'
                                            ? Colors.transparent
                                            : Colors.grey.shade300,
                                        width: 1,
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Нет',
                                        style: TextStyle(
                                          color: selectedInsurance == 'no'
                                              ? Colors.white
                                              : Colors.black87,
                                          fontWeight: selectedInsurance == 'no'
                                              ? FontWeight.w600
                                              : FontWeight.w500,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (selectedInsurance == 'yes') ...[
                            const SizedBox(height: 8),
                            const Text(
                              'Сумма стоимости товаров в юанях',
                              style: TextStyle(
                                color: Colors.black54,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            _outlinedInput(
                              TextEditingController(
                                text: insuranceAmount ?? '',
                              ),
                              hint: 'Например: 5000',
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              onChanged: (value) {
                                setSheetState(() {
                                  insuranceAmount = value;
                                });
                              },
                            ),
                          ],
                          const SizedBox(height: 20),
                          FilledButton(
                            onPressed:
                                selectedPacking.isNotEmpty &&
                                    selectedInsurance != null &&
                                    selectedCategory != null &&
                                    (selectedInsurance == 'no' ||
                                        (selectedInsurance == 'yes' &&
                                            insuranceAmount?.isNotEmpty ==
                                                true))
                                ? () => Navigator.of(sheetContext).pop(true)
                                : null,
                            child: const Text('Отправить на сборку'),
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
      _showStyledSnackBar(
        context,
        'Сборка создана с ${_selectedTracks.length} треками',
      );
      setState(() {
        _selectedTracks.clear();
        _selectedStatus = null;
      });
    }
  }

  Future<void> _cancelPhotoRequest(TrackItem track) async {
    final ok = await _confirmAction(
      context,
      title: 'Отменить фотоотчёт',
      message: 'Вы уверены, что хотите отменить запрос фотоотчёта?',
    );
    if (!ok) return;
    setState(() {
      _requestedPhotoReports.remove(track.code);
      _photoRequestNotes.remove(track.code);
      _photoRequestCreatedAt.remove(track.code);
      _photoRequestUpdatedAt.remove(track.code);
    });
    if (mounted) {
      _showStyledSnackBar(context, 'Запрос фотоотчёта отменён');
    }
  }

  Future<void> _cancelQuestion(TrackItem track) async {
    final ok = await _confirmAction(
      context,
      title: 'Отменить вопрос',
      message: 'Вы уверены, что хотите отменить вопрос?',
    );
    if (!ok) return;
    setState(() {
      _askedQuestions.remove(track.code);
      _questionCreatedAt.remove(track.code);
      _questionUpdatedAt.remove(track.code);
    });
    if (mounted) {
      _showStyledSnackBar(context, 'Вопрос отменён');
    }
  }

  Future<void> _showAboutProductSheet(
    BuildContext context,
    TrackItem track,
  ) async {
    final existing = _productInfos[track.code];
    final nameController = TextEditingController(text: existing?.name ?? '');
    final qtyController = TextEditingController(
      text: existing?.quantity?.toString() ?? '',
    );
    final images = List<String>.from(existing?.images ?? const []);
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
                        qtyController,
                        hint: 'например: 2',
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: _ActionChipButton(
                          icon: Icons.add_photo_alternate_rounded,
                          label: 'Выбрать изображения',
                          onPressed: () async {
                            try {
                              final picker = ImagePicker();
                              final pickedFiles = await picker.pickMultiImage(
                                imageQuality: 85,
                              );
                              final paths = pickedFiles
                                  .map((file) => file.path)
                                  .toList();
                              if (paths.isNotEmpty) {
                                setSheetState(() => images.addAll(paths));
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
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (images.isNotEmpty)
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: images.map((path) {
                            return Stack(
                              children: [
                                Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x14000000),
                                        blurRadius: 10,
                                        offset: Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: Image.file(
                                    File(path),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        const ColoredBox(color: Colors.black12),
                                  ),
                                ),
                                Positioned(
                                  right: 2,
                                  top: 2,
                                  child: InkWell(
                                    onTap: () => setSheetState(
                                      () => images.remove(path),
                                    ),
                                    child: const CircleAvatar(
                                      radius: 12,
                                      backgroundColor: Colors.white,
                                      child: Icon(
                                        Icons.close_rounded,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
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
      setState(() {
        _productInfos[track.code] = _ProductInfo(
          name: nameController.text.trim(),
          quantity: int.tryParse(qtyController.text.trim()),
          images: images,
        );
      });
      _showStyledSnackBar(context, 'Информация о товаре сохранена');
    }
  }

  Future<void> _exportXlsx() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    try {
      final excel = xls.Excel.createExcel();
      final sheet = excel['Tracks'];
      sheet.appendRow([
        xls.TextCellValue('Код'),
        xls.TextCellValue('Статус'),
        xls.TextCellValue('Дата'),
        xls.TextCellValue('Заметка'),
      ]);

      final clientCode = ref.read(activeClientCodeProvider);
      if (clientCode != null) {
        final tracks = ref
            .read(tracksListProvider(clientCode))
            .maybeWhen(data: (t) => t, orElse: () => const <TrackItem>[]);
        final filtered = _applyFilters(tracks);
        for (final t in filtered) {
          sheet.appendRow([
            xls.TextCellValue(t.code),
            xls.TextCellValue(t.status),
            xls.TextCellValue(DateFormat('yyyy-MM-dd').format(t.date)),
            xls.TextCellValue(t.comment ?? ''),
          ]);
        }
      }

      final bytes = excel.encode();
      if (bytes == null) {
        _showStyledSnackBar(context, 'Ошибка генерации файла', isError: true);
        return;
      }

      final dir = await getApplicationDocumentsDirectory();
      final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filePath = '${dir.path}/tracks_$ts.xlsx';
      final file = File(filePath);
      await file.writeAsBytes(bytes, flush: true);

      _showStyledSnackBar(context, 'Файл сохранён');

      await Share.shareXFiles([XFile(filePath)], text: 'Экспорт треков');
    } catch (e) {
      _showStyledSnackBar(context, 'Ошибка экспорта: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
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

    final tracksAsync = ref.watch(tracksListProvider(clientCode));
    final bottomPad = AppLayout.bottomScrollPadding(context);
    final topPad = AppLayout.topBarTotalHeight(context);
    const bulkButtonExtraPad = 72.0;

    return Stack(
      children: [
        ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            topPad * 0.7 + 6,
            16,
            bottomPad +
                16 +
                (_selectedTracks.isEmpty ? 0 : bulkButtonExtraPad + 8),
          ),
          children: [
            Text(
              'Треки',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 18),
            Container(
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
              child: _Filters(
                status: _status,
                statuses: _allStatuses,
                viewMode: _viewMode,
                query: _query,
                onStatusChanged: (v) => setState(() => _status = v),
                onViewModeChanged: (v) => setState(() => _viewMode = v),
                onQueryChanged: (v) => setState(() => _query = v),
              ),
            ),
            const SizedBox(height: 18),
            tracksAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => EmptyState(
                icon: Icons.error_outline_rounded,
                title: 'Не удалось загрузить треки',
                message: e.toString(),
              ),
              data: (tracks) {
                final filtered = _applyFilters(tracks);
                if (filtered.isEmpty) {
                  return const EmptyState(
                    icon: Icons.local_shipping_outlined,
                    title: 'Ничего не найдено',
                    message: 'Попробуйте изменить фильтры или строку поиска.',
                  );
                }

                final groups = _groupTracks(filtered);
                return Column(
                  children: groups
                      .map(
                        (g) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _TrackGroupCard(
                            group: g.group,
                            tracks: g.tracks,
                            selectedTrackCodes: _selectedTracks,
                            selectedStatus: _selectedStatus,
                            onToggle: _toggleTrack,
                            requestedPhotoReports: _requestedPhotoReports,
                            onPhotoRequest: (track) =>
                                _showPhotoRequestSheet(context, track),
                            onCancelPhotoRequest: (track) =>
                                _cancelPhotoRequest(track),
                            photoRequestCreatedAt: _photoRequestCreatedAt,
                            photoRequestUpdatedAt: _photoRequestUpdatedAt,
                            photoRequestNotes: _photoRequestNotes,
                            overrideComments: _overrideComments,
                            onAskQuestion: (track) =>
                                _showAskQuestionSheet(context, track),
                            onCancelQuestion: (track) => _cancelQuestion(track),
                            onEditComment: (track) =>
                                _showCommentSheet(context, track),
                            onEditProduct: (track) =>
                                _showAboutProductSheet(context, track),
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
                            onEditGroupComment: (group) =>
                                _showGroupCommentSheet(context, group),
                            onAskGroupQuestion: (group) =>
                                _showGroupQuestionSheet(context, group),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
        if (_selectedTracks.isNotEmpty)
          Positioned(
            left: 16,
            right: 16,
            bottom:
                AppLayout.bottomBarHeight +
                AppLayout.bottomBarBottomMargin -
                75,
            child: SafeArea(
              top: false,
              child: FilledButton(
                onPressed: _selectedStatus == null
                    ? null
                    : () => _bulkAction(context),
                child: Text(_actionLabel()),
              ),
            ),
          ),
      ],
    );
  }

  List<TrackItem> _applyFilters(List<TrackItem> tracks) {
    final q = _query.trim().toLowerCase();
    return tracks.where((t) {
      final statusOk = _status == 'Все' ? true : t.status == _status;
      final queryOk = q.isEmpty ? true : t.code.toLowerCase().contains(q);
      final viewOk = switch (_viewMode) {
        ViewMode.all => true,
        ViewMode.groups => t.groupId != null,
        ViewMode.singles => t.groupId == null,
      };
      return statusOk && queryOk && viewOk;
    }).toList();
  }

  List<_GroupBucket> _groupTracks(List<TrackItem> tracks) {
    final byKey = <String, _GroupBucket>{};
    for (final t in tracks) {
      final key = t.groupId ?? '__${t.code}';
      byKey[key] = (byKey[key] ?? _GroupBucket(group: t.group, tracks: []))
        ..tracks.add(t);
    }
    final list = byKey.values.toList(growable: false);
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

const Set<String> _selectableStatuses = {
  'На складе',
  'Отправлен',
  'Прибыл на терминал',
  'Сформирован к выдаче',
};

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
            gradient: const LinearGradient(
              colors: [Color(0xFFfe3301), Color(0xFFff5f02)],
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
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: Color(0xFFfe3301),
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

class _TrackGroupCard extends StatelessWidget {
  final TrackGroup? group;
  final List<TrackItem> tracks;
  final Set<String> selectedTrackCodes;
  final String? selectedStatus;
  final ValueChanged<TrackItem> onToggle;
  final Set<String> requestedPhotoReports;
  final ValueChanged<TrackItem> onPhotoRequest;
  final ValueChanged<TrackItem> onCancelPhotoRequest;
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
  final ValueChanged<TrackGroup> onEditGroupComment;
  final ValueChanged<TrackGroup> onAskGroupQuestion;

  const _TrackGroupCard({
    required this.group,
    required this.tracks,
    required this.selectedTrackCodes,
    required this.selectedStatus,
    required this.onToggle,
    required this.requestedPhotoReports,
    required this.onPhotoRequest,
    required this.onCancelPhotoRequest,
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
  });

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd MMM yyyy', 'ru');
    final groupComment = group != null ? (groupComments[group!.id] ?? '') : '';
    final groupQuestion = group != null
        ? (groupQuestions[group!.id] ?? '')
        : '';
    final groupQuestionCreated = group != null
        ? groupQuestionCreatedAt[group!.id]
        : null;
    final groupQuestionUpdated = group != null
        ? groupQuestionUpdatedAt[group!.id]
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
          if (group != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Группа сборки',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                      if (group!.status != null)
                        StatusPill(text: group!.status!),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Категория: ${group!.category}',
                    style: const TextStyle(color: Colors.black54),
                  ),
                  Text(
                    'Упаковка: ${group!.packing.join(', ')}',
                    style: const TextStyle(color: Colors.black54),
                  ),
                  if (group!.insurance)
                    Text(
                      'Страховка: ${group!.insuranceAmount?.toStringAsFixed(0) ?? '—'} ¥',
                      style: const TextStyle(color: Colors.black54),
                    ),
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
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _ActionChipButton(
                        label: 'Добавить заметку',
                        onPressed: () => onEditGroupComment(group!),
                      ),
                      _ActionChipButton(
                        icon: Icons.help_outline_rounded,
                        iconOnly: true,
                        onPressed: () => onAskGroupQuestion(group!),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
          ],
          ...tracks.asMap().entries.map((entry) {
            final index = entry.key;
            final track = entry.value;
            final canSelect = track.status == 'На складе';
            final allowedByStatus =
                selectedStatus == null || selectedStatus == track.status;
            final isSelected = selectedTrackCodes.contains(track.code);

            final availablePhotoReport = track.status == 'На складе';
            final canAskQuestion = track.status == 'На складе';
            final availableFillInfo =
                track.status == 'На складе' ||
                track.status == 'На сборке' ||
                track.status == 'Отправлен';
            final isPhotoRequested =
                track.photoRequestAt != null ||
                requestedPhotoReports.contains(track.code);
            final commentText = overrideComments[track.code] ?? track.comment;
            final hasQuestion = (askedQuestions[track.code] ?? '')
                .trim()
                .isNotEmpty;
            final photoCreated =
                track.photoRequestAt ?? photoRequestCreatedAt[track.code];
            final photoUpdated =
                track.photoTaskUpdatedAt ?? photoRequestUpdatedAt[track.code];
            final productInfo = productInfos[track.code];
            final photoStatusLabel = track.photoTaskStatus?.label ?? 'NEW';
            final questionCreated = questionCreatedAt[track.code];
            final questionUpdated = questionUpdatedAt[track.code];

            final List<Widget> infoSections = [];
            final commentValue = (commentText ?? '').trim();
            if (commentValue.isNotEmpty) {
              infoSections.add(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Заметка',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      commentValue,
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              );
            }

            if (track.photoTaskStatus != null || isPhotoRequested) {
              final photoNote = photoRequestNotes[track.code] ?? '';
              infoSections.add(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Фотоотчёт',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Статус: $photoStatusLabel',
                      style: const TextStyle(color: Colors.black54),
                    ),
                    if (photoNote.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Пожелание: $photoNote',
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ],
                    if (photoCreated != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Создан: ${df.format(photoCreated)}',
                        style: const TextStyle(color: Colors.black45),
                      ),
                    ],
                    if (photoUpdated != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Обновлён: ${df.format(photoUpdated)}',
                        style: const TextStyle(color: Colors.black45),
                      ),
                    ],
                  ],
                ),
              );
            }

            if (hasQuestion) {
              final questionText = askedQuestions[track.code] ?? '';
              final qStatus = questionStatus[track.code] ?? 'Новый';
              final qAnswer = questionAnswers[track.code] ?? '';
              infoSections.add(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Вопрос',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Статус: $qStatus',
                      style: const TextStyle(color: Colors.black54),
                    ),
                    if (questionText.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Вопрос: $questionText',
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ],
                    if (qAnswer.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Ответ: $qAnswer',
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ],
                    if (questionCreated != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Создан: ${df.format(questionCreated)}',
                        style: const TextStyle(color: Colors.black45),
                      ),
                    ],
                    if (questionUpdated != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Обновлён: ${df.format(questionUpdated)}',
                        style: const TextStyle(color: Colors.black45),
                      ),
                    ],
                  ],
                ),
              );
            }

            if (productInfo != null &&
                (productInfo.name.isNotEmpty ||
                    productInfo.quantity != null ||
                    productInfo.images.isNotEmpty)) {
              infoSections.add(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'О товаре',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (productInfo.name.isNotEmpty)
                      Text(
                        'Название: ${productInfo.name}',
                        style: const TextStyle(color: Colors.black54),
                      ),
                    if (productInfo.quantity != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Количество: ${productInfo.quantity}',
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ],
                    if (productInfo.images.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Изображений: ${productInfo.images.length}',
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ],
                  ],
                ),
              );
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
                                onChanged: (_) => onToggle(track),
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                            const SizedBox(width: 2),
                          ],
                          Expanded(
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
                          if (track.status != 'На сборке')
                            StatusPill(text: track.status),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        df.format(track.date),
                        style: const TextStyle(color: Colors.black54),
                      ),
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
                      Row(
                        children: [
                          // Icon buttons on the left
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (availablePhotoReport) ...[
                                _ActionChipButton(
                                  icon: Icons.photo_camera_rounded,
                                  iconOnly: true,
                                  onPressed: () => isPhotoRequested
                                      ? onCancelPhotoRequest(track)
                                      : onPhotoRequest(track),
                                ),
                                const SizedBox(width: 6),
                              ],
                              if (canAskQuestion) ...[
                                _ActionChipButton(
                                  icon: Icons.help_outline_rounded,
                                  iconOnly: true,
                                  onPressed: () => hasQuestion
                                      ? onCancelQuestion(track)
                                      : onAskQuestion(track),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(width: 8),
                          // Text buttons on the right, wrapped to avoid overflow
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                alignment: WrapAlignment.end,
                                children: [
                                  _ActionChipButton(
                                    label: 'Заметка',
                                    onPressed: () => onEditComment(track),
                                  ),
                                  if (availableFillInfo)
                                    _ActionChipButton(
                                      label: 'О товаре',
                                      onPressed: () => onEditProduct(track),
                                    ),
                                ],
                              ),
                            ),
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
}

class _DropdownItem<T> {
  final T value;
  final String label;

  const _DropdownItem({required this.value, required this.label});
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
                    child: Container(
                      width: menuWidth,
                      constraints: const BoxConstraints(maxHeight: 280),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ListView(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        children: widget.items.map((item) {
                          return InkWell(
                            onTap: () {
                              setState(() {
                                _selectedValue = item.value;
                              });
                              widget.onChanged(item.value);
                              _overlayEntry?.remove();
                              _overlayEntry = null;
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: _selectedValue == item.value
                                    ? const Color(
                                        0xFFfe3301,
                                      ).withValues(alpha: 0.1)
                                    : Colors.transparent,
                              ),
                              child: Text(
                                item.label,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: _selectedValue == item.value
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  color: _selectedValue == item.value
                                      ? const Color(0xFFfe3301)
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
              Column(
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
                  ),
                  const SizedBox(height: 2),
                  Text(
                    selectedLabel,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Icon(
                _overlayEntry != null
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                color: const Color(0xFFfe3301),
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
  final bool iconOnly;

  const _ActionChipButton({
    this.icon,
    this.label,
    required this.onPressed,
    this.iconOnly = false,
  });

  static const _grad = LinearGradient(
    colors: [Color(0xFFfe3301), Color(0xFFff5f02)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  @override
  Widget build(BuildContext context) {
    final isDisabled = onPressed == null;

    // Icon-only button (circular)
    if (iconOnly && icon != null) {
      return Opacity(
        opacity: isDisabled ? 0.45 : 1,
        child: Container(
          decoration: BoxDecoration(gradient: _grad, shape: BoxShape.circle),
          padding: const EdgeInsets.all(1.5),
          child: Material(
            color: Colors.white,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onPressed,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(icon, size: 18, color: const Color(0xFFfe3301)),
              ),
            ),
          ),
        ),
      );
    }

    // Text-only or text+icon button
    return Opacity(
      opacity: isDisabled ? 0.45 : 1,
      child: Container(
        decoration: BoxDecoration(
          gradient: _grad,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(1),
        child: Material(
          color: Colors.white,
          borderRadius: const BorderRadius.all(Radius.circular(11)),
          child: InkWell(
            borderRadius: BorderRadius.circular(11),
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 16, color: const Color(0xFFfe3301)),
                    const SizedBox(width: 6),
                  ],
                  if (label != null)
                    Text(
                      label!,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
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

class _GroupBucket {
  final TrackGroup? group;
  final List<TrackItem> tracks;

  _GroupBucket({required this.group, required this.tracks});

  DateTime get latestDate {
    var latest = DateTime.fromMillisecondsSinceEpoch(0);
    for (final t in tracks) {
      if (t.date.isAfter(latest)) latest = t.date;
    }
    return latest;
  }
}

Widget _outlinedInput(
  TextEditingController controller, {
  String? hint,
  TextInputType? keyboardType,
  List<TextInputFormatter>? inputFormatters,
  ValueChanged<String>? onChanged,
}) {
  return Container(
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFFfe3301), Color(0xFFff5f02)],
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
