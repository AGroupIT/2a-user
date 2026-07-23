import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/app_colors.dart';
import '../data/shop_availability_provider.dart';

class MarketplaceAccessGate extends ConsumerWidget {
  const MarketplaceAccessGate({
    super.key,
    required this.child,
    this.platformCode,
    this.requirePurchaseList = false,
  });

  final Widget child;
  final String? platformCode;
  final bool requirePurchaseList;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final availability = ref.watch(shopAvailabilityProvider);
    return availability.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => _UnavailableMarketplace(
        reason: 'availability_unavailable',
        platformCode: platformCode,
        onRetry: () => ref.invalidate(shopAvailabilityProvider),
      ),
      data: (value) {
        final selected = platformCode == null
            ? null
            : value.platform(platformCode!);
        final allowed = platformCode == null
            ? requirePurchaseList
                  ? value.platforms.any(
                      (platform) => value.canUsePurchaseList(platform.code),
                    )
                  : value.hasBrowsablePlatform
            : requirePurchaseList
            ? value.canUsePurchaseList(platformCode!)
            : value.canBrowse(platformCode!);
        if (allowed) return child;
        return _UnavailableMarketplace(
          reason: selected?.reason ?? value.reason,
          platformCode: selected?.code ?? platformCode,
          platformName: selected?.nameRu,
          onRetry: () => ref.invalidate(shopAvailabilityProvider),
        );
      },
    );
  }
}

class _UnavailableMarketplace extends StatelessWidget {
  const _UnavailableMarketplace({
    required this.reason,
    required this.onRetry,
    this.platformCode,
    this.platformName,
  });

  final String? reason;
  final VoidCallback onRetry;
  final String? platformCode;
  final String? platformName;

  @override
  Widget build(BuildContext context) {
    final marketplace = platformName?.trim().isNotEmpty == true
        ? platformName!
        : platformCode?.toUpperCase() ?? 'маркетплейсы';
    final text = switch (reason) {
      'agent_marketplaces_disabled' || 'agent_platform_disabled' =>
        'Ваш агент пока не подключил каталог $marketplace для клиентов.',
      'client_inactive' =>
        'Каталог $marketplace недоступен для неактивного аккаунта.',
      'platform_disabled_globally' ||
      'integration_unhealthy' ||
      'integration_not_ready' ||
      'system_disabled' => 'Интеграция с $marketplace ещё готовится к запуску.',
      _ => 'Не удалось проверить доступность маркетплейсов.',
    };
    final isJd = platformCode == 'jd';
    final badge = platformCode == null
        ? '2A'
        : isJd
        ? 'JD'
        : platformCode!;
    final accent = isJd ? const Color(0xFFE1251B) : const Color(0xFFFF6A00);

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
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      color: accent,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  platformCode == null
                      ? 'Каталоги маркетплейсов'
                      : 'Каталог $marketplace',
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
