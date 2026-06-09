import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/sentry_config.dart';
import '../../../core/logging/client_log_service.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/network_diagnostics.dart';
import '../../../core/services/push_notification_service.dart';
import '../../../core/services/update_service.dart';
import '../../../core/ui/app_colors.dart';
import '../../../core/ui/app_toast.dart';
import '../../../core/ui/app_layout.dart';
import '../../../core/ui/blurred_modal_bottom_sheet.dart';
import '../../../core/utils/clipboard_helper.dart';
import '../../clients/application/client_codes_controller.dart';
import '../../clients/presentation/client_switcher_sheet.dart';
import '../../notifications/application/notifications_controller.dart';
import '../../notifications/presentation/notifications_sheet.dart';
import '../../profile/data/problem_report_repository.dart';
import '../../profile/data/profile_provider.dart';
import '../../profile/presentation/problem_report_sheet.dart';

class DesktopSideNavExpandedNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void toggle() => state = !state;
}

final desktopSideNavExpandedProvider =
    NotifierProvider<DesktopSideNavExpandedNotifier, bool>(
      DesktopSideNavExpandedNotifier.new,
    );

class DesktopSideNavScrollOffsetNotifier extends Notifier<double> {
  @override
  double build() => 0;

  void set(double value) => state = value;
}

final desktopSideNavScrollOffsetProvider =
    NotifierProvider<DesktopSideNavScrollOffsetNotifier, double>(
      DesktopSideNavScrollOffsetNotifier.new,
    );

class DesktopSideNav extends ConsumerStatefulWidget {
  final int? currentShellIndex;
  final ValueChanged<int>? onShellTap;

  const DesktopSideNav({super.key, this.currentShellIndex, this.onShellTap});

  @override
  ConsumerState<DesktopSideNav> createState() => _DesktopSideNavState();
}

class _DesktopSideNavState extends ConsumerState<DesktopSideNav> {
  bool _networkDiagnosticsRunning = false;
  bool _updateCheckRunning = false;
  late final ScrollController _menuScrollController;

