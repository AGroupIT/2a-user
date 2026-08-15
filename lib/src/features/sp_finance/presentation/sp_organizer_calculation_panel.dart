import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/app_colors.dart';
import '../../../core/ui/app_toast.dart';
import '../../../core/utils/locale_text.dart';
import '../data/sp_organizer_calculation_models.dart';
import '../data/sp_organizer_provider.dart';
import 'sp_organizer_calculation_profile_sheet.dart';
import 'sp_finance_ui.dart';

class SpOrganizerCalculationPanel extends ConsumerStatefulWidget {
  final int purchaseId;

  const SpOrganizerCalculationPanel({super.key, required this.purchaseId});

  @override
  ConsumerState<SpOrganizerCalculationPanel> createState() =>
      _SpOrganizerCalculationPanelState();
}

class _SpOrganizerCalculationPanelState
    extends ConsumerState<SpOrganizerCalculationPanel> {
  bool _applying = false;
  bool _posting = false;
  bool _actualizing = false;
  bool _confirmationPending = false;

  @override
  Widget build(BuildContext context) {
    final previewAsync = ref.watch(
      spOrganizerCalculationPreviewProvider(widget.purchaseId),
    );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: SpFinanceUi.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: context.brandPrimary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  Icons.calculate_rounded,
                  color: context.brandPrimary,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr(context, ru: 'Параметры расчёта', zh: '结算参数'),
                      style: SpFinanceUi.sectionTitleStyle,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tr(
                        context,
                        ru: 'Для себя и для клиента · безопасный preview',
                        zh: '自用与客户 · 安全预览',
                      ),
                      style: SpFinanceUi.labelStyle,
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SpFinanceHeaderActionButton(
                    tooltip: tr(context, ru: 'Настроить профиль', zh: '设置结算配置'),
                    onTap: previewAsync.asData == null
                        ? null
                        : () =>
                              _editProfile(context, previewAsync.requireValue),
                    child: Icon(
                      Icons.tune_rounded,
                      color: context.brandPrimary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 6),
                  SpFinanceHeaderActionButton(
                    tooltip: tr(context, ru: 'Обновить расчёт', zh: '刷新结算'),
                    onTap: () => ref.invalidate(
                      spOrganizerCalculationPreviewProvider(widget.purchaseId),
                    ),
                    child: Icon(
                      Icons.refresh_rounded,
                      color: context.brandPrimary,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          previewAsync.when(
            loading: () => const SizedBox(
              height: 104,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (error, _) => _CalculationError(
              message:
                  '${tr(context, ru: 'Не удалось получить расчёт', zh: '无法获取结算')}: $error',
              onRetry: () => ref.invalidate(
                spOrganizerCalculationPreviewProvider(widget.purchaseId),
              ),
            ),
            data: (preview) => _CalculationContent(
              preview: preview,
              applying: _applying,
              posting: _posting,
              actualizing: _actualizing,
              onApply: preview.canApplyCalculation
                  ? () => _applyCalculation(preview)
                  : null,
              onPost:
                  preview.canPostAllocation &&
                      preview.currentAppliedSnapshot != null
                  ? () => _postCalculationAllocation(preview)
                  : null,
              onActualize:
                  preview.canActualizeCalculation &&
                      preview.currentAppliedSnapshot != null
                  ? () => _actualizeCalculation(preview)
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editProfile(
    BuildContext context,
    SpOrganizerCalculationPreview preview,
  ) async {
    final saved = await showSpOrganizerCalculationProfileSheet(
      context: context,
      purchaseId: widget.purchaseId,
      selfProfile: preview.effectiveSelfProfile ?? preview.effectiveProfile,
      clientProfile: preview.effectiveClientProfile ?? preview.effectiveProfile,
    );
    if (saved != true || !context.mounted) return;
    ref.invalidate(spOrganizerCalculationPreviewProvider(widget.purchaseId));
  }

  Future<void> _applyCalculation(SpOrganizerCalculationPreview preview) async {
    if (_confirmationPending || _applying || _posting || _actualizing) return;
    _confirmationPending = true;
    bool? confirmed;
    try {
      confirmed = await _confirm(
        title: tr(context, ru: 'Зафиксировать расчёт?', zh: '确认固定结算？'),
        message: tr(
          context,
          ru: 'Будет создан неизменяемый снимок текущего серверного расчёта. Начисления, оплаты, позиции и старые суммы не изменятся.',
          zh: '将创建当前服务器结算的不可变快照。应收、付款、明细和旧金额不会被修改。',
        ),
        confirmLabel: tr(context, ru: 'Зафиксировать', zh: '确认固定'),
      );
    } finally {
      _confirmationPending = false;
    }
    if (confirmed != true || !mounted) return;
    setState(() => _applying = true);
    try {
      final result = await ref
          .read(spOrganizerRepositoryProvider)
          .applyCalculation(widget.purchaseId, inputHash: preview.inputHash);
      if (!mounted) return;
      ref.invalidate(spOrganizerCalculationPreviewProvider(widget.purchaseId));
      _showSuccess(
        result.created
            ? result.referenceAllocationPersisted
                  ? tr(
                      context,
                      ru: 'Расчёт и распределение зафиксированы · версия ${result.snapshot.version}',
                      zh: '结算和分摊已固定 · 版本 ${result.snapshot.version}',
                    )
                  : tr(
                      context,
                      ru: 'Расчёт зафиксирован · версия ${result.snapshot.version}',
                      zh: '结算已固定 · 版本 ${result.snapshot.version}',
                    )
            : tr(context, ru: 'Этот расчёт уже был зафиксирован', zh: '该结算已固定'),
      );
    } catch (error) {
      if (!mounted) return;
      _showError(
        tr(
          context,
          ru: 'Не удалось зафиксировать расчёт. Обновите preview и повторите.',
          zh: '无法固定结算。请刷新预览后重试。',
        ),
      );
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  Future<void> _actualizeCalculation(
    SpOrganizerCalculationPreview preview,
  ) async {
    final appliedSnapshot = preview.currentAppliedSnapshot;
    if (appliedSnapshot == null) return;
    if (_confirmationPending || _applying || _posting || _actualizing) return;
    _confirmationPending = true;
    bool? confirmed;
    try {
      confirmed = await _confirm(
        title: tr(
          context,
          ru: 'Актуализировать обязательства 2A?',
          zh: '更新2A关联应付？',
        ),
        message: tr(
          context,
          ru: 'Снимок соберёт суммы явно связанных самовыкупов, строк Garage и счетов 2A. Возможные пересечения будут отмечены. Долги участников и legacy-прибыль не изменятся.',
          zh: '快照将汇总明确关联的代购、Garage明细和2A账单，并标记可能重复的金额。参与者欠款和旧版利润不会改变。',
        ),
        confirmLabel: tr(context, ru: 'Актуализировать', zh: '更新'),
      );
    } finally {
      _confirmationPending = false;
    }
    if (confirmed != true || !mounted) return;
    setState(() => _actualizing = true);
    try {
      final result = await ref
          .read(spOrganizerRepositoryProvider)
          .actualizeCalculation(
            widget.purchaseId,
            expectedAppliedSnapshotId: appliedSnapshot.id,
          );
      if (!mounted) return;
      ref.invalidate(spOrganizerCalculationPreviewProvider(widget.purchaseId));
      _showSuccess(
        result.created
            ? tr(
                context,
                ru: 'Обязательства 2A актуализированы · версия ${result.snapshot.version}',
                zh: '2A关联应付已更新 · 版本 ${result.snapshot.version}',
              )
            : tr(
                context,
                ru: 'Связанные суммы 2A уже актуальны',
                zh: '2A关联金额已是最新',
              ),
      );
    } catch (error) {
      if (!mounted) return;
      _showError(
        tr(
          context,
          ru: 'Не удалось актуализировать. Сначала обновите и зафиксируйте текущий расчёт.',
          zh: '无法更新。请先刷新并固定当前结算。',
        ),
      );
    } finally {
      if (mounted) setState(() => _actualizing = false);
    }
  }

  Future<void> _postCalculationAllocation(
    SpOrganizerCalculationPreview preview,
  ) async {
    final appliedSnapshot = preview.currentAppliedSnapshot;
    if (appliedSnapshot == null) return;
    if (_confirmationPending || _applying || _posting || _actualizing) return;
    _confirmationPending = true;
    bool? confirmed;
    try {
      confirmed = await _confirm(
        title: tr(
          context,
          ru: 'Начислить зафиксированное распределение?',
          zh: '将固定分摊记入账本？',
        ),
        message: tr(
          context,
          ru: 'Будет создан отдельный неизменяемый ledger новых начислений. Существующие оплаты останутся только в legacy-балансе и не уменьшат новый долг. Старые позиции, оплаты, расходы и суммы не изменятся.',
          zh: '将创建独立且不可变的新应收账本。现有付款只保留在旧版余额中，不会减少新欠款。旧明细、付款、费用和金额均不会更改。',
        ),
        confirmLabel: tr(context, ru: 'Начислить отдельно', zh: '单独入账'),
      );
    } finally {
      _confirmationPending = false;
    }
    if (confirmed != true || !mounted) return;
    setState(() => _posting = true);
    try {
      final result = await ref
          .read(spOrganizerRepositoryProvider)
          .postCalculationAllocation(
            widget.purchaseId,
            expectedAppliedSnapshotId: appliedSnapshot.id,
          );
      if (!mounted) return;
      ref.invalidate(spOrganizerCalculationPreviewProvider(widget.purchaseId));
      _showSuccess(
        result.created
            ? tr(
                context,
                ru: 'Распределение начислено в отдельный ledger · версия ${result.posting.version}',
                zh: '分摊已记入独立账本 · 版本 ${result.posting.version}',
              )
            : tr(
                context,
                ru: 'Это распределение уже начислено отдельно',
                zh: '该分摊已单独入账',
              ),
      );
    } catch (error) {
      if (!mounted) return;
      _showError(
        tr(
          context,
          ru: 'Не удалось начислить распределение. Обновите расчёт и повторите.',
          zh: '无法记入分摊。请刷新结算后重试。',
        ),
      );
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  Future<bool?> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
  }) {
    return showSpFinanceConfirmationSheet(
      context: context,
      icon: Icons.calculate_rounded,
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: tr(context, ru: 'Отмена', zh: '取消'),
    );
  }

  void _showSuccess(String message) {
    AppToast.show(context, message);
  }

  void _showError(String message) {
    AppToast.show(context, message, isError: true);
  }
}

class _CalculationContent extends StatelessWidget {
  final SpOrganizerCalculationPreview preview;
  final bool applying;
  final bool posting;
  final bool actualizing;
  final VoidCallback? onApply;
  final VoidCallback? onPost;
  final VoidCallback? onActualize;

  const _CalculationContent({
    required this.preview,
    required this.applying,
    required this.posting,
    required this.actualizing,
    this.onApply,
    this.onPost,
    this.onActualize,
  });

  @override
  Widget build(BuildContext context) {
    final summary = preview.summary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final tileWidth = constraints.maxWidth >= 700
                ? (constraints.maxWidth - 24) / 4
                : (constraints.maxWidth - 8) / 2;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _CalculationMetric(
                  width: tileWidth,
                  label: tr(context, ru: 'Начислено клиентам', zh: '客户应付'),
                  amount: summary.totalDueRub,
                  color: context.brandPrimary,
                ),
                _CalculationMetric(
                  width: tileWidth,
                  label: tr(context, ru: 'Получено', zh: '已收'),
                  amount: summary.paidRub,
                  color: const Color(0xFF239B63),
                ),
                _CalculationMetric(
                  width: tileWidth,
                  label: tr(context, ru: 'Осталось получить', zh: '待收'),
                  amount: summary.balanceRub,
                  color: const Color(0xFFD97706),
                ),
                _CalculationMetric(
                  width: tileWidth,
                  label: tr(context, ru: 'Ожидаемая прибыль', zh: '预计利润'),
                  amount: summary.totalProfitRub,
                  color: const Color(0xFF6D5BD0),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 10),
        _ProfileNotice(
          selfProfile: preview.effectiveSelfProfile ?? preview.effectiveProfile,
          clientProfile:
              preview.effectiveClientProfile ?? preview.effectiveProfile,
        ),
        if (preview.referencePreview != null) ...[
          const SizedBox(height: 10),
          _ReferencePreviewCard(preview: preview.referencePreview!),
        ],
        if (preview.postedAllocation != null) ...[
          const SizedBox(height: 10),
          _PostedAllocationCard(posting: preview.postedAllocation!),
        ],
        const SizedBox(height: 10),
        _TwoAObligationCard(obligation: preview.organizerTo2A),
        if (preview.participants.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            tr(context, ru: 'Legacy-баланс и оплаты', zh: '旧版余额与付款'),
            style: SpFinanceUi.bodyStyle,
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 92,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: preview.participants.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) => _ParticipantBalanceCard(
                participant: preview.participants[index],
              ),
            ),
          ),
        ],
        if (preview.unallocatedExpensesRub != 0 ||
            preview.unassignedPaidRub != 0) ...[
          const SizedBox(height: 10),
          _AllocationNotice(preview: preview),
        ],
        if (preview.warnings.any(
          (warning) =>
              warning == 'legacy_refund_correction_semantics' ||
              warning == 'legacy_exclusion_flag_not_applied' ||
              warning == 'profile_fields_pending_engine' ||
              warning == 'profile_allocation_pending_engine' ||
              warning == 'profile_apply_pending_engine' ||
              warning == 'profile_ledger_pending_explicit_posting',
        )) ...[
          const SizedBox(height: 10),
          _CalculationWarnings(warnings: preview.warnings),
        ],
        const SizedBox(height: 12),
        _CalculationSnapshotActions(
          preview: preview,
          applying: applying,
          posting: posting,
          actualizing: actualizing,
          onApply: onApply,
          onPost: onPost,
          onActualize: onActualize,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Icon(
              preview.matchesLegacy
                  ? Icons.verified_rounded
                  : Icons.warning_amber_rounded,
              size: 17,
              color: preview.matchesLegacy
                  ? const Color(0xFF239B63)
                  : const Color(0xFFD97706),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                preview.matchesLegacy
                    ? tr(
                        context,
                        ru: 'Суммы совпадают с текущим расчётом СП. Preview не сохранён.',
                        zh: '金额与当前拼团结算一致。预览未保存。',
                      )
                    : tr(
                        context,
                        ru: 'Preview отличается от текущего СП: начисления ${_signedRub(preview.totalDueDeltaRub)}, оплаты ${_signedRub(preview.paidDeltaRub)}, прибыль ${_signedRub(preview.profitDeltaRub)}.',
                        zh: '预览与当前拼团不同：应收 ${_signedRub(preview.totalDueDeltaRub)}，已收 ${_signedRub(preview.paidDeltaRub)}，利润 ${_signedRub(preview.profitDeltaRub)}。',
                      ),
                style: SpFinanceUi.labelStyle,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ReferencePreviewCard extends StatelessWidget {
  final SpOrganizerReferenceCalculationPreview preview;

  const _ReferencePreviewCard({required this.preview});

  @override
  Widget build(BuildContext context) {
    final missing = <String>{
      ...preview.self.missingRequirements,
      ...preview.client.missingRequirements,
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.brandPrimary.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.brandPrimary.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.receipt_long_outlined,
                size: 19,
                color: context.brandPrimary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tr(
                    context,
                    ru: 'Предварительный расчёт по параметрам',
                    zh: '按参数预估',
                  ),
                  style: SpFinanceUi.bodyStyle,
                ),
              ),
              _PreviewStatusChip(complete: preview.complete),
            ],
          ),
          const SizedBox(height: 10),
          _ReferenceScopeAmount(
            title: tr(context, ru: 'Для себя · себестоимость', zh: '自用 · 成本'),
            scope: preview.self,
            color: const Color(0xFF4963D2),
          ),
          const SizedBox(height: 8),
          _ReferenceScopeAmount(
            title: tr(context, ru: 'Для клиента · начисление', zh: '客户 · 应付'),
            scope: preview.client,
            color: context.brandPrimary,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  tr(context, ru: 'Ожидаемая прибыль', zh: '预计利润'),
                  style: SpFinanceUi.labelStyle,
                ),
              ),
              Text(
                _rub(preview.expectedProfitRub),
                style: const TextStyle(
                  color: Color(0xFF6D5BD0),
                  fontFamily: 'Gilroy',
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          if (preview.allocation?.participants.isNotEmpty == true) ...[
            const SizedBox(height: 11),
            Row(
              children: [
                Expanded(
                  child: Text(
                    tr(
                      context,
                      ru: 'Распределение новых параметров',
                      zh: '新参数分摊',
                    ),
                    style: SpFinanceUi.labelStyle.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  preview.allocation!.ledgerPosted
                      ? tr(context, ru: 'начислено отдельно', zh: '已单独入账')
                      : preview.allocation!.applied
                      ? tr(context, ru: 'зафиксировано', zh: '已固定')
                      : tr(context, ru: 'не начислено', zh: '未入账'),
                  style: SpFinanceUi.labelStyle.copyWith(
                    color:
                        preview.allocation!.applied ||
                            preview.allocation!.ledgerPosted
                        ? const Color(0xFF2F7D5B)
                        : const Color(0xFFD97706),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            SizedBox(
              height: 126,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: preview.allocation!.participants.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) => _ReferenceParticipantCard(
                  participant: preview.allocation!.participants[index],
                  ledgerPosted: preview.allocation!.ledgerPosted,
                ),
              ),
            ),
          ],
          if (missing.isNotEmpty) ...[
            const SizedBox(height: 9),
            Text(
              tr(
                context,
                ru: 'Для полного preview: ${_missingReferenceLabels(missing, ru: true)}.',
                zh: '完整预估还需：${_missingReferenceLabels(missing, ru: false)}。',
              ),
              style: SpFinanceUi.labelStyle.copyWith(
                color: const Color(0xFFD97706),
              ),
            ),
          ],
          const SizedBox(height: 7),
          Text(
            preview.allocation?.ledgerPosted == true
                ? tr(
                    context,
                    ru: 'Начислено в отдельном новом ledger. Существующие оплаты остаются только в legacy-балансе и не уменьшают этот новый долг.',
                    zh: '已记入独立的新账本。现有付款仅保留在旧版余额中，不会减少这笔新欠款。',
                  )
                : preview.allocation?.applied == true
                ? tr(
                    context,
                    ru: 'Распределение зафиксировано в неизменяемом снимке, но не начислено: текущие долги и оплаты не изменены.',
                    zh: '分摊已固定在不可变快照中，但尚未入账：当前应收和付款未更改。',
                  )
                : tr(
                    context,
                    ru: 'Расчёт и распределение выполняются на сервере только для preview и не меняют текущие начисления.',
                    zh: '计算和分摊仅在服务器预览中执行，不会修改当前应收。',
                  ),
            style: SpFinanceUi.labelStyle,
          ),
        ],
      ),
    );
  }
}

class _PostedAllocationCard extends StatelessWidget {
  final SpOrganizerPostedAllocation posting;

  const _PostedAllocationCard({required this.posting});

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF2F7D5B);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.065),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.account_balance_wallet_outlined,
                color: accent,
                size: 19,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tr(
                    context,
                    ru: 'Новый ledger начислений · версия ${posting.version}',
                    zh: '新应收账本 · 版本 ${posting.version}',
                  ),
                  style: SpFinanceUi.bodyStyle,
                ),
              ),
              if (posting.stale)
                Text(
                  tr(context, ru: 'устарел', zh: '已过期'),
                  style: SpFinanceUi.labelStyle.copyWith(
                    color: const Color(0xFFD97706),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 7,
            children: [
              _InlineAmount(
                label: tr(context, ru: 'Начислено', zh: '应付'),
                value: posting.totalDueRub,
              ),
              _InlineAmount(
                label: tr(context, ru: 'Оплачено', zh: '已付'),
                value: posting.totalPaidRub,
              ),
              _InlineAmount(
                label: tr(context, ru: 'Новый долг', zh: '新欠款'),
                value: posting.balanceRub,
                valueColor: const Color(0xFFD97706),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            tr(
              context,
              ru: 'Legacy-оплаты не применены к этому ledger. Они продолжают учитываться только в старом балансе.',
              zh: '旧版付款未用于此账本，仍仅计入旧版余额。',
            ),
            style: SpFinanceUi.labelStyle.copyWith(color: accent),
          ),
        ],
      ),
    );
  }
}

class _InlineAmount extends StatelessWidget {
  final String label;
  final double value;
  final Color? valueColor;

  const _InlineAmount({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '$label: ', style: SpFinanceUi.labelStyle),
          TextSpan(
            text: _rub(value),
            style: SpFinanceUi.bodyStyle.copyWith(
              color: valueColor ?? context.brandPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReferenceParticipantCard extends StatelessWidget {
  final SpOrganizerReferenceParticipantAllocation participant;
  final bool ledgerPosted;

  const _ReferenceParticipantCard({
    required this.participant,
    required this.ledgerPosted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 214,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  participant.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SpFinanceUi.bodyStyle,
                ),
              ),
              Text('${participant.itemsCount}', style: SpFinanceUi.labelStyle),
            ],
          ),
          const SizedBox(height: 7),
          _ReferenceParticipantLine(
            label: tr(context, ru: 'Себестоимость', zh: '成本'),
            amount: participant.self.totalRub,
            color: const Color(0xFF4963D2),
          ),
          const SizedBox(height: 4),
          _ReferenceParticipantLine(
            label: ledgerPosted
                ? tr(context, ru: 'Новый долг', zh: '新欠款')
                : tr(context, ru: 'Клиенту', zh: '客户应付'),
            amount: participant.client.totalRub,
            color: context.brandPrimary,
          ),
          const Spacer(),
          _ReferenceParticipantLine(
            label: tr(context, ru: 'Прибыль', zh: '利润'),
            amount: participant.expectedProfitRub,
            color: const Color(0xFF6D5BD0),
            strong: true,
          ),
        ],
      ),
    );
  }
}

class _ReferenceParticipantLine extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final bool strong;

  const _ReferenceParticipantLine({
    required this.label,
    required this.amount,
    required this.color,
    this.strong = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: SpFinanceUi.labelStyle)),
        Text(
          _rub(amount),
          style: TextStyle(
            color: color,
            fontFamily: 'Gilroy',
            fontSize: strong ? 12.5 : 11.5,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _PreviewStatusChip extends StatelessWidget {
  final bool complete;

  const _PreviewStatusChip({required this.complete});

  @override
  Widget build(BuildContext context) {
    final color = complete ? const Color(0xFF239B63) : const Color(0xFFD97706);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        complete
            ? tr(context, ru: 'Готов', zh: '完整')
            : tr(context, ru: 'Не полный', zh: '未完整'),
        style: TextStyle(
          color: color,
          fontFamily: 'Gilroy',
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ReferenceScopeAmount extends StatelessWidget {
  final String title;
  final SpOrganizerReferenceCalculationScope scope;
  final Color color;

  const _ReferenceScopeAmount({
    required this.title,
    required this.scope,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final detail = <String>[
      '${tr(context, ru: 'товары', zh: '商品')} ${_rub(scope.goodsRub)}',
      if (scope.internationalDeliveryRub != 0)
        '${tr(context, ru: 'вес', zh: '重量')} ${_rub(scope.internationalDeliveryRub)}',
      if (scope.packingRub != 0)
        '${tr(context, ru: 'упаковка', zh: '包装')} ${_rub(scope.packingRub)}',
      if (scope.insuranceRub != 0)
        '${tr(context, ru: 'страховка', zh: '保险')} ${_rub(scope.insuranceRub)}',
      if (scope.domesticDeliveryRub != 0)
        '${tr(context, ru: 'доставка', zh: '配送')} ${_rub(scope.domesticDeliveryRub)}',
      if (scope.additionalExpensesRub != 0)
        '${tr(context, ru: 'расходы', zh: '费用')} ${_rub(scope.additionalExpensesRub)}',
      if (scope.commissionRub != 0)
        '${tr(context, ru: 'комиссия', zh: '佣金')} ${_rub(scope.commissionRub)}',
    ].join(' · ');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: SpFinanceUi.labelStyle)),
              Text(
                _rub(scope.totalRub),
                style: TextStyle(
                  color: color,
                  fontFamily: 'Gilroy',
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(detail, style: SpFinanceUi.labelStyle),
        ],
      ),
    );
  }
}

class _CalculationMetric extends StatelessWidget {
  final double width;
  final String label;
  final double amount;
  final Color color;

  const _CalculationMetric({
    required this.width,
    required this.label,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: color.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: SpFinanceUi.labelStyle,
          ),
          const SizedBox(height: 5),
          Text(
            _rub(amount),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontFamily: 'Gilroy',
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileNotice extends StatelessWidget {
  final SpOrganizerCalculationProfile selfProfile;
  final SpOrganizerCalculationProfile clientProfile;

  const _ProfileNotice({
    required this.selfProfile,
    required this.clientProfile,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: SpFinanceUi.softDecoration(context),
      child: Column(
        children: [
          _ProfileScopeLine(
            title: tr(context, ru: 'Для себя', zh: '自用'),
            icon: Icons.person_outline_rounded,
            profile: selfProfile,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Divider(
              height: 1,
              color: Colors.black.withValues(alpha: 0.06),
            ),
          ),
          _ProfileScopeLine(
            title: tr(context, ru: 'Для клиента', zh: '客户'),
            icon: Icons.groups_outlined,
            profile: clientProfile,
          ),
        ],
      ),
    );
  }
}

class _ProfileScopeLine extends StatelessWidget {
  final String title;
  final IconData icon;
  final SpOrganizerCalculationProfile profile;

  const _ProfileScopeLine({
    required this.title,
    required this.icon,
    required this.profile,
  });

  @override
  Widget build(BuildContext context) {
    final rate = profile.cnyRubRate;
    final profileDetails = <String>[
      if (profile.pricePerKg != null)
        '${tr(context, ru: 'Тариф', zh: '费率')} ${profile.pricePerKg} ${profile.pricePerKgCurrency ?? profile.currency}/кг',
      if (profile.packingAmount != null)
        '${tr(context, ru: 'Упаковка', zh: '包装')} ${profile.packingAmount} ${profile.packingCurrency ?? profile.currency}',
      if (profile.parcelWeightKg != null)
        '${tr(context, ru: 'Вес', zh: '重量')} ${profile.parcelWeightKg} кг',
      if (profile.domesticDeliveryAmount != null)
        '${tr(context, ru: 'Доставка', zh: '配送')} ${profile.domesticDeliveryAmount} ${profile.domesticDeliveryCurrency ?? profile.currency}',
      if (profile.additionalExpensesAmount != null)
        '${tr(context, ru: 'Доп. расходы', zh: '其他费用')} ${profile.additionalExpensesAmount} ${profile.additionalExpensesCurrency ?? profile.currency}',
      if (profile.insuranceMode != null && profile.insuranceMode != 'none')
        _profileModeLabel(
          context,
          titleRu: 'Страховка',
          titleZh: '保险',
          mode: profile.insuranceMode!,
          percent: profile.insurancePercent,
          fixed: profile.insuranceFixedAmount,
          currency: profile.insuranceFixedCurrency ?? profile.currency,
        ),
      if (profile.commissionMode != null &&
          profile.commissionMode != 'none' &&
          profile.commissionMode != 'hidden_margin')
        _profileModeLabel(
          context,
          titleRu: 'Комиссия',
          titleZh: '佣金',
          mode: profile.commissionMode!,
          percent: profile.commissionPercent,
          fixed: profile.commissionFixedAmount,
          currency: profile.currency,
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: context.brandPrimary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: SpFinanceUi.bodyStyle.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            if (rate != null)
              Text(
                '1 ¥ = ${rate.toStringAsFixed(2)} ₽',
                style: SpFinanceUi.bodyStyle,
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          profile.usesLegacyFallback
              ? tr(
                  context,
                  ru: 'Используются текущие поля закупки',
                  zh: '使用当前采购字段',
                )
              : tr(context, ru: 'Отдельный профиль сохранён', zh: '已保存独立配置'),
          style: SpFinanceUi.labelStyle,
        ),
        if (profileDetails.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: profileDetails
                .map(
                  (detail) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(detail, style: SpFinanceUi.labelStyle),
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ],
    );
  }
}

class _TwoAObligationCard extends StatelessWidget {
  final SpOrganizerTo2AObligation obligation;

  const _TwoAObligationCard({required this.obligation});

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFD97706);
    final breakdown = obligation.breakdown;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.local_shipping_outlined,
                color: accent,
                size: 21,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr(
                        context,
                        ru: 'Явно связанные обязательства перед 2A',
                        zh: '明确关联的2A应付',
                      ),
                      style: SpFinanceUi.bodyStyle,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      obligation.available && obligation.amountRub != null
                          ? _rub(obligation.amountRub!)
                          : tr(
                              context,
                              ru: 'Актуализация ещё не выполнена или нет связей',
                              zh: '尚未更新或没有关联',
                            ),
                      style: SpFinanceUi.labelStyle,
                    ),
                  ],
                ),
              ),
              if (obligation.stale)
                const Icon(Icons.update_rounded, color: accent, size: 19),
            ],
          ),
          if (obligation.available) ...[
            const SizedBox(height: 9),
            Text(
              [
                '${tr(context, ru: 'Самовыкуп', zh: '代购')}: ${_rub(breakdown.selfBuyoutRub)}',
                'Garage: ${_rub(breakdown.garageRub)}',
                '${tr(context, ru: 'Счета', zh: '账单')}: ${_rub(breakdown.invoicesRub)}',
              ].join(' · '),
              style: SpFinanceUi.labelStyle,
            ),
            if (obligation.mayContainOverlaps) ...[
              const SizedBox(height: 6),
              Text(
                tr(
                  context,
                  ru: 'Источники показаны раздельно: между ними возможны пересечения. Сумма не меняет долги участников и legacy-прибыль.',
                  zh: '各来源分开显示，可能存在重复。该金额不会改变参与者欠款或旧版利润。',
                ),
                style: SpFinanceUi.labelStyle.copyWith(color: accent),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _CalculationSnapshotActions extends StatelessWidget {
  final SpOrganizerCalculationPreview preview;
  final bool applying;
  final bool posting;
  final bool actualizing;
  final VoidCallback? onApply;
  final VoidCallback? onPost;
  final VoidCallback? onActualize;

  const _CalculationSnapshotActions({
    required this.preview,
    required this.applying,
    required this.posting,
    required this.actualizing,
    this.onApply,
    this.onPost,
    this.onActualize,
  });

  @override
  Widget build(BuildContext context) {
    final applied = preview.currentAppliedSnapshot;
    final posted = preview.postedAllocation;
    final actualized = preview.organizerTo2A.actualizedSnapshot;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: SpFinanceUi.softDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                applied == null
                    ? Icons.lock_clock_outlined
                    : Icons.verified_user_outlined,
                color: context.brandPrimary,
                size: 19,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  applied == null
                      ? tr(
                          context,
                          ru: 'Текущий preview ещё не зафиксирован',
                          zh: '当前预览尚未固定',
                        )
                      : tr(
                          context,
                          ru: 'Зафиксирован расчёт · версия ${applied.version}',
                          zh: '结算已固定 · 版本 ${applied.version}',
                        ),
                  style: SpFinanceUi.bodyStyle,
                ),
              ),
            ],
          ),
          if (actualized != null) ...[
            const SizedBox(height: 5),
            Text(
              tr(
                context,
                ru: 'Связанные суммы 2A · снимок ${actualized.version}',
                zh: '2A关联金额 · 快照 ${actualized.version}',
              ),
              style: SpFinanceUi.labelStyle,
            ),
          ],
          if (posted != null && posted.stale == false) ...[
            const SizedBox(height: 5),
            Text(
              tr(
                context,
                ru: 'Новый ledger начислений · версия ${posted.version}',
                zh: '新应收账本 · 版本 ${posted.version}',
              ),
              style: SpFinanceUi.labelStyle.copyWith(
                color: const Color(0xFF2F7D5B),
              ),
            ),
          ],
          if (preview.applyBlockingWarnings.isNotEmpty) ...[
            const SizedBox(height: 7),
            Text(
              tr(
                context,
                ru: 'Фиксация недоступна: сначала устраните предупреждения расчётного движка.',
                zh: '暂不能固定：请先处理结算引擎警告。',
              ),
              style: SpFinanceUi.labelStyle.copyWith(
                color: const Color(0xFFD97706),
              ),
            ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: FilledButton.icon(
              onPressed: applying || posting || actualizing ? null : onApply,
              icon: applying
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      applied == null
                          ? Icons.lock_outline_rounded
                          : Icons.check_rounded,
                    ),
              label: Text(
                applied == null
                    ? tr(context, ru: 'Зафиксировать расчёт', zh: '固定结算')
                    : tr(context, ru: 'Расчёт зафиксирован', zh: '结算已固定'),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton.icon(
              onPressed: applying || posting || actualizing ? null : onPost,
              icon: posting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      preview.allocationAlreadyPosted
                          ? Icons.account_balance_wallet_rounded
                          : Icons.add_card_rounded,
                    ),
              label: Text(
                preview.allocationAlreadyPosted
                    ? tr(
                        context,
                        ru: 'Распределение начислено отдельно',
                        zh: '分摊已单独入账',
                      )
                    : tr(
                        context,
                        ru: 'Начислить зафиксированное распределение',
                        zh: '将固定分摊单独入账',
                      ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton.icon(
              onPressed: applying || posting || actualizing
                  ? null
                  : onActualize,
              icon: actualizing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync_rounded),
              label: Text(
                tr(
                  context,
                  ru: 'Актуализировать связанные суммы 2A',
                  zh: '更新2A关联金额',
                ),
              ),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            tr(
              context,
              ru: 'Фиксация и актуализация создают audit-снимки. Начисление создаёт отдельный новый ledger; legacy-позиции, оплаты и расходы ни одна команда не переписывает.',
              zh: '固定与更新会创建审计快照。入账会创建独立的新账本；所有操作均不会改写旧明细、付款和费用。',
            ),
            style: SpFinanceUi.labelStyle,
          ),
        ],
      ),
    );
  }
}

class _ParticipantBalanceCard extends StatelessWidget {
  final SpOrganizerParticipantCalculation participant;

  const _ParticipantBalanceCard({required this.participant});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 190,
      padding: const EdgeInsets.all(11),
      decoration: SpFinanceUi.softDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            participant.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: SpFinanceUi.bodyStyle,
          ),
          const Spacer(),
          Text(
            '${tr(context, ru: 'Остаток', zh: '待收')}: ${_rub(participant.balanceRub)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: participant.balanceRub > 0
                  ? const Color(0xFFD97706)
                  : const Color(0xFF239B63),
              fontFamily: 'Gilroy',
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '${participant.itemsCount} · ${_rub(participant.paidRub)}',
            style: SpFinanceUi.labelStyle,
          ),
        ],
      ),
    );
  }
}

