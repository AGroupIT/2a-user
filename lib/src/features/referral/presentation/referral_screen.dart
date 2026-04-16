import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/network/api_client.dart';
import '../../../core/ui/app_colors.dart';
import '../../../core/ui/app_layout.dart';
import '../../../core/ui/tutorial_card.dart';
import '../data/referral_provider.dart';

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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            success ? Colors.green.shade600 : Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
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
          description: 'Приглашайте друзей и коллег. Когда они оплатят первый счёт — вы получаете бонусные килограммы к вашим отправлениям.',
          targetKey: _referralInfoKey,
        ),
        TutorialStep(
          icon: Icons.qr_code_rounded,
          title: 'Ваш реферальный код',
          description: 'Нажмите «Скопировать» или «Поделиться», чтобы отправить код другу. Он вводит его при регистрации — и оба получают бонус после первой оплаты.',
          targetKey: _codeCardKey,
        ),
        TutorialStep(
          icon: Icons.balance_rounded,
          title: 'Бонусный баланс',
          description: 'Накопленные килограммы автоматически вычитаются из веса следующего счёта. Чем больше приглашённых — тем больше скидка.',
          targetKey: _balanceKey,
        ),
      ],
      child: Scaffold(
        backgroundColor: AppColors.brandBg,
        body: referralAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline,
                    size: 48, color: Colors.red.shade400),
                const SizedBox(height: 12),
                const Text(
                  'Не удалось загрузить данные',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
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
          onRefresh: () async => ref.invalidate(referralProvider),
          color: brandColor,
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              AppLayout.topBarTotalHeight(context) * 0.7 + 16,
              16,
              AppLayout.bottomScrollPadding(context) + 16,
            ),
            children: [
              // === Заголовок ===
              KeyedSubtree(
                key: _referralInfoKey,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Реферальная программа',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),

              // === Карточка с кодом (содержит бонусный баланс) ===
              KeyedSubtree(
                key: _codeCardKey,
                child: KeyedSubtree(
                  key: _balanceKey,
                  child: _CodeCard(data: data, brandColor: brandColor),
                ),
              ),

              const SizedBox(height: 16),

              // === Привязка чужого кода ===
              if (data.referredByName == null)
                _LinkCodeCard(
                  controller: _linkCodeController,
                  isLinking: _isLinking,
                  brandColor: brandColor,
                  onLink: _linkReferralCode,
                ),

              if (data.referredByName != null) ...[
                _InfoCard(
                  icon: Icons.person_outline_rounded,
                  title: 'Вас пригласил',
                  value:
                      '${data.referredByName} (${data.referredByCode ?? ''})',
                  brandColor: brandColor,
                ),
              ],

              const SizedBox(height: 16),

              // === Рефералы ===
              if (data.referrals.isNotEmpty) ...[
                _SectionHeader(title: 'Ваши рефералы (${data.referrals.length})'),
                const SizedBox(height: 8),
                ...data.referrals.map((r) => _ReferralEntryTile(
                      entry: r,
                      brandColor: brandColor,
                    )),
                const SizedBox(height: 16),
              ],

              // === История транзакций ===
              if (data.transactions.isNotEmpty) ...[
                _SectionHeader(title: 'История начислений'),
                const SizedBox(height: 8),
                ...data.transactions.map((t) => _TransactionTile(
                      transaction: t,
                      brandColor: brandColor,
                    )),
              ],
            ],
          ),
        ),
      ),
    ));
  }
}

// ============================================================
// Карточка реферального кода
// ============================================================

class _CodeCard extends StatelessWidget {
  final ReferralData data;
  final Color brandColor;

  const _CodeCard({required this.data, required this.brandColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            brandColor,
            HSLColor.fromColor(brandColor)
                .withLightness(
                    (HSLColor.fromColor(brandColor).lightness + 0.15)
                        .clamp(0.0, 1.0))
                .toColor(),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: brandColor.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (data.referralCode != null) ...[
            const Text(
              'Ваш реферальный код',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  data.referralCode!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(
                        ClipboardData(text: data.referralCode!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Код скопирован'),
                        backgroundColor: Colors.green.shade600,
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.copy_rounded,
                            color: Colors.white, size: 16),
                        SizedBox(width: 4),
                        Text(
                          'Копировать',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.scale_rounded,
                    color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Бонусных кг на балансе',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '${data.referralKgBalance.toStringAsFixed(2)} кг',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
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
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
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
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Если вас пригласил знакомый, введите его код и получите 2 бонусных кг',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: 'ABC123',
                    filled: true,
                    fillColor: AppColors.brandBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: brandColor, width: 2),
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 14),
                  ),
                  style: const TextStyle(
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
                          style: TextStyle(fontWeight: FontWeight.w600),
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
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: brandColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
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
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
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
// Заголовок секции
// ============================================================

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
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

  const _ReferralEntryTile(
      {required this.entry, required this.brandColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: brandColor.withValues(alpha: 0.1),
            child: Text(
              (entry.fullName?.isNotEmpty == true
                      ? entry.fullName![0]
                      : '?')
                  .toUpperCase(),
              style: TextStyle(
                color: brandColor,
                fontWeight: FontWeight.w700,
              ),
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
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Оплаченных счетов: ${entry.paidInvoicesCount}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (entry.earnedKg > 0)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '+${entry.earnedKg.toStringAsFixed(2)} кг',
                style: TextStyle(
                  fontSize: 12,
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

  const _TransactionTile(
      {required this.transaction, required this.brandColor});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd.MM.yyyy');
    final isPositive =
        transaction.type == 'earned' || transaction.type == 'referee_bonus' ||
        (transaction.type == 'admin_credit' && transaction.kgAmount > 0);
    final color =
        isPositive ? Colors.green.shade600 : Colors.orange.shade700;
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
        typeLabel = transaction.kgAmount > 0 ? 'Начислено администратором' : 'Списано администратором';
        icon = transaction.kgAmount > 0 ? Icons.admin_panel_settings_rounded : Icons.remove_circle_outline_rounded;
        break;
      default:
        typeLabel = transaction.type;
        icon = Icons.info_outline_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
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
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (transaction.description != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    transaction.description!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 2),
                Text(
                  dateFormat.format(transaction.createdAt),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$prefix${transaction.kgAmount.toStringAsFixed(2)} кг',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