  static const _primaryItems = <_SideNavEntry>[
    _SideNavEntry(
      icon: CupertinoIcons.house,
      selectedIcon: CupertinoIcons.house_fill,
      label: 'Главная',
      route: '/',
      shellIndex: 0,
    ),
    _SideNavEntry(
      icon: CupertinoIcons.photo_on_rectangle,
      selectedIcon: CupertinoIcons.photo_fill_on_rectangle_fill,
      label: 'Фотоотчёты',
      route: '/photos',
      shellIndex: 1,
    ),
    _SideNavEntry(
      icon: CupertinoIcons.cube,
      selectedIcon: CupertinoIcons.cube_fill,
      label: 'Треки',
      route: '/tracks',
      shellIndex: 2,
    ),
    _SideNavEntry(
      icon: CupertinoIcons.creditcard,
      selectedIcon: CupertinoIcons.creditcard_fill,
      label: 'Счета',
      route: '/invoices',
      shellIndex: 3,
    ),
    _SideNavEntry(
      icon: CupertinoIcons.chat_bubble_text,
      selectedIcon: CupertinoIcons.chat_bubble_text_fill,
      label: 'Поддержка',
      route: '/support',
      shellIndex: 4,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _menuScrollController = ScrollController(
      initialScrollOffset: ref.read(desktopSideNavScrollOffsetProvider),
    );
    _menuScrollController.addListener(_saveMenuScrollOffset);
  }

  void _saveMenuScrollOffset() {
    if (!_menuScrollController.hasClients) return;
    ref
        .read(desktopSideNavScrollOffsetProvider.notifier)
        .set(_menuScrollController.offset);
  }

  @override
  void dispose() {
    _menuScrollController.removeListener(_saveMenuScrollOffset);
    _menuScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final expanded = ref.watch(desktopSideNavExpandedProvider);
    final top = MediaQuery.paddingOf(context).top;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final currentPath = GoRouterState.of(context).uri.path;
    final clientCode = ref.watch(activeClientCodeProvider);
    ref.watch(notificationsControllerProvider);
    final unreadNotifications = ref.watch(unreadNotificationsCountProvider);
    final profileAsync = ref.watch(clientProfileProvider);
    final profile = profileAsync.asData?.value;
    final isProfileLoading = profile == null && profileAsync.isLoading;
    final cabinetItems = <_SideNavEntry>[
      _primaryItems.first,
      _SideNavEntry(
        icon: CupertinoIcons.bell,
        selectedIcon: CupertinoIcons.bell_fill,
        label: unreadNotifications > 0
            ? 'Уведомления · $unreadNotifications'
            : 'Уведомления',
        action: clientCode == null
            ? null
            : () => _openNotifications(clientCode),
        hasBadge: unreadNotifications > 0,
        attention: unreadNotifications > 0,
      ),
      ..._primaryItems.skip(1),
    ];
    const serviceItems = <_SideNavEntry>[
      _SideNavEntry(
        icon: Icons.person_rounded,
        selectedIcon: Icons.person_rounded,
        label: 'Профиль',
        route: '/profile',
      ),
      _SideNavEntry(
        icon: Icons.account_balance_wallet_rounded,
        selectedIcon: Icons.account_balance_wallet_rounded,
        label: 'Оплата',
        route: '/payment-chat',
      ),
      _SideNavEntry(
        icon: Icons.calculate_rounded,
        selectedIcon: Icons.calculate_rounded,
        label: 'Калькулятор',
        route: '/calculator',
      ),
      _SideNavEntry(
        icon: Icons.description_rounded,
        selectedIcon: Icons.description_rounded,
        label: 'Выкуп',
        route: '/purchase-blanks',
      ),
      _SideNavEntry(
        icon: Icons.shopping_bag_rounded,
        selectedIcon: Icons.shopping_bag_rounded,
        label: 'СП',
        route: '/sp-finance',
      ),
      _SideNavEntry(
        icon: Icons.travel_explore_rounded,
        selectedIcon: Icons.travel_explore_rounded,
        label: 'Поиск трека',
        route: '/search-nocode',
      ),
    ];
    const infoItems = <_SideNavEntry>[
      _SideNavEntry(
        icon: Icons.card_giftcard_rounded,
        selectedIcon: Icons.card_giftcard_rounded,
        label: 'Рефералы',
        route: '/referral',
      ),
      _SideNavEntry(
        icon: Icons.newspaper_rounded,
        selectedIcon: Icons.newspaper_rounded,
        label: 'Новости',
        route: '/news',
      ),
      _SideNavEntry(
        icon: Icons.rule_rounded,
        selectedIcon: Icons.rule_rounded,
        label: 'Правила',
        route: '/rules',
      ),
      _SideNavEntry(
        icon: Icons.price_change_rounded,
        selectedIcon: Icons.price_change_rounded,
        label: 'Тарифы',
        route: '/tariffs',
      ),
    ];
    final diagnosticItems = <_SideNavEntry>[
      _SideNavEntry(
        icon: Icons.system_update_rounded,
        selectedIcon: Icons.system_update_rounded,
        label: _updateCheckRunning ? 'Проверяем…' : 'Обновление',
        action: _checkForUpdate,
        loading: _updateCheckRunning,
      ),
      _SideNavEntry(
        icon: Icons.wifi_rounded,
        selectedIcon: Icons.wifi_rounded,
        label: _networkDiagnosticsRunning ? 'Диагностика…' : 'Диагностика',
        action: _runNetworkDiagnostics,
        loading: _networkDiagnosticsRunning,
      ),
      _SideNavEntry(
        icon: Icons.bug_report_outlined,
        selectedIcon: Icons.bug_report_outlined,
        label: 'Проблема',
        action: isProfileLoading ? null : () => _openProblemReport(profile),
        loading: isProfileLoading,
      ),
      if (SentryConfig.verifyButtonEnabled)
        _SideNavEntry(
          icon: Icons.bug_report_rounded,
          selectedIcon: Icons.bug_report_rounded,
          label: 'Sentry',
          action: () {
            throw StateError('Sentry verify test exception');
          },
        ),
    ];

    return SafeArea(
      top: false,
      right: false,
      bottom: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppLayout.sideNavHorizontalMargin,
          top + 14,
          10,
          bottom + 14,
        ),
        child: _SideNavSurface(
          expanded: expanded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _CollapseButton(
                expanded: expanded,
                onTap: () {
                  HapticFeedback.selectionClick();
                  ref.read(desktopSideNavExpandedProvider.notifier).toggle();
                },
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  key: const PageStorageKey<String>('desktop-side-nav-scroll'),
                  controller: _menuScrollController,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SideNavSection(
                        title: 'Кабинет',
                        expanded: expanded,
                        entries: cabinetItems,
                        currentPath: currentPath,
                        isSelected: _isSelected,
                        onTap: _handleEntryTap,
                      ),
                      _SideNavSection(
                        title: 'Сервисы',
                        expanded: expanded,
                        entries: serviceItems,
                        currentPath: currentPath,
                        isSelected: _isSelected,
                        onTap: _handleEntryTap,
                      ),
                      _SideNavSection(
                        title: 'Материалы',
                        expanded: expanded,
                        entries: infoItems,
                        currentPath: currentPath,
                        isSelected: _isSelected,
                        onTap: _handleEntryTap,
                      ),
                      _SideNavSection(
                        title: 'Диагностика',
                        expanded: expanded,
                        entries: diagnosticItems,
                        currentPath: currentPath,
                        isSelected: _isSelected,
                        onTap: _handleEntryTap,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _SideClientSwitcherButton(expanded: expanded),
            ],
          ),
        ),
      ),
    );
  }

  bool _isSelected(_SideNavEntry entry, String currentPath) {
    if (entry.shellIndex != null && widget.currentShellIndex != null) {
      return entry.shellIndex == widget.currentShellIndex;
    }
    final route = entry.route;
    if (route == null) return false;
    if (route == '/') return currentPath == '/';
    return currentPath == route || currentPath.startsWith('$route/');
  }

  void _handleEntryTap(_SideNavEntry entry) {
    final route = entry.route;
    HapticFeedback.selectionClick();
    ClientLogService.instance.action(
      'Нажата боковая навигация',
      data: {
        'tab': entry.label,
        'route': route,
        'shellIndex': entry.shellIndex,
      },
    );

    if (entry.action != null) {
      entry.action!.call();
      return;
    }

    if (entry.shellIndex != null && widget.onShellTap != null) {
      widget.onShellTap!(entry.shellIndex!);
      return;
    }

    if (route != null) {
      context.go(route);
    }
  }

  void _openNotifications(String clientCode) {
    final navigator = Navigator.of(context);
    final router = GoRouter.of(context);
    final useSideSheet = AppLayout.useSideNavigation(context);
    var isSheetOpen = true;

    void handleNavigate(String route) {
      if (!isSheetOpen || !navigator.mounted) return;
      isSheetOpen = false;
      if (navigator.canPop()) {
        navigator.pop();
      }
      router.go(route);
    }

    showBlurredModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.22),
      useSafeArea: true,
      isScrollControlled: true,
      builder: (_) {
        if (useSideSheet) {
          return NotificationsSheet(
            clientCode: clientCode,
            onNavigate: handleNavigate,
          );
        }

        return DraggableScrollableSheet(
          initialChildSize: 0.74,
          minChildSize: 0.46,
          maxChildSize: 0.96,
          expand: false,
          builder: (_, controller) => NotificationsSheet(
            clientCode: clientCode,
            onNavigate: handleNavigate,
            controller: controller,
          ),
        );
      },
    ).whenComplete(() => isSheetOpen = false);
  }

  Future<void> _runNetworkDiagnostics() async {
    if (_networkDiagnosticsRunning) return;

    final messenger = ScaffoldMessenger.of(context);
    final brandColor = context.brandPrimary;

    setState(() => _networkDiagnosticsRunning = true);
    ClientLogService.instance.action('Запуск диагностики сети');

    try {
      final report = await NetworkDiagnosticsService(
        ref.read(apiClientProvider),
      ).collect(clientCode: ref.read(activeClientCodeProvider));
      final copied = await AppClipboard.copyText(report.toSupportText());

      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            copied
                ? 'Диагностика сети скопирована. Отправьте её менеджеру.'
                : 'Диагностика сети собрана, но не скопирована автоматически.',
          ),
          backgroundColor: brandColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } catch (error, stackTrace) {
      await ClientLogService.instance.captureNonFatal(
        'Не удалось собрать диагностику сети',
        error: error,
        stackTrace: stackTrace,
      );

      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Не удалось собрать диагностику сети'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _networkDiagnosticsRunning = false);
      }
    }
  }

  Future<void> _checkForUpdate() async {
    if (_updateCheckRunning) return;

    setState(() => _updateCheckRunning = true);
    ClientLogService.instance.action('Ручная проверка обновления');

    try {
      await UpdateService.manualCheckAndPrompt(context);
    } finally {
      if (mounted) {
        setState(() => _updateCheckRunning = false);
      }
    }
  }

  void _openProblemReport(ClientProfile? profile) {
    if (profile == null) {
      AppToast.showFromSnackBar(
        context,
        SnackBar(
          content: const Text('Профиль ещё не загрузился. Попробуйте ещё раз.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    final rootNavigator = Navigator.of(context, rootNavigator: true);
    final hostContext = rootNavigator.context;
    final repository = ref.read(problemReportRepositoryProvider);
    final currentScreen = ClientLogService.instance.currentScreen;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!hostContext.mounted) return;
      showProblemReportSheet(
        context: hostContext,
        profile: profile,
        repository: repository,
        currentScreen: currentScreen,
      );
    });
  }
}

