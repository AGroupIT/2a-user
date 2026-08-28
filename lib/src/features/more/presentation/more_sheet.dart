import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/sentry_config.dart';
import '../../../core/logging/client_log_service.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/network_diagnostics.dart';
import '../../../core/services/update_service.dart';
import '../../../core/services/platform_helper.dart';
import '../../../core/ui/animated_hero_glow_backdrop.dart';
import '../../../core/ui/app_colors.dart';
import '../../../core/ui/app_toast.dart';
import '../../../core/ui/sheet_handle.dart';
import '../../../core/utils/clipboard_helper.dart';
import '../../clients/application/client_codes_controller.dart';
import '../../garage/application/garage_providers.dart';
import '../../partner_program/data/client_partner_program_provider.dart';
import '../../profile/data/problem_report_repository.dart';
import '../../profile/data/profile_provider.dart';
import '../../profile/presentation/problem_report_sheet.dart';
import '../../self_buyout/data/self_buyout_service.dart';

class MoreSheet extends ConsumerStatefulWidget {
  const MoreSheet({super.key});

  @override
  ConsumerState<MoreSheet> createState() => _MoreSheetState();
}

class _MoreSheetState extends ConsumerState<MoreSheet> {
  bool _networkDiagnosticsRunning = false;
  bool _updateCheckRunning = false;

