import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:twoalogisticcabineuser/src/core/ui/app_toast.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/ui/scroll_to_top_button.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:twoalogisticcabineuser/src/core/ui/blurred_modal_bottom_sheet.dart';
import '../../../core/network/api_client.dart';
import '../../../core/ui/app_layout.dart';
import '../../../core/ui/tutorial_card.dart';
import '../../../core/ui/empty_state.dart';
import '../../../core/ui/sheet_handle.dart';
import '../../../core/ui/status_timeline_sheet.dart';
import '../../../core/ui/app_colors.dart';
import '../../../core/ui/app_input_decoration.dart';
import '../../../core/network/api_config.dart';
import '../../../core/utils/clipboard_helper.dart';
import '../../../core/utils/locale_text.dart';
import '../../payments/presentation/bank_qr_payment_screen.dart';
import '../../../core/utils/error_utils.dart';
import '../../clients/application/client_codes_controller.dart';
import '../../photos/domain/photo_item.dart';
import '../../photos/presentation/photo_viewer_screen.dart';
import '../../referral/data/referral_provider.dart';
import '../../shell/application/shell_branch_provider.dart';
import '../data/invoices_provider.dart';
import '../domain/invoice_item.dart';

String _localizeMarket(String market) {
  switch (market.trim()) {
    case '19公里':
      return 'Южные ворота';
    case '柳布利诺':
      return 'Люблино';
    default:
      return market;
  }
}

List<StatusTimelineStatus> _invoiceTimelineStatuses(
  List<InvoiceStatus> statuses,
) {
  return statuses
      .map(
        (status) => StatusTimelineStatus(
          code: status.code,
          name: status.nameRu.isNotEmpty ? status.nameRu : status.code,
          color: _parseHexColor(status.color),
          sortOrder: status.sortOrder,
        ),
      )
      .toList(growable: false);
}

/// Парсит HEX цвет из строки
Color? _parseHexColor(String? hexString) {
  if (hexString == null || hexString.isEmpty) return null;
  try {
    String hex = hexString.replaceAll('#', '');
    if (hex.length == 6) {
      hex = 'FF$hex';
    }
    return Color(int.parse(hex, radix: 16));
  } catch (_) {
    return null;
  }
}

String _formatUsdAmount(num value, {bool withCents = false}) {
  final money = NumberFormat.decimalPattern('ru');
  if (withCents) {
    return '\$${value.toStringAsFixed(2)}';
  }
  return '\$${money.format(value.round())}';
}

Future<bool> _requestInvoicePaymentStatus(
  BuildContext context,
  WidgetRef ref,
  InvoiceItem item,
) async {
  final apiClient = ref.read(apiClientProvider);
  final activeCode = ref.read(activeClientCodeProvider);

  void invalidateInvoiceData() {
    if (activeCode != null) {
      ref.invalidate(invoicesListProvider(activeCode));
      ref.invalidate(invoicesDigestProvider(activeCode));
      ref.invalidate(invoicesCountProvider(activeCode));
    }
    ref.invalidate(invoiceByIdProvider(item.id));
  }

  try {
    await requestInvoicePayment(apiClient, item.id);
    if (context.mounted) {
      invalidateInvoiceData();
    }
    return true;
  } catch (_) {
    if (!context.mounted) return false;

    invalidateInvoiceData();
    AppToast.showFromSnackBar(
      context,
      SnackBar(
        content: const Text('Не удалось отправить счёт в обработку'),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.fixed,
      ),
    );
    return false;
  }
}

class InvoicesScreen extends ConsumerStatefulWidget {
  final String? initialInvoiceId;
  final String? initialClientCode;

  const InvoicesScreen({
    super.key,
    this.initialInvoiceId,
    this.initialClientCode,
  });

  @override
  ConsumerState<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends ConsumerState<InvoicesScreen> {
  final ScrollController _scrollController = ScrollController();
  String? _selectedStatusCode; // null = "Все"
  String _query = '';

  final GlobalKey _invoicesListKey = GlobalKey();
  final GlobalKey _filtersKey = GlobalKey();
  final GlobalKey _firstInvoiceKey = GlobalKey();
  String? _handledInitialInvoiceId;
  String? _loadingInitialInvoiceId;
  String? _initialClientSwitchTarget;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didUpdateWidget(covariant InvoicesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialInvoiceId != widget.initialInvoiceId ||
        oldWidget.initialClientCode != widget.initialClientCode) {
      _handledInitialInvoiceId = null;
      _loadingInitialInvoiceId = null;
      _initialClientSwitchTarget = null;
    }
  }

