// TODO: Update to ShowcaseView.get() API when showcaseview 6.0.0 is released
// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';

import '../persistence/shared_preferences_provider.dart';

// ─── Enum ─────────────────────────────────────────────────────────────────────

/// Гранулярные блоки для отслеживания showcase — один флаг на каждый блок.
/// Блок показывается ТОЛЬКО когда:
///   1. shouldShow == true (ещё не показывался в этой сессии)
///   2. Данные для блока загружены (data condition — проверяется в каждом экране)
enum ShowcaseBlock {
  // ── Главная ──────────────────────────────────────
  homeQuickCards,   // Всегда видим
  homeDigest,       // Только когда есть треки/счета
  homePhotos,       // Только когда есть фотоотчёты

  // ── Треки ────────────────────────────────────────
  tracksFilters,    // Всегда видим
  tracksItem,       // Только когда есть треки
  tracksAddButton,  // Всегда видим

  // ── Фотоотчёты ───────────────────────────────────
  photosStats,      // Всегда видим
  photosDateFilter, // Всегда видим
  photosGrid,       // Только когда есть фото

  // ── Счета ────────────────────────────────────────
  invoicesFilters,  // Всегда видим
  invoicesItem,     // Только когда есть счета

  // ── Профиль ──────────────────────────────────────
  profilePersonalData,
  profileStats,
  profileExport,
  profileLogout,

  // ── Новости ──────────────────────────────────────
  newsHeader,
  newsCard,         // Только когда есть новости

  // ── Правила ──────────────────────────────────────
  rulesHeader,
  rulesCard,        // Только когда есть правила

  // ── Чат с поддержкой ─────────────────────────────
  supportMessages,
  supportInput,

  // ── Чат по оплате ────────────────────────────────
  paymentChatInfoBanner,
  paymentChatInput,

  // ── Добавить треки ───────────────────────────────
  addTracksInput,
  addTracksSubmit,

  // ── Поиск ────────────────────────────────────────
  searchInput,

  // ── СП Сборки ────────────────────────────────────
  spAssemblyCard,         // Только когда есть сборки
  spAssemblyStats,        // На странице детали
  spAssemblyParticipants, // На странице детали
  spAssemblyTracks,       // На странице детали

  // ── СП Редактирование трека ───────────────────────
  spTrackEditParticipant,
  spTrackEditPrices,
  spTrackEditSave,

  // ── Реферальная программа ────────────────────────
  referralInfo,

  // ── Калькулятор ──────────────────────────────────
  calculatorForm,

  // ── Тарифы ───────────────────────────────────────
  tariffsList,
}

// ─── Backward-compat alias (used only in auth_provider reset loop) ─────────────
/// @deprecated Use ShowcaseBlock instead
enum ShowcasePage {
  home,
  tracks,
  invoices,
  profile,
  photos,
  addTracks,
  support,
  paymentChat,
  search,
  news,
  rules,
  notifications,
  spAssemblies,
  spAssemblyDetail,
  spTrackEdit,
}

// ─── Helper ───────────────────────────────────────────────────────────────────

/// Запускает showcase только для ключей, чьи виджеты примонтированы (currentContext != null).
void startShowCaseSafe(BuildContext context, List<GlobalKey> keys) {
  final visible = keys.where((k) => k.currentContext != null).toList();
  if (visible.isNotEmpty) {
    ShowCaseWidget.of(context).startShowCase(visible);
  }
}

EdgeInsets getShowcaseTargetPadding({EdgeInsets base = const EdgeInsets.all(8)}) {
  return base;
}

// ─── Service ──────────────────────────────────────────────────────────────────

class ShowcaseService {
  static const String _prefix = 'showcase_seen_';
  static const String _blockPrefix = 'sc_block_';
  static const String _firstLoginKey = 'showcase_first_login_done';
  static const String _termsAcceptedKey = 'terms_accepted';

  final SharedPreferences _prefs;

  ShowcaseService(this._prefs);

  // ── Per-block API (new) ──────────────────────────────────────────────────

  bool shouldShowBlock(ShowcaseBlock block) {
    return !(_prefs.getBool('$_blockPrefix${block.name}') ?? false);
  }

  Future<void> markBlockAsSeen(ShowcaseBlock block) async {
    await _prefs.setBool('$_blockPrefix${block.name}', true);
  }

  /// Помечает ВСЕ блоки как просмотренные — вызывается при "Пропустить обучение".
  Future<void> markAllBlocksSeen() async {
    for (final block in ShowcaseBlock.values) {
      await _prefs.setBool('$_blockPrefix${block.name}', true);
    }
  }

