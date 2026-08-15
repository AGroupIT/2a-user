import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/ui/animated_hero_glow_backdrop.dart';
import '../../../core/ui/app_colors.dart';
import '../../../core/ui/app_layout.dart';
import '../../../core/ui/app_toast.dart';
import '../../../core/ui/scroll_to_top_button.dart';
import '../../../core/ui/tutorial_card.dart';
import '../../../core/utils/clipboard_helper.dart';
import '../../../core/utils/locale_text.dart';
import '../data/client_partner_program_provider.dart';

BoxDecoration _programCardDecoration({Color color = Colors.white}) {
  return BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(24),
    border: Border.all(color: Colors.black.withValues(alpha: 0.035)),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.05),
        blurRadius: 24,
        spreadRadius: -14,
        offset: const Offset(0, 14),
      ),
    ],
  );
}

String _usd(double value) {
  return NumberFormat.currency(
    locale: 'en_US',
    symbol: r'$',
    decimalDigits: 2,
  ).format(value);
}

class PartnerProgramScreen extends ConsumerStatefulWidget {
  const PartnerProgramScreen({super.key});

  @override
  ConsumerState<PartnerProgramScreen> createState() =>
      _PartnerProgramScreenState();
}

class _PartnerProgramScreenState extends ConsumerState<PartnerProgramScreen> {
  final _scrollController = ScrollController();
  final _summaryKey = GlobalKey();
  final _inviteKey = GlobalKey();
  final _payoutsKey = GlobalKey();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(clientPartnerProgramProvider);
    await ref.read(clientPartnerProgramProvider.future);
  }

  Future<void> _copyInvite(String inviteUrl) async {
    final copied = await AppClipboard.copyText(inviteUrl);
    if (!mounted) return;
    AppToast.show(
      context,
      copied
          ? tr(context, ru: 'Ссылка скопирована', zh: '邀请链接已复制')
          : tr(context, ru: 'Не удалось скопировать ссылку', zh: '无法复制邀请链接'),
      isError: !copied,
    );
  }

  void _shareInvite(String inviteUrl) {
    Share.share(
      tr(
        context,
        ru: 'Зарегистрируйтесь в 2A Logistic по моей ссылке: $inviteUrl',
        zh: '通过我的邀请链接注册 2A Logistic：$inviteUrl',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final programAsync = ref.watch(clientPartnerProgramProvider);
    final topPad = AppLayout.topBarTotalHeight(context);
    final bottomPad = AppLayout.bottomScrollPadding(context);

    return TutorialScreenWrapper(
      screenKey: 'partner_program',
      steps: [
        TutorialStep(
          icon: Icons.handshake_rounded,
          title: tr(context, ru: 'Партнёрская программа', zh: '合作伙伴计划'),
          description: tr(
            context,
            ru: 'Здесь собраны ваш статус, заработок и результаты приглашений.',
            zh: '这里汇总您的合作状态、收益和邀请结果。',
          ),
          targetKey: _summaryKey,
        ),
        TutorialStep(
          icon: Icons.link_rounded,
          title: tr(context, ru: 'Ссылка приглашения', zh: '邀请链接'),
          description: tr(
            context,
            ru: 'Скопируйте ссылку или отправьте её будущему клиенту.',
            zh: '复制链接或将其发送给新客户。',
          ),
          targetKey: _inviteKey,
        ),
        TutorialStep(
          icon: Icons.payments_rounded,
          title: tr(context, ru: 'Начисления и выплаты', zh: '佣金与付款'),
          description: tr(
            context,
            ru: 'Следите за периодами, суммами и статусами выплат.',
            zh: '查看结算周期、金额和付款状态。',
          ),
          targetKey: _payoutsKey,
        ),
      ],
      child: programAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: context.brandPrimary),
        ),
        error: (_, _) => _PartnerProgramErrorState(
          onRetry: () => ref.invalidate(clientPartnerProgramProvider),
        ),
        data: (data) => Stack(
          children: [
            RefreshIndicator(
              onRefresh: _refresh,
              color: context.brandPrimary,
              child: ListView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  16,
                  topPad * 0.7 + 16,
                  16,
                  bottomPad + 16,
                ),
                children: [
                  const _PartnerProgramPageHeader(),
                  const SizedBox(height: 12),
                  if (data == null)
                    const _PartnerProgramUnavailableState()
                  else ...[
                    KeyedSubtree(
                      key: _summaryKey,
                      child: _PartnerProgramHero(data: data),
                    ),
                    const SizedBox(height: 14),
                    KeyedSubtree(
                      key: _inviteKey,
                      child: _PartnerInviteCard(
                        data: data,
                        onCopy: _copyInvite,
                        onShare: _shareInvite,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _PartnerMetricsCard(data: data),
                    const SizedBox(height: 14),
                    _PartnerTermsCard(data: data),
                    const SizedBox(height: 14),
                    KeyedSubtree(
                      key: _payoutsKey,
                      child: _PartnerPayoutsCard(payouts: data.payouts),
                    ),
                  ],
                ],
              ),
            ),
            ScrollToTopButton(controller: _scrollController),
          ],
        ),
      ),
    );
  }
}