class _AllocationNotice extends StatelessWidget {
  final SpOrganizerCalculationPreview preview;

  const _AllocationNotice({required this.preview});

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      if (preview.unallocatedExpensesRub != 0)
        '${tr(context, ru: 'нераспределённые расходы', zh: '未分摊费用')}: ${_rub(preview.unallocatedExpensesRub)}',
      if (preview.unassignedPaidRub != 0)
        '${tr(context, ru: 'оплаты без участника', zh: '未关联参与者的付款')}: ${_rub(preview.unassignedPaidRub)}',
    ];
    return Text(
      parts.join(' · '),
      style: SpFinanceUi.labelStyle.copyWith(color: const Color(0xFFD97706)),
    );
  }
}

class _CalculationWarnings extends StatelessWidget {
  final List<String> warnings;

  const _CalculationWarnings({required this.warnings});

  @override
  Widget build(BuildContext context) {
    final messages = <String>[
      if (warnings.contains('legacy_refund_correction_semantics'))
        tr(
          context,
          ru: 'Возвраты и корректировки пока показаны по правилам текущего СП.',
          zh: '退款和调整暂按当前拼团规则显示。',
        ),
      if (warnings.contains('legacy_exclusion_flag_not_applied'))
        tr(
          context,
          ru: 'Пометка «исключить из расчёта» пока не меняет legacy-суммы.',
          zh: '“排除结算”标记暂不改变旧版金额。',
        ),
      if (warnings.contains('profile_fields_pending_engine'))
        tr(
          context,
          ru: 'В этой preview-волне применяется курс профиля; остальные новые настройки пока только сохранены в профиле.',
          zh: '本次预览仅应用配置汇率；其他新设置暂仅保存在配置中。',
        ),
      if (warnings.contains('profile_allocation_pending_engine'))
        tr(
          context,
          ru: 'Параметры уже участвуют в серверном preview, но фиксация недоступна до детерминированного распределения по участникам.',
          zh: '参数已用于服务器预估，但在参与者确定性分摊完成前暂不能固定。',
        ),
      if (warnings.contains('profile_apply_pending_engine'))
        tr(
          context,
          ru: 'Расчёт пока неполный: фиксация недоступна, пока сервер не сможет безопасно распределить все суммы.',
          zh: '结算尚不完整：服务器安全分摊全部金额前无法固定。',
        ),
      if (warnings.contains('profile_ledger_pending_explicit_posting'))
        tr(
          context,
          ru: 'Полное распределение можно зафиксировать снимком. Оно не меняет текущие долги и оплаты без отдельной команды начисления.',
          zh: '完整分摊可固定为快照。除非单独执行入账命令，否则不会更改当前应收和付款。',
        ),
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(0xFFD97706).withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: const Color(0xFFD97706).withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var index = 0; index < messages.length; index++) ...[
            if (index > 0) const SizedBox(height: 5),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 1),
                  child: Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: Color(0xFFD97706),
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(messages[index], style: SpFinanceUi.labelStyle),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _CalculationError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _CalculationError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: SpFinanceUi.softDecoration(context),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFC2413A)),
          const SizedBox(width: 9),
          Expanded(child: Text(message, style: SpFinanceUi.labelStyle)),
          TextButton(
            onPressed: onRetry,
            child: Text(tr(context, ru: 'Повторить', zh: '重试')),
          ),
        ],
      ),
    );
  }
}