  Future<void> resetAllBlocks() async {
    for (final block in ShowcaseBlock.values) {
      await _prefs.remove('$_blockPrefix${block.name}');
    }
  }

  // ── Legacy page API (kept for backward compat) ───────────────────────────

  bool shouldShowShowcase(ShowcasePage page) {
    return !(_prefs.getBool('$_prefix${page.name}') ?? false);
  }

  Future<void> markPageAsSeen(ShowcasePage page) async {
    await _prefs.setBool('$_prefix${page.name}', true);
  }

  Future<void> resetAllShowcases() async {
    // Reset new block-level keys
    for (final block in ShowcaseBlock.values) {
      await _prefs.remove('$_blockPrefix${block.name}');
    }
    // Reset legacy page-level keys
    for (final page in ShowcasePage.values) {
      await _prefs.remove('$_prefix${page.name}');
    }
    await _prefs.remove(_firstLoginKey);
    await _prefs.remove(_termsAcceptedKey);
  }

  Future<void> resetShowcase(ShowcasePage page) async {
    await _prefs.remove('$_prefix${page.name}');
  }

  // ── Terms & first login ──────────────────────────────────────────────────

  bool get isFirstLogin => !(_prefs.getBool(_firstLoginKey) ?? false);

  Future<void> markFirstLoginDone() async {
    await _prefs.setBool(_firstLoginKey, true);
  }

  bool get hasAcceptedTerms => _prefs.getBool(_termsAcceptedKey) ?? false;

  Future<void> acceptTerms() async {
    await _prefs.setBool(_termsAcceptedKey, true);
  }
}

// ─── Providers ────────────────────────────────────────────────────────────────

final showcaseServiceProvider = Provider<ShowcaseService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ShowcaseService(prefs);
});

/// Сигнал для сброса обучения — инкрементируется при сбросе.
/// Экраны слушают этот провайдер и сбрасывают флаг _showcaseStarted.
class ShowcaseTutorialResetNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void trigger() => state++;
}

final showcaseTutorialResetProvider =
    NotifierProvider<ShowcaseTutorialResetNotifier, int>(
  ShowcaseTutorialResetNotifier.new,
);

/// Блоки, которые нужно пометить как просмотренные после завершения тура.
/// Устанавливается в _startShowcaseIfNeeded каждого экрана перед startShowCase.
/// Читается и сбрасывается в app-level ShowCaseWidget.onFinish.
class ShowcasePendingBlocksNotifier extends Notifier<List<ShowcaseBlock>> {
  @override
  List<ShowcaseBlock> build() => [];

  void setBlocks(List<ShowcaseBlock> blocks) => state = blocks;
  void clear() => state = [];
}

final showcasePendingBlocksProvider =
    NotifierProvider<ShowcasePendingBlocksNotifier, List<ShowcaseBlock>>(
  ShowcasePendingBlocksNotifier.new,
);

/// Читает shouldShow для конкретного блока — реактивный.
/// Инвалидируй через `ref.invalidate(showcaseBlockProvider(block))` после markBlockAsSeen.
final showcaseBlockProvider = Provider.family<bool, ShowcaseBlock>((ref, block) {
  final service = ref.watch(showcaseServiceProvider);
  return service.shouldShowBlock(block);
});

/// Контроллер блока — удобная обёртка для markAsSeen + invalidate.
final showcaseBlockNotifierProvider =
    Provider.family<_ShowcaseBlockController, ShowcaseBlock>((ref, block) {
  return _ShowcaseBlockController(ref, block);
});

class _ShowcaseBlockController {
  final Ref _ref;
  final ShowcaseBlock _block;
  _ShowcaseBlockController(this._ref, this._block);

  bool get shouldShow => _ref.read(showcaseServiceProvider).shouldShowBlock(_block);

  Future<void> markAsSeen() async {
    await _ref.read(showcaseServiceProvider).markBlockAsSeen(_block);
    _ref.invalidate(showcaseBlockProvider(_block));
  }
}

// ─── Legacy providers (kept for screens not yet migrated) ────────────────────

class ShowcaseState {
  final bool shouldShow;
  final List<GlobalKey> keys;

  const ShowcaseState({required this.shouldShow, this.keys = const []});

  ShowcaseState copyWith({bool? shouldShow, List<GlobalKey>? keys}) {
    return ShowcaseState(
      shouldShow: shouldShow ?? this.shouldShow,
      keys: keys ?? this.keys,
    );
  }
}

final showcaseProvider = Provider.family<ShowcaseState, ShowcasePage>((ref, page) {
  final service = ref.watch(showcaseServiceProvider);
  return ShowcaseState(shouldShow: service.shouldShowShowcase(page));
});

