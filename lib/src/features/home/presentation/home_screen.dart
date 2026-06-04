import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:twoalogisticcabineuser/src/core/ui/app_toast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/cache/stale_data_cache.dart';
import '../../../core/network/api_config.dart';
import '../../../core/services/showcase_service.dart';
import '../../../core/services/update_service.dart';
import '../../../core/ui/app_cached_media_image.dart';
import '../../../core/ui/app_colors.dart';
import '../../../core/ui/app_layout.dart';
import '../../../core/ui/empty_state.dart';
import '../../../core/utils/clipboard_helper.dart';
import '../../assemblies/data/assemblies_provider.dart';
import '../../assemblies/domain/assembly_item.dart';
import '../../auth/data/auth_provider.dart';
import '../../clients/application/client_codes_controller.dart';
import '../../invoices/data/invoices_provider.dart';
import '../../invoices/domain/invoice_item.dart';
import '../../photos/data/photos_provider.dart';
import '../../photos/domain/photo_item.dart';
import '../../photos/presentation/photo_viewer_screen.dart';
import '../../profile/data/profile_provider.dart';
import '../../referral/data/referral_provider.dart';
import '../../tracks/data/tracks_provider.dart';
import '../../tracks/domain/track_item.dart';
import '../../tracks/presentation/add_tracks_dialog.dart';
import '../../../core/ui/tutorial_card.dart';

