import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';

/// Обёртка для экранов, использующих Showcase
/// Каждый экран с Showcase должен быть обёрнут в этот виджет
class ShowcaseWrapper extends StatelessWidget {
  final Widget child;
  final VoidCallback? onComplete;
  final VoidCallback? onStart;
  
  const ShowcaseWrapper({
    super.key,
    required this.child,
    this.onComplete,
    this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    return ShowCaseWidget(
      blurValue: 1,
      autoPlayDelay: const Duration(seconds: 3),
      onComplete: (index, key) {
        onComplete?.call();
      },
      onStart: (index, key) {
        onStart?.call();
      },
      builder: (context) => child,
    );
  }
}

/// Идентификаторы страниц для showcase
enum ShowcasePage {
  home,
  tracks,
  invoices,
  profile,
  photos,
  addTracks,
  support,
  search,
  news,
  rules,
  notifications,
}

/// Сервис для управления showcase туториалами
/// Отслеживает какие страницы пользователь уже видел
class ShowcaseService {
  static const String _prefix = 'showcase_seen_';
  static const String _firstLoginKey = 'showcase_first_login_done';
  
  final SharedPreferences _prefs;
  
  ShowcaseService(this._prefs);
  
  /// Проверить, нужно ли показывать showcase для страницы
  bool shouldShowShowcase(ShowcasePage page) {
    return !(_prefs.getBool('$_prefix${page.name}') ?? false);
  }
  
  /// Отметить страницу как просмотренную
  Future<void> markPageAsSeen(ShowcasePage page) async {
    await _prefs.setBool('$_prefix${page.name}', true);
  }
  
  /// Проверить, был ли первый вход (авторизация)
  bool get isFirstLogin => !(_prefs.getBool(_firstLoginKey) ?? false);
  
  /// Отметить что первый вход выполнен
  Future<void> markFirstLoginDone() async {
    await _prefs.setBool(_firstLoginKey, true);
  }
  
  /// Сбросить все просмотренные страницы (для тестирования)
  Future<void> resetAllShowcases() async {
    for (final page in ShowcasePage.values) {
      await _prefs.remove('$_prefix${page.name}');
    }
    await _prefs.remove(_firstLoginKey);
  }
  
  /// Сбросить showcase для конкретной страницы
  Future<void> resetShowcase(ShowcasePage page) async {
    await _prefs.remove('$_prefix${page.name}');
  }
}

/// Провайдер для SharedPreferences
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences должен быть инициализирован в main()');
});

/// Провайдер для ShowcaseService
final showcaseServiceProvider = Provider<ShowcaseService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ShowcaseService(prefs);
});

/// Состояние showcase для каждой страницы
class ShowcaseState {
  final bool shouldShow;
  final List<GlobalKey> keys;
  
  const ShowcaseState({
    required this.shouldShow,
    this.keys = const [],
  });
  
  ShowcaseState copyWith({
    bool? shouldShow,
    List<GlobalKey>? keys,
  }) {
    return ShowcaseState(
      shouldShow: shouldShow ?? this.shouldShow,
      keys: keys ?? this.keys,
    );
  }
}

/// Notifier для управления состоянием showcase на странице
/// Используем Notifier из Riverpod 3.x
class ShowcaseNotifier extends Notifier<ShowcaseState> {
  late ShowcasePage _page;
  
  @override
  ShowcaseState build() {
    // Этот метод не используется напрямую, состояние инициализируется в _buildForPage
    return const ShowcaseState(shouldShow: false);
  }
  
  /// Инициализация для конкретной страницы
  ShowcaseState _buildForPage(ShowcasePage page) {
    _page = page;
    final service = ref.read(showcaseServiceProvider);
    return ShowcaseState(shouldShow: service.shouldShowShowcase(page));
  }
  
  /// Запустить showcase
  void startShowcase(BuildContext context, List<GlobalKey> keys) {
    if (state.shouldShow && keys.isNotEmpty) {
      // Небольшая задержка чтобы виджеты успели отрисоваться
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ShowCaseWidget.of(context).startShowCase(keys);
      });
    }
  }
  
  /// Отметить как просмотренное
  Future<void> markAsSeen() async {
    final service = ref.read(showcaseServiceProvider);
    await service.markPageAsSeen(_page);
    state = state.copyWith(shouldShow: false);
  }
  
  /// Сбросить (для тестирования)
  Future<void> reset() async {
    final service = ref.read(showcaseServiceProvider);
    await service.resetShowcase(_page);
    state = state.copyWith(shouldShow: true);
  }
}

/// Внутренний провайдер для Notifier
final _showcaseNotifierProvider = NotifierProvider<ShowcaseNotifier, ShowcaseState>(
  ShowcaseNotifier.new,
);

/// Провайдер состояния showcase для каждой страницы
/// Использует Provider.family для простоты
final showcaseProvider = Provider.family<ShowcaseState, ShowcasePage>((ref, page) {
  final service = ref.watch(showcaseServiceProvider);
  return ShowcaseState(shouldShow: service.shouldShowShowcase(page));
});

/// Провайдер для notifier с методами (для конкретной страницы)
final showcaseNotifierProvider = Provider.family<_ShowcaseController, ShowcasePage>((ref, page) {
  return _ShowcaseController(ref, page);
});

/// Контроллер для управления showcase
class _ShowcaseController {
  final Ref _ref;
  final ShowcasePage _page;
  
