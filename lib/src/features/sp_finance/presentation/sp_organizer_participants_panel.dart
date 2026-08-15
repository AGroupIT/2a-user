import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/app_colors.dart';
import '../../../core/utils/locale_text.dart';
import '../data/sp_organizer_models.dart';
import '../data/sp_organizer_provider.dart';
import '../data/sp_v2_models.dart';
import '../data/sp_v2_provider.dart';
import 'sp_finance_ui.dart';
import 'sp_organizer_purchase_kind.dart';

class SpOrganizerParticipantsPanel extends ConsumerWidget {
  final int purchaseId;

  const SpOrganizerParticipantsPanel({super.key, required this.purchaseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final capabilities = ref
        .watch(spOrganizerCapabilitiesProvider)
        .asData
        ?.value;
    final purchase = ref
        .watch(spV2PurchaseDetailProvider(purchaseId))
        .asData
        ?.value;
    final participantsAsync = ref.watch(
      spOrganizerParticipantsProvider(purchaseId),
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
                  Icons.people_alt_rounded,
                  color: context.brandPrimary,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr(context, ru: 'Участники закупки', zh: '拼团参与者'),
                      style: SpFinanceUi.sectionTitleStyle,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      capabilities?.purchaseKinds == true && purchase != null
                          ? '${spOrganizerPurchaseKindLabel(context, purchase.kind)} · ${tr(context, ru: '«Я» и клиенты организатора', zh: '“我”和团长客户')}'
                          : tr(
                              context,
                              ru: '«Я» и клиенты организатора',
                              zh: '“我”和团长客户',
                            ),
                      style: SpFinanceUi.labelStyle,
                    ),
                  ],
                ),
              ),
              SpFinanceHeaderActionButton(
                tooltip: tr(context, ru: 'Добавить участника', zh: '添加参与者'),
                onTap: () => _showParticipantPicker(context, ref),
                child: Icon(
                  Icons.person_add_alt_1_rounded,
                  color: context.brandPrimary,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          participantsAsync.when(
            loading: () => const SizedBox(
              height: 62,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (error, _) => _ParticipantsMessage(
              icon: Icons.error_outline_rounded,
              message:
                  '${tr(context, ru: 'Не удалось загрузить участников', zh: '无法加载参与者')}: $error',
            ),
            data: (data) {
              if (data.participants.isEmpty) {
                return _ParticipantsMessage(
                  icon: Icons.person_add_alt_rounded,
                  message: tr(
                    context,
                    ru: 'Добавьте себя или клиента. Старые товары продолжат отображаться через совместимый режим.',
                    zh: '添加自己或客户。旧商品仍会通过兼容模式显示。',
                  ),
                );
              }
              return LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth >= 700) {
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: data.participants
                          .map(
                            (participant) =>
                                _ParticipantChip(participant: participant),
                          )
                          .toList(growable: false),
                    );
                  }
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (
                          var index = 0;
                          index < data.participants.length;
                          index++
                        ) ...[
                          if (index > 0) const SizedBox(width: 8),
                          _ParticipantChip(
                            participant: data.participants[index],
                          ),
                        ],
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showParticipantPicker(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final saved = await showSpFinanceModalSheet<bool>(
      context: context,
      builder: (context) => _ParticipantPickerSheet(purchaseId: purchaseId),
    );
    if (!context.mounted || saved != true) return;
    ref.invalidate(spOrganizerParticipantsProvider(purchaseId));
  }
}

class _ParticipantChip extends StatelessWidget {
  final SpOrganizerParticipant participant;

  const _ParticipantChip({required this.participant});

  @override
  Widget build(BuildContext context) {
    final customer = participant.customer;
    final color = customer.isOrganizerSelf
        ? context.brandPrimary
        : AppColors.textSecondary;
    return Container(
      constraints: const BoxConstraints(maxWidth: 230),
      padding: const EdgeInsets.fromLTRB(8, 7, 11, 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: color.withValues(alpha: 0.14),
            child: Icon(
              customer.isOrganizerSelf
                  ? Icons.person_rounded
                  : Icons.person_outline_rounded,
              size: 17,
              color: color,
            ),
          ),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              customer.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontFamily: 'Gilroy',
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          if (participant.legacyDerived) ...[
            const SizedBox(width: 5),
            Tooltip(
              message: tr(
                context,
                ru: 'Получен из существующих товаров',
                zh: '来自现有商品',
              ),
              child: Icon(
                Icons.history_rounded,
                size: 14,
                color: color.withValues(alpha: 0.72),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ParticipantsMessage extends StatelessWidget {
  final IconData icon;
  final String message;

  const _ParticipantsMessage({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: SpFinanceUi.softDecoration(context),
      child: Row(
        children: [
          Icon(icon, color: context.brandPrimary),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: SpFinanceUi.labelStyle)),
        ],
      ),
    );
  }
}

class _ParticipantPickerSheet extends ConsumerStatefulWidget {
  final int purchaseId;

  const _ParticipantPickerSheet({required this.purchaseId});

  @override
  ConsumerState<_ParticipantPickerSheet> createState() =>
      _ParticipantPickerSheetState();
}

class _ParticipantPickerSheetState
    extends ConsumerState<_ParticipantPickerSheet> {
  int? _savingCustomerId;
  bool _savingSelf = false;

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(spV2CustomersProvider);
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.86,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
            child: Column(
              children: [
                Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE1E5ED),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        tr(context, ru: 'Добавить участника', zh: '添加参与者'),
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontFamily: 'Gilroy',
                          fontSize: 23,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              children: [
                _ParticipantPickerTile(
                  icon: Icons.person_rounded,
                  title: tr(context, ru: 'Я', zh: '我'),
                  subtitle: tr(
                    context,
                    ru: 'Собственные товары организатора',
                    zh: '团长自己的商品',
                  ),
                  loading: _savingSelf,
                  onTap: _savingCustomerId == null && !_savingSelf
                      ? () => _saveSelf()
                      : null,
                ),
                const SizedBox(height: 8),
                customersAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (error, _) => _ParticipantsMessage(
                    icon: Icons.error_outline_rounded,
                    message:
                        '${tr(context, ru: 'Не удалось загрузить клиентов', zh: '无法加载客户')}: $error',
                  ),
                  data: (customers) => Column(
                    children: customers
                        .map(
                          (customer) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _ParticipantPickerTile(
                              icon: Icons.person_outline_rounded,
                              title: customer.fullName,
                              subtitle: _customerSubtitle(context, customer),
                              loading: _savingCustomerId == customer.id,
                              onTap: _savingCustomerId == null && !_savingSelf
                                  ? () => _saveCustomer(customer)
                                  : null,
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _customerSubtitle(BuildContext context, SpV2Customer customer) {
    final details = [
      customer.phone,
      customer.city,
    ].whereType<String>().where((value) => value.isNotEmpty).toList();
    return details.isEmpty
        ? tr(context, ru: 'Клиент организатора', zh: '团长客户')
        : details.join(' · ');
  }

  Future<void> _saveSelf() async {
    if (_savingSelf || _savingCustomerId != null) return;
    setState(() => _savingSelf = true);
    await _save(self: true);
  }

  Future<void> _saveCustomer(SpV2Customer customer) async {
    if (_savingSelf || _savingCustomerId != null) return;
    setState(() => _savingCustomerId = customer.id);
    await _save(customerId: customer.id);
  }

  Future<void> _save({int? customerId, bool self = false}) async {
    try {
      await ref
          .read(spOrganizerRepositoryProvider)
          .saveParticipant(
            widget.purchaseId,
            customerId: customerId,
            self: self,
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _savingCustomerId = null;
        _savingSelf = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${tr(context, ru: 'Не удалось добавить участника', zh: '无法添加参与者')}: $error',
          ),
        ),
      );
    }
  }
}

class _ParticipantPickerTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool loading;
  final VoidCallback? onTap;

  const _ParticipantPickerTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: context.brandPrimary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: context.brandPrimary),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SpFinanceUi.bodyStyle.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SpFinanceUi.labelStyle,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (loading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                const Icon(
                  Icons.add_circle_outline_rounded,
                  color: AppColors.textSecondary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