void _showStyledSnackBar(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  AppToast.show(context, message, isError: isError);
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  // Флаг для показа диалога принятия правил
  bool _termsDialogShown = false;
  final _noCodeSearchController = TextEditingController();

  final GlobalKey _quickCardsKey = GlobalKey();
  final GlobalKey _digestKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _checkAndShowTermsDialog();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) UpdateService.checkAndPrompt(context);
    });
  }

  @override
  void dispose() {
    _noCodeSearchController.dispose();
    super.dispose();
  }

  /// Проверить и показать диалог принятия правил если нужно
  void _checkAndShowTermsDialog() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _termsDialogShown) return;

      final showcaseService = ref.read(showcaseServiceProvider);
      // Показываем диалог только если пользователь еще не принял правила
      if (!showcaseService.hasAcceptedTerms) {
        _termsDialogShown = true;
        _showTermsDialog();
      }
    });
  }

  /// Показать диалог принятия правил
  Future<void> _showTermsDialog() async {
    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _TermsAcceptanceDialog(),
    );
  }

  void _openNoCodeSearch() {
    final query = _noCodeSearchController.text.trim();
    final location = query.length >= 3
        ? Uri(
            path: '/search-nocode',
            queryParameters: {'query': query},
          ).toString()
        : '/search-nocode';
    context.push(location);
  }

  @override
  Widget build(BuildContext context) {
    final clientCode = ref.watch(activeClientCodeProvider);
    final authState = ref.watch(authProvider);
    final clientProfile = ref.watch(clientProfileProvider);
    // Используем имя из профиля (актуальное с сервера), иначе из кэша авторизации
    final clientName =
        clientProfile.asData?.value?.fullName ??
        authState.clientName ??
        'Клиент';
    final shouldLoadDashboardData =
        authState.isLoggedIn && !authState.isLoading;

    if (clientCode == null) {
      return const EmptyState(
        icon: Icons.badge_outlined,
        title: 'Выберите код клиента',
        message:
            'Чтобы увидеть данные, сначала выберите или добавьте код клиента.',
      );
    }

    final AsyncValue<List<TrackItem>> tracksDigestAsync =
        shouldLoadDashboardData
        ? ref.watch(tracksDigestProvider(clientCode))
        : const AsyncValue.loading();
    final AsyncValue<List<AssemblyItem>> assembliesDigestAsync =
        shouldLoadDashboardData
        ? ref.watch(assembliesDigestProvider(clientCode))
        : const AsyncValue.loading();
    final AsyncValue<List<InvoiceItem>> invoicesDigestAsync =
        shouldLoadDashboardData
        ? ref.watch(invoicesDigestProvider(clientCode))
        : const AsyncValue.loading();
    final AsyncValue<List<PhotoItem>> recentPhotosAsync =
        shouldLoadDashboardData
        ? ref.watch(photosRecentProvider((clientCode: clientCode, limit: 12)))
        : const AsyncValue.loading();

    final AsyncValue<int> tracksCountAsync = shouldLoadDashboardData
        ? ref.watch(tracksCountProvider(clientCode))
        : const AsyncValue.loading();
    final AsyncValue<int> assembliesCountAsync = shouldLoadDashboardData
        ? ref.watch(assembliesCountProvider(clientCode))
        : const AsyncValue.loading();
    final AsyncValue<int> invoicesCountAsync = shouldLoadDashboardData
        ? ref.watch(invoicesCountProvider(clientCode))
        : const AsyncValue.loading();
    final AsyncValue<int> tracksWeeklyCountAsync = shouldLoadDashboardData
        ? ref.watch(tracksWeeklyCountProvider(clientCode))
        : const AsyncValue.loading();
    final AsyncValue<int> assembliesWeeklyCountAsync = shouldLoadDashboardData
        ? ref.watch(assembliesWeeklyCountProvider(clientCode))
        : const AsyncValue.loading();
    final AsyncValue<int> invoicesWeeklyCountAsync = shouldLoadDashboardData
        ? ref.watch(invoicesWeeklyCountProvider(clientCode))
        : const AsyncValue.loading();
    final AsyncValue<ReferralData> referralAsync = shouldLoadDashboardData
        ? ref.watch(referralProvider)
        : const AsyncValue.loading();
    final staleNotice = ref.watch(staleDataNoticeProvider);

    final tracksCount = tracksCountAsync.asData?.value;
    final assembliesCount = assembliesCountAsync.asData?.value;
    final invoicesCount = invoicesCountAsync.asData?.value;
    final tracksWeeklyCount = tracksWeeklyCountAsync.asData?.value;
    final assembliesWeeklyCount = assembliesWeeklyCountAsync.asData?.value;
    final invoicesWeeklyCount = invoicesWeeklyCountAsync.asData?.value;
    final referralData = referralAsync.asData?.value;
    final bonusKgBalance = referralData?.referralKgBalance;
    final bonusKgWeekly = referralData == null
        ? null
        : _weeklyBonusKg(referralData);
    final agent = clientProfile.asData?.value?.agent;

    final topPad = AppLayout.topBarTotalHeight(context);
    final bottomContentGap = AppLayout.bottomScrollPadding(context) + 16;

    Future<void> onRefresh() async {
      debugPrint('[Home] pull-to-refresh triggered');
      ref.read(staleDataNoticeProvider.notifier).clear();
      ref.invalidate(clientProfileProvider);
      unawaited(
        ref.read(clientProfileProvider.future).catchError((
          Object error,
          StackTrace stackTrace,
        ) {
          debugPrint('[Home] profile refresh failed: $error');
          return null;
        }),
      );
      if (!mounted) return;
      ref.invalidate(tracksDigestProvider(clientCode));
      ref.invalidate(assembliesDigestProvider(clientCode));
      ref.invalidate(invoicesDigestProvider(clientCode));
      ref.invalidate(photosRecentProvider((clientCode: clientCode, limit: 12)));
      ref.invalidate(tracksCountProvider(clientCode));
      ref.invalidate(assembliesCountProvider(clientCode));
      ref.invalidate(invoicesCountProvider(clientCode));
      ref.invalidate(tracksWeeklyCountProvider(clientCode));
      ref.invalidate(assembliesWeeklyCountProvider(clientCode));
      ref.invalidate(invoicesWeeklyCountProvider(clientCode));
      ref.invalidate(referralProvider);
      await Future.wait([
        ref.read(tracksDigestProvider(clientCode).future),
        ref.read(assembliesDigestProvider(clientCode).future),
        ref.read(invoicesDigestProvider(clientCode).future),
        ref.read(
          photosRecentProvider((clientCode: clientCode, limit: 12)).future,
        ),
        ref.read(tracksCountProvider(clientCode).future),
        ref.read(assembliesCountProvider(clientCode).future),
        ref.read(invoicesCountProvider(clientCode).future),
        ref.read(tracksWeeklyCountProvider(clientCode).future),
        ref.read(assembliesWeeklyCountProvider(clientCode).future),
        ref.read(invoicesWeeklyCountProvider(clientCode).future),
        ref.read(referralProvider.future),
      ]);
    }

    return TutorialScreenWrapper(
      screenKey: 'home',
      steps: [
        TutorialStep(
          icon: Icons.dashboard_rounded,
          title: 'Главная страница',
          description:
              'Здесь собрана ключевая информация: счётчики треков, сборок, счетов и фотоотчётов. Нажмите на любую карточку — перейдёте в нужный раздел.',
          targetKey: _quickCardsKey,
        ),
        TutorialStep(
          icon: Icons.local_shipping_rounded,
          title: 'Последние посылки',
          description:
              'Блок показывает последние треки с текущим статусом. Цветной значок — этап доставки. Нажмите на трек, чтобы увидеть детали.',
          targetKey: _digestKey,
        ),
        TutorialStep(
          icon: Icons.receipt_long_rounded,
          title: 'Счета',
          description:
              'Последние счета на оплату. «Требует оплаты» — посылка ждёт оплаты перед отправкой. «Оплачен» — уже в пути.',
          targetKey: _digestKey,
        ),
        TutorialStep(
          icon: Icons.photo_rounded,
          title: 'Фотоотчёты',
          description:
              'Последние фотографии ваших посылок со склада. Нажмите на фото, чтобы открыть в полном размере.',
          targetKey: _digestKey,
        ),
      ],
      child: RefreshIndicator(
        onRefresh: onRefresh,
        color: context.brandPrimary,
        child: ListView(
          shrinkWrap: true,
          primary: false,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(16, topPad * 0.7 + 16, 16, 0),
          children: [
            _HomeReveal(
              order: 0,
              child: _GreetingBlock(
                fullName: clientName,
                clientCode: clientCode,
                agentName: agent?.name,
                onTap: () => context.push('/profile'),
              ),
            ),
            const SizedBox(height: 15),
            if (staleNotice != null) ...[
              _HomeReveal(
                order: 1,
                child: _StaleDataBanner(
                  message: staleNotice.message,
                  onRefresh: () => unawaited(onRefresh()),
                  onDismiss: () =>
                      ref.read(staleDataNoticeProvider.notifier).clear(),
                ),
              ),
              const SizedBox(height: 15),
            ],
            _HomeReveal(
              order: 2,
              child: KeyedSubtree(
                key: _quickCardsKey,
                child: _StatsBlock(
                  bonusKgValue: _formatKg(bonusKgBalance),
                  bonusKgWeekly: _formatDeltaKg(bonusKgWeekly),
                  tracksValue: _formatCount(tracksCount),
                  tracksWeekly: _formatDeltaCount(tracksWeeklyCount),
                  assembliesValue: _formatCount(assembliesCount),
                  assembliesWeekly: _formatDeltaCount(assembliesWeeklyCount),
                  invoicesValue: _formatCount(invoicesCount),
                  invoicesWeekly: _formatDeltaCount(invoicesWeeklyCount),
                  onTracksTap: () => context.go('/tracks'),
                  onAssembliesTap: () => context.go('/tracks'),
                  onBonusKgTap: () => context.push('/referral'),
                  onInvoicesTap: () => context.go('/invoices'),
                  onAddTracksTap: () => showAddTracksDialog(context, ref),
                ),
              ),
            ),
            const SizedBox(height: 15),
            if (agent?.hasHomeBanner == true) ...[
              _HomeReveal(order: 3, child: _PromoSlider(agent: agent!)),
              const SizedBox(height: 15),
            ],
            if (agent?.hasWarehouseContacts == true) ...[
              _HomeReveal(
                order: 4,
                child: _WarehouseDataBlock(
                  clientCode: clientCode,
                  agent: agent!,
                ),
              ),
              const SizedBox(height: 15),
            ],
            _HomeReveal(
              order: 5,
              child: _NoCodeSearchCard(
                controller: _noCodeSearchController,
                onSearch: _openNoCodeSearch,
              ),
            ),
            const SizedBox(height: 15),
            _HomeReveal(
              order: 6,
              child: KeyedSubtree(
                key: _digestKey,
                child: _DigestBlock(
                  tracksAsync: tracksDigestAsync,
                  assembliesAsync: assembliesDigestAsync,
                  invoicesAsync: invoicesDigestAsync,
                  photosAsync: recentPhotosAsync,
                  onTrackTap: (track) {
                    final params = <String, String>{
                      if (track.id != null) 'trackId': track.id.toString(),
                      'trackCode': track.code,
                    };
                    context.go(
                      Uri(path: '/tracks', queryParameters: params).toString(),
                    );
                  },
                  onAssemblyTap: (assembly) {
                    context.go(
                      Uri(
                        path: '/tracks',
                        queryParameters: {'assemblyId': assembly.id.toString()},
                      ).toString(),
                    );
                  },
                  onInvoiceTap: (invoice) {
                    context.go(
                      Uri(
                        path: '/invoices',
                        queryParameters: {'invoiceId': invoice.id},
                      ).toString(),
                    );
                  },
                  onPhotoTap: (photo) {
                    Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute<void>(
                        fullscreenDialog: true,
                        builder: (_) => PhotoViewerScreen(item: photo),
                      ),
                    );
                  },
                ),
              ),
            ),
            SizedBox(height: bottomContentGap),
          ],
        ),
      ),
    );
  }
}