  _ShowcaseController(this._ref, this._page);
  
  bool get shouldShow {
    final service = _ref.read(showcaseServiceProvider);
    return service.shouldShowShowcase(_page);
  }
  
  /// Запустить showcase
  void startShowcase(BuildContext context, List<GlobalKey> keys) {
    if (shouldShow && keys.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ShowCaseWidget.of(context).startShowCase(keys);
      });
    }
  }
  
  /// Отметить как просмотренное
  Future<void> markAsSeen() async {
    final service = _ref.read(showcaseServiceProvider);
    await service.markPageAsSeen(_page);
  }
  
  /// Сбросить (для тестирования)
  Future<void> reset() async {
    final service = _ref.read(showcaseServiceProvider);
    await service.resetShowcase(_page);
  }
}

/// Кастомный виджет для showcase tooltip
class ShowcaseTooltip extends StatelessWidget {
  final String title;
  final String description;
  final VoidCallback? onNext;
  final VoidCallback? onSkip;
  final bool isLast;
  final int currentStep;
  final int totalSteps;

  const ShowcaseTooltip({
    super.key,
    required this.title,
    required this.description,
    this.onNext,
    this.onSkip,
    this.isLast = false,
    this.currentStep = 1,
    this.totalSteps = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 300),
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
          // Progress indicator
          Row(
            children: [
              ...List.generate(totalSteps, (index) {
                final isActive = index < currentStep;
                final isCurrent = index == currentStep - 1;
                return Expanded(
                  child: Container(
                    height: 3,
                    margin: EdgeInsets.only(right: index < totalSteps - 1 ? 4 : 0),
                    decoration: BoxDecoration(
                      color: isActive 
                          ? const Color(0xFFfe3301) 
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: isCurrent
                        ? TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: 1),
                            duration: const Duration(milliseconds: 300),
                            builder: (context, value, child) {
                              return FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: value,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFfe3301),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              );
                            },
                          )
                        : null,
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 12),
          
          // Title
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 6),
          
          // Description
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
          
          // Buttons
          Row(
            children: [
              // Skip button
              if (onSkip != null && !isLast)
                TextButton(
                  onPressed: onSkip,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey.shade600,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  child: const Text(
                    'Пропустить',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              const Spacer(),
              
              // Next/Finish button
              FilledButton(
                onPressed: onNext,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFfe3301),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  isLast ? 'Готово' : 'Далее',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Helper для создания GlobalKey с идентификатором
class ShowcaseKeys {
  // Home screen keys
  static final homeQuickCards = GlobalKey(debugLabel: 'home_quick_cards');
  static final homeTracksCard = GlobalKey(debugLabel: 'home_tracks_card');
  static final homeAssembliesCard = GlobalKey(debugLabel: 'home_assemblies_card');
  static final homeInvoicesCard = GlobalKey(debugLabel: 'home_invoices_card');
  static final homeDigest = GlobalKey(debugLabel: 'home_digest');
  static final homePhotos = GlobalKey(debugLabel: 'home_photos');
  
  // Bottom navigation keys
  static final navHome = GlobalKey(debugLabel: 'nav_home');
  static final navPhotos = GlobalKey(debugLabel: 'nav_photos');
  static final navTracks = GlobalKey(debugLabel: 'nav_tracks');
  static final navInvoices = GlobalKey(debugLabel: 'nav_invoices');
  static final navAdd = GlobalKey(debugLabel: 'nav_add');
  
  // Tracks screen keys
  static final tracksFilter = GlobalKey(debugLabel: 'tracks_filter');
  static final tracksSearch = GlobalKey(debugLabel: 'tracks_search');
  static final tracksViewMode = GlobalKey(debugLabel: 'tracks_view_mode');
  static final tracksItem = GlobalKey(debugLabel: 'tracks_item');
  
  // Invoices screen keys
  static final invoicesFilter = GlobalKey(debugLabel: 'invoices_filter');
  static final invoicesSearch = GlobalKey(debugLabel: 'invoices_search');
  static final invoicesItem = GlobalKey(debugLabel: 'invoices_item');
  
  // Profile screen keys
  static final profileInfo = GlobalKey(debugLabel: 'profile_info');
  static final profileStats = GlobalKey(debugLabel: 'profile_stats');
  static final profileSettings = GlobalKey(debugLabel: 'profile_settings');
  
  // Top bar keys
  static final topBarNotifications = GlobalKey(debugLabel: 'topbar_notifications');
  static final topBarProfile = GlobalKey(debugLabel: 'topbar_profile');
  static final topBarClientCode = GlobalKey(debugLabel: 'topbar_client_code');
  static final topBarMenu = GlobalKey(debugLabel: 'topbar_menu');
  static final topBarHome = GlobalKey(debugLabel: 'topbar_home');
  static final topBarSearch = GlobalKey(debugLabel: 'topbar_search');
  
  // Search screen keys
  static final searchInput = GlobalKey(debugLabel: 'search_input');
  static final searchResult = GlobalKey(debugLabel: 'search_result');
  
  // News screen keys
  static final newsList = GlobalKey(debugLabel: 'news_list');
  
  // Rules screen keys
  static final rulesList = GlobalKey(debugLabel: 'rules_list');
  
  // Notifications keys
  static final notificationsFilter = GlobalKey(debugLabel: 'notifications_filter');
  static final notificationsList = GlobalKey(debugLabel: 'notifications_list');
}