  List<InvoiceItem> _applyFilters(List<InvoiceItem> items) {
    final q = _query.trim().toLowerCase();
    return items.where((inv) {
      // Фильтр по статусу (сравниваем по коду статуса)
      final statusOk =
          _selectedStatusCode == null || inv.status == _selectedStatusCode;
      final queryOk = q.isEmpty
          ? true
          : inv.invoiceNumber.toLowerCase().contains(q) ||
                inv.tariffName?.toLowerCase().contains(q) == true;
      return statusOk && queryOk;
    }).toList();
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

  Future<bool> _selectClientCodeIfAvailable(String? code) async {
    final requested = code?.trim();
    if (requested == null || requested.isEmpty) return false;

    final codesState = ref.read(clientCodesControllerProvider).asData?.value;
    if (codesState == null) return false;
    String? targetCode;
    for (final candidate in codesState.codes) {
      if (candidate.toUpperCase() == requested.toUpperCase()) {
        targetCode = candidate;
        break;
      }
    }
    if (targetCode == null) return false;

    final activeCode = ref.read(activeClientCodeProvider);
    if (activeCode?.toUpperCase() == targetCode.toUpperCase()) return true;

    await ref
        .read(clientCodesControllerProvider.notifier)
        .selectClient(targetCode);
    return true;
  }

  void _maybeOpenInitialInvoice(List<InvoiceItem> items, String clientCode) {
    final invoiceId = widget.initialInvoiceId;
    if (invoiceId == null || invoiceId.isEmpty) return;
    if (_handledInitialInvoiceId == invoiceId) return;

    InvoiceItem? invoice;
    for (final item in items) {
      if (item.id == invoiceId || item.invoiceNumber == invoiceId) {
        invoice = item;
        break;
      }
    }
    if (invoice == null) {
      _loadInitialInvoiceFromApi(invoiceId, clientCode);
      return;
    }

    _handledInitialInvoiceId = invoiceId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _openInvoiceDetail(invoice!, clientCode);
    });
  }

  void _loadInitialInvoiceFromApi(String invoiceId, String clientCode) {
    if (_loadingInitialInvoiceId == invoiceId) return;
    _loadingInitialInvoiceId = invoiceId;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || widget.initialInvoiceId != invoiceId) return;
      try {
        final invoice = await ref.read(invoiceByIdProvider(invoiceId).future);
        if (!mounted || widget.initialInvoiceId != invoiceId) return;

        if (invoice == null) {
          _handledInitialInvoiceId = invoiceId;
          return;
        }

        final invoiceClientCode = invoice.clientCode;
        if (invoiceClientCode != null &&
            invoiceClientCode.toUpperCase() != clientCode.toUpperCase() &&
            await _selectClientCodeIfAvailable(invoiceClientCode)) {
          return;
        }

        _handledInitialInvoiceId = invoiceId;
        _openInvoiceDetail(invoice, invoiceClientCode ?? clientCode);
      } catch (e) {
        debugPrint('[InvoicesScreen] Failed to open initial invoice: $e');
      } finally {
        if (_loadingInitialInvoiceId == invoiceId) {
          _loadingInitialInvoiceId = null;
        }
      }
    });
  }

  void _openInvoiceDetail(InvoiceItem item, String clientCode) {
    final referral = ref
        .read(referralProvider)
        .whenOrNull(data: (value) => value);
    final bonusBalance = referral?.referralKgBalance ?? 0;
    final maxBonusPct = referral?.maxBonusPercent ?? 0;

    showBlurredModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.22),
      builder: (sheetContext) => _InvoiceDetailSheet(
        item: item,
        clientCode: clientCode,
        bonusBalance: bonusBalance,
        maxBonusPercent: maxBonusPct,
        onPay: () {
          Navigator.pop(sheetContext);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _goToPaymentChatFromDigest(item);
          });
        },
        onBonusApplied: () {
          final activeCode = ref.read(activeClientCodeProvider);
          if (activeCode != null) {
            ref.invalidate(invoicesListProvider(activeCode));
          }
          ref.invalidate(referralProvider);
        },
      ),
    );
  }

  Future<void> _goToPaymentChatFromDigest(InvoiceItem item) async {
    if (!mounted) return;
    final paymentRequested = await _requestInvoicePaymentStatus(
      context,
      ref,
      item,
    );
    if (!paymentRequested || !mounted) return;

    final money = NumberFormat.decimalPattern('ru');
    final buffer = StringBuffer();
    buffer.writeln('💳 **Запрос на оплату счёта**');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('🆔 ID: ${item.id}');
    buffer.writeln('🔢 Номер: ${item.invoiceNumber}');
    buffer.writeln('📊 Статус: В обработке');
    buffer.writeln('');
    buffer.writeln('💵 К оплате: \$${money.format(item.totalCostUsd.round())}');
    if (item.totalCostCny > 0) {
      buffer.writeln(
        '🇨🇳 К оплате: ¥${money.format(item.totalCostCny.round())}',
      );
    }
    if (item.totalCostRub > 0) {
      buffer.writeln(
        '🇷🇺 К оплате: ${money.format(item.totalCostRub.round())} ₽',
      );
    }

    context.push(
      '/payment-chat',
      extra: {
        'message': buffer.toString(),
        'invoiceId': item.id,
        'invoiceNumber': item.invoiceNumber,
        'amount': item.totalCostUsd,
        if (item.totalCostCny > 0) 'totalCostCny': item.totalCostCny,
        if (item.totalCostRub > 0) 'totalCostRub': item.totalCostRub,
        if (item.clientRubRate != null) 'clientRubRate': item.clientRubRate,
        if (item.clientYuanRate != null) 'clientYuanRate': item.clientYuanRate,
      },
    );
  }

  Future<void> _showInvoiceFiltersSheet(List<InvoiceStatus> statuses) async {
    final result = await showBlurredModalBottomSheet<_InvoiceFiltersResult>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.22),
      builder: (sheetContext) => _InvoiceFiltersSheet(
        selectedStatusCode: _selectedStatusCode,
        statuses: statuses,
      ),
    );

    if (result == null || !mounted) return;
    setState(() => _selectedStatusCode = result.statusCode);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(activeShellBranchIndexProvider, (previous, next) {
      if (previous == next || next != ShellBranchIndex.invoices) return;
      final activeCode = ref.read(activeClientCodeProvider);
      if (activeCode != null) {
        ref.invalidate(invoicesListProvider(activeCode));
      }
      ref.invalidate(invoiceStatusesProvider);
    });

    final clientCode = ref.watch(activeClientCodeProvider);
    if (clientCode == null) {
      return const EmptyState(
        icon: Icons.badge_outlined,
        title: 'Выберите код клиента',
        message:
            'Чтобы увидеть счета, сначала выберите или добавьте код клиента.',
      );
    }
    final switchTarget = _clientCodeSwitchTarget(clientCode);
    if (switchTarget != null) {
      _scheduleInitialClientSwitch(switchTarget);
      return const Center(child: CircularProgressIndicator());
    }

    final invoicesAsync = ref.watch(invoicesListProvider(clientCode));
    final statusesAsync = ref.watch(invoiceStatusesProvider);
    final bottomPad = AppLayout.bottomScrollPadding(context);
    final topPad = AppLayout.topBarTotalHeight(context);

    Future<void> onRefresh() async {
      debugPrint('[Invoices] pull-to-refresh triggered');
      ref.invalidate(invoicesListProvider(clientCode));
      ref.invalidate(invoiceStatusesProvider);
      await ref.read(invoicesListProvider(clientCode).future);
      debugPrint('[Invoices] pull-to-refresh completed');
    }

    final List<InvoiceStatus> dbStatuses = statusesAsync.when(
      data: (statuses) => statuses,
      loading: () => <InvoiceStatus>[],
      error: (_, _) => <InvoiceStatus>[],
    );

    return invoicesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) {
        final errorInfo = ErrorUtils.getErrorInfo(e);
        return EmptyState(
          icon: errorInfo.icon,
          title: errorInfo.title,
          message: errorInfo.message,
        );
      },
      data: (items) {
        _maybeOpenInitialInvoice(items, clientCode);
        final filtered = _applyFilters(items);

        return TutorialScreenWrapper(
          screenKey: 'invoices',
          steps: [
            TutorialStep(
              icon: Icons.receipt_long_rounded,
              title: 'Счета на оплату',
              description:
                  'Счёт выставляется после взвешивания посылок на складе в России. Здесь указан точный итог к оплате.',
              targetKey: _invoicesListKey,
            ),
            TutorialStep(
              icon: Icons.info_rounded,
              title: 'Статус счёта',
              description:
                  '«Требует оплаты» — необходимо оплатить, посылка ждёт. «Оплачен» — посылка уже передана в доставку.',
              targetKey: _firstInvoiceKey,
            ),
            TutorialStep(
              icon: Icons.filter_alt_rounded,
              title: 'Фильтр и поиск',
              description:
                  'Фильтруйте счета по статусу или ищите по номеру. Актуально когда счетов накопилось много.',
              targetKey: _filtersKey,
            ),
            TutorialStep(
              icon: Icons.payment_rounded,
              title: 'Оплатить счёт',
              description:
                  'Нажмите на счёт → откроется карточка с деталями. Кнопка «Оплатить» переводит на экран оплаты картой или USDT.',
              targetKey: _firstInvoiceKey,
            ),
            TutorialStep(
              icon: Icons.redeem_rounded,
              title: 'Бонусные килограммы',
              description:
                  'Если у вас есть бонусный вес из реферальной программы — нажмите «Применить бонус» перед оплатой. Он вычтется из суммы счёта.',
              targetKey: _firstInvoiceKey,
            ),
          ],
          child: Stack(
            children: [
              RefreshIndicator(
                onRefresh: onRefresh,
                color: context.brandPrimary,
                child: ListView.builder(
                  controller: _scrollController,
                  key: _invoicesListKey,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    16,
                    topPad * 0.7 + 14,
                    16,
                    bottomPad + 16,
                  ),
                  addAutomaticKeepAlives: false,
                  addSemanticIndexes: false,
                  itemCount: filtered.isEmpty ? 4 : filtered.length + 3,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return const _InvoicesHeroHeader();
                    }
                    if (index == 1) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: _InvoiceControlsCard(
                          filtersKey: _filtersKey,
                          isFilterActive: _selectedStatusCode != null,
                          query: _query,
                          onFilterTap: () =>
                              _showInvoiceFiltersSheet(dbStatuses),
                          onQueryChanged: (value) =>
                              setState(() => _query = value),
                          onClear: () => setState(() => _query = ''),
                        ),
                      );
                    }
                    if (index == 2) {
                      return const SizedBox(height: 15);
                    }
                    if (filtered.isEmpty) {
                      return const EmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: 'Ничего не найдено',
                        message:
                            'Попробуйте изменить фильтры или строку поиска.',
                      );
                    }

                    final invoiceIndex = index - 3;
                    final invoiceTile = _InvoiceTile(
                      item: filtered[invoiceIndex],
                      clientCode: clientCode,
                    );
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: invoiceIndex == 0
                          ? KeyedSubtree(
                              key: _firstInvoiceKey,
                              child: invoiceTile,
                            )
                          : invoiceTile,
                    );
                  },
                ),
              ),
              ScrollToTopButton(controller: _scrollController),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}