double _weeklyBonusKg(ReferralData data) {
  final weekStart = DateTime.now().subtract(const Duration(days: 7));
  return data.transactions
      .where(
        (transaction) =>
            !transaction.createdAt.isBefore(weekStart) &&
            transaction.kgAmount > 0 &&
            (transaction.type == 'earned' ||
                transaction.type == 'referee_bonus'),
      )
      .fold<double>(0, (sum, transaction) => sum + transaction.kgAmount);
}

String _formatCount(int? value) {
  if (value == null) return '–';
  return NumberFormat.decimalPattern('ru_RU').format(value);
}

String _formatDeltaCount(int? value) {
  if (value == null) return '–';
  return '+${_formatCount(value)}';
}

String _formatKg(double? value) {
  if (value == null) return '–';
  final fixed = value.toStringAsFixed(2);
  return fixed.replaceFirst(RegExp(r'\.?0+$'), '');
}

String _formatDeltaKg(double? value) {
  if (value == null) return '–';
  return '+${_formatKg(value)}';
}

class _HomeReveal extends StatefulWidget {
  final int order;
  final Widget child;

  const _HomeReveal({required this.order, required this.child});

  @override
  State<_HomeReveal> createState() => _HomeRevealState();
}

class _HomeRevealState extends State<_HomeReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    final curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _opacity = Tween<double>(begin: 0, end: 1).animate(curve);
    _offset = Tween<Offset>(
      begin: const Offset(0, 0.045),
      end: Offset.zero,
    ).animate(curve);

    Future<void>.delayed(Duration(milliseconds: 55 * widget.order), () {
      if (!mounted) return;
      _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _offset, child: widget.child),
    );
  }
}

class _StaleDataBanner extends StatelessWidget {
  const _StaleDataBanner({
    required this.message,
    required this.onRefresh,
    required this.onDismiss,
  });