class _PartnerProgramPageHeader extends StatelessWidget {
  const _PartnerProgramPageHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/');
              }
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 46,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.black.withValues(alpha: 0.035),
                ),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            tr(context, ru: 'Партнёрская программа', zh: '合作伙伴计划'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontFamily: 'Gilroy',
              fontSize: 26,
              height: 1.05,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.35,
            ),
          ),
        ),
      ],
    );
  }
}

class _PartnerProgramHero extends StatelessWidget {
  const _PartnerProgramHero({required this.data});

  final ClientPartnerProgramData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: context.brandGradient,
        borderRadius: BorderRadius.circular(24),
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
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            const Positioned.fill(child: AnimatedHeroGlowBackdrop()),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.22),
                          ),
                        ),
                        child: const Icon(
                          Icons.handshake_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tr(
                                context,
                                ru: 'Ваш партнёрский кабинет',
                                zh: '您的合作伙伴中心',
                              ),
                              style: const TextStyle(
                                color: Colors.white,
                                fontFamily: 'Gilroy',
                                fontSize: 22,
                                height: 1.08,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              data.partnerCode.isEmpty
                                  ? tr(
                                      context,
                                      ru: 'Код партнёра не указан',
                                      zh: '未设置合作伙伴代码',
                                    )
                                  : '${tr(context, ru: 'Код партнёра', zh: '合作伙伴代码')}: ${data.partnerCode}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.78),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _PartnerStatusChip(active: data.active),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    tr(context, ru: 'Доступно к выплате', zh: '可提现金额'),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.74),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _usd(data.payableUsd),
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Gilroy',
                      fontSize: 32,
                      height: 1,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 13),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _HeroInfoChip(
                        icon: Icons.stacked_line_chart_rounded,
                        label:
                            '${tr(context, ru: 'За всё время', zh: '累计收益')} ${_usd(data.lifetimeEarnedUsd)}',
                      ),
                      _HeroInfoChip(
                        icon: Icons.group_rounded,
                        label:
                            '${data.registeredCount} ${tr(context, ru: 'клиентов', zh: '位客户')}',
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

class _PartnerStatusChip extends StatelessWidget {
  const _PartnerStatusChip({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: active ? 0.18 : 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
      ),
      child: Text(
        active
            ? tr(context, ru: 'Активна', zh: '已启用')
            : tr(context, ru: 'Отключена', zh: '已停用'),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _HeroInfoChip extends StatelessWidget {
  const _HeroInfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 15),
          const SizedBox(width: 6),
          Flexible(
            fit: FlexFit.loose,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PartnerInviteCard extends StatelessWidget {
  const _PartnerInviteCard({
    required this.data,
    required this.onCopy,
    required this.onShare,
  });

  final ClientPartnerProgramData data;
  final ValueChanged<String> onCopy;
  final ValueChanged<String> onShare;

  @override
  Widget build(BuildContext context) {
    final inviteUrl = data.inviteUrl;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _programCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeading(
            icon: Icons.link_rounded,
            title: tr(context, ru: 'Ссылка приглашения', zh: '邀请链接'),
          ),
          const SizedBox(height: 12),
          Text(
            inviteUrl == null
                ? tr(
                    context,
                    ru: data.active
                        ? 'Ссылка пока не сформирована. Обратитесь к менеджеру.'
                        : 'Приглашения станут доступны после активации программы.',
                    zh: data.active ? '邀请链接尚未生成，请联系经理。' : '计划启用后即可使用邀请功能。',
                  )
                : tr(
                    context,
                    ru: 'Отправьте эту ссылку новому клиенту. Регистрация автоматически будет закреплена за вами.',
                    zh: '将此链接发送给新客户，注册后客户将自动关联到您。',
                  ),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12.5,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (inviteUrl != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: context.brandPrimary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: context.brandPrimary.withValues(alpha: 0.14),
                ),
              ),
              child: SelectableText(
                inviteUrl,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12.5,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (data.shortCode != null) ...[
              const SizedBox(height: 9),
              Text(
                '${tr(context, ru: 'Короткий код', zh: '短代码')}: ${data.shortCode}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final copyButton = FilledButton.icon(
                  onPressed: () => onCopy(inviteUrl),
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: Text(tr(context, ru: 'Копировать', zh: '复制')),
                );
                final shareButton = OutlinedButton.icon(
                  onPressed: () => onShare(inviteUrl),
                  icon: const Icon(Icons.ios_share_rounded, size: 18),
                  label: Text(tr(context, ru: 'Поделиться', zh: '分享')),
                );

                if (constraints.maxWidth < 300) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      copyButton,
                      const SizedBox(height: 8),
                      shareButton,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: copyButton),
                    const SizedBox(width: 9),
                    Expanded(child: shareButton),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _PartnerMetricsCard extends StatelessWidget {
  const _PartnerMetricsCard({required this.data});

  final ClientPartnerProgramData data;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      _MetricData(
        tr(context, ru: 'Зарегистрировано', zh: '已注册'),
        data.registeredCount.toString(),
        Icons.person_add_alt_1_rounded,
      ),
      _MetricData(
        tr(context, ru: 'Ожидают отправки', zh: '待发货重量'),
        '${data.awaitingWeightKg.toStringAsFixed(3)} ${tr(context, ru: 'кг', zh: '公斤')}',
        Icons.hourglass_top_rounded,
      ),
      _MetricData(
        tr(context, ru: 'Оплачено', zh: '已付款重量'),
        '${data.paidWeightKg.toStringAsFixed(3)} ${tr(context, ru: 'кг', zh: '公斤')}',
        Icons.scale_rounded,
      ),
      _MetricData(
        tr(context, ru: 'Доступно к выплате', zh: '可提现'),
        _usd(data.payableUsd),
        Icons.account_balance_wallet_rounded,
      ),
      _MetricData(
        tr(context, ru: 'Выплачено', zh: '已支付'),
        _usd(data.paidUsd),
        Icons.check_circle_rounded,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _programCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeading(
            icon: Icons.analytics_rounded,
            title: tr(context, ru: 'Результаты программы', zh: '计划数据'),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 680 ? 3 : 2;
              const spacing = 9.0;
              final width =
                  (constraints.maxWidth - spacing * (columns - 1)) / columns;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  for (final metric in metrics)
                    SizedBox(
                      width: width,
                      child: _PartnerMetric(data: metric),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MetricData {
  const _MetricData(this.label, this.value, this.icon);

  final String label;
  final String value;
  final IconData icon;
}

class _PartnerMetric extends StatelessWidget {
  const _PartnerMetric({required this.data});

  final _MetricData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 92),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: Colors.black.withValues(alpha: 0.025)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(data.icon, color: context.brandPrimary, size: 19),
          const SizedBox(height: 10),
          Text(
            data.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontFamily: 'Gilroy',
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            data.label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10.5,
              height: 1.15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PartnerTermsCard extends StatelessWidget {
  const _PartnerTermsCard({required this.data});

  final ClientPartnerProgramData data;

  @override
  Widget build(BuildContext context) {
    final rate = data.rateUsdPerKg;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _programCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeading(
            icon: Icons.rule_folder_rounded,
            title: tr(context, ru: 'Условия начисления', zh: '佣金规则'),
          ),
          const SizedBox(height: 12),
          _TermsRow(
            label: tr(context, ru: 'Префикс клиентов', zh: '客户前缀'),
            value: data.prefix ?? '—',
          ),
          const SizedBox(height: 9),
          _TermsRow(
            label: tr(context, ru: 'Ставка', zh: '费率'),
            value: rate == null ? '—' : '${rate.toStringAsFixed(4)} USD/кг',
          ),
          const SizedBox(height: 12),
          Text(
            tr(
              context,
              ru: 'Начисления рассчитываются сервером по фактически оплаченным перевозкам приглашённых клиентов.',
              zh: '佣金由服务器根据受邀客户实际支付的运输费用计算。',
            ),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _TermsRow extends StatelessWidget {
  const _TermsRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _PartnerPayoutsCard extends StatelessWidget {
  const _PartnerPayoutsCard({required this.payouts});

  final List<ClientPartnerPayout> payouts;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _programCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeading(
            icon: Icons.payments_rounded,
            title: tr(context, ru: 'Начисления и выплаты', zh: '佣金与付款'),
            trailing: payouts.length.toString(),
          ),
          const SizedBox(height: 12),
          if (payouts.isEmpty)
            _EmptyPayouts()
          else
            for (var index = 0; index < payouts.length; index++) ...[
              if (index > 0) const SizedBox(height: 9),
              _PartnerPayoutTile(payout: payouts[index]),
            ],
        ],
      ),
    );
  }
}

class _PartnerPayoutTile extends StatelessWidget {
  const _PartnerPayoutTile({required this.payout});

  final ClientPartnerPayout payout;

  @override
  Widget build(BuildContext context) {
    final paid = payout.status == 'paid';
    final amount = payout.paidAmountUsd ?? payout.payableAmountUsd;
    final date = DateFormat('dd.MM.yyyy');
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: Colors.black.withValues(alpha: 0.025)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: (paid ? const Color(0xFF2E9D68) : AppColors.brandOrange)
                  .withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              paid ? Icons.check_rounded : Icons.schedule_rounded,
              color: paid ? const Color(0xFF2E9D68) : AppColors.brandOrange,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${date.format(payout.periodFrom.toLocal())} — ${date.format(payout.periodTo.toLocal())}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  paid
                      ? tr(context, ru: 'Выплачено', zh: '已支付')
                      : tr(context, ru: 'Ожидает выплаты', zh: '待支付'),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _usd(amount),
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontFamily: 'Gilroy',
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyPayouts extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(
            Icons.payments_outlined,
            color: context.brandPrimary.withValues(alpha: 0.72),
            size: 30,
          ),
          const SizedBox(height: 8),
          Text(
            tr(context, ru: 'Выплат пока нет', zh: '暂无付款记录'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            tr(
              context,
              ru: 'История появится после первого расчётного периода.',
              zh: '首个结算周期结束后，此处将显示记录。',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11.5,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.icon,
    required this.title,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: context.brandPrimary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: context.brandPrimary, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontFamily: 'Gilroy',
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        if (trailing != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: context.brandPrimary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              trailing!,
              style: TextStyle(
                color: context.brandPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
      ],
    );
  }
}

class _PartnerProgramUnavailableState extends StatelessWidget {
  const _PartnerProgramUnavailableState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _programCardDecoration(),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: context.brandPrimary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(
              Icons.handshake_outlined,
              color: context.brandPrimary,
              size: 31,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            tr(
              context,
              ru: 'Партнёрская программа не подключена',
              zh: '尚未加入合作伙伴计划',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontFamily: 'Gilroy',
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            tr(
              context,
              ru: 'Если вы хотите приглашать клиентов и получать комиссию, обратитесь к своему менеджеру.',
              zh: '如需邀请客户并获得佣金，请联系您的经理。',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _PartnerProgramErrorState extends StatelessWidget {
  const _PartnerProgramErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(22),
          decoration: _programCardDecoration(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                color: AppColors.brandOrange,
                size: 38,
              ),
              const SizedBox(height: 12),
              Text(
                tr(
                  context,
                  ru: 'Не удалось загрузить партнёрскую программу',
                  zh: '无法加载合作伙伴计划',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontFamily: 'Gilroy',
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(tr(context, ru: 'Повторить', zh: '重试')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