class _InvoicesHeroHeader extends StatelessWidget {
  const _InvoicesHeroHeader();

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
            const Positioned.fill(child: _InvoicesHeaderGlowBackdrop()),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
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
                          Icons.receipt_long_rounded,
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
                              'Счета',
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
                              'Суммы, статусы и понятная расшифровка оплаты',
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InvoicesHeaderGlowBackdrop extends StatefulWidget {
  const _InvoicesHeaderGlowBackdrop();

  @override
  State<_InvoicesHeaderGlowBackdrop> createState() =>
      _InvoicesHeaderGlowBackdropState();
}

class _InvoicesHeaderGlowBackdropState
    extends State<_InvoicesHeaderGlowBackdrop>
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
                    child: _InvoicesHeaderGlowCircle(
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
                    child: _InvoicesHeaderGlowCircle(
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
                    child: _InvoicesHeaderGlowCircle(
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

class _InvoicesHeaderGlowCircle extends StatelessWidget {
  final double size;
  final Color color;

  const _InvoicesHeaderGlowCircle({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

class _InvoiceControlsCard extends StatelessWidget {
  final GlobalKey filtersKey;
  final bool isFilterActive;
  final String query;
  final VoidCallback onFilterTap;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onClear;

  const _InvoiceControlsCard({
    required this.filtersKey,
    required this.isFilterActive,
    required this.query,
    required this.onFilterTap,
    required this.onQueryChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withValues(alpha: 0.035)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 24,
            spreadRadius: -16,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _InvoiceSearchField(
              query: query,
              onChanged: onQueryChanged,
              onClear: onClear,
            ),
          ),
          const SizedBox(width: 10),
          _InvoiceHeaderIconButton(
            key: filtersKey,
            icon: Icons.filter_alt_rounded,
            tooltip: 'Фильтр',
            isActive: isFilterActive,
            onTap: onFilterTap,
          ),
        ],
      ),
    );
  }
}

class _InvoiceHeaderIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool isActive;
  final VoidCallback onTap;

  const _InvoiceHeaderIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = context.brandPrimary;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isActive ? accent : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.black.withValues(alpha: 0.035)),
            ),
            child: Icon(
              icon,
              size: 22,
              color: isActive ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _InvoiceSearchField extends StatefulWidget {
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _InvoiceSearchField({
    required this.query,
    required this.onChanged,
    required this.onClear,
  });

  @override
  State<_InvoiceSearchField> createState() => _InvoiceSearchFieldState();
}

class _InvoiceSearchFieldState extends State<_InvoiceSearchField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.query);
  }