  final String message;
  final VoidCallback onRefresh;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    const warning = Color(0xFFF59E0B);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: warning.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(Icons.sync_problem_rounded, color: warning, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Данные могут быть не свежими',
                    style: TextStyle(
                      color: Color(0xFF7C2D12),
                      fontFamily: 'Gilroy',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    message,
                    style: const TextStyle(
                      color: Color(0xFF9A3412),
                      fontFamily: 'Gilroy',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: 1.25,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: onRefresh,
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF9A3412),
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text(
                      'Обновить',
                      style: TextStyle(
                        fontFamily: 'Gilroy',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onDismiss,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              icon: const Icon(
                Icons.close_rounded,
                color: Color(0xFF9A3412),
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GreetingBlock extends StatelessWidget {
  final String fullName;
  final String clientCode;
  final String? agentName;
  final VoidCallback onTap;

  const _GreetingBlock({
    required this.fullName,
    required this.clientCode,
    required this.agentName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final greeting = _greetingFor(DateTime.now());
    final agentLabel = agentName?.trim();
    final radius = BorderRadius.circular(24);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Semantics(
        button: true,
        label: 'Открыть профиль',
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            splashColor: Colors.white.withValues(alpha: 0.08),
            highlightColor: Colors.white.withValues(alpha: 0.04),
            child: Ink(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    context.brandPrimary.withValues(alpha: 0.98),
                    context.brandSecondary.withValues(alpha: 0.9),
                  ],
                ),
                borderRadius: radius,
                boxShadow: [
                  BoxShadow(
                    color: context.brandPrimary.withValues(alpha: 0.22),
                    offset: const Offset(0, 14),
                    blurRadius: 32,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: radius,
                child: Stack(
                  children: [
                    const Positioned.fill(child: _HeaderGlowBackdrop()),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      greeting,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.86,
                                        ),
                                        fontFamily: 'Gilroy',
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        height: 1.2,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    SizedBox(
                                      height: 34,
                                      child: _OverflowMarqueeText(
                                        text: fullName,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontFamily: 'Gilroy',
                                          fontSize: 28,
                                          fontWeight: FontWeight.w900,
                                          height: 34 / 28,
                                          letterSpacing: -0.4,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              const _PulsingHeaderIcon(),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _HeaderInfoPill(
                                icon: Icons.badge_rounded,
                                label: 'Код $clientCode',
                              ),
                              if (agentLabel != null && agentLabel.isNotEmpty)
                                _HeaderInfoPill(
                                  icon: Icons.apartment_rounded,
                                  label: agentLabel,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _greetingFor(DateTime now) {
    final h = now.hour;
    if (h >= 5 && h < 12) return 'Доброе утро';
    if (h >= 12 && h < 17) return 'Добрый день';
    if (h >= 17 && h < 23) return 'Добрый вечер';
    return 'Доброй ночи';
  }
}

class _HeaderInfoPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeaderInfoPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 190),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'Gilroy',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderGlowBackdrop extends StatefulWidget {
  const _HeaderGlowBackdrop();

  @override
  State<_HeaderGlowBackdrop> createState() => _HeaderGlowBackdropState();
}

class _HeaderGlowBackdropState extends State<_HeaderGlowBackdrop>
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
                    child: _HeaderGlowCircle(
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
                    child: _HeaderGlowCircle(
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
                    child: _HeaderGlowCircle(
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

class _HeaderGlowCircle extends StatelessWidget {
  final double size;
  final Color color;

  const _HeaderGlowCircle({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

class _PulsingHeaderIcon extends StatefulWidget {
  const _PulsingHeaderIcon();

  @override
  State<_PulsingHeaderIcon> createState() => _PulsingHeaderIconState();
}

class _PulsingHeaderIconState extends State<_PulsingHeaderIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _scale = Tween<double>(
      begin: 0.96,
      end: 1.04,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
        ),
        child: const Icon(
          Icons.local_shipping_rounded,
          color: Colors.white,
          size: 25,
        ),
      ),
    );
  }
}

class _OverflowMarqueeText extends StatefulWidget {
  final String text;
  final TextStyle style;

  const _OverflowMarqueeText({required this.text, required this.style});

  @override
  State<_OverflowMarqueeText> createState() => _OverflowMarqueeTextState();
}

class _OverflowMarqueeTextState extends State<_OverflowMarqueeText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double _lastOverflow = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void didUpdateWidget(covariant _OverflowMarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text || oldWidget.style != widget.style) {
      _lastOverflow = 0;
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _syncAnimation(double overflow) {
    if (overflow <= 0) {
      if (_controller.isAnimating || _controller.value != 0) {
        _controller.stop();
        _controller.value = 0;
      }
      return;
    }

    if ((_lastOverflow - overflow).abs() < 0.5 && _controller.isAnimating) {
      return;
    }

    _lastOverflow = overflow;
    final durationMs = (2800 + overflow * 18).clamp(3200, 8000).round();
    _controller.duration = Duration(milliseconds: durationMs);
    _controller.repeat(reverse: true);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final direction = Directionality.of(context);
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: widget.style),
          maxLines: 1,
          textDirection: direction,
        )..layout();
        final textWidth = painter.width;
        final overflow = textWidth - constraints.maxWidth;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _syncAnimation(overflow);
        });

        if (overflow <= 0) {
          return Text(
            widget.text,
            maxLines: 1,
            overflow: TextOverflow.visible,
            softWrap: false,
            style: widget.style,
          );
        }

        return ClipRect(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final eased = Curves.easeInOut.transform(_controller.value);
              return Transform.translate(
                offset: Offset(-overflow * eased, 0),
                child: child,
              );
            },
            child: SizedBox(
              width: textWidth,
              child: Text(
                widget.text,
                maxLines: 1,
                overflow: TextOverflow.visible,
                softWrap: false,
                style: widget.style,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PromoSlider extends StatelessWidget {
  const _PromoSlider({required this.agent});

  final AgentInfo agent;

  static const _textColor = Color(0xFF2F2F2F);
  static const _designWidth = 400.0;
  static const _designHeight = 149.0;
  static const _textBlockWidth = 230.0;

  @override
  Widget build(BuildContext context) {
    final imageUrl = _textOrNull(agent.homeBannerImageUrl);
    final resolvedImageUrl = imageUrl == null
        ? null
        : ApiConfig.getMediaUrl(imageUrl);
    final eyebrow = _textOrNull(agent.homeBannerEyebrow);
    final title = _textOrNull(agent.homeBannerTitle);
    final description = _textOrNull(agent.homeBannerDescription);

    if (imageUrl == null &&
        eyebrow == null &&
        title == null &&
        description == null) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final scale = width / _designWidth;
        final radius = BorderRadius.circular(10 * scale);

        return SizedBox(
          width: width,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              boxShadow: [
                BoxShadow(
                  color: const Color(0x1A000000),
                  offset: Offset(3 * scale, 4 * scale),
                  blurRadius: 25 * scale,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: radius,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: imageUrl == null
                        ? const ColoredBox(color: Color(0xCCFFFFFF))
                        : RepaintBoundary(
                            child: Image.network(
                              resolvedImageUrl!,
                              fit: BoxFit.cover,
                              alignment: Alignment.centerLeft,
                              gaplessPlayback: true,
                              filterQuality: FilterQuality.low,
                              errorBuilder: (_, error, _) {
                                if (kDebugMode) {
                                  debugPrint(
                                    '[Home] Banner image failed: '
                                    '$resolvedImageUrl $error',
                                  );
                                }
                                return const ColoredBox(
                                  color: Color(0xCCFFFFFF),
                                );
                              },
                            ),
                          ),
                  ),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: _designHeight * scale,
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(10 * scale),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (eyebrow != null)
                            SizedBox(
                              width: _textBlockWidth * scale,
                              child: Text(
                                eyebrow,
                                style: TextStyle(
                                  color: _textColor,
                                  fontFamily: 'Gilroy',
                                  fontWeight: FontWeight.w300,
                                  fontSize: 13.6 * scale,
                                  height: 16 / 13.6,
                                  letterSpacing: 0,
                                ),
                              ),
                            ),
                          if (eyebrow != null && title != null)
                            SizedBox(height: 10 * scale),
                          if (title != null)
                            SizedBox(
                              width: _textBlockWidth * scale,
                              child: Text(
                                title,
                                style: TextStyle(
                                  color: _textColor,
                                  fontFamily: 'Gilroy',
                                  fontWeight: FontWeight.w500,
                                  fontSize: 18.6 * scale,
                                  height: 23 / 18.6,
                                  letterSpacing: 0,
                                ),
                              ),
                            ),
                          if ((eyebrow != null || title != null) &&
                              description != null)
                            SizedBox(height: 10 * scale),
                          if (description != null)
                            SizedBox(
                              width: _textBlockWidth * scale,
                              child: Text(
                                description,
                                style: TextStyle(
                                  color: _textColor,
                                  fontFamily: 'Gilroy',
                                  fontWeight: FontWeight.w400,
                                  fontSize: 13.6 * scale,
                                  height: 16 / 13.6,
                                  letterSpacing: 0,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static String? _textOrNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}

class _StatsBlock extends StatelessWidget {
  final String bonusKgValue;
  final String bonusKgWeekly;
  final String tracksValue;
  final String tracksWeekly;
  final String assembliesValue;
  final String assembliesWeekly;
  final String invoicesValue;
  final String invoicesWeekly;
  final VoidCallback onTracksTap;
  final VoidCallback onAssembliesTap;
  final VoidCallback onBonusKgTap;
  final VoidCallback onInvoicesTap;
  final VoidCallback onAddTracksTap;

  const _StatsBlock({
    required this.bonusKgValue,
    required this.bonusKgWeekly,
    required this.tracksValue,
    required this.tracksWeekly,
    required this.assembliesValue,
    required this.assembliesWeekly,
    required this.invoicesValue,
    required this.invoicesWeekly,
    required this.onTracksTap,
    required this.onAssembliesTap,
    required this.onBonusKgTap,
    required this.onInvoicesTap,
    required this.onAddTracksTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AddTracksStatCard(onTap: onAddTracksTap),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                title: 'Треки',
                value: tracksValue,
                weeklyValue: tracksWeekly,
                icon: Icons.local_shipping_rounded,
                onTap: onTracksTap,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatCard(
                title: 'Сборки',
                value: assembliesValue,
                weeklyValue: assembliesWeekly,
                icon: Icons.inventory_2_rounded,
                onTap: onAssembliesTap,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                title: 'Бонусные кг',
                value: bonusKgValue,
                weeklyValue: bonusKgWeekly,
                icon: Icons.scale_rounded,
                onTap: onBonusKgTap,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatCard(
                title: 'Счета',
                value: invoicesValue,
                weeklyValue: invoicesWeekly,
                icon: Icons.receipt_long_rounded,
                onTap: onInvoicesTap,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String weeklyValue;
  final IconData icon;
  final VoidCallback? onTap;

  const _StatCard({
    required this.title,
    required this.value,
    required this.weeklyValue,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      constraints: const BoxConstraints(minHeight: 102),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            offset: const Offset(0, 8),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: context.brandPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: context.brandPrimary, size: 18),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontFamily: 'Gilroy',
                    fontWeight: FontWeight.w700,
                    fontSize: 12.3,
                    height: 1.15,
                  ),
                ),
              ),
              if (onTap != null)
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSecondary.withValues(alpha: 0.8),
                  size: 19,
                ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontFamily: 'Gilroy',
                fontWeight: FontWeight.w900,
                fontSize: 25,
                height: 0.95,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.trending_up_rounded,
                  size: 13,
                  color: context.brandPrimary,
                ),
                const SizedBox(width: 3),
                Text(
                  '$weeklyValue за неделю',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontFamily: 'Gilroy',
                    fontWeight: FontWeight.w700,
                    fontSize: 10.5,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: card,
      ),
    );
  }
}

class _AddTracksStatCard extends StatelessWidget {
  final VoidCallback onTap;

  const _AddTracksStatCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 78),
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            gradient: context.brandGradient,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: context.brandPrimary.withValues(alpha: 0.24),
                offset: const Offset(0, 12),
                blurRadius: 28,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.22),
                  ),
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Добавить треки',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Gilroy',
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        height: 1.1,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Вставьте номера — мы начнём отслеживание',
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
              const SizedBox(width: 10),
              const _NudgingArrowIcon(),
            ],
          ),
        ),
      ),
    );
  }
}

class _NudgingArrowIcon extends StatefulWidget {
  const _NudgingArrowIcon();

  @override
  State<_NudgingArrowIcon> createState() => _NudgingArrowIconState();
}

class _NudgingArrowIconState extends State<_NudgingArrowIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat(reverse: true);
    _offset = Tween<double>(begin: 0, end: 5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _offset,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_offset.value, 0),
          child: child,
        );
      },
      child: const Icon(
        Icons.arrow_forward_rounded,
        color: Colors.white,
        size: 24,
      ),
    );
  }
}

class _WarehouseDataBlock extends StatelessWidget {
  final String clientCode;
  final AgentInfo agent;

  const _WarehouseDataBlock({required this.clientCode, required this.agent});

  @override
  Widget build(BuildContext context) {
    final address = _warehouseAddressForClient(agent.warehouseAddress);
    final phone = agent.warehousePhone?.trim() ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            offset: const Offset(0, 10),
            blurRadius: 26,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: context.brandPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.warehouse_rounded,
                  color: context.brandPrimary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Склад и маркировка',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontFamily: 'Gilroy',
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                        height: 1.15,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Скопируйте данные для отправки товара',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textSecondary,
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
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
            ),
            child: Row(
              children: [
                Icon(Icons.qr_code_2_rounded, color: context.brandPrimary),
                const SizedBox(width: 9),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(text: 'Код клиента: '),
                        TextSpan(
                          text: clientCode,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontFamily: 'Gilroy',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (address.isNotEmpty || phone.isNotEmpty) ...[
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                final useStack = constraints.maxWidth < 340;
                final children = <Widget>[
                  if (address.isNotEmpty)
                    _WarehouseCopyButton(
                      label: 'Адрес склада',
                      icon: CupertinoIcons.doc_on_doc,
                      value: address,
                    ),
                  if (phone.isNotEmpty)
                    _WarehouseCopyButton(
                      label: 'Телефон склада',
                      icon: CupertinoIcons.phone,
                      value: phone,
                    ),
                ];

                if (useStack || children.length == 1) {
                  return Column(
                    children: [
                      for (var i = 0; i < children.length; i++) ...[
                        if (i > 0) const SizedBox(height: 8),
                        children[i],
                      ],
                    ],
                  );
                }

                return Row(
                  children: [
                    for (var i = 0; i < children.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(child: children[i]),
                    ],
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  String _warehouseAddressForClient(String? rawAddress) {
    final base = (rawAddress ?? '')
        .replaceFirst(RegExp(r'\s*\(不要隐藏代码\s*[^)]*\)\s*$'), '')
        .trim();
    if (base.isEmpty) return '';
    return '$base(不要隐藏代码 $clientCode)';
  }
}

class _WarehouseCopyButton extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;

  const _WarehouseCopyButton({
    required this.label,
    required this.icon,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.brandPrimary.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () => _copyValue(context),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(
              color: context.brandPrimary.withValues(alpha: 0.12),
            ),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: context.brandPrimary, size: 17),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.brandPrimary,
                    fontFamily: 'Gilroy',
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                    height: 1.1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _copyValue(BuildContext context) async {
    final copied = await AppClipboard.copyText(value);
    if (!context.mounted) return;
    if (!copied) {
      _showStyledSnackBar(context, 'Не удалось скопировать', isError: true);
      return;
    }
    HapticFeedback.selectionClick();
    _showStyledSnackBar(context, 'Текст скопирован');
  }
}

class _NoCodeSearchCard extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSearch;

  const _NoCodeSearchCard({required this.controller, required this.onSearch});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, 8),
            blurRadius: 22,
          ),
        ],
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
                  color: context.brandPrimary.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  Icons.manage_search_rounded,
                  color: context.brandPrimary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Поиск трека без кода',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontFamily: 'Gilroy',
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        height: 1.15,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Если склад ещё не привязал посылку к вашему коду',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontFamily: 'Gilroy',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.15,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  textInputAction: TextInputAction.search,
                  autocorrect: false,
                  enableSuggestions: false,
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontFamily: 'Gilroy',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Трек-номер',
                    hintStyle: TextStyle(
                      color: AppColors.textSecondary.withValues(alpha: 0.72),
                      fontFamily: 'Gilroy',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: context.brandPrimary,
                      size: 20,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide(
                        color: Colors.black.withValues(alpha: 0.05),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide(
                        color: Colors.black.withValues(alpha: 0.05),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide(
                        color: context.brandPrimary.withValues(alpha: 0.55),
                        width: 1.4,
                      ),
                    ),
                  ),
                  onSubmitted: (_) => onSearch(),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: onSearch,
                  style: FilledButton.styleFrom(
                    backgroundColor: context.brandPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Найти',
                    style: TextStyle(
                      fontFamily: 'Gilroy',
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _DigestTab {
  tracks('Треки', Icons.local_shipping_rounded),
  assemblies('Сборки', Icons.inventory_2_rounded),
  invoices('Счета', Icons.receipt_long_rounded),
  photos('Фото', Icons.photo_library_rounded);

  final String label;
  final IconData icon;

  const _DigestTab(this.label, this.icon);
}

class _DigestBlock extends StatefulWidget {
  final AsyncValue<List<TrackItem>> tracksAsync;
  final AsyncValue<List<AssemblyItem>> assembliesAsync;
  final AsyncValue<List<InvoiceItem>> invoicesAsync;
  final AsyncValue<List<PhotoItem>> photosAsync;
  final ValueChanged<TrackItem> onTrackTap;
  final ValueChanged<AssemblyItem> onAssemblyTap;
  final ValueChanged<InvoiceItem> onInvoiceTap;
  final ValueChanged<PhotoItem> onPhotoTap;

  const _DigestBlock({
    required this.tracksAsync,
    required this.assembliesAsync,
    required this.invoicesAsync,
    required this.photosAsync,
    required this.onTrackTap,
    required this.onAssemblyTap,
    required this.onInvoiceTap,
    required this.onPhotoTap,
  });

  @override
  State<_DigestBlock> createState() => _DigestBlockState();
}

class _DigestBlockState extends State<_DigestBlock> {
  _DigestTab _selected = _DigestTab.tracks;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            offset: const Offset(0, 10),
            blurRadius: 26,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Последние обновления',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontFamily: 'Gilroy',
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        height: 1.15,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Треки, сборки, счета и фото в одном месте',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontFamily: 'Gilroy',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        height: 1.15,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          _DigestTabBar(
            selected: _selected,
            onChanged: (tab) => setState(() => _selected = tab),
          ),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: KeyedSubtree(
              key: ValueKey(_selected),
              child: switch (_selected) {
                _DigestTab.tracks => _TrackDigestList(
                  itemsAsync: widget.tracksAsync,
                  onTap: widget.onTrackTap,
                ),
                _DigestTab.assemblies => _AssemblyDigestList(
                  itemsAsync: widget.assembliesAsync,
                  onTap: widget.onAssemblyTap,
                ),
                _DigestTab.invoices => _InvoiceDigestList(
                  itemsAsync: widget.invoicesAsync,
                  onTap: widget.onInvoiceTap,
                ),
                _DigestTab.photos => _PhotoDigestGrid(
                  itemsAsync: widget.photosAsync,
                  onTap: widget.onPhotoTap,
                ),
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DigestTabBar extends StatelessWidget {
  final _DigestTab selected;
  final ValueChanged<_DigestTab> onChanged;

  const _DigestTabBar({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          for (var i = 0; i < _DigestTab.values.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            _DigestTabButton(
              tab: _DigestTab.values[i],
              selected: selected == _DigestTab.values[i],
              onTap: () => onChanged(_DigestTab.values[i]),
            ),
          ],
        ],
      ),
    );
  }
}

class _DigestTabButton extends StatelessWidget {
  final _DigestTab tab;
  final bool selected;
  final VoidCallback onTap;

  const _DigestTabButton({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : AppColors.textPrimary;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 170),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? context.brandPrimary : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? context.brandPrimary
                  : Colors.black.withValues(alpha: 0.04),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(tab.icon, size: 16, color: foreground),
              const SizedBox(width: 6),
              Text(
                tab.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: foreground,
                  fontFamily: 'Gilroy',
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrackDigestList extends StatelessWidget {
  final AsyncValue<List<TrackItem>> itemsAsync;
  final ValueChanged<TrackItem> onTap;

  const _TrackDigestList({required this.itemsAsync, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return itemsAsync.when(
      loading: () => const _DigestStateCard(child: CircularProgressIndicator()),
      error: (e, _) => _DigestStateCard(
        child: Text(
          'Не удалось загрузить треки: $e',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.red),
        ),
      ),
      data: (items) {
        final top = items.take(10).toList(growable: false);
        if (top.isEmpty) {
          return const _DigestStateCard(child: Text('Пока нет треков.'));
        }

        return _DigestListColumn(
          children: [
            for (final track in top)
              _DigestItemCard(
                icon: Icons.local_shipping_rounded,
                title: track.code,
                createdAt: track.createdAt,
                updatedAt: track.updatedAt,
                statusText: track.status,
                statusColor: _statusColor(track.statusColor),
                markers: _TrackDigestMarkers(track: track),
                onTap: () => onTap(track),
              ),
          ],
        );
      },
    );
  }
}

class _AssemblyDigestList extends StatelessWidget {
  final AsyncValue<List<AssemblyItem>> itemsAsync;
  final ValueChanged<AssemblyItem> onTap;

  const _AssemblyDigestList({required this.itemsAsync, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return itemsAsync.when(
      loading: () => const _DigestStateCard(child: CircularProgressIndicator()),
      error: (e, _) => _DigestStateCard(
        child: Text(
          'Не удалось загрузить сборки: $e',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.red),
        ),
      ),
      data: (items) {
        final top = items.take(10).toList(growable: false);
        if (top.isEmpty) {
          return const _DigestStateCard(child: Text('Пока нет сборок.'));
        }

        return _DigestListColumn(
          children: [
            for (final assembly in top)
              _DigestItemCard(
                icon: Icons.inventory_2_rounded,
                title: assembly.number,
                createdAt: assembly.createdAt,
                updatedAt: assembly.updatedAt,
                statusText: assembly.status,
                statusColor: _statusColor(assembly.statusColor),
                onTap: () => onTap(assembly),
              ),
          ],
        );
      },
    );
  }
}

class _InvoiceDigestList extends StatelessWidget {
  final AsyncValue<List<InvoiceItem>> itemsAsync;
  final ValueChanged<InvoiceItem> onTap;

  const _InvoiceDigestList({required this.itemsAsync, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return itemsAsync.when(
      loading: () => const _DigestStateCard(child: CircularProgressIndicator()),
      error: (e, _) => _DigestStateCard(
        child: Text(
          'Не удалось загрузить счета: $e',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.red),
        ),
      ),
      data: (items) {
        final top = items.take(10).toList(growable: false);
        if (top.isEmpty) {
          return const _DigestStateCard(child: Text('Пока нет счетов.'));
        }

        return _DigestListColumn(
          children: [
            for (final invoice in top)
              _DigestItemCard(
                icon: Icons.receipt_long_rounded,
                title: invoice.invoiceNumber,
                createdAt: invoice.createdAt,
                updatedAt: invoice.updatedAt ?? invoice.sendDate,
                statusText: invoice.statusName ?? invoice.status,
                statusColor: _statusColor(invoice.statusColor),
                onTap: () => onTap(invoice),
              ),
          ],
        );
      },
    );
  }
}

class _PhotoDigestGrid extends StatelessWidget {
  final AsyncValue<List<PhotoItem>> itemsAsync;
  final ValueChanged<PhotoItem> onTap;

  const _PhotoDigestGrid({required this.itemsAsync, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return itemsAsync.when(
      loading: () => const _DigestStateCard(child: CircularProgressIndicator()),
      error: (e, _) => _DigestStateCard(
        child: Text(
          'Не удалось загрузить фото: $e',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.red),
        ),
      ),
      data: (items) {
        final top = items.take(12).toList(growable: false);
        if (top.isEmpty) {
          return const _DigestStateCard(child: Text('Пока нет фотоотчётов.'));
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final tileSize = (constraints.maxWidth - 16) / 3;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in top)
                  SizedBox(
                    width: tileSize,
                    height: tileSize,
                    child: _PhotoThumb(item: item, onOpen: () => onTap(item)),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class _DigestListColumn extends StatelessWidget {
  final List<Widget> children;

  const _DigestListColumn({required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: 5),
          children[i],
        ],
      ],
    );
  }
}

class _DigestItemCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String statusText;
  final Color? statusColor;
  final Widget? markers;
  final VoidCallback onTap;

  const _DigestItemCard({
    required this.icon,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.statusText,
    required this.statusColor,
    required this.onTap,
    this.markers,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 76),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.black.withValues(alpha: 0.035)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: (statusColor ?? context.brandPrimary).withValues(
                    alpha: 0.14,
                  ),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  icon,
                  color: statusColor ?? context.brandPrimary,
                  size: 21,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontFamily: 'Gilroy',
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        _DigestDateLabel(
                          icon: CupertinoIcons.plus_circle,
                          value: _formatDigestDate(createdAt),
                        ),
                        _DigestDateLabel(
                          icon: CupertinoIcons.arrow_2_circlepath_circle,
                          value: _formatDigestDate(updatedAt),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _DigestStatusPill(text: statusText, color: statusColor),
                  if (markers != null) ...[const SizedBox(height: 8), markers!],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DigestDateLabel extends StatelessWidget {
  final IconData icon;
  final String value;

  const _DigestDateLabel({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontFamily: 'Gilroy',
            fontSize: 12,
            fontWeight: FontWeight.w700,
            height: 1.1,
          ),
        ),
      ],
    );
  }
}

class _DigestStatusPill extends StatelessWidget {
  final String text;
  final Color? color;

  const _DigestStatusPill({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    final accent = color ?? context.brandPrimary;
    return Container(
      constraints: const BoxConstraints(maxWidth: 132),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: _readableStatusTextColor(accent),
          fontFamily: 'Gilroy',
          fontSize: 12,
          fontWeight: FontWeight.w900,
          height: 1.1,
        ),
      ),
    );
  }
}

Color _readableStatusTextColor(Color color) {
  final hsl = HSLColor.fromColor(color);
  return hsl.withLightness((hsl.lightness * 0.46).clamp(0.18, 0.38)).toColor();
}

class _TrackDigestMarkers extends StatelessWidget {
  final TrackItem track;

  const _TrackDigestMarkers({required this.track});

  @override
  Widget build(BuildContext context) {
    final activePhoto = track.activePhotoRequest;
    final hasPhotoMedia =
        track.photoReportUrls.isNotEmpty ||
        (activePhoto?.mediaUrls.isNotEmpty ?? false);
    final photoDone = hasPhotoMedia || activePhoto?.status == 'completed';
    final photoPending = activePhoto != null && !photoDone;

    final activeQuestion = track.activeQuestion;
    final questionDone =
        activeQuestion?.hasAnswer == true ||
        activeQuestion?.status == 'completed';
    final questionPending = activeQuestion != null && !questionDone;

    final hasProductInfo = track.productInfo != null;

    return SizedBox(
      width: 89,
      height: 24,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _DigestMarkerIcon(
            icon: CupertinoIcons.camera_circle,
            color: _markerColor(
              context,
              done: photoDone,
              pending: photoPending,
            ),
          ),
          const SizedBox(width: 5),
          _DigestMarkerIcon(
            icon: CupertinoIcons.info_circle,
            color: _markerColor(context, done: hasProductInfo, pending: false),
          ),
          const SizedBox(width: 5),
          _DigestMarkerIcon(
            icon: CupertinoIcons.question_circle,
            color: _markerColor(
              context,
              done: questionDone,
              pending: questionPending,
            ),
          ),
        ],
      ),
    );
  }
}

class _DigestMarkerIcon extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _DigestMarkerIcon({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Icon(icon, size: 24, color: color);
  }
}

class _DigestStateCard extends StatelessWidget {
  final Widget child;

  const _DigestStateCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 92),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.035)),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}

String _formatDigestDate(DateTime? value) {
  if (value == null) return '—';
  return DateFormat('dd.MM.yy').format(value);
}

Color? _statusColor(String? hexColor) {
  if (hexColor == null || hexColor.isEmpty) return null;
  try {
    final hex = hexColor.replaceAll('#', '');
    if (hex.length == 6) return Color(int.parse('FF$hex', radix: 16));
    if (hex.length == 8) return Color(int.parse(hex, radix: 16));
  } catch (_) {}
  return null;
}

Color _markerColor(
  BuildContext context, {
  required bool done,
  required bool pending,
}) {
  if (done) return const Color(0xFF22C55E);
  if (pending) return context.brandPrimary;
  return const Color(0x552F2F2F);
}

class _PhotoThumb extends StatelessWidget {
  final PhotoItem item;
  final VoidCallback onOpen;

  const _PhotoThumb({required this.item, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    // RepaintBoundary предотвращает перерисовку при скролле
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onOpen,
            child: AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (item.isVideo)
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.black.withValues(alpha: 0.45),
                              Colors.black.withValues(alpha: 0.15),
                            ],
                          ),
                        ),
                      )
                    else
                      AppCachedMediaImage(
                        url: item.url,
                        thumbnailSize: 360,
                        maxHeightDiskCache: 400,
                        maxWidthDiskCache: 400,
                        memCacheHeight: 200,
                        memCacheWidth: 200,
                        imageBuilder: (_, imageProvider) => DecoratedBox(
                          decoration: BoxDecoration(
                            image: DecorationImage(
                              image: imageProvider,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        placeholder: (_, _) => Container(
                          color: Colors.black.withValues(alpha: 0.06),
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                        errorWidget: (_, _, _) => AppCachedMediaImage(
                          url: item.url,
                          variant: AppMediaImageVariant.full,
                          fit: BoxFit.cover,
                          maxHeightDiskCache: 400,
                          maxWidthDiskCache: 400,
                          memCacheHeight: 200,
                          memCacheWidth: 200,
                          placeholder: (_, _) => Container(
                            color: Colors.black.withValues(alpha: 0.06),
                            child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                          errorWidget: (_, _, _) => Container(
                            color: Colors.black.withValues(alpha: 0.06),
                            child: const Center(
                              child: Icon(Icons.broken_image_outlined),
                            ),
                          ),
                        ),
                      ),
                    if (item.isVideo)
                      const Center(
                        child: Icon(
                          Icons.play_circle_fill_rounded,
                          color: Colors.white,
                          size: 34,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Диалог принятия правил оказания услуг при первом входе
class _TermsAcceptanceDialog extends ConsumerWidget {
  const _TermsAcceptanceDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Получаем название компании из профиля клиента (agent.name)
    final profile = ref.watch(clientProfileProvider);
    final companyName = profile.asData?.value?.agent?.name ?? '2A Logistic';

    return PopScope(
      canPop: false, // Запрещаем закрытие диалога свайпом или кнопкой "назад"
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero, // Убираем отступы по бокам
        child: Container(
          margin: const EdgeInsets.symmetric(
            horizontal: 24,
          ), // Добавляем margin вместо insetPadding
          constraints: const BoxConstraints(maxWidth: 500),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Заголовок с иконкой
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 32,
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: context.brandPrimary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          Icons.description_rounded,
                          size: 48,
                          color: context.brandPrimary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Добро пожаловать!',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1A1A1A),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                // Контент (скроллируемый)
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Прежде чем продолжить',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A1A1A),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Для использования приложения необходимо ознакомиться и принять правила оказания услуг компании $companyName.',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade700,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),

                        // Блок с основными пунктами
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.grey.shade200,
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildInfoItem(
                                icon: Icons.check_circle_outline_rounded,
                                text: 'Условия оказания услуг',
                                color: context.brandPrimary,
                              ),
                              const SizedBox(height: 12),
                              _buildInfoItem(
                                icon: Icons.verified_user_outlined,
                                text: 'Права и обязанности клиентов',
                                color: context.brandPrimary,
                              ),
                              const SizedBox(height: 12),
                              _buildInfoItem(
                                icon: Icons.inventory_2_outlined,
                                text: 'Правила упаковки и маркировки',
                                color: context.brandPrimary,
                              ),
                              const SizedBox(height: 12),
                              _buildInfoItem(
                                icon: Icons.policy_outlined,
                                text: 'Порядок работы и процедуры',
                                color: context.brandPrimary,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Кнопка "Ознакомиться с правилами"
                        OutlinedButton.icon(
                          onPressed: () async {
                            // Открываем правила поверх диалога
                            await context.push('/rules');
                            // После возврата пользователь снова видит диалог
                          },
                          icon: const Icon(Icons.article_outlined, size: 20),
                          label: const Text('Ознакомиться с правилами'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: context.brandPrimary,
                            side: BorderSide(
                              color: context.brandPrimary,
                              width: 2,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Кнопка "Соглашаюсь"
                        FilledButton.icon(
                          onPressed: () async {
                            // Отмечаем что пользователь принял правила
                            final service = ref.read(showcaseServiceProvider);
                            await service.acceptTerms();

                            if (context.mounted) {
                              Navigator.of(context).pop();
                            }
                          },
                          icon: const Icon(Icons.done_rounded, size: 22),
                          label: const Text(
                            'Соглашаюсь',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: context.brandPrimary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 18,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 4,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Мелкий текст
                        Text(
                          'Нажимая кнопку "Соглашаюсь", вы подтверждаете, что ознакомились с правилами оказания услуг и обязуетесь их соблюдать.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            height: 1.4,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
            ),
          ),
        ),
      ],
    );
  }
}
