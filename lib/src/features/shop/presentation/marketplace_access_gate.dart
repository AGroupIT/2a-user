import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/app_colors.dart';
import '../data/shop_availability_provider.dart';

class MarketplaceAccessGate extends ConsumerWidget {
  const MarketplaceAccessGate({
    super.key,
    required this.child,
    this.platformCode = '1688',
    this.requirePurchaseList = false,
  });

  final Widget child;
  final String platformCode;
  final bool requirePurchaseList;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final availability = ref.watch(shopAvailabilityProvider);
    return availability.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => _UnavailableMarketplace(
        reason: 'availability_unavailable',
        onRetry: () => ref.invalidate(shopAvailabilityProvider),
      ),
      data: (value) {
        final allowed = requirePurchaseList
            ? value.canUsePurchaseList(platformCode)
            : value.canBrowse(platformCode);
        if (allowed) return child;
        return _UnavailableMarketplace(
          reason: value.platform(platformCode)?.reason ?? value.reason,
          onRetry: () => ref.invalidate(shopAvailabilityProvider),
        );
      },
    );
  }
}

class _UnavailableMarketplace extends StatelessWidget {
  const _UnavailableMarketplace({required this.reason, required this.onRetry});

  final String? reason;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final text = switch (reason) {
      'agent_marketplaces_disabled' || 'agent_platform_disabled' =>
        'Ваш агент пока не подключил каталог 1688 для клиентов.',
      'client_inactive' => 'Каталог 1688 недоступен для неактивного аккаунта.',
      'platform_disabled_globally' ||
      'integration_unhealthy' ||
      'integration_not_ready' ||
      'system_disabled' => 'Интеграция с 1688 ещё готовится к запуску.',
      _ => 'Не удалось проверить доступность каталога 1688.',
    };

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6A00).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    '1688',
                    style: TextStyle(
                      color: Color(0xFFFF6A00),
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Каталог 1688',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Проверить снова'),
                    ),
                    TextButton.icon(
                      onPressed: () => context.push('/shop/purchases'),
                      icon: const Icon(Icons.receipt_long_rounded),
                      label: const Text('История заявок'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