  @override
  void didUpdateWidget(covariant _InvoiceSearchField oldWidget) {
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
      radius: 18,
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
          hintText: 'Поиск по счёту',
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

class _InvoiceSheetSurface extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? pinnedChild;
  final Widget? footer;
  final bool keyboardAware;

  const _InvoiceSheetSurface({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
    this.pinnedChild,
    this.footer,
    this.keyboardAware = false,
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
            maxHeight: MediaQuery.sizeOf(context).height * 0.92,
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
                child: _InvoiceSheetHeader(
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
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: child,
                  ),
                ),
              ),
              if (footer != null)
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 10, 16, 12 + bottomPadding),
                  child: footer,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InvoiceSheetHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _InvoiceSheetHeader({
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
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

class _InvoiceSectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _InvoiceSectionCard({
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

class _InvoicePrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  const _InvoicePrimaryButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 50,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            gradient: enabled ? context.brandGradient : null,
            color: enabled ? null : const Color(0xFFE9ECEF),
            borderRadius: BorderRadius.circular(18),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: context.brandPrimary.withValues(alpha: 0.18),
                      blurRadius: 18,
                      spreadRadius: -10,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Gilroy',
                    fontSize: 14.5,
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

class _InvoiceSecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _InvoiceSecondaryButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 50,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: context.brandPrimary.withValues(alpha: 0.34),
            ),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.brandPrimary,
              fontFamily: 'Gilroy',
              fontSize: 14.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _InvoiceFiltersResult {
  final String? statusCode;

  const _InvoiceFiltersResult(this.statusCode);
}

class _InvoiceStatusOption {
  final String? code;
  final String label;

  const _InvoiceStatusOption({required this.code, required this.label});
}

class _InvoiceFiltersSheet extends StatefulWidget {
  final String? selectedStatusCode;
  final List<InvoiceStatus> statuses;

  const _InvoiceFiltersSheet({
    required this.selectedStatusCode,
    required this.statuses,
  });

  @override
  State<_InvoiceFiltersSheet> createState() => _InvoiceFiltersSheetState();
}

class _InvoiceFiltersSheetState extends State<_InvoiceFiltersSheet> {
  late String? _statusCode = widget.selectedStatusCode;

  @override
  Widget build(BuildContext context) {
    final options = <_InvoiceStatusOption>[
      const _InvoiceStatusOption(code: null, label: 'Все'),
      ...widget.statuses.map(
        (status) =>
            _InvoiceStatusOption(code: status.code, label: status.nameRu),
      ),
    ];

    return _InvoiceSheetSurface(
      icon: Icons.filter_alt_rounded,
      title: 'Фильтр',
      subtitle: 'Выберите нужный статус счёта',
      footer: Row(
        children: [
          Expanded(
            child: _InvoiceSecondaryButton(
              label: 'Сбросить',
              onTap: () =>
                  Navigator.pop(context, const _InvoiceFiltersResult(null)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _InvoicePrimaryButton(
              label: 'Применить',
              icon: Icons.check_rounded,
              onTap: () =>
                  Navigator.pop(context, _InvoiceFiltersResult(_statusCode)),
            ),
          ),
        ],
      ),
      child: _InvoiceSectionCard(
        icon: Icons.flag_rounded,
        title: 'Статус счёта',
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in options)
              _InvoiceFilterChip(
                label: option.label,
                selected: option.code == _statusCode,
                onTap: () => setState(() => _statusCode = option.code),
              ),
          ],
        ),
      ),
    );
  }
}

class _InvoiceFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _InvoiceFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = context.brandPrimary;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? accent : Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? accent : Colors.black.withValues(alpha: 0.06),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                const Icon(Icons.check_rounded, color: Colors.white, size: 15),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.textPrimary,
                  fontFamily: 'Gilroy',
                  fontSize: 13,
                  height: 1,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InvoiceDetailSummaryCard extends StatelessWidget {
  final InvoiceItem item;
  final Color? statusColor;
  final VoidCallback onStatusTap;
  final VoidCallback onCopyNumber;

  const _InvoiceDetailSummaryCard({
    required this.item,
    required this.statusColor,
    required this.onStatusTap,
    required this.onCopyNumber,
  });

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.decimalPattern('ru');
    final amountUsd = _formatUsdAmount(item.totalCostUsd);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withValues(alpha: 0.035)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Номер счёта',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontFamily: 'Gilroy',
                        fontSize: 11.5,
                        height: 1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            item.invoiceNumber,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontFamily: 'Gilroy',
                              fontSize: 20,
                              height: 1.04,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.25,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            onTap: onCopyNumber,
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox(
                              width: 30,
                              height: 30,
                              child: Icon(
                                Icons.copy_rounded,
                                size: 16,
                                color: context.brandPrimary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onStatusTap,
                child: _InvoiceCardStatusPill(
                  text: item.statusName ?? item.status,
                  color: statusColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Стоимость в долларах',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontFamily: 'Gilroy',
                        fontSize: 11.5,
                        height: 1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      amountUsd,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontFamily: 'Gilroy',
                        fontSize: 31,
                        height: 1,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.65,
                      ),
                    ),
                  ],
                ),
              ),
              if (item.totalCostRub > 0 || item.totalCostCny > 0)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (item.totalCostRub > 0)
                      _InvoiceSmallAmount(
                        label: '${money.format(item.totalCostRub.round())} ₽',
                      ),
                    if (item.totalCostCny > 0) ...[
                      const SizedBox(height: 5),
                      _InvoiceSmallAmount(
                        label: '¥${money.format(item.totalCostCny.round())}',
                      ),
                    ],
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InvoiceSmallAmount extends StatelessWidget {
  final String label;

  const _InvoiceSmallAmount({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontFamily: 'Gilroy',
          fontSize: 12.2,
          height: 1,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

// ─── Карточка счёта в списке ──────────────────────────────────────────────────

class _InvoiceTile extends ConsumerStatefulWidget {
  final InvoiceItem item;
  final String clientCode;

  const _InvoiceTile({required this.item, required this.clientCode});

  @override
  ConsumerState<_InvoiceTile> createState() => _InvoiceTileState();
}

class _InvoiceTileState extends ConsumerState<_InvoiceTile> {
  bool _isNavigatingToPayment = false;

  void _showInvoiceStatusTimeline(
    BuildContext context,
    List<InvoiceStatus> statuses,
  ) {
    final item = widget.item;
    showStatusTimelineSheet(
      context: context,
      title: 'Статус счёта',
      currentStatusCode: item.status,
      currentStatusName: item.statusName ?? item.status,
      currentStatusColor: _parseHexColor(item.statusColor),
      history: item.statusHistory,
      statuses: _invoiceTimelineStatuses(statuses),
    );
  }

  void _openDetail(
    BuildContext context,
    double bonusBalance,
    double maxBonusPct,
  ) {
    showBlurredModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.22),
      builder: (sheetContext) => _InvoiceDetailSheet(
        item: widget.item,
        clientCode: widget.clientCode,
        bonusBalance: bonusBalance,
        maxBonusPercent: maxBonusPct,
        onPay: () {
          Navigator.pop(sheetContext);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _goToPayment(context);
          });
        },
        onBonusApplied: () {
          final clientCode = ref.read(activeClientCodeProvider);
          if (clientCode != null) {
            ref.invalidate(invoicesListProvider(clientCode));
          }
          ref.invalidate(referralProvider);
        },
      ),
    );
  }

  Future<void> _goToPayment(BuildContext context) async {
    if (_isNavigatingToPayment) return;
    _isNavigatingToPayment = true;

    final item = widget.item;
    final paymentRequested = await _requestInvoicePaymentStatus(
      context,
      ref,
      item,
    );
    if (!paymentRequested) {
      if (mounted) setState(() => _isNavigatingToPayment = false);
      return;
    }
    if (!mounted) return;

    // Ensure payment TG config is loaded before navigating
    String? paymentTgUsername = ref
        .read(paymentTgUsernameProvider)
        .whenOrNull(data: (v) => v);
    if (paymentTgUsername == null) {
      try {
        paymentTgUsername = await ref.read(paymentTgUsernameProvider.future);
      } catch (_) {}
      if (!mounted) return;
    }
    if (paymentTgUsername != null && paymentTgUsername.isNotEmpty) {
      final text = Uri.encodeComponent(
        'Добрый день! Хочу оплатить счет ${item.invoiceNumber}',
      );
      final tgUrl = 'tg://resolve?domain=$paymentTgUsername&text=$text';
      final webUrl = 'https://t.me/$paymentTgUsername';

      launchUrl(Uri.parse(tgUrl), mode: LaunchMode.externalApplication)
          .then((_) {
            if (mounted) setState(() => _isNavigatingToPayment = false);
          })
          .catchError((_) {
            launchUrl(
              Uri.parse(webUrl),
              mode: LaunchMode.externalApplication,
            ).whenComplete(() {
              if (mounted) setState(() => _isNavigatingToPayment = false);
            });
          });
      return;
    }

    // Fallback: in-app payment chat
    if (!context.mounted) return;
    _goToPaymentChat(context);
  }

  void _goToPaymentChat(BuildContext context) {
    if (!mounted) return;
    final money = NumberFormat.decimalPattern('ru');
    final item = widget.item;
    final buffer = StringBuffer();
    buffer.writeln('💳 **Запрос на оплату счёта**');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('🆔 ID: ${item.id}');
    buffer.writeln('🔢 Номер: ${item.invoiceNumber}');
    buffer.writeln('📊 Статус: В обработке');
    buffer.writeln('');
    buffer.writeln('💵 К оплате: \$${money.format(item.totalCostUsd.round())}');
    if (item.totalCostCny > 0) {
      buffer.writeln(
        '🇨🇳 К оплате: ¥${money.format(item.totalCostCny.round())}',
      );
    }
    if (item.totalCostRub > 0) {
      buffer.writeln(
        '🇷🇺 К оплате: ${money.format(item.totalCostRub.round())} ₽',
      );
    }
    if (item.clientRubRate != null || item.clientYuanRate != null) {
      buffer.writeln('');
      if (item.clientRubRate != null) {
        buffer.writeln(
          '📈 Курс \$/₽: ${item.clientRubRate!.toStringAsFixed(2)}',
        );
      }
      if (item.clientYuanRate != null) {
        buffer.writeln(
          '📈 Курс \$/¥: ${item.clientYuanRate!.toStringAsFixed(2)}',
        );
      }
    }

    context
        .push(
          '/payment-chat',
          extra: {
            'message': buffer.toString(),
            'invoiceId': item.id,
            'invoiceNumber': item.invoiceNumber,
            'amount': item.totalCostUsd,
            if (item.totalCostCny > 0) 'totalCostCny': item.totalCostCny,
            if (item.totalCostRub > 0) 'totalCostRub': item.totalCostRub,
            if (item.clientRubRate != null) 'clientRubRate': item.clientRubRate,
            if (item.clientYuanRate != null)
              'clientYuanRate': item.clientYuanRate,
          },
        )
        .whenComplete(() {
          if (mounted) {
            setState(() => _isNavigatingToPayment = false);
            // Обновляем список счетов после возврата из чата оплаты
            final clientCode = ref.read(activeClientCodeProvider);
            if (clientCode != null) {
              ref.invalidate(invoicesListProvider(clientCode));
            }
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final statusColor = _parseHexColor(item.statusColor);
    final referralAsync = ref.watch(referralProvider);
    final invoiceStatuses =
        ref.watch(invoiceStatusesProvider).asData?.value ??
        const <InvoiceStatus>[];

    final double bonusBalance =
        referralAsync.whenOrNull(data: (r) => r.referralKgBalance) ?? 0;
    final double maxBonusPct =
        referralAsync.whenOrNull(data: (r) => r.maxBonusPercent) ?? 0;

    final createdText = _formatListDate(item.createdAt);
    final updatedAt =
        item.updatedAt ??
        item.paidAt ??
        item.sendDate ??
        item.arrivalDate ??
        item.createdAt;
    final updatedText = _formatListDate(updatedAt);

    final amountUsdText = _formatUsdAmount(item.totalCostUsd);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: () => _openDetail(context, bonusBalance, maxBonusPct),
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.black.withValues(alpha: 0.035)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 24,
                spreadRadius: -16,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: context.brandPrimary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(
                      Icons.receipt_long_rounded,
                      color: context.brandPrimary,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Номер счёта',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontFamily: 'Gilroy',
                            fontSize: 11.5,
                            height: 1,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          item.invoiceNumber,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Gilroy',
                            fontSize: 19,
                            height: 1.04,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () =>
                        _showInvoiceStatusTimeline(context, invoiceStatuses),
                    child: _InvoiceCardStatusPill(
                      text: item.statusName ?? item.status,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.black.withValues(alpha: 0.035),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.80),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: context.brandPrimary.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Icon(
                        Icons.attach_money_rounded,
                        color: context.brandPrimary,
                        size: 23,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Итого',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontFamily: 'Gilroy',
                              fontSize: 11.5,
                              height: 1,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            amountUsdText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Gilroy',
                              fontSize: 27,
                              height: 1,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.black.withValues(alpha: 0.035),
                        ),
                      ),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textSecondary.withValues(alpha: 0.78),
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _InvoiceDateMeta(
                    icon: CupertinoIcons.plus_circle,
                    label: createdText,
                  ),
                  _InvoiceDateMeta(
                    icon: CupertinoIcons.arrow_2_circlepath_circle,
                    label: updatedText,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatListDate(DateTime? date) {
    if (date == null) return '--.--.--';
    return DateFormat('dd.MM.yy', 'ru').format(date);
  }
}

class _InvoiceDateMeta extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InvoiceDateMeta({required this.icon, required this.label});

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
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
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

class _InvoiceCardStatusPill extends StatelessWidget {
  final String text;
  final Color? color;

  const _InvoiceCardStatusPill({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    final accent = color ?? context.brandPrimary;
    final isLight = accent.computeLuminance() > 0.58;
    final bg = isLight
        ? accent.withValues(alpha: 0.42)
        : accent.withValues(alpha: 0.12);
    final textColor = isLight ? AppColors.textPrimary : accent;

    return Container(
      constraints: const BoxConstraints(minHeight: 26, maxWidth: 96),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'Gilroy',
          fontSize: 11.6,
          height: 1,
          fontWeight: FontWeight.w900,
          color: textColor,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

// ─── Детальный лист счёта ─────────────────────────────────────────────────────

class _InvoiceDetailSheet extends ConsumerStatefulWidget {
  final InvoiceItem item;
  final String clientCode;
  final double bonusBalance;
  final double maxBonusPercent;
  final VoidCallback onPay;
  final VoidCallback onBonusApplied;

  const _InvoiceDetailSheet({
    required this.item,
    required this.clientCode,
    required this.bonusBalance,
    required this.maxBonusPercent,
    required this.onPay,
    required this.onBonusApplied,
  });

  @override
  ConsumerState<_InvoiceDetailSheet> createState() =>
      _InvoiceDetailSheetState();
}

class _InvoiceDetailSheetState extends ConsumerState<_InvoiceDetailSheet> {
  final _bonusKgCtrl = TextEditingController();
  bool _isApplyingBonus = false;

  @override
  void dispose() {
    _bonusKgCtrl.dispose();
    super.dispose();
  }

  bool get _isUnpaid =>
      widget.item.status.toLowerCase() == 'unpaid' ||
      widget.item.status.toLowerCase() == 'pending';

  // Bank QR Sprint4: открыть экран оплаты в рублях; по успешной отправке чека
  // обновить список и закрыть лист счёта.
  Future<void> _openBankQr(BuildContext context) async {
    final navigator = Navigator.of(context);
    final changed = await navigator.push<bool>(
      MaterialPageRoute(
        builder: (_) => BankQrPaymentScreen(
          invoiceId: widget.item.id,
          invoiceNumber: widget.item.invoiceNumber,
        ),
      ),
    );
    if (changed == true && mounted) {
      widget.onBonusApplied(); // переиспользуем как refresh списка счетов
      if (navigator.canPop()) navigator.pop();
    }
  }

  List<PhotoItem> _scalePhotoItems(InvoiceItem item) {
    final date = item.updatedAt ?? item.createdAt ?? DateTime.now();
    return item.scalePhotoUrls
        .map((url) => PhotoItem(url: ApiConfig.getMediaUrl(url), date: date))
        .toList(growable: false);
  }

  void _openScalePhoto(InvoiceItem item, int index) {
    final photos = _scalePhotoItems(item);
    if (index < 0 || index >= photos.length) return;

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

  void _openWaybillPhoto(InvoiceItem item) {
    final url = item.tkWaybillPhotoUrl;
    if (url == null || url.isEmpty) return;

    final photo = PhotoItem(
      url: ApiConfig.getMediaUrl(url),
      date: item.updatedAt ?? item.createdAt ?? DateTime.now(),
    );

    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) =>
            PhotoViewerScreen(item: photo, allPhotos: [photo], initialIndex: 0),
      ),
    );
  }

  void _showInvoiceStatusTimeline(List<InvoiceStatus> statuses) {
    final item = widget.item;
    showStatusTimelineSheet(
      context: context,
      title: 'Статус счёта',
      currentStatusCode: item.status,
      currentStatusName: item.statusName ?? item.status,
      currentStatusColor: _parseHexColor(item.statusColor),
      history: item.statusHistory,
      statuses: _invoiceTimelineStatuses(statuses),
    );
  }

  Future<void> _applyBonusKg() async {
    final item = widget.item;
    final kg = double.tryParse(_bonusKgCtrl.text.replaceAll(',', '.'));
    if (kg == null || kg <= 0) return;

    final maxKg = (item.weight * widget.maxBonusPercent / 100).clamp(
      0.0,
      widget.bonusBalance,
    );
    if (kg > maxKg) {
      AppToast.showFromSnackBar(
        context,
        SnackBar(
          content: Text('Максимум: ${maxKg.toStringAsFixed(2)} кг'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isApplyingBonus = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.post(
        '/client/invoices/${item.id}/apply-bonus',
        data: {'bonusKg': kg},
      );
      _bonusKgCtrl.selection = const TextSelection.collapsed(offset: 0);
      _bonusKgCtrl.clear();
      widget.onBonusApplied();
      if (mounted) {
        AppToast.showFromSnackBar(
          context,
          SnackBar(
            content: Text('Применено ${kg.toStringAsFixed(2)} бонусных кг'),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        AppToast.showFromSnackBar(
          context,
          const SnackBar(
            content: Text('Ошибка применения бонуса'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isApplyingBonus = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final df = DateFormat('dd MMM yyyy', 'ru');
    final money = NumberFormat.decimalPattern('ru');
    final statusColor = _parseHexColor(item.statusColor);
    final invoiceStatuses =
        ref.watch(invoiceStatusesProvider).asData?.value ??
        const <InvoiceStatus>[];
    final pricePerKg = item.clientPricePerKg ?? item.tariffBaseCost ?? 0;
    final maxKg = (item.weight * widget.maxBonusPercent / 100).clamp(
      0.0,
      widget.bonusBalance,
    );
    final enteredKg =
        double.tryParse(_bonusKgCtrl.text.replaceAll(',', '.')) ?? 0;
    final bonusDiscount = (enteredKg * pricePerKg).clamp(
      0.0,
      item.totalCostUsd,
    );
    final showBonusSection =
        _isUnpaid && widget.bonusBalance > 0 && pricePerKg > 0;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: _InvoiceSheetSurface(
        icon: Icons.receipt_long_rounded,
        title: 'Счёт ${item.invoiceNumber}',
        subtitle: 'Разбивка суммы и данные для оплаты',
        keyboardAware: true,
        pinnedChild: _InvoiceDetailSummaryCard(
          item: item,
          statusColor: statusColor,
          onStatusTap: () => _showInvoiceStatusTimeline(invoiceStatuses),
          onCopyNumber: () async {
            final copied = await AppClipboard.copyText(item.invoiceNumber);
            if (!context.mounted) return;
            AppToast.showFromSnackBar(
              context,
              SnackBar(
                content: Text(
                  copied ? 'Номер скопирован' : 'Не удалось скопировать',
                ),
                backgroundColor: copied ? null : Colors.red.shade700,
              ),
            );
          },
        ),
        footer: _isUnpaid
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _InvoicePrimaryButton(
                    label: tr(context, ru: 'Оплатить в юанях', zh: '用人民币支付'),
                    icon: Icons.payment_rounded,
                    onTap: widget.onPay,
                  ),
                  // Bank QR Sprint4: вторая кнопка — только если доступна QR-оплата.
                  if (widget.item.bankQrPaymentAvailable) ...[
                    const SizedBox(height: 8),
                    _InvoiceSecondaryButton(
                      label: tr(context, ru: 'Оплатить в рублях', zh: '用卢布支付'),
                      onTap: () => _openBankQr(context),
                    ),
                  ],
                ],
              )
            : _InvoiceSecondaryButton(
                label: 'Закрыть',
                onTap: () => Navigator.of(context).pop(),
              ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildPlainInfoBlock([
              _buildInfoRow(context, 'Номер счёта', item.invoiceNumber),
              _buildInfoRow(context, 'Статус', item.statusName ?? item.status),
              if (item.createdAt != null)
                _buildInfoRow(context, 'Выставлен', df.format(item.createdAt!)),
              if (item.paidAt != null)
                _buildInfoRow(context, 'Оплачен', df.format(item.paidAt!)),
              if (item.arrivalMarket != null && item.arrivalMarket!.isNotEmpty)
                _buildInfoRow(
                  context,
                  'Рынок прибытия',
                  _localizeMarket(item.arrivalMarket!),
                ),
            ]),
            const SizedBox(height: 12),
            _buildSection('Груз и доставка', [
              if (item.totalTracks > 0)
                _buildInfoRow(context, 'Треков в счёте', '${item.totalTracks}'),
              if (item.placesCount > 0)
                _buildInfoRow(
                  context,
                  'Количество мест',
                  '${item.placesCount}',
                ),
              if (item.weight > 0)
                _buildInfoRow(
                  context,
                  'Вес',
                  '${item.weight.toStringAsFixed(2)} кг',
                ),
              if (item.volume > 0)
                _buildInfoRow(
                  context,
                  'Объём',
                  '${item.volume.toStringAsFixed(3)} м³',
                ),
              if (item.weight > 0 && item.volume > 0)
                _buildInfoRow(
                  context,
                  'Плотность',
                  '${(item.weight / item.volume).toStringAsFixed(2)} кг/м³',
                ),
              if (item.tariffName != null && item.tariffName!.isNotEmpty)
                _buildInfoRow(context, 'Тариф', item.tariffName!),
            ], icon: Icons.inventory_2_rounded),
            const SizedBox(height: 12),
            _buildSection('Расчёт суммы', [
              if (item.clientPricePerKg != null && item.clientPricePerKg! > 0)
                _buildInfoRow(
                  context,
                  'Тариф за кг',
                  '\$${item.clientPricePerKg!.toStringAsFixed(2)}/кг',
                ),
              if (item.photoReportCoefficient != null &&
                  item.photoReportCoefficient! > 1.0)
                _buildInfoRow(
                  context,
                  'Коэфф. фото',
                  '×${item.photoReportCoefficient!.toStringAsFixed(2)}',
                ),
              if (item.clientPricePerKgWithPhoto != null &&
                  item.clientPricePerKgWithPhoto! > 0 &&
                  item.clientPricePerKgWithPhoto != item.clientPricePerKg)
                _buildInfoRow(
                  context,
                  'Итоговый тариф',
                  '\$${item.clientPricePerKgWithPhoto!.toStringAsFixed(2)}/кг',
                ),
              if (item.shippingCost != null && item.shippingCost! > 0)
                _buildInfoRow(
                  context,
                  'Доставка по тарифу',
                  '\$${item.shippingCost!.toStringAsFixed(2)}',
                ),
              if (item.transshipmentCost != null && item.transshipmentCost! > 0)
                _buildInfoRow(
                  context,
                  'Разгрузка',
                  '\$${item.transshipmentCost!.toStringAsFixed(2)}',
                ),
              if (item.hasDetailedPackagingUsage)
                _buildPackagingUsageBlock(context, item)
              else if (item.resolvedPackagingCostTotal != null &&
                  item.resolvedPackagingCostTotal! > 0)
                _buildInfoRow(
                  context,
                  _packagingLabel(item),
                  '\$${item.resolvedPackagingCostTotal!.toStringAsFixed(2)}',
                ),
              if (item.insuranceCostClient != null &&
                  item.insuranceCostClient! > 0)
                _buildInfoRow(
                  context,
                  'Страховка',
                  '\$${item.insuranceCostClient!.toStringAsFixed(2)}',
                )
              else if (item.insuranceCost != null && item.insuranceCost! > 0)
                _buildInfoRow(
                  context,
                  'Страховка',
                  '\$${item.insuranceCost!.toStringAsFixed(2)}',
                ),
              if (item.discountAmount != null && item.discountAmount! > 0)
                _buildInfoRow(
                  context,
                  'Скидка',
                  '−\$${item.discountAmount!.toStringAsFixed(2)}',
                ),
              if (item.bonusKgApplied > 0)
                _buildInfoRow(
                  context,
                  'Бонусные кг',
                  '−${item.bonusKgApplied.toStringAsFixed(2)} кг',
                ),
              const Divider(height: 22),
              if (item.totalCostUsd > 0)
                _buildInfoRow(
                  context,
                  'Итого в долларах',
                  _formatUsdAmount(item.totalCostUsd, withCents: true),
                  isTotal: true,
                ),
              if (item.totalCostCny > 0)
                _buildInfoRow(
                  context,
                  'К оплате в юанях',
                  '¥${money.format(item.totalCostCny.round())}',
                  isTotal: true,
                ),
              if (item.totalCostRub > 0)
                _buildInfoRow(
                  context,
                  'К оплате в рублях',
                  '${money.format(item.totalCostRub.round())} ₽',
                  isTotal: true,
                ),
              if (item.clientRubRate != null)
                _buildInfoRow(
                  context,
                  'Курс \$/₽',
                  item.clientRubRate!.toStringAsFixed(2),
                ),
              if (item.clientYuanRate != null)
                _buildInfoRow(
                  context,
                  'Курс \$/¥',
                  item.clientYuanRate!.toStringAsFixed(4),
                ),
            ], icon: Icons.payments_rounded),
            if (showBonusSection) ...[
              const SizedBox(height: 12),
              _buildBonusSection(
                context: context,
                item: item,
                maxKg: maxKg,
                enteredKg: enteredKg,
                bonusDiscount: bonusDiscount,
              ),
            ],
            if (item.scalePhotoUrls.isNotEmpty ||
                item.tkWaybillPhotoUrl != null) ...[
              const SizedBox(height: 12),
              _buildMediaSection(item),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBonusSection({
    required BuildContext context,
    required InvoiceItem item,
    required double maxKg,
    required double enteredKg,
    required double bonusDiscount,
  }) {
    return _buildSection('Бонусные кг', [
      _buildInfoRow(
        context,
        'Доступно',
        '${widget.bonusBalance.toStringAsFixed(2)} кг',
      ),
      _buildInfoRow(context, 'Можно списать', '${maxKg.toStringAsFixed(2)} кг'),
      if (item.bonusKgApplied > 0)
        _buildInfoRow(
          context,
          'Уже применено',
          '${item.bonusKgApplied.toStringAsFixed(2)} кг',
        ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _bonusKgCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+[.,]?\d*')),
              ],
              decoration: appInputDecoration(
                context,
                hintText: 'Кол-во кг',
                fillColor: Colors.white,
                isDense: true,
                borderColor: Colors.green.shade300,
                focusedBorderColor: Colors.green.shade600,
                focusedWidth: 2,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 46,
            child: ElevatedButton(
              onPressed: _isApplyingBonus ? null : _applyBonusKg,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              child: _isApplyingBonus
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Применить'),
            ),
          ),
        ],
      ),
      if (enteredKg > 0) ...[
        const SizedBox(height: 8),
        Text(
          'Предварительная скидка: ~\$${bonusDiscount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 13,
            color: Colors.green.shade700,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ], icon: Icons.redeem_rounded);
  }

  Widget _buildMediaSection(InvoiceItem item) {
    return _buildSection('Фото и накладные', [
      if (item.scalePhotoUrls.isNotEmpty) ...[
        const Text(
          'Фото с весов',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 104,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: item.scalePhotoUrls.length,
            addAutomaticKeepAlives: false,
            addSemanticIndexes: false,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _openScalePhoto(item, index),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.network(
                    ApiConfig.getMediaUrl(item.scalePhotoUrls[index]),
                    width: 104,
                    height: 104,
                    cacheWidth: 240,
                    cacheHeight: 240,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.low,
                    errorBuilder: (_, _, _) => Container(
                      width: 104,
                      height: 104,
                      color: const Color(0xFFEEEEEE),
                      child: const Icon(Icons.broken_image, color: Colors.grey),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
      if (item.tkWaybillPhotoUrl != null) ...[
        if (item.scalePhotoUrls.isNotEmpty) const SizedBox(height: 12),
        const Text(
          'Фото накладной',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _openWaybillPhoto(item),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(
                ApiConfig.getMediaUrl(item.tkWaybillPhotoUrl!),
                width: 104,
                height: 104,
                cacheWidth: 240,
                cacheHeight: 240,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.low,
                errorBuilder: (_, _, _) => Container(
                  width: 104,
                  height: 104,
                  color: const Color(0xFFEEEEEE),
                  child: const Icon(Icons.broken_image, color: Colors.grey),
                ),
              ),
            ),
          ),
        ),
      ],
    ], icon: Icons.photo_library_rounded);
  }

  Widget _buildSection(
    String title,
    List<Widget> children, {
    required IconData icon,
  }) {
    if (children.isEmpty) return const SizedBox.shrink();
    return _InvoiceSectionCard(
      icon: icon,
      title: title,
      child: Column(children: children),
    );
  }

  Widget _buildPlainInfoBlock(List<Widget> children) {
    if (children.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.035)),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    String label,
    String value, {
    bool isTotal = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                color: isTotal
                    ? const Color(0xFF333333)
                    : const Color(0xFF666666),
                fontSize: isTotal ? 15 : 14,
                fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                color: isTotal ? context.brandPrimary : const Color(0xFF333333),
                fontSize: isTotal ? 18 : 14,
                fontWeight: isTotal ? FontWeight.w900 : FontWeight.w600,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPackagingUsageBlock(BuildContext context, InvoiceItem item) {
    final total =
        item.resolvedPackagingCostTotal ?? item.packagingUsageClientTotal;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Расход упаковки',
                  style: TextStyle(
                    color: Color(0xFF666666),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '\$${total.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Color(0xFF333333),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F8FA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE8EAEE)),
            ),
            child: Column(
              children: item.packagingUsage.map((usage) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: usage.isPrimary
                              ? context.brandPrimary.withValues(alpha: 0.10)
                              : Colors.blue.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          usage.isPrimary ? 'Основа' : 'Доп',
                          style: TextStyle(
                            color: usage.isPrimary
                                ? context.brandPrimary
                                : Colors.blue.shade700,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${usage.name} × ${usage.quantityDisplay()}',
                          style: const TextStyle(
                            color: Color(0xFF333333),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '\$${usage.effectiveClientTotalCost.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Color(0xFF333333),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  String _packagingLabel(InvoiceItem item) {
    final name = item.packagingNames;
    final base = name.isEmpty ? 'Упаковка' : 'Упаковка: $name';
    if (item.billablePlacesCount > 1 && item.packagingUnitCost > 0) {
      return '$base ×${item.billablePlacesCount}';
    }
    return base;
  }
}