String _profileModeLabel(
  BuildContext context, {
  required String titleRu,
  required String titleZh,
  required String mode,
  required double? percent,
  required double? fixed,
  required String currency,
}) {
  final title = tr(context, ru: titleRu, zh: titleZh);
  if (mode == 'percent' && percent != null) {
    return '$title ${percent.toStringAsFixed(2)}%';
  }
  if (mode == 'fixed' && fixed != null) {
    return '$title ${fixed.toStringAsFixed(2)} $currency';
  }
  return title;
}

String _rub(double value) {
  final fixed = value.toStringAsFixed(2).replaceAll('.', ',');
  return '$fixed ₽';
}

String _signedRub(double value) {
  final sign = value > 0 ? '+' : '';
  return '$sign${_rub(value)}';
}

String _missingReferenceLabels(Set<String> requirements, {required bool ru}) {
  final labels = <String>[];
  if (requirements.any((value) => value.endsWith('_weight'))) {
    labels.add(ru ? 'указать вес' : '填写重量');
  }
  if (requirements.any((value) => value.endsWith('_cny_rub_rate'))) {
    labels.add(ru ? 'указать курс CNY/RUB' : '填写 CNY/RUB 汇率');
  }
  if (requirements.any((value) => value.endsWith('_usd_rub_rate'))) {
    labels.add(ru ? 'указать курс USD/RUB' : '填写 USD/RUB 汇率');
  }
  if (requirements.any((value) => value.contains('_goods_price_item_'))) {
    labels.add(ru ? 'заполнить цены товаров' : '填写商品价格');
  }
  if (labels.isEmpty) {
    labels.add(ru ? 'заполнить обязательные параметры' : '填写必填参数');
  }
  return labels.join(', ');
}