class _SideNavEntry {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String? route;
  final int? shellIndex;
  final VoidCallback? action;
  final bool loading;
  final bool hasBadge;
  final bool attention;

  const _SideNavEntry({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.route,
    this.shellIndex,
    this.action,
    this.loading = false,
    this.hasBadge = false,
    this.attention = false,
  });
}

class _SideNavSection extends StatelessWidget {
  final String title;
  final bool expanded;
  final List<_SideNavEntry> entries;
  final String currentPath;
  final bool Function(_SideNavEntry entry, String currentPath) isSelected;
  final ValueChanged<_SideNavEntry> onTap;

  const _SideNavSection({
    required this.title,
    required this.expanded,
    required this.entries,
    required this.currentPath,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.fromLTRB(6, expanded ? 8 : 6, 6, 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.36),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withValues(alpha: 0.035)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (expanded) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontFamily: 'Gilroy',
                  fontWeight: FontWeight.w800,
                  fontSize: 11.5,
                  height: 1.1,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Center(
                child: Container(
                  width: 18,
                  height: 3,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            ),
          for (var i = 0; i < entries.length; i++) ...[
            _SideNavButton(
              icon: entries[i].icon,
              selectedIcon: entries[i].selectedIcon,
              label: entries[i].label,
              expanded: expanded,
              selected: isSelected(entries[i], currentPath),
              loading: entries[i].loading,
              hasBadge: entries[i].hasBadge,
              attention: entries[i].attention,
              onTap: entries[i].action == null && entries[i].route == null
                  ? null
                  : () => onTap(entries[i]),
            ),
            if (i < entries.length - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _SideNavSurface extends StatelessWidget {
  final bool expanded;
  final Widget child;

  const _SideNavSurface({required this.expanded, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 34,
            spreadRadius: -16,
            offset: const Offset(8, 18),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.90),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withValues(alpha: 0.76)),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.98),
                  const Color(0xFFF8FAFC).withValues(alpha: 0.88),
                ],
              ),
            ),
            child: Padding(
              padding: EdgeInsets.all(expanded ? 10 : 8),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _SideNavButton extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool expanded;
  final bool selected;
  final bool loading;
  final bool hasBadge;
  final bool attention;
  final VoidCallback? onTap;

  const _SideNavButton({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.expanded,
    required this.selected,
    required this.onTap,
    this.loading = false,
    this.hasBadge = false,
    this.attention = false,
  });

  @override
  Widget build(BuildContext context) {
    final contentColor = selected ? Colors.white : const Color(0xFF3A3F4B);
    final mutedColor = selected
        ? Colors.white
        : attention
        ? context.brandPrimary
        : context.brandPrimary;

    return Tooltip(
      message: label,
      waitDuration: const Duration(milliseconds: 500),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: loading ? null : onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            height: 48,
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: expanded ? 13 : 0),
            decoration: BoxDecoration(
              gradient: selected
                  ? context.brandGradient
                  : attention
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        context.brandPrimary.withValues(alpha: 0.12),
                        context.brandSecondary.withValues(alpha: 0.07),
                      ],
                    )
                  : null,
              color: selected ? null : Colors.white.withValues(alpha: 0.38),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected
                    ? Colors.white.withValues(alpha: 0.22)
                    : Colors.black.withValues(alpha: 0.035),
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: context.brandPrimary.withValues(alpha: 0.18),
                        blurRadius: 16,
                        spreadRadius: -7,
                        offset: const Offset(0, 9),
                      ),
                    ]
                  : null,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final showLabel = expanded && constraints.maxWidth >= 118;

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    showLabel
                        ? Row(
                            children: [
                              _SideNavIcon(
                                icon: selected ? selectedIcon : icon,
                                selected: selected,
                                loading: loading,
                                color: mutedColor,
                              ),
                              const SizedBox(width: 11),
                              Expanded(
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Transform.translate(
                                    offset: const Offset(0, 1),
                                    child: Text(
                                      label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textHeightBehavior:
                                          const TextHeightBehavior(
                                            applyHeightToFirstAscent: false,
                                            applyHeightToLastDescent: false,
                                          ),
                                      strutStyle: const StrutStyle(
                                        fontFamily: 'Gilroy',
                                        fontSize: 14,
                                        height: 1,
                                        forceStrutHeight: true,
                                      ),
                                      style: TextStyle(
                                        fontFamily: 'Gilroy',
                                        fontSize: 14,
                                        height: 1,
                                        fontWeight: FontWeight.w800,
                                        color: contentColor,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Center(
                            child: _SideNavIcon(
                              icon: selected ? selectedIcon : icon,
                              selected: selected,
                              loading: loading,
                              color: mutedColor,
                            ),
                          ),
                    if (hasBadge)
                      Positioned(
                        right: showLabel ? 8 : 15,
                        top: showLabel ? 10 : 8,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(color: Colors.white, width: 1.4),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _SideNavIcon extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final bool loading;
  final Color color;

  const _SideNavIcon({
    required this.icon,
    required this.selected,
    required this.loading,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2.2,
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      );
    }

    return Icon(icon, size: selected ? 24 : 22, color: color);
  }
}

class _CollapseButton extends StatelessWidget {
  final bool expanded;
  final VoidCallback onTap;

  const _CollapseButton({required this.expanded, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _SideNavButton(
      icon: expanded
          ? Icons.keyboard_double_arrow_left_rounded
          : Icons.keyboard_double_arrow_right_rounded,
      selectedIcon: expanded
          ? Icons.keyboard_double_arrow_left_rounded
          : Icons.keyboard_double_arrow_right_rounded,
      label: expanded ? 'Свернуть меню' : 'Развернуть меню',
      expanded: expanded,
      selected: false,
      onTap: onTap,
    );
  }
}

class _SideClientSwitcherButton extends ConsumerWidget {
  final bool expanded;

  const _SideClientSwitcherButton({required this.expanded});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(clientCodesControllerProvider);
    final label = state.when(
      data: (s) => (s.activeCode ?? 'Код клиента'),
      loading: () => '…',
      error: (_, _) => 'Код клиента',
    );

    return Tooltip(
      message: 'Код клиента: $label',
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => showBlurredModalBottomSheet<void>(
            context: context,
            backgroundColor: Colors.transparent,
            barrierColor: Colors.black.withValues(alpha: 0.22),
            useSafeArea: true,
            isScrollControlled: true,
            builder: (_) => const ClientSwitcherSheet(),
          ),
          child: Container(
            height: 54,
            padding: EdgeInsets.symmetric(horizontal: expanded ? 13 : 0),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.58),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final showLabel = expanded && constraints.maxWidth >= 118;
                if (!showLabel) {
                  return Center(
                    child: _ClientCodeDot(color: context.brandPrimary),
                  );
                }

                return Row(
                  children: [
                    _ClientCodeDot(color: context.brandPrimary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Код клиента',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Gilroy',
                              fontSize: 10.5,
                              height: 1,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF8B92A1),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Gilroy',
                              fontSize: 15,
                              height: 1,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF2F2F2F),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      CupertinoIcons.chevron_up_chevron_down,
                      size: 15,
                      color: Color(0xFF5E6472),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _ClientCodeDot extends StatelessWidget {
  final Color color;

  const _ClientCodeDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(99),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.34),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
    );
  }
}
