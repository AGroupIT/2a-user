import 'package:flutter/material.dart';
import 'package:twoalogisticcabineuser/src/core/ui/app_toast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/network/api_client.dart';
import '../../../core/ui/app_colors.dart';
import '../../../core/ui/app_input_decoration.dart';
import '../../../core/ui/app_layout.dart';
import '../../../core/ui/app_page_header.dart';
import '../../../core/ui/tutorial_card.dart';
import '../../../core/utils/clipboard_helper.dart';
import '../data/referral_provider.dart';

const _textColor = Color(0xFF2F2F2F);
const _mutedTextColor = Color(0x992F2F2F);

BoxDecoration _referralCardDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(10),
    boxShadow: const [
      BoxShadow(color: Color(0x1A000000), offset: Offset(3, 4), blurRadius: 25),
    ],
  );
}

TextStyle get _sectionTitleStyle {
  return const TextStyle(
    color: _textColor,
    fontFamily: 'Gilroy',
    fontSize: 18,
    height: 22 / 18,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
  );
}

class ReferralScreen extends ConsumerStatefulWidget {
  const ReferralScreen({super.key});

  @override
  ConsumerState<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends ConsumerState<ReferralScreen> {
  final _linkCodeController = TextEditingController();
  bool _isLinking = false;

  final GlobalKey _referralInfoKey = GlobalKey();
  final GlobalKey _codeCardKey = GlobalKey();
  final GlobalKey _balanceKey = GlobalKey();

  @override
  void dispose() {
    _linkCodeController.dispose();
    super.dispose();
  }

  Future<void> _linkReferralCode() async {
    final code = _linkCodeController.text.trim().toUpperCase();
    if (code.isEmpty) return;

    setState(() => _isLinking = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.post('/client/referral/link', data: {'code': code});
      _linkCodeController.clear();
      ref.invalidate(referralProvider);
      if (mounted) {
        _showSnackbar('Реферальный код привязан!', true);
      }
    } catch (e) {
      if (mounted) {
        _showSnackbar('Ошибка привязки кода', false);
      }
    } finally {
      if (mounted) setState(() => _isLinking = false);
    }
  }

  void _showSnackbar(String message, bool success) {
    AppToast.showFromSnackBar(
      context,
      SnackBar(
        content: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: AppToast.hide,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  success
                      ? Icons.check_circle_outline_rounded
                      : Icons.error_outline_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Gilroy',
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: success
            ? context.brandPrimary
            : const Color(0xFFE53935),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          AppLayout.bottomBarObstruction(context) + 12,
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final referralAsync = ref.watch(referralProvider);
    final brandColor = context.brandPrimary;
    return TutorialScreenWrapper(
      screenKey: 'referral',
      steps: [
        TutorialStep(
          icon: Icons.group_add_rounded,
          title: 'Реферальная программа',
          description:
              'Приглашайте друзей и коллег. Когда они оплатят первый счёт — вы получаете бонусные килограммы к вашим отправлениям.',
          targetKey: _referralInfoKey,
        ),
        TutorialStep(
          icon: Icons.qr_code_rounded,
          title: 'Ваш реферальный код',
          description:
              'Нажмите «Скопировать» или «Поделиться», чтобы отправить код другу. Он вводит его при регистрации — и оба получают бонус после первой оплаты.',
          targetKey: _codeCardKey,
        ),
        TutorialStep(
          icon: Icons.balance_rounded,
          title: 'Бонусный баланс',
          description:
              'Накопленные килограммы автоматически вычитаются из веса следующего счёта. Чем больше приглашённых — тем больше скидка.',
          targetKey: _balanceKey,
        ),
      ],
      child: Scaffold(
        backgroundColor: AppColors.brandBg,
        body: referralAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Colors.red.shade400,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Не удалось загрузить данные',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => ref.invalidate(referralProvider),
                    child: const Text('Повторить'),
                  ),
                ],
              ),
            ),
          ),
          data: (data) => RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(referralProvider);
              await ref.read(referralProvider.future);
            },
            color: brandColor,
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                16,
                AppLayout.topBarTotalHeight(context) * 0.7 + 16,
                16,
                AppLayout.bottomScrollPadding(context) + 16,
              ),
              children: [
                const AppPageHeader(
                  title: 'Реферальная программа',
                  showBack: true,
                ),
                const SizedBox(height: 15),

                KeyedSubtree(
                  key: _referralInfoKey,
                  child: _ReferralIntroCard(brandColor: brandColor),
                ),
                const SizedBox(height: 15),

                KeyedSubtree(
                  key: _codeCardKey,
                  child: KeyedSubtree(
                    key: _balanceKey,
                    child: _CodeCard(
                      data: data,
                      brandColor: brandColor,
                      onCopied: () => _showSnackbar('Код скопирован', true),
                    ),
                  ),
                ),

                const SizedBox(height: 15),

                if (data.referredByName == null)
                  _LinkCodeCard(
                    controller: _linkCodeController,
                    isLinking: _isLinking,
                    brandColor: brandColor,
                    onLink: _linkReferralCode,
                  ),
                if (data.referredByName != null)
                  _InfoCard(
                    icon: Icons.person_outline_rounded,
                    title: 'Вас пригласил',
                    value:
                        '${data.referredByName} (${data.referredByCode ?? ''})',
                    brandColor: brandColor,
                  ),

                const SizedBox(height: 15),

                _SectionCard(
                  title: 'Ваши рефералы (${data.referrals.length})',
                  child: data.referrals.isEmpty
                      ? const _EmptyState(
                          icon: Icons.group_add_rounded,
                          title: 'Рефералов пока нет',
                          description:
                              'Скопируйте код выше и отправьте его друзьям или коллегам.',
                        )
                      : Column(
                          children: data.referrals
                              .map(
                                (r) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: _ReferralEntryTile(
                                    entry: r,
                                    brandColor: brandColor,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                ),

                const SizedBox(height: 15),

                _SectionCard(
                  title: 'История начислений',
                  child: data.transactions.isEmpty
                      ? const _EmptyState(
                          icon: Icons.history_rounded,
                          title: 'История пока пустая',
                          description:
                              'Начисления появятся после первых оплат приглашенных клиентов.',
                        )
                      : Column(
                          children: data.transactions
                              .map(
                                (t) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: _TransactionTile(
                                    transaction: t,
                                    brandColor: brandColor,
                                  ),
                                ),
                              )
                              .toList(),
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

// ============================================================
// Вводная карточка
// ============================================================

class _ReferralIntroCard extends StatelessWidget {
  final Color brandColor;

  const _ReferralIntroCard({required this.brandColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _referralCardDecoration(),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: brandColor,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.card_giftcard_rounded,
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
                  'Приглашайте и получайте бонусные кг',
                  style: TextStyle(
                    color: _textColor,
                    fontFamily: 'Gilroy',
                    fontSize: 18,
                    height: 22 / 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Когда приглашенный клиент оплатит первый счет, бонусы появятся на вашем балансе и будут доступны для оплаты доставки.',
                  style: TextStyle(
                    color: _mutedTextColor,
                    fontFamily: 'Gilroy',
                    fontSize: 14,
                    height: 18 / 14,
                    fontWeight: FontWeight.w400,
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

// ============================================================
// Общая секция
// ============================================================

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _referralCardDecoration(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: _sectionTitleStyle),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.brandPrimary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: context.brandPrimary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _textColor,
                    fontFamily: 'Gilroy',
                    fontSize: 14,
                    height: 16 / 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    color: _mutedTextColor,
                    fontFamily: 'Gilroy',
                    fontSize: 13,
                    height: 16 / 13,
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

// ============================================================
// Карточка реферального кода
// ============================================================

class _CodeCard extends StatelessWidget {
  final ReferralData data;
  final Color brandColor;
  final VoidCallback onCopied;

  const _CodeCard({
    required this.data,
    required this.brandColor,
    required this.onCopied,
  });

  @override
  Widget build(BuildContext context) {
    final referralCode = data.referralCode;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _referralCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Ваш реферальный код', style: _sectionTitleStyle),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: brandColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    referralCode ?? 'Код пока не доступен',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: referralCode == null
                          ? _mutedTextColor
                          : _textColor,
                      fontFamily: 'Gilroy',
                      fontSize: referralCode == null ? 15 : 26,
                      height: referralCode == null ? 18 / 15 : 30 / 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: referralCode == null ? 0 : 2,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                if (referralCode != null)
                  Material(
                    color: brandColor,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      onTap: () async {
                        final copied = await AppClipboard.copyText(
                          referralCode,
                        );
                        if (!context.mounted) return;
                        if (copied) {
                          onCopied();
                        } else {
                          AppToast.showFromSnackBar(
                            context,
                            SnackBar(
                              content: const Text('Не удалось скопировать'),
                              backgroundColor: Colors.red.shade700,
                            ),
                          );
                        }
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        child: Icon(
                          Icons.copy_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ReferralMetric(
                  icon: Icons.scale_rounded,
                  label: 'Бонусные кг',
                  value: '${data.referralKgBalance.toStringAsFixed(2)} кг',
                  color: brandColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ReferralMetric(
                  icon: Icons.percent_rounded,
                  label: 'Макс. к счету',
                  value: '${data.maxBonusPercent.toStringAsFixed(0)}%',
                  color: brandColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _ReferralMetric(
            icon: Icons.people_alt_rounded,
            label: 'Приглашенных клиентов',
            value: '${data.referrals.length}',
            color: brandColor,
            wide: true,
          ),
        ],
      ),
    );
  }
}

class _ReferralMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool wide;

  const _ReferralMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.wide = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: wide ? 54 : 68),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _mutedTextColor,
                    fontFamily: 'Gilroy',
                    fontSize: 12,
                    height: 14 / 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _textColor,
                    fontFamily: 'Gilroy',
                    fontSize: 18,
                    height: 20 / 18,
                    fontWeight: FontWeight.w800,
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

// ============================================================
// Привязка реферального кода
// ============================================================

class _LinkCodeCard extends StatelessWidget {
  final TextEditingController controller;
  final bool isLinking;
  final Color brandColor;
  final VoidCallback onLink;

  const _LinkCodeCard({
    required this.controller,
    required this.isLinking,
    required this.brandColor,
    required this.onLink,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _referralCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.link_rounded, color: brandColor, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Введите реферальный код',
                style: TextStyle(
                  color: _textColor,
                  fontFamily: 'Gilroy',
                  fontSize: 18,
                  height: 22 / 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Если вас пригласил знакомый, введите его код и получите 2 бонусных кг',
            style: TextStyle(
              color: _mutedTextColor,
              fontFamily: 'Gilroy',
              fontSize: 14,
              height: 18 / 14,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  textCapitalization: TextCapitalization.characters,
                  decoration: appInputDecoration(
                    context,
                    hintText: 'ABC123',
                    fillColor: brandColor.withValues(alpha: 0.07),
                    borderColor: Colors.transparent,
                    focusedBorderColor: brandColor,
                    focusedWidth: 2,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                  ),
                  style: const TextStyle(
                    color: _textColor,
                    fontFamily: 'Gilroy',
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: isLinking ? null : onLink,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brandColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: isLinking
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Привязать',
                          style: TextStyle(
                            fontFamily: 'Gilroy',
                            fontWeight: FontWeight.w700,
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

// ============================================================
// Информационная карточка
// ============================================================

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color brandColor;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.brandColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _referralCardDecoration(),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: brandColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: brandColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _mutedTextColor,
                    fontFamily: 'Gilroy',
                    fontSize: 12,
                    height: 14 / 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: _textColor,
                    fontFamily: 'Gilroy',
                    fontSize: 15,
                    height: 18 / 15,
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

// ============================================================
// Плитка реферала
// ============================================================

class _ReferralEntryTile extends StatelessWidget {
  final ReferralEntry entry;
  final Color brandColor;

  const _ReferralEntryTile({required this.entry, required this.brandColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: brandColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: brandColor.withValues(alpha: 0.1),
            child: Text(
              (entry.fullName?.isNotEmpty == true ? entry.fullName![0] : '?')
                  .toUpperCase(),
              style: const TextStyle(
                fontFamily: 'Gilroy',
                fontWeight: FontWeight.w700,
              ).copyWith(color: brandColor),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.fullName ?? 'Без имени',
                  style: const TextStyle(
                    color: _textColor,
                    fontFamily: 'Gilroy',
                    fontSize: 15,
                    height: 18 / 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Оплаченных счетов: ${entry.paidInvoicesCount}',
                  style: const TextStyle(
                    color: _mutedTextColor,
                    fontFamily: 'Gilroy',
                    fontSize: 12,
                    height: 14 / 12,
                  ),
                ),
              ],
            ),
          ),
          if (entry.earnedKg > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '+${entry.earnedKg.toStringAsFixed(2)} кг',
                style: TextStyle(
                  fontFamily: 'Gilroy',
                  fontSize: 12,
                  height: 14 / 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.green.shade700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================
// Плитка транзакции
// ============================================================

class _TransactionTile extends StatelessWidget {
  final ReferralTransaction transaction;
  final Color brandColor;

  const _TransactionTile({required this.transaction, required this.brandColor});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd.MM.yyyy');
    final isPositive =
        transaction.type == 'earned' ||
        transaction.type == 'referee_bonus' ||
        (transaction.type == 'admin_credit' && transaction.kgAmount > 0);
    final color = isPositive ? Colors.green.shade600 : Colors.orange.shade700;
    final prefix = isPositive ? '+' : '-';

    String typeLabel;
    IconData icon;
    switch (transaction.type) {
      case 'earned':
        typeLabel = 'Начислено за реферала';
        icon = Icons.add_circle_outline_rounded;
        break;
      case 'used':
        typeLabel = 'Использовано в счёте';
        icon = Icons.remove_circle_outline_rounded;
        break;
      case 'referee_bonus':
        typeLabel = 'Стартовый бонус';
        icon = Icons.card_giftcard_rounded;
        break;
      case 'expired':
        typeLabel = 'Истёк срок';
        icon = Icons.timer_off_outlined;
        break;
      case 'admin_credit':
        typeLabel = transaction.kgAmount > 0
            ? 'Начислено администратором'
            : 'Списано администратором';
        icon = transaction.kgAmount > 0
            ? Icons.admin_panel_settings_rounded
            : Icons.remove_circle_outline_rounded;
        break;
      default:
        typeLabel = transaction.type;
        icon = Icons.info_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  typeLabel,
                  style: const TextStyle(
                    color: _textColor,
                    fontFamily: 'Gilroy',
                    fontSize: 14,
                    height: 16 / 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (transaction.description != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    transaction.description!,
                    style: const TextStyle(
                      color: _mutedTextColor,
                      fontFamily: 'Gilroy',
                      fontSize: 12,
                      height: 15 / 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 2),
                Text(
                  dateFormat.format(transaction.createdAt),
                  style: const TextStyle(
                    color: _mutedTextColor,
                    fontFamily: 'Gilroy',
                    fontSize: 11,
                    height: 13 / 11,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$prefix${transaction.kgAmount.toStringAsFixed(2)} кг',
            style: TextStyle(
              fontFamily: 'Gilroy',
              fontSize: 15,
              height: 18 / 15,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