final showcaseNotifierProvider =
    Provider.family<_ShowcaseController, ShowcasePage>((ref, page) {
  return _ShowcaseController(ref, page);
});

class _ShowcaseController {
  final Ref _ref;
  final ShowcasePage _page;

  _ShowcaseController(this._ref, this._page);

  bool get shouldShow {
    final service = _ref.read(showcaseServiceProvider);
    return service.shouldShowShowcase(_page);
  }

  Future<void> markAsSeen() async {
    final service = _ref.read(showcaseServiceProvider);
    await service.markPageAsSeen(_page);
    _ref.invalidate(showcaseProvider(_page));
  }

  Future<void> reset() async {
    final service = _ref.read(showcaseServiceProvider);
    await service.resetShowcase(_page);
    _ref.invalidate(showcaseProvider(_page));
  }
}

// ─── ShowcaseWrapper ──────────────────────────────────────────────────────────

/// Обёртка для экранов с showcase.
///
/// Ранее создавала ShowCaseWidget на каждый экран, что приводило к конфликту
/// глобального currentScope из синглтона ShowcaseService (пакета).
/// Теперь является no-op: единственный ShowCaseWidget создаётся на уровне
/// MaterialApp.builder в app.dart. Параметры onComplete / onSkipAll сохранены
/// для обратной совместимости, но игнорируются — их роль берут на себя
/// showcasePendingBlocksProvider и глобальная кнопка пропуска.
class ShowcaseWrapper extends StatelessWidget {
  final Widget child;
  final VoidCallback? onComplete;
  final VoidCallback? onStart;
  final VoidCallback? onSkipAll;

  const ShowcaseWrapper({
    super.key,
    required this.child,
    this.onComplete,
    this.onStart,
    this.onSkipAll,
  });

  @override
  Widget build(BuildContext context) => child;
}

// ─── ShowcaseKeys (static keys for SP screens) ───────────────────────────────

class ShowcaseKeys {
  // SP Assemblies
  static final spAssemblyCard = GlobalKey(debugLabel: 'sp_assembly_card');

  // SP Assembly Detail
  static final spStats = GlobalKey(debugLabel: 'sp_stats');
  static final spParticipants = GlobalKey(debugLabel: 'sp_participants');
  static final spTracks = GlobalKey(debugLabel: 'sp_tracks');

  // SP Track Edit
  static final spTrackParticipant = GlobalKey(debugLabel: 'sp_track_participant');
  static final spTrackPrices = GlobalKey(debugLabel: 'sp_track_prices');
  static final spTrackWeight = GlobalKey(debugLabel: 'sp_track_weight');
  static final spTrackCalculation = GlobalKey(debugLabel: 'sp_track_calculation');
  static final spTrackSave = GlobalKey(debugLabel: 'sp_track_save');
}

// ─── Tooltip widgets ──────────────────────────────────────────────────────────

class ScrollableShowcaseTooltip extends StatelessWidget {
  final String title;
  final String description;
  final bool isLast;
  final int currentStep;
  final int totalSteps;
  final VoidCallback? onSkip;

  const ScrollableShowcaseTooltip({
    super.key,
    required this.title,
    required this.description,
    this.isLast = false,
    this.currentStep = 1,
    this.totalSteps = 1,
    this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 300, maxHeight: 350),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (totalSteps > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: List.generate(totalSteps, (index) {
                  final isActive = index < currentStep;
                  return Expanded(
                    child: Container(
                      height: 3,
                      margin: EdgeInsets.only(
                          right: index < totalSteps - 1 ? 4 : 0),
                      decoration: BoxDecoration(
                        color: isActive
                            ? const Color(0xFFfe3301)
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: Scrollbar(
                thumbVisibility: true,
                child: SingleChildScrollView(
                  child: Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade600,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (onSkip != null && !isLast)
                TextButton(
                  onPressed: onSkip,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey.shade600,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  child: const Text('Пропустить',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              const Spacer(),
              FilledButton(
                onPressed: () => ShowCaseWidget.of(context).next(),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFfe3301),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(isLast ? 'Готово' : 'Далее',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    if (!isLast) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward_rounded, size: 16),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class SimpleShowcaseTooltip extends StatelessWidget {
  final String title;
  final String description;
  final bool isLast;

  const SimpleShowcaseTooltip({
    super.key,
    required this.title,
    required this.description,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: () => ShowCaseWidget.of(context).next(),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFfe3301),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(isLast ? 'Готово' : 'Далее',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  if (!isLast) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_rounded, size: 16),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