  void _go(BuildContext context, String route) {
    Navigator.of(context).pop();
    if (route == '/support') {
      context.go(route);
    } else {
      context.push(route);
    }
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

  void _showProfileUnavailableMessage() {
    AppToast.showFromSnackBar(
      context,
      SnackBar(
        content: const Text('Профиль ещё не загрузился. Попробуйте ещё раз.'),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _openProblemReport(ClientProfile? profile) {
    if (profile == null) {
      _showProfileUnavailableMessage();
      return;
    }

    final rootNavigator = Navigator.of(context, rootNavigator: true);
    final hostContext = rootNavigator.context;
    final repository = ref.read(problemReportRepositoryProvider);
    final currentScreen = ClientLogService.instance.currentScreen;

    Navigator.of(context).pop();
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

  @override
  Widget build(BuildContext context) {
    final activeCode = ref.watch(activeClientCodeProvider);
    final profileAsync = ref.watch(clientProfileProvider);
    final profile = profileAsync.asData?.value;
    final isProfileLoading = profile == null && profileAsync.isLoading;
    final bottomSafe = MediaQuery.paddingOf(context).bottom;
    // Самовыкуп не скрываем молча, если временно недоступен только из-за курса.
    final selfBuyoutAvailability = ref
        .watch(selfBuyoutAvailabilityProvider)
        .asData
        ?.value;
    final selfBuyoutAvailable = selfBuyoutAvailability?.available ?? false;
    final selfBuyoutWaitingForRates = _isSelfBuyoutWaitingForRates(
      selfBuyoutAvailability?.reason,
    );
    final showSelfBuyout = selfBuyoutAvailable || selfBuyoutWaitingForRates;
    final showGarage =
        ref.watch(garageAvailabilityProvider).asData?.value.available ?? false;
    final showPartnerProgram =
        ref.watch(clientPartnerProgramProvider).asData?.value != null;
    final showManualUpdateCheck = shouldShowManualUpdateMenu(
      isAndroid: isAndroidImpl(),
      isRustoreDistribution: UpdateService.isRustoreDistribution,
    );

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.88,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 36,
            spreadRadius: -14,
            offset: const Offset(0, -14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            const SheetHandle(),
            Flexible(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(16, 14, 16, 24 + bottomSafe),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _MoreHeader(activeCode: activeCode),
                    const SizedBox(height: 14),
                    _QuickActionsGrid(
                      actions: [
                        _QuickActionData(
                          icon: Icons.account_balance_wallet_rounded,
                          title: 'Чат по оплатам',
                          subtitle: 'Оплата счетов',
                          color: const Color(0xFF4CAF50),
                          onTap: () => _go(context, '/payment-chat'),
                        ),
                        _QuickActionData(
                          icon: Icons.support_agent_rounded,
                          title: 'Чат поддержки',
                          subtitle: 'Помощь менеджера',
                          onTap: () => _go(context, '/support'),
                        ),
                        if (showSelfBuyout)
                          _QuickActionData(
                            icon: Icons.savings_rounded,
                            title: 'Самовыкуп',
                            subtitle: selfBuyoutWaitingForRates
                                ? 'Ожидаем курсы'
                                : 'Оплата в юанях',
                            color: selfBuyoutWaitingForRates
                                ? const Color(0xFFF59E0B)
                                : const Color(0xFF10B981),
                            onTap: () => _go(context, '/self-buyout'),
                          ),
                        if (showGarage)
                          _QuickActionData(
                            icon: Icons.garage_rounded,
                            title: 'Гараж',
                            subtitle: 'Запчасти и заказы',
                            color: const Color(0xFF3B82F6),
                            onTap: () => _go(context, '/garage'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _MoreSection(
                      title: 'Разделы',
                      children: [
                        _MoreMenuTile(
                          icon: Icons.person_rounded,
                          title: 'Профиль',
                          subtitle: 'Аккаунт и настройки',
                          onTap: () => _go(context, '/profile'),
                        ),
                        _MoreMenuTile(
                          icon: Icons.card_giftcard_rounded,
                          title: 'Реферальная программа',
                          subtitle: 'Бонусные килограммы и приглашения',
                          iconColor: const Color(0xFF4CAF50),
                          onTap: () => _go(context, '/referral'),
                        ),
                        if (showPartnerProgram)
                          _MoreMenuTile(
                            icon: Icons.handshake_rounded,
                            title: 'Партнёрская программа',
                            subtitle: 'Приглашения, комиссия и выплаты',
                            iconColor: const Color(0xFF0F9D8A),
                            onTap: () => _go(context, '/partner-program'),
                          ),
                        _MoreMenuTile(
                          icon: Icons.description_rounded,
                          title: 'Выкуп по бланку',
                          subtitle: 'Заявки на выкуп товаров по ссылкам',
                          iconColor: const Color(0xFFFF5722),
                          onTap: () => _go(context, '/purchase-blanks'),
                        ),
                        _MoreMenuTile(
                          icon: Icons.shopping_bag_rounded,
                          title: 'Совместные покупки',
                          subtitle: 'Финансы и участие в СП',
                          iconColor: const Color(0xFF9C27B0),
                          onTap: () => _go(context, '/sp-finance'),
                        ),
                        _MoreMenuTile(
                          icon: Icons.travel_explore_rounded,
                          title: 'Поиск трека без кода',
                          subtitle: 'Если склад ещё не привязал посылку',
                          iconColor: const Color(0xFF00BCD4),
                          onTap: () => _go(context, '/search-nocode'),
                        ),
                        _MoreMenuTile(
                          icon: Icons.newspaper_rounded,
                          title: 'Новости',
                          subtitle: 'Обновления и объявления',
                          onTap: () => _go(context, '/news'),
                        ),
                        _MoreMenuTile(
                          icon: Icons.rule_rounded,
                          title: 'Правила',
                          subtitle: 'Условия работы склада и доставки',
                          onTap: () => _go(context, '/rules'),
                        ),
                        _MoreMenuTile(
                          icon: Icons.price_change_rounded,
                          title: 'Тарифы',
                          subtitle: 'Стоимость услуг и доставки',
                          iconColor: const Color(0xFFFF9800),
                          onTap: () => _go(context, '/tariffs'),
                        ),
                        if (showManualUpdateCheck)
                          _MoreMenuTile(
                            icon: Icons.system_update_rounded,
                            title: _updateCheckRunning
                                ? 'Проверяем обновления…'
                                : 'Проверить обновления',
                            subtitle: 'Найти новую версию приложения',
                            iconColor: const Color(0xFF4CAF50),
                            loading: _updateCheckRunning,
                            onTap: _checkForUpdate,
                          ),
                        _MoreMenuTile(
                          icon: Icons.wifi_rounded,
                          title: _networkDiagnosticsRunning
                              ? 'Диагностика выполняется…'
                              : 'Диагностика сети',
                          subtitle: _networkDiagnosticsRunning
                              ? 'Собираем отчёт для поддержки'
                              : 'Скопировать отчёт для менеджера',
                          iconColor: const Color(0xFF2196F3),
                          loading: _networkDiagnosticsRunning,
                          onTap: _runNetworkDiagnostics,
                        ),
                        _MoreMenuTile(
                          icon: Icons.bug_report_outlined,
                          title: 'Сообщить о проблеме',
                          subtitle: isProfileLoading
                              ? 'Загружаем профиль'
                              : 'Отправить отчёт в поддержку',
                          iconColor: Colors.redAccent,
                          loading: isProfileLoading,
                          onTap: () => _openProblemReport(profile),
                        ),
                        if (SentryConfig.verifyButtonEnabled)
                          _MoreMenuTile(
                            icon: Icons.bug_report_rounded,
                            title: 'Verify Sentry Setup',
                            subtitle: 'Тестовая ошибка для проверки Sentry',
                            iconColor: Colors.redAccent,
                            onTap: () {
                              throw StateError('Sentry verify test exception');
                            },
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoreHeader extends StatelessWidget {
  final String? activeCode;

  const _MoreHeader({required this.activeCode});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: context.brandGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: context.brandPrimary.withValues(alpha: 0.22),
            blurRadius: 24,
            spreadRadius: -10,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            const Positioned.fill(child: AnimatedHeroGlowBackdrop()),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.22),
                          ),
                        ),
                        child: const Icon(
                          Icons.apps_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ещё',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontFamily: 'Gilroy',
                                fontWeight: FontWeight.w900,
                                fontSize: 24,
                                height: 1.05,
                                letterSpacing: -0.35,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Быстрый доступ к сервисам кабинета',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Color(0xE6FFFFFF),
                                fontFamily: 'Gilroy',
                                fontWeight: FontWeight.w600,
                                fontSize: 12.5,
                                height: 1.15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _HeaderPill(
                        icon: Icons.badge_rounded,
                        label: activeCode == null
                            ? 'Код не выбран'
                            : 'Код $activeCode',
                      ),
                      const _HeaderPill(
                        icon: Icons.bolt_rounded,
                        label: 'Инструменты и помощь',
                      ),
                    ],
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

class _HeaderPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeaderPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 15),
          const SizedBox(width: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'Gilroy',
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionData {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color? color;
  final VoidCallback onTap;

  const _QuickActionData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.color,
  });
}

class _QuickActionsGrid extends StatelessWidget {
  final List<_QuickActionData> actions;

  const _QuickActionsGrid({required this.actions});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var index = 0; index < actions.length; index += 2) {
      rows.add(
        Row(
          children: [
            Expanded(child: _QuickActionCard(data: actions[index])),
            const SizedBox(width: 10),
            Expanded(
              child: index + 1 < actions.length
                  ? _QuickActionCard(data: actions[index + 1])
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      );
      if (index + 2 < actions.length) rows.add(const SizedBox(height: 10));
    }

    return Column(children: rows);
  }
}

class _QuickActionCard extends StatelessWidget {
  final _QuickActionData data;

  const _QuickActionCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final color = data.color ?? context.brandPrimary;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: data.onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.black.withValues(alpha: 0.045)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.045),
                blurRadius: 16,
                spreadRadius: -8,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 92),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(data.icon, color: color, size: 21),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    data.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontFamily: 'Gilroy',
                      fontWeight: FontWeight.w900,
                      fontSize: 14.5,
                      height: 1.05,
                      letterSpacing: -0.1,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    data.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontFamily: 'Gilroy',
                      fontWeight: FontWeight.w600,
                      fontSize: 11.5,
                      height: 1.1,
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

class _MoreSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _MoreSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 0, 2, 10),
          child: Text(
            title,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontFamily: 'Gilroy',
              fontWeight: FontWeight.w800,
              fontSize: 12,
              height: 1.1,
              letterSpacing: 0.2,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 18,
                spreadRadius: -10,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                children[i],
                if (i < children.length - 1)
                  Divider(
                    height: 1,
                    indent: 64,
                    endIndent: 14,
                    color: Colors.black.withValues(alpha: 0.055),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MoreMenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? iconColor;
  final bool loading;

  const _MoreMenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.iconColor,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? context.brandSecondary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 21),
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
                        color: AppColors.textPrimary,
                        fontFamily: 'Gilroy',
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                        height: 1.12,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontFamily: 'Gilroy',
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (loading)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                )
              else
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSecondary.withValues(alpha: 0.64),
                  size: 23,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

bool _isSelfBuyoutWaitingForRates(String? reason) {
  return reason == 'rate_stale' ||
      reason == 'no_rate' ||
      reason == 'rate_invalid';
}

@visibleForTesting
bool shouldShowManualUpdateMenu({
  required bool isAndroid,
  required bool isRustoreDistribution,
}) {
  return isAndroid && !isRustoreDistribution;
}
