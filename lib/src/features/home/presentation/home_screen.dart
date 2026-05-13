import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:twoalogisticcabineuser/src/core/ui/app_toast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/network/api_config.dart';
import '../../../core/services/demo_mode_provider.dart';
import '../../../core/services/showcase_service.dart';
import '../../../core/services/update_service.dart';
import '../../../core/ui/app_colors.dart';
import '../../../core/ui/app_layout.dart';
import '../../../core/ui/empty_state.dart';
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

    // После принятия правил — предлагаем пройти обучение
    await _showOnboardingOfferIfNeeded();
  }

  /// Показать предложение пройти обучение (однократно)
  Future<void> _showOnboardingOfferIfNeeded() async {
    if (!mounted) return;
    final showcaseService = ref.read(showcaseServiceProvider);
    if (showcaseService.hasSeenOnboardingOffer) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _OnboardingOfferDialog(),
    );
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

    if (clientCode == null) {
      return const EmptyState(
        icon: Icons.badge_outlined,
        title: 'Выберите код клиента',
        message:
            'Чтобы увидеть данные, сначала выберите или добавьте код клиента.',
      );
    }

    final tracksDigestAsync = ref.watch(tracksDigestProvider(clientCode));
    final assembliesDigestAsync = ref.watch(
      assembliesDigestProvider(clientCode),
    );
    final invoicesDigestAsync = ref.watch(invoicesDigestProvider(clientCode));
    final recentPhotosAsync = ref.watch(
      photosRecentProvider((clientCode: clientCode, limit: 12)),
    );

    final tracksCountAsync = ref.watch(tracksCountProvider(clientCode));
    final assembliesCountAsync = ref.watch(assembliesCountProvider(clientCode));
    final invoicesCountAsync = ref.watch(invoicesCountProvider(clientCode));
    final tracksWeeklyCountAsync = ref.watch(
      tracksWeeklyCountProvider(clientCode),
    );
    final assembliesWeeklyCountAsync = ref.watch(
      assembliesWeeklyCountProvider(clientCode),
    );
    final invoicesWeeklyCountAsync = ref.watch(
      invoicesWeeklyCountProvider(clientCode),
    );
    final referralAsync = ref.watch(referralProvider);

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

    // TODO(redesign): Replace hardcoded balance values when balance backend is ready.
    const balanceValue = '0 ₽';
    const balanceWeekly = '+0';

    final topPad = AppLayout.topBarTotalHeight(context);
    final bottomContentGap = AppLayout.bottomScrollPadding(context) + 16;

    Future<void> onRefresh() async {
      debugPrint('[Home] pull-to-refresh triggered');
      ref.invalidate(clientProfileProvider);
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
        ref.read(clientProfileProvider.future),
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
            _GreetingBlock(fullName: clientName),
            const SizedBox(height: 15),
            if (agent?.hasHomeBanner == true) ...[
              _PromoSlider(agent: agent!),
              const SizedBox(height: 15),
            ],
            KeyedSubtree(
              key: _quickCardsKey,
              child: _StatsBlock(
                balanceValue: balanceValue,
                balanceWeekly: balanceWeekly,
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
                onInvoicesTap: () => context.go('/invoices'),
              ),
            ),
            const SizedBox(height: 15),
            if (agent?.hasWarehouseContacts == true) ...[
              _WarehouseDataBlock(clientCode: clientCode, agent: agent!),
              const SizedBox(height: 15),
            ],
            KeyedSubtree(
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

class _GreetingBlock extends StatelessWidget {
  final String fullName;
  static const _textColor = Color(0xFF2F2F2F);
  static const _nameStyle = TextStyle(
    color: _textColor,
    fontFamily: 'Gilroy',
    fontSize: 33.6,
    fontWeight: FontWeight.bold,
    letterSpacing: 0,
  );

  const _GreetingBlock({required this.fullName});

  @override
  Widget build(BuildContext context) {
    final greeting = _greetingFor(DateTime.now());
    return SizedBox(
      width: double.infinity,
      height: 74,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 153,
            height: 28,
            child: Text(
              greeting,
              maxLines: 1,
              overflow: TextOverflow.visible,
              softWrap: false,
              style: const TextStyle(
                color: _textColor,
                fontFamily: 'Gilroy',
                fontSize: 23.6,
                fontWeight: FontWeight.w400,
                letterSpacing: 0,
              ),
            ),
          ),
          const SizedBox(height: 5),
          SizedBox(
            width: double.infinity,
            height: 41,
            child: _OverflowMarqueeText(text: fullName, style: _nameStyle),
          ),
        ],
      ),
    );
  }

  String _greetingFor(DateTime now) {
    final h = now.hour;
    if (h >= 5 && h < 12) return 'Доброе утро!';
    if (h >= 12 && h < 17) return 'Добрый день!';
    if (h >= 17 && h < 23) return 'Добрый вечер!';
    return 'Доброй ночи!';
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
  static const _designHeight = 132.0;
  static const _textBlockWidth = 218.5;

  @override
  Widget build(BuildContext context) {
    final imageUrl = _textOrNull(agent.homeBannerImageUrl);
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
                        : CachedNetworkImage(
                            imageUrl: ApiConfig.getMediaUrl(imageUrl),
                            fit: BoxFit.cover,
                            alignment: Alignment.centerLeft,
                            errorWidget: (_, _, _) =>
                                const ColoredBox(color: Color(0xCCFFFFFF)),
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
                                  fontSize: 16.6 * scale,
                                  height: 20 / 16.6,
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
  final String balanceValue;
  final String balanceWeekly;
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
  final VoidCallback onInvoicesTap;

  const _StatsBlock({
    required this.balanceValue,
    required this.balanceWeekly,
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
    required this.onInvoicesTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                title: 'Депозит',
                value: balanceValue,
                weeklyValue: balanceWeekly,
                icon: Icons.account_balance_wallet_rounded,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                title: 'Бонусные КГ',
                value: bonusKgValue,
                weeklyValue: bonusKgWeekly,
                icon: Icons.scale_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
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
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                title: 'Сборки',
                value: assembliesValue,
                weeklyValue: assembliesWeekly,
                icon: Icons.inventory_2_rounded,
                onTap: onAssembliesTap,
              ),
            ),
            const SizedBox(width: 10),
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

  static const _textColor = Color(0xFF2F2F2F);

  @override
  Widget build(BuildContext context) {
    final card = Container(
      height: 90,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            offset: Offset(3, 4),
            blurRadius: 25,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 18,
            child: Row(
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: context.brandPrimary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, color: Colors.white, size: 13),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _textColor,
                      fontFamily: 'Gilroy',
                      fontWeight: FontWeight.w700,
                      fontSize: 14.6,
                      height: 18 / 14.6,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 31,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 1,
                style: const TextStyle(
                  color: _textColor,
                  fontFamily: 'Gilroy',
                  fontWeight: FontWeight.w900,
                  fontSize: 24.6,
                  height: 31 / 24.6,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
          SizedBox(
            height: 14,
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    weeklyValue,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _textColor,
                      fontFamily: 'Gilroy',
                      fontWeight: FontWeight.w400,
                      fontSize: 11.6,
                      height: 14 / 11.6,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                const Text(
                  'за неделю',
                  maxLines: 1,
                  style: TextStyle(
                    color: _textColor,
                    fontFamily: 'Gilroy',
                    fontWeight: FontWeight.w400,
                    fontSize: 11.6,
                    height: 14 / 11.6,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return card;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: card,
    );
  }
}

class _WarehouseDataBlock extends StatelessWidget {
  final String clientCode;
  final AgentInfo agent;

  const _WarehouseDataBlock({required this.clientCode, required this.agent});

  static const _textColor = Color(0xFF2F2F2F);

  @override
  Widget build(BuildContext context) {
    final address = _warehouseAddressForClient(agent.warehouseAddress);
    final phone = agent.warehousePhone?.trim() ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            offset: Offset(3, 4),
            blurRadius: 25,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Данные склада',
            style: TextStyle(
              color: _textColor,
              fontFamily: 'Gilroy',
              fontWeight: FontWeight.w600,
              fontSize: 18,
              height: 22 / 18,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 10),
          if (address.isNotEmpty) ...[
            _WarehouseCopyLine(label: 'Адрес:', value: address),
            if (phone.isNotEmpty) const SizedBox(height: 5),
          ],
          if (phone.isNotEmpty)
            _WarehouseCopyLine(label: 'Телефон:', value: phone),
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

class _WarehouseCopyLine extends StatelessWidget {
  final String label;
  final String value;

  const _WarehouseCopyLine({required this.label, required this.value});

  static const _textColor = Color(0xFF2F2F2F);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _copyValue(context),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
            color: _textColor,
            fontFamily: 'Gilroy',
            fontSize: 14,
            height: 16 / 14,
            letterSpacing: 0,
          ),
          children: [
            TextSpan(
              text: '$label ',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(fontWeight: FontWeight.w400),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copyValue(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    HapticFeedback.selectionClick();
    _showStyledSnackBar(context, 'Текст скопирован');
  }
}

enum _DigestTab {
  tracks('Треки'),
  assemblies('Сборки'),
  invoices('Счета'),
  photos('Фотоотчеты');

  final String label;

  const _DigestTab(this.label);
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Последние обновления',
          style: TextStyle(
            color: Color(0xFF000000),
            fontFamily: 'Gilroy',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            height: 22 / 18,
          ),
        ),
        const SizedBox(height: 6),
        _DigestTabBar(
          selected: _selected,
          onChanged: (tab) => setState(() => _selected = tab),
        ),
        const SizedBox(height: 8),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
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
    );
  }
}

class _DigestTabBar extends StatelessWidget {
  final _DigestTab selected;
  final ValueChanged<_DigestTab> onChanged;

  const _DigestTabBar({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            offset: const Offset(3, 4),
            blurRadius: 25,
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final buttons = _DigestTab.values
              .map(
                (tab) => _DigestTabButton(
                  tab: tab,
                  selected: selected == tab,
                  onTap: () => onChanged(tab),
                ),
              )
              .toList(growable: false);

          if (constraints.maxWidth < 360) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(children: buttons),
            );
          }

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: buttons,
          );
        },
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
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            gradient: selected
                ? RadialGradient(
                    colors: [context.brandPrimary, context.brandSecondary],
                    center: Alignment.center,
                    radius: 0.9,
                  )
                : null,
            color: selected ? null : Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            tab.label,
            maxLines: 1,
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xFF2F2F2F),
              fontFamily: 'Gilroy',
              fontSize: 17,
              fontWeight: FontWeight.w400,
              height: 20 / 17,
            ),
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
            final tileSize = (constraints.maxWidth - 10) / 3;
            return Wrap(
              spacing: 5,
              runSpacing: 5,
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
  final String title;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String statusText;
  final Color? statusColor;
  final Widget? markers;
  final VoidCallback onTap;

  const _DigestItemCard({
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
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 60),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                          color: Color(0xFF2F2F2F),
                          fontFamily: 'Gilroy',
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          height: 24 / 16,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Opacity(
                        opacity: 0.5,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 2,
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
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 89,
                    maxWidth: 156,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _DigestStatusPill(text: statusText, color: statusColor),
                      if (markers != null) ...[
                        const SizedBox(height: 6),
                        markers!,
                      ],
                    ],
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
        Icon(icon, size: 24, color: const Color(0xFF2F2F2F)),
        const SizedBox(width: 5),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF2F2F2F),
            fontFamily: 'Gilroy',
            fontSize: 16,
            fontWeight: FontWeight.w400,
            height: 24 / 16,
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
    final bg = color ?? const Color(0xFFB8E1C8);
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 89, maxWidth: 156),
      child: Container(
        height: 22,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            text,
            maxLines: 1,
            softWrap: false,
            style: const TextStyle(
              color: Color(0xFF2F2F2F),
              fontFamily: 'Gilroy',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 16 / 14,
            ),
          ),
        ),
      ),
    );
  }
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
      constraints: const BoxConstraints(minHeight: 60),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
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
                      CachedNetworkImage(
                        imageUrl: ApiConfig.getMediaUrl(item.url),
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
                        errorWidget: (_, _, _) => Container(
                          color: Colors.black.withValues(alpha: 0.06),
                          child: const Center(
                            child: Icon(Icons.broken_image_outlined),
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

/// Диалог предложения пройти обучение
class _OnboardingOfferDialog extends ConsumerWidget {
  const _OnboardingOfferDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
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
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Иконка
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.brandPrimary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    Icons.school_rounded,
                    size: 48,
                    color: context.brandPrimary,
                  ),
                ),
                const SizedBox(height: 20),

                // Заголовок
                const Text(
                  'Пройти обучение?',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1A1A1A),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),

                // Описание
                Text(
                  'Мы покажем, как пользоваться приложением: отслеживать треки, работать со счетами и многое другое.',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey.shade600,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),

                // Кнопка "Да"
                FilledButton(
                  onPressed: () async {
                    final svc = ref.read(showcaseServiceProvider);
                    await svc.markOnboardingOffered();
                    ref.read(demoModeProvider.notifier).enable();
                    if (context.mounted) {
                      Navigator.of(context).pop(true);
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: context.brandPrimary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Да, пройти обучение',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 12),

                // Кнопка "Нет"
                TextButton(
                  onPressed: () async {
                    final svc = ref.read(showcaseServiceProvider);
                    await svc.markOnboardingOffered();
                    if (context.mounted) {
                      Navigator.of(context).pop(false);
                    }
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey.shade600,
                    minimumSize: const Size(double.infinity, 48),
                  ),
                  child: const Text(
                    'Нет, пропустить',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
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
