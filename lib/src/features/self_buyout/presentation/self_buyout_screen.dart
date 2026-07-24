import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/app_colors.dart';
import '../../../core/ui/app_layout.dart';
import '../../../core/ui/blurred_modal_bottom_sheet.dart';
import '../../../core/utils/locale_text.dart';
import '../../purchase_blanks/presentation/purchase_blank_ui.dart';
import '../data/self_buyout_models.dart';
import '../data/self_buyout_service.dart';
import 'self_buyout_create_sheet.dart';
import 'self_buyout_detail_sheet.dart';
import 'self_buyout_qr_sheet.dart';
import 'self_buyout_ui.dart';

class SelfBuyoutScreen extends ConsumerStatefulWidget {
  const SelfBuyoutScreen({super.key});

  @override
  ConsumerState<SelfBuyoutScreen> createState() => _SelfBuyoutScreenState();
}

class _SelfBuyoutScreenState extends ConsumerState<SelfBuyoutScreen> {
  Timer? _operatorStatusTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.invalidate(selfBuyoutAvailabilityProvider);
    });
    _operatorStatusTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      ref.invalidate(selfBuyoutAvailabilityProvider);
    });
  }

  @override
  void dispose() {
    _operatorStatusTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final requestsAsync = ref.watch(selfBuyoutRequestsProvider);
    final availability = ref
        .watch(selfBuyoutAvailabilityProvider)
        .asData
        ?.value;
    final topPad = AppLayout.topBarTotalHeight(context);
    final bottomPad = AppLayout.bottomScrollPadding(context);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(selfBuyoutRequestsProvider);
        ref.invalidate(selfBuyoutAvailabilityProvider);
        await Future.wait([
          ref.read(selfBuyoutRequestsProvider.future),
          ref.read(selfBuyoutAvailabilityProvider.future),
        ]);
      },
      color: context.brandPrimary,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16, topPad * 0.7 + 16, 16, bottomPad + 16),
        children: [
          const PurchaseBlankPageHeader(title: 'Самовыкуп'),
          const SizedBox(height: 12),
          _hero(context, ref, availability),
          const SizedBox(height: 18),
          requestsAsync.when(
            data: (rows) => _list(context, ref, rows),
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => _errorBox(context, ref),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _hero(
    BuildContext context,
    WidgetRef ref,
    SelfBuyoutAvailability? availability,
  ) {
    final canCreate = availability?.available ?? false;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: context.brandGradient,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: context.brandPrimary.withValues(alpha: 0.20),
            blurRadius: 26,
            spreadRadius: -14,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PurchaseBlankHeroChip(
                icon: Icons.savings_rounded,
                label: tr(context, ru: 'Самовыкуп', zh: '自助代购'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            tr(context, ru: 'Помощь в самовыкупе', zh: '自助代购协助'),
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'Gilroy',
              fontSize: 22,
              height: 1.1,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            tr(
              context,
              ru: 'Мы помогаем вам самостоятельно выкупить товары с нужных площадок, предоставляя нужное количество юаней.',
              zh: '我们为您提供所需数量的人民币，帮助您自行在平台购买商品。',
            ),
            style: const TextStyle(
              color: Color(0xE6FFFFFF),
              fontFamily: 'Gilroy',
              fontSize: 13.5,
              height: 1.3,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _operatorStatus(context, availability),
          const SizedBox(height: 16),
          _heroButton(context, ref, canCreate, availability),
          if (!canCreate &&
              _availabilityMessage(context, availability) != null) ...[
            const SizedBox(height: 10),
            Text(
              _availabilityMessage(context, availability)!,
              style: const TextStyle(
                color: Color(0xE6FFFFFF),
                fontFamily: 'Gilroy',
                fontSize: 12.5,
                height: 1.25,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _operatorStatus(
    BuildContext context,
    SelfBuyoutAvailability? availability,
  ) {
    final isLoading = availability == null;
    final sleeping = availability?.operatorSleeping;

    final IconData icon;
    final String label;
    final Color accent;
    if (isLoading) {
      icon = Icons.sync_rounded;
      label = tr(
        context,
        ru: 'Проверяем режим работы операторов',
        zh: '正在检查客服工作状态',
      );
      accent = Colors.white;
    } else if (sleeping == true) {
      icon = Icons.bedtime_rounded;
      label = tr(context, ru: 'Операторы сейчас отдыхают', zh: '客服当前休息中');
      accent = const Color(0xFFFFD59A);
    } else {
      icon = Icons.support_agent_rounded;
      label = tr(context, ru: 'Операторы сейчас работают', zh: '客服当前在线');
      accent = const Color(0xFFB8F5D8);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: accent),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: accent,
                fontFamily: 'Gilroy',
                fontSize: 12.5,
                height: 1.2,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _availabilityMessage(
    BuildContext context,
    SelfBuyoutAvailability? availability,
  ) {
    final reason = availability?.reason;
    if (reason == 'rate_stale' ||
        reason == 'no_rate' ||
        reason == 'rate_invalid') {
      return tr(
        context,
        ru: 'Создать заявку на самовыкуп можно будет после обновления курсов валют. Ожидайте обновления курсов.',
        zh: '汇率更新后即可创建自助代购申请，请等待汇率更新。',
      );
    }
    if (reason == 'client_disabled') {
      return availability?.disabledReason ??
          tr(
            context,
            ru: 'Самовыкуп для вашего аккаунта временно недоступен.',
            zh: '您的账户暂时无法使用自助代购。',
          );
    }
    if (reason == 'feature_disabled') {
      return tr(context, ru: 'Самовыкуп временно недоступен.', zh: '自助代购暂不可用。');
    }
    return null;
  }

  Widget _heroButton(
    BuildContext context,
    WidgetRef ref,
    bool canCreate,
    SelfBuyoutAvailability? availability,
  ) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: canCreate
            ? () => _openCreate(context, ref, availability!)
            : null,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 48,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_rounded, color: context.brandPrimary, size: 20),
              const SizedBox(width: 8),
              Text(
                canCreate
                    ? tr(context, ru: 'Создать заявку', zh: '创建申请')
                    : tr(context, ru: 'Временно недоступно', zh: '暂不可用'),
                style: TextStyle(
                  color: context.brandPrimary,
                  fontFamily: 'Gilroy',
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _list(
    BuildContext context,
    WidgetRef ref,
    List<SelfBuyoutRequest> rows,
  ) {
    if (rows.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
        decoration: PurchaseBlankUi.cardDecoration(),
        child: Column(
          children: [
            const Icon(
              Icons.inbox_rounded,
              size: 40,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 10),
            Text(
              tr(context, ru: 'Заявок пока нет', zh: '暂无申请'),
              style: PurchaseBlankUi.bodyStyle,
            ),
          ],
        ),
      );
    }
    return Column(
      children: [
        for (final r in rows) ...[
          _RequestCard(request: r, onTap: () => _onCardTap(context, ref, r)),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _errorBox(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: PurchaseBlankUi.cardDecoration(),
      child: Column(
        children: [
          Text(
            tr(context, ru: 'Не удалось загрузить заявки', zh: '无法加载申请'),
            style: PurchaseBlankUi.bodyStyle,
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => ref.invalidate(selfBuyoutRequestsProvider),
            child: Text(tr(context, ru: 'Повторить', zh: '重试')),
          ),
        ],
      ),
    );
  }

  Future<void> _openCreate(
    BuildContext context,
    WidgetRef ref,
    SelfBuyoutAvailability availability,
  ) async {
    final created = await showBlurredModalBottomSheet<SelfBuyoutRequest>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.22),
      builder: (_) => SelfBuyoutCreateSheet(availability: availability),
    );
    if (created != null && context.mounted) {
      ref.invalidate(selfBuyoutRequestsProvider);
      await _openQr(context, ref, created);
    }
  }

  Future<void> _onCardTap(
    BuildContext context,
    WidgetRef ref,
    SelfBuyoutRequest r,
  ) async {
    final action = await showBlurredModalBottomSheet<SelfBuyoutDetailAction>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.22),
      builder: (_) => SelfBuyoutDetailSheet(request: r),
    );
    if (!context.mounted) return;
    switch (action) {
      case SelfBuyoutDetailAction.continuePayment:
        await _openQr(context, ref, r);
      case SelfBuyoutDetailAction.correctRequisites:
        await _correctRequisites(context, ref, r);
      case null:
        break;
    }
  }

  Future<void> _correctRequisites(
    BuildContext context,
    WidgetRef ref,
    SelfBuyoutRequest request,
  ) async {
    final corrected = await showBlurredModalBottomSheet<SelfBuyoutRequest>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.22),
      builder: (_) =>
          SelfBuyoutCreateSheet.correctRequisites(correctionRequest: request),
    );
    if (corrected != null) {
      ref.invalidate(selfBuyoutRequestsProvider);
    }
  }

  Future<void> _openQr(
    BuildContext context,
    WidgetRef ref,
    SelfBuyoutRequest r,
  ) async {
    final changed = await showBlurredModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.22),
      builder: (_) => SelfBuyoutQrSheet(
        requestId: r.id,
        requestNumber: r.requestNumber,
        cnyAmount: r.requestedCnyAmount,
      ),
    );
    if (changed == true) {
      ref.invalidate(selfBuyoutRequestsProvider);
    }
  }
}

class _RequestCard extends StatelessWidget {
  final SelfBuyoutRequest request;
  final VoidCallback onTap;

  const _RequestCard({required this.request, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = selfBuyoutStatusColor(request.status);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: PurchaseBlankUi.cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      request.requestNumber,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontFamily: 'Gilroy',
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      selfBuyoutStatusLabel(context, request.status),
                      style: TextStyle(
                        color: color,
                        fontFamily: 'Gilroy',
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _kv(
                      tr(context, ru: 'Юани', zh: '人民币'),
                      '${request.requestedCnyAmount.toStringAsFixed(2)} RMB',
                    ),
                  ),
                  Expanded(
                    child: _kv(
                      tr(context, ru: 'К оплате', zh: '应付'),
                      '${request.paymentRubAmount.toStringAsFixed(2)} ₽',
                    ),
                  ),
                ],
              ),
              if (request.status == 'new' ||
                  request.status == 'awaiting_payment') ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.qr_code_2_rounded,
                      size: 15,
                      color: context.brandPrimary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      tr(context, ru: 'Нажмите, чтобы оплатить', zh: '点击付款'),
                      style: TextStyle(
                        color: context.brandPrimary,
                        fontFamily: 'Gilroy',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _kv(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: PurchaseBlankUi.labelStyle),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontFamily: 'Gilroy',
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}
