import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:twoalogisticcabineuser/src/core/ui/app_toast.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/ui/scroll_to_top_button.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/network/api_client.dart';
import '../../../core/ui/app_layout.dart';
import '../../../core/ui/tutorial_card.dart';
import '../../../core/ui/empty_state.dart';
import '../../../core/ui/sheet_handle.dart';
import '../../../core/ui/status_pill.dart';
import '../../../core/ui/status_timeline_sheet.dart';
import '../../../core/ui/app_colors.dart';
import '../../../core/ui/app_input_decoration.dart';
import '../../../core/network/api_config.dart';
import '../../../core/utils/clipboard_helper.dart';
import '../../../core/utils/error_utils.dart';
import '../../clients/application/client_codes_controller.dart';
import '../../photos/domain/photo_item.dart';
import '../../photos/presentation/photo_viewer_screen.dart';
import '../../referral/data/referral_provider.dart';
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

Future<bool> _requestInvoicePaymentStatus(
  BuildContext context,
  WidgetRef ref,
  InvoiceItem item,
) async {
  try {
    await requestInvoicePayment(ref.read(apiClientProvider), item.id);
    final activeCode = ref.read(activeClientCodeProvider);
    if (activeCode != null) {
      ref.invalidate(invoicesListProvider(activeCode));
      ref.invalidate(invoicesDigestProvider(activeCode));
      ref.invalidate(invoicesCountProvider(activeCode));
    }
    ref.invalidate(invoiceByIdProvider(item.id));
    return true;
  } catch (_) {
    final activeCode = ref.read(activeClientCodeProvider);
    if (activeCode != null) {
      ref.invalidate(invoicesListProvider(activeCode));
      ref.invalidate(invoicesDigestProvider(activeCode));
      ref.invalidate(invoicesCountProvider(activeCode));
    }
    ref.invalidate(invoiceByIdProvider(item.id));

    if (context.mounted) {
      AppToast.showFromSnackBar(
        context,
        SnackBar(
          content: const Text('Не удалось отправить счёт в обработку'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.fixed,
        ),
      );
    }
    return false;
  }
}

class InvoicesScreen extends ConsumerStatefulWidget {
  final String? initialInvoiceId;

  const InvoicesScreen({super.key, this.initialInvoiceId});

  @override
  ConsumerState<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends ConsumerState<InvoicesScreen> {
  final ScrollController _scrollController = ScrollController();
  String? _selectedStatusCode; // null = "Все"
  String _query = '';
  bool _isSearchVisible = false;

  final GlobalKey _invoicesListKey = GlobalKey();
  final GlobalKey _filtersKey = GlobalKey();
  final GlobalKey _firstInvoiceKey = GlobalKey();
  String? _handledInitialInvoiceId;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didUpdateWidget(covariant InvoicesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialInvoiceId != widget.initialInvoiceId) {
      _handledInitialInvoiceId = null;
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
    if (invoice == null) return;

    _handledInitialInvoiceId = invoiceId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _openInvoiceDetail(invoice!, clientCode);
    });
  }

  void _openInvoiceDetail(InvoiceItem item, String clientCode) {
    final referral = ref
        .read(referralProvider)
        .whenOrNull(data: (value) => value);
    final bonusBalance = referral?.referralKgBalance ?? 0;
    final maxBonusPct = referral?.maxBonusPercent ?? 0;

    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
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
    final result = await showModalBottomSheet<_InvoiceFiltersResult>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
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
    final clientCode = ref.watch(activeClientCodeProvider);
    if (clientCode == null) {
      return const EmptyState(
        icon: Icons.badge_outlined,
        title: 'Выберите код клиента',
        message:
            'Чтобы увидеть счета, сначала выберите или добавьте код клиента.',
      );
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
                    topPad * 0.7 + 16,
                    16,
                    bottomPad + 16,
                  ),
                  addAutomaticKeepAlives: false,
                  addSemanticIndexes: false,
                  itemCount: filtered.isEmpty ? 4 : filtered.length + 3,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _InvoiceHeaderSection(
                        filtersKey: _filtersKey,
                        isFilterActive: _selectedStatusCode != null,
                        isSearchActive: _isSearchVisible || _query.isNotEmpty,
                        onFilterTap: () => _showInvoiceFiltersSheet(dbStatuses),
                        onSearchTap: () {
                          setState(() => _isSearchVisible = !_isSearchVisible);
                        },
                      );
                    }
                    if (index == 1) {
                      return AnimatedSize(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutCubic,
                        alignment: Alignment.topCenter,
                        child: (_isSearchVisible || _query.isNotEmpty)
                            ? Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: _InvoiceSearchField(
                                  query: _query,
                                  onChanged: (value) =>
                                      setState(() => _query = value),
                                  onClear: () => setState(() {
                                    _query = '';
                                    _isSearchVisible = false;
                                  }),
                                ),
                              )
                            : const SizedBox.shrink(),
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

class _InvoiceHeaderSection extends StatelessWidget {
  final GlobalKey filtersKey;
  final bool isFilterActive;
  final bool isSearchActive;
  final VoidCallback onFilterTap;
  final VoidCallback onSearchTap;

  const _InvoiceHeaderSection({
    required this.filtersKey,
    required this.isFilterActive,
    required this.isSearchActive,
    required this.onFilterTap,
    required this.onSearchTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Expanded(
            child: Text(
              'Счета',
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
          _InvoiceHeaderIconButton(
            key: filtersKey,
            icon: Icons.filter_alt_rounded,
            tooltip: 'Фильтр',
            isActive: isFilterActive,
            onTap: onFilterTap,
          ),
          const SizedBox(width: 10),
          _InvoiceHeaderIconButton(
            icon: Icons.search_rounded,
            tooltip: 'Поиск',
            isActive: isSearchActive,
            onTap: onSearchTap,
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
          hintText: 'Поиск по счёту',
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

class _InvoiceFiltersResult {
  final String? statusCode;

  const _InvoiceFiltersResult(this.statusCode);
}

class _InvoiceStatusOption {
  final String? code;
  final String label;

  const _InvoiceStatusOption({required this.code, required this.label});
}

class _InvoiceFiltersSheet extends StatelessWidget {
  final String? selectedStatusCode;
  final List<InvoiceStatus> statuses;

  const _InvoiceFiltersSheet({
    required this.selectedStatusCode,
    required this.statuses,
  });

  @override
  Widget build(BuildContext context) {
    final options = <_InvoiceStatusOption>[
      const _InvoiceStatusOption(code: null, label: 'Все'),
      ...statuses.map(
        (status) =>
            _InvoiceStatusOption(code: status.code, label: status.nameRu),
      ),
    ];

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
              'Фильтр',
              style: TextStyle(
                fontFamily: 'Gilroy',
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2F2F2F),
              ),
            ),
            const SizedBox(height: 12),
            for (final option in options)
              _InvoiceFilterOptionTile(
                title: option.label,
                selected: option.code == selectedStatusCode,
                onTap: () =>
                    Navigator.pop(context, _InvoiceFiltersResult(option.code)),
              ),
          ],
        ),
      ),
    );
  }
}

class _InvoiceFilterOptionTile extends StatelessWidget {
  final String title;
  final bool selected;
  final VoidCallback onTap;

  const _InvoiceFilterOptionTile({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Gilroy',
                    fontSize: 16,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: selected
                        ? context.brandPrimary
                        : const Color(0xFF2F2F2F),
                  ),
                ),
              ),
              if (selected)
                Icon(Icons.check_rounded, color: context.brandPrimary),
            ],
          ),
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

  bool get _isUnpaid =>
      widget.item.status.toLowerCase() == 'unpaid' ||
      widget.item.status.toLowerCase() == 'pending';

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
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
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
    final money = NumberFormat.decimalPattern('ru');
    final statusColor = _parseHexColor(item.statusColor);
    final referralAsync = ref.watch(referralProvider);
    final invoiceStatuses =
        ref.watch(invoiceStatusesProvider).asData?.value ??
        const <InvoiceStatus>[];

    final double bonusBalance =
        referralAsync.whenOrNull(data: (r) => r.referralKgBalance) ?? 0;
    final double maxBonusPct =
        referralAsync.whenOrNull(data: (r) => r.maxBonusPercent) ?? 0;

    final amountText = item.totalCostUsd > 0
        ? '\$${money.format(item.totalCostUsd.round())}'
        : item.totalCostRub > 0
        ? '${money.format(item.totalCostRub.round())} ₽'
        : item.totalCostCny > 0
        ? '¥${money.format(item.totalCostCny.round())}'
        : '\$0';
    final createdText = _formatListDate(item.createdAt);
    final updatedAt =
        item.updatedAt ??
        item.paidAt ??
        item.sendDate ??
        item.arrivalDate ??
        item.createdAt;
    final updatedText = _formatListDate(updatedAt);
    final actionText = _isUnpaid ? 'Оплатить' : 'Открыть';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openDetail(context, bonusBalance, maxBonusPct),
      child: Container(
        constraints: const BoxConstraints(minHeight: 92),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 26,
              offset: Offset(3, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.invoiceNumber,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Gilroy',
                          fontSize: 16,
                          height: 19 / 16,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF2F2F2F),
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Opacity(
                        opacity: 0.5,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 2,
                          children: [
                            _InvoiceCardDate(
                              icon: CupertinoIcons.plus_circle,
                              text: createdText,
                            ),
                            _InvoiceCardDate(
                              icon: CupertinoIcons.arrow_2_circlepath_circle,
                              text: updatedText,
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
                  onTap: () =>
                      _showInvoiceStatusTimeline(context, invoiceStatuses),
                  child: _InvoiceCardStatusPill(
                    text: item.statusName ?? item.status,
                    color: statusColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 24,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      amountText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Gilroy',
                        fontSize: 16,
                        height: 19 / 16,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF000000),
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _InvoiceCardActionButton(
                    label: _isNavigatingToPayment ? '...' : actionText,
                    onTap: _isUnpaid
                        ? () => _goToPayment(context)
                        : () => _openDetail(context, bonusBalance, maxBonusPct),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatListDate(DateTime? date) {
    if (date == null) return '--.--.--';
    return DateFormat('dd.MM.yy', 'ru').format(date);
  }
}

class _InvoiceCardDate extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InvoiceCardDate({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 24, color: const Color(0xFF2F2F2F)),
        const SizedBox(width: 5),
        Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: 'Gilroy',
            fontSize: 16,
            height: 24 / 16,
            fontWeight: FontWeight.w400,
            color: Color(0xFF2F2F2F),
            letterSpacing: 0,
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
    final background = color ?? context.brandPrimary.withValues(alpha: 0.18);
    return Container(
      height: 34,
      constraints: const BoxConstraints(minWidth: 72, maxWidth: 128),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: 'Gilroy',
          fontSize: 14,
          height: 16 / 14,
          fontWeight: FontWeight.w500,
          color: Color(0xFF000000),
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _InvoiceCardActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _InvoiceCardActionButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 24,
          width: 190,
          constraints: const BoxConstraints(maxWidth: 190),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: context.brandPrimary, width: 0.5),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Gilroy',
              fontSize: 12,
              height: 14 / 12,
              fontWeight: FontWeight.w400,
              color: Color(0xFF2F2F2F),
              letterSpacing: 0,
            ),
          ),
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

    return DraggableScrollableSheet(
      initialChildSize: 1.0,
      minChildSize: 0.5,
      maxChildSize: 1.0,
      expand: false,
      builder: (context, scrollController) {
        return GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            ),
            child: Column(
              children: [
                // Ручка
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Заголовок
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    item.invoiceNumber,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () async {
                                    final copied = await AppClipboard.copyText(
                                      item.invoiceNumber,
                                    );
                                    if (!context.mounted) return;
                                    AppToast.showFromSnackBar(
                                      context,
                                      SnackBar(
                                        content: Text(
                                          copied
                                              ? 'Номер скопирован'
                                              : 'Не удалось скопировать',
                                        ),
                                        backgroundColor: copied
                                            ? null
                                            : Colors.red.shade700,
                                      ),
                                    );
                                  },
                                  child: const Icon(
                                    Icons.copy,
                                    size: 18,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () =>
                                  _showInvoiceStatusTimeline(invoiceStatuses),
                              child: StatusPill(
                                text: item.statusName ?? item.status,
                                color: statusColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                const Divider(height: 1),

                // Контент
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.only(
                      top: 20,
                      left: 16,
                      right: 16,
                      bottom:
                          MediaQuery.of(context).viewInsets.bottom +
                          MediaQuery.of(context).padding.bottom +
                          24,
                    ),
                    children: [
                      // ══ Основная информация ══════════════════════════════
                      _buildSection('Основная информация', [
                        if (item.createdAt != null)
                          _buildInfoRow(
                            context,
                            'Дата создания',
                            df.format(item.createdAt!),
                          ),
                        if (item.paidAt != null)
                          _buildInfoRow(
                            context,
                            'Дата оплаты',
                            df.format(item.paidAt!),
                          ),
                        if (item.arrivalMarket != null &&
                            item.arrivalMarket!.isNotEmpty)
                          _buildInfoRow(
                            context,
                            'Рынок прибытия',
                            _localizeMarket(item.arrivalMarket!),
                          ),
                      ]),
                      const SizedBox(height: 20),

                      // ══ Информация по коробкам ═══════════════════════════
                      _buildSection('Информация по коробкам', [
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
                        if (item.scalePhotoUrls.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 100,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: item.scalePhotoUrls.length,
                              addAutomaticKeepAlives: false,
                              addSemanticIndexes: false,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(width: 8),
                              itemBuilder: (context, index) {
                                return GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => _openScalePhoto(item, index),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      ApiConfig.getMediaUrl(
                                        item.scalePhotoUrls[index],
                                      ),
                                      width: 100,
                                      height: 100,
                                      cacheWidth: 240,
                                      cacheHeight: 240,
                                      fit: BoxFit.cover,
                                      filterQuality: FilterQuality.low,
                                      errorBuilder: (_, _, _) => Container(
                                        width: 100,
                                        height: 100,
                                        color: const Color(0xFFEEEEEE),
                                        child: const Icon(
                                          Icons.broken_image,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ]),

                      // ══ Накладная от ТК ═══════════════════════════════
                      if (item.tkWaybillPhotoUrl != null) ...[
                        const SizedBox(height: 20),
                        _buildSection('Накладная от ТК', [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              ApiConfig.getMediaUrl(item.tkWaybillPhotoUrl!),
                              width: double.infinity,
                              cacheWidth: 1200,
                              fit: BoxFit.cover,
                              filterQuality: FilterQuality.low,
                              errorBuilder: (_, _, _) => Container(
                                height: 120,
                                color: const Color(0xFFEEEEEE),
                                child: const Center(
                                  child: Icon(
                                    Icons.broken_image,
                                    color: Colors.grey,
                                    size: 40,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ]),
                      ],
                      const SizedBox(height: 20),

                      // ══ Финансовая информация ════════════════════════════
                      _buildSection('Финансовая информация', [
                        // Коэффициент фотоотчёта
                        if (item.photoReportCoefficient != null &&
                            item.photoReportCoefficient! != 1.0) ...[
                          _buildInfoRow(
                            context,
                            'Коэф. фотоотчёта',
                            'x${item.photoReportCoefficient!.toStringAsFixed(2)}',
                          ),
                          if (item.totalTracks > 0)
                            _buildInfoRow(
                              context,
                              'Треки с фото / без',
                              '${item.tracksWithPhoto} / '
                                  '${item.totalTracks - item.tracksWithPhoto} '
                                  'из ${item.totalTracks}',
                            ),
                        ],

                        // Тариф: базовый
                        if (item.clientPricePerKg != null &&
                            item.clientPricePerKg! > 0)
                          _buildInfoRow(
                            context,
                            'Тариф',
                            '\$${item.clientPricePerKg!.toStringAsFixed(2)}/кг',
                          ),

                        // Коэффициент за фото
                        if (item.photoReportCoefficient != null &&
                            item.photoReportCoefficient! > 1.0)
                          _buildInfoRow(
                            context,
                            'Коэфф. фото',
                            '×${item.photoReportCoefficient!.toStringAsFixed(2)}',
                          ),

                        // Итоговый тариф с коэффициентом
                        if (item.clientPricePerKgWithPhoto != null &&
                            item.clientPricePerKgWithPhoto! > 0 &&
                            item.clientPricePerKgWithPhoto !=
                                item.clientPricePerKg)
                          _buildInfoRow(
                            context,
                            'Итого тариф',
                            '\$${item.clientPricePerKgWithPhoto!.toStringAsFixed(2)}/кг',
                          ),

                        // Стоимость по тарифу
                        if (item.shippingCost != null && item.shippingCost! > 0)
                          _buildInfoRow(
                            context,
                            'Стоимость по тарифу',
                            '\$${item.shippingCost!.toStringAsFixed(2)}',
                          ),

                        const Divider(height: 20),

                        // Разгрузка
                        if (item.transshipmentCost != null &&
                            item.transshipmentCost! > 0)
                          _buildInfoRow(
                            context,
                            'Разгрузка',
                            '\$${item.transshipmentCost!.toStringAsFixed(2)}',
                          ),

                        // Упаковка считается за все места, а не за одну коробку.
                        if (item.resolvedPackagingCostTotal != null &&
                            item.resolvedPackagingCostTotal! > 0)
                          _buildInfoRow(
                            context,
                            _packagingLabel(item),
                            '\$${item.resolvedPackagingCostTotal!.toStringAsFixed(2)}',
                          ),

                        // Страховка — показываем только если есть стоимость
                        if ((item.insuranceCostClient != null &&
                                item.insuranceCostClient! > 0) ||
                            (item.insuranceCost != null &&
                                item.insuranceCost! > 0)) ...[
                          if (item.insurancePercentClient != null &&
                              item.insurancePercentClient! > 0)
                            _buildInfoRow(
                              context,
                              'Страховка',
                              '${item.insurancePercentClient!.toStringAsFixed(1)}%',
                            )
                          else if (item.insurancePercent != null &&
                              item.insurancePercent! > 0)
                            _buildInfoRow(
                              context,
                              'Страховка',
                              '${item.insurancePercent!.toStringAsFixed(1)}%',
                            ),
                          if (item.insuranceCostClient != null &&
                              item.insuranceCostClient! > 0)
                            _buildInfoRow(
                              context,
                              'Страховка',
                              '\$${item.insuranceCostClient!.toStringAsFixed(2)}',
                            )
                          else if (item.insuranceCost != null &&
                              item.insuranceCost! > 0)
                            _buildInfoRow(
                              context,
                              'Страховка',
                              '\$${item.insuranceCost!.toStringAsFixed(2)}',
                            ),
                        ],

                        // Скидка
                        if (item.discountAmount != null &&
                            item.discountAmount! > 0)
                          _buildInfoRow(
                            context,
                            'Скидка',
                            '−\$${item.discountAmount!.toStringAsFixed(2)}',
                          ),

                        // Применённые бонусные кг
                        if (item.bonusKgApplied > 0)
                          _buildInfoRow(
                            context,
                            'Оплата бонусами',
                            '−${item.bonusKgApplied.toStringAsFixed(2)} кг',
                          ),

                        const Divider(height: 20),

                        // Стоимость доставки в $
                        if (item.totalCostUsd > 0)
                          _buildInfoRow(
                            context,
                            'Стоимость доставки',
                            '\$${item.totalCostUsd.toStringAsFixed(2)}',
                            isTotal: true,
                          ),

                        // К оплате в ¥
                        if (item.totalCostCny > 0) ...[
                          const SizedBox(height: 4),
                          _buildInfoRow(
                            context,
                            'К оплате в юанях',
                            '¥${money.format(item.totalCostCny.round())}',
                            isTotal: true,
                          ),
                        ],

                        // К оплате в ₽
                        if (item.totalCostRub > 0) ...[
                          const SizedBox(height: 4),
                          _buildInfoRow(
                            context,
                            'К оплате в рублях',
                            '${money.format(item.totalCostRub.round())} ₽',
                            isTotal: true,
                          ),
                        ],

                        // Курс валют (только если есть)
                        if (item.clientRubRate != null ||
                            item.clientYuanRate != null) ...[
                          const Divider(height: 20),
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
                        ],
                      ]),
                      const SizedBox(height: 24),

                      // ══ Бонусные кг ══════════════════════════════════════
                      if (showBonusSection) ...[
                        const Text(
                          'Бонусные кг',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF333333),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.scale_rounded,
                                    color: Colors.green.shade700,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Доступно: ${widget.bonusBalance.toStringAsFixed(2)} кг',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                                ],
                              ),
                              if (item.bonusKgApplied > 0) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Уже применено: ${item.bonusKgApplied.toStringAsFixed(2)} кг',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.green.shade600,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _bonusKgCtrl,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      inputFormatters: [
                                        FilteringTextInputFormatter.allow(
                                          RegExp(r'^\d+[.,]?\d*'),
                                        ),
                                      ],
                                      decoration: appInputDecoration(
                                        context,
                                        hintText:
                                            'Кол-во кг (макс ${maxKg.toStringAsFixed(2)})',
                                        fillColor: Colors.white,
                                        isDense: true,
                                        borderColor: Colors.green.shade300,
                                        focusedBorderColor:
                                            Colors.green.shade600,
                                        focusedWidth: 2,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
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
                                      onPressed: _isApplyingBonus
                                          ? null
                                          : _applyBonusKg,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green.shade600,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                        ),
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
                              if (enteredKg > 0 && pricePerKg > 0) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Скидка: ~\$${bonusDiscount.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.green.shade700,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // ══ Кнопка оплаты ════════════════════════════════════
                      if (_isUnpaid)
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: widget.onPay,
                            child: const Text('Перейти к оплате'),
                          ),
                        ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    if (children.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F8F8),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(children: children),
        ),
      ],
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

  String _packagingLabel(InvoiceItem item) {
    final name = item.packagingNames;
    final base = name.isEmpty ? 'Упаковка' : 'Упаковка: $name';
    if (item.billablePlacesCount > 1 && item.packagingUnitCost > 0) {
      return '$base ×${item.billablePlacesCount}';
    }
    return base;
  }
}
