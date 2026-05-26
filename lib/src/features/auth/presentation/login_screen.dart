import 'package:flutter/material.dart';
import 'package:twoalogisticcabineuser/src/core/ui/app_toast.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/agent_domain_resolver.dart';
import '../../../core/ui/app_background.dart';
import '../../../core/ui/app_colors.dart';
import '../../tariffs/data/tariffs_provider.dart';
import '../data/auth_provider.dart';
import 'auth_visuals.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _domainCtrl = TextEditingController();
  final _loginCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final detectedDomain = AgentDomainResolver.currentAgentDomain;
    if (detectedDomain != null) {
      _domainCtrl.text = detectedDomain;
    }
  }

  @override
  void dispose() {
    _domainCtrl.dispose();
    _loginCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_domainCtrl.text.isEmpty ||
        _loginCtrl.text.isEmpty ||
        _passwordCtrl.text.isEmpty) {
      _showError('Заполните все поля');
      return;
    }

    // Закрываем клавиатуру перед началом
    FocusScope.of(context).unfocus();

    setState(() => _isLoading = true);

    try {
      final success = await ref
          .read(authProvider.notifier)
          .login(
            email: _loginCtrl.text.trim(),
            domain: _domainCtrl.text.trim(),
            password: _passwordCtrl.text,
          );

      if (!mounted) return;

      if (!success) {
        // Небольшая задержка чтобы пользователь увидел что была попытка
        await Future.delayed(const Duration(milliseconds: 300));

        if (!mounted) return;

        setState(() => _isLoading = false);

        // Показываем ошибку из authProvider
        final authState = ref.read(authProvider);
        final errorMessage = authState.error ?? 'Ошибка авторизации';
        debugPrint('❌ Login failed: $errorMessage');

        // Ждём завершения анимации loader'а перед показом SnackBar
        await Future.delayed(const Duration(milliseconds: 100));

        if (mounted) {
          _showError(errorMessage);
        }
      } else {
        debugPrint('✅ Login successful');
        setState(() => _isLoading = false);
      }
      // Router will automatically redirect to / on successful login
    } catch (e) {
      if (!mounted) return;

      // Небольшая задержка чтобы пользователь увидел что была попытка
      await Future.delayed(const Duration(milliseconds: 300));

      if (!mounted) return;

      setState(() => _isLoading = false);
      debugPrint('❌ Login exception: $e');

      // Ждём завершения анимации loader'а
      await Future.delayed(const Duration(milliseconds: 100));

      if (mounted) {
        _showError('Произошла ошибка при входе. Попробуйте ещё раз');
      }
    }
  }

  void _showError(String message) {
    AppToast.showFromSnackBar(
      context,
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Ошибка входа',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        duration: const Duration(seconds: 5),
        elevation: 8,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final topPadding = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const AppBackground(),
          GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                24,
                topPadding + 28,
                24,
                bottomPadding + 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AuthHeroHeader(
                    icon: Icons.local_shipping_rounded,
                    title: 'Вход в личный кабинет',
                    subtitle:
                        'Следите за грузами, сборками, счетами и фотоотчётами в одном защищённом кабинете.',
                    trustItems: [
                      AuthTrustItem(icon: Icons.route_rounded, label: 'Треки'),
                      AuthTrustItem(
                        icon: Icons.inventory_2_rounded,
                        label: 'Сборки',
                      ),
                      AuthTrustItem(
                        icon: Icons.support_agent_rounded,
                        label: 'Поддержка',
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  AuthFormCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildTextField(
                          controller: _domainCtrl,
                          label: 'Домен партнёра',
                          hint: 'example-company',
                          prefixIcon: Icons.business_rounded,
                          keyboardType: TextInputType.url,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _loginCtrl,
                          label: 'Email или телефон',
                          hint: 'user@example.com',
                          prefixIcon: Icons.person_rounded,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _passwordCtrl,
                          label: 'Пароль',
                          hint: '••••••••',
                          prefixIcon: Icons.lock_rounded,
                          obscureText: _obscurePassword,
                          keyboardType: TextInputType.text,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _login(),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              color: const Color(0xFF999999),
                              size: 20,
                            ),
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => context.push('/forgot-password'),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              'Забыли пароль?',
                              style: TextStyle(
                                color: AuthVisuals.primary(context),
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton(
                                onPressed: _isLoading ? null : _login,
                                style: AuthVisuals.primaryButtonStyle(context),
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        'Войти',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _isLoading
                                    ? null
                                    : () => context.push('/register'),
                                style: AuthVisuals.outlinedButtonStyle(context),
                                child: const FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'Зарегистрироваться',
                                    maxLines: 1,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  const _PublicTariffsPreview(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData prefixIcon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    List<TextInputFormatter>? inputFormatters,
    TextInputAction? textInputAction,
    void Function(String)? onSubmitted,
  }) {
    final accent = AuthVisuals.primary(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.78),
            border: Border.all(color: accent.withValues(alpha: 0.16)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            obscureText: obscureText,
            inputFormatters: inputFormatters,
            textInputAction: textInputAction,
            onSubmitted: onSubmitted,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                color: Color(0xFFAAAAAA),
                fontSize: 14,
              ),
              prefixIcon: Icon(
                prefixIcon,
                color: accent.withValues(alpha: 0.72),
                size: 20,
              ),
              suffixIcon: suffixIcon,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PublicTariffsPreview extends ConsumerWidget {
  const _PublicTariffsPreview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tariffsAsync = ref.watch(publicDefaultTariffsProvider);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.65)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: tariffsAsync.when(
        loading: () => const SizedBox(
          height: 88,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        error: (_, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PublicTariffsHeader(accent: AuthVisuals.primary(context)),
            const SizedBox(height: 12),
            Text(
              'Не удалось загрузить тарифы доставки.',
              style: TextStyle(
                color: AppColors.textSecondary.withValues(alpha: 0.9),
                fontWeight: FontWeight.w500,
                height: 1.25,
              ),
            ),
          ],
        ),
        data: (tariffs) {
          if (tariffs.isEmpty) return const SizedBox.shrink();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PublicTariffsHeader(accent: AuthVisuals.primary(context)),
              const SizedBox(height: 14),
              for (var i = 0; i < tariffs.length; i++) ...[
                _PublicTariffRow(tariff: tariffs[i]),
                if (i != tariffs.length - 1)
                  Divider(
                    height: 18,
                    color: const Color(0xFF2F2F2F).withValues(alpha: 0.08),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _PublicTariffsHeader extends StatelessWidget {
  final Color accent;

  const _PublicTariffsHeader({required this.accent});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.price_change_rounded, color: accent, size: 20),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Тарифы доставки',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF2F2F2F),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PublicTariffRow extends StatelessWidget {
  final UserDeliveryTariff tariff;

  const _PublicTariffRow({required this.tariff});

  @override
  Widget build(BuildContext context) {
    final accent = AuthVisuals.primary(context);
    final price = _priceFrom(tariff);
    final priceText = price > 0 ? 'от \$${_fmt(price)}/кг' : 'цена от —';

    return Row(
      children: [
        Expanded(
          child: Text(
            tariff.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              height: 1.15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2F2F2F),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            priceText,
            style: TextStyle(
              color: accent,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  static double _priceFrom(UserDeliveryTariff tariff) {
    final tierPrices = tariff.weightTiers
        .map((tier) => tier.pricePerKg)
        .where((price) => price > 0)
        .toList();
    if (tierPrices.isEmpty) return tariff.baseCost;
    tierPrices.sort();
    return tierPrices.first;
  }

  static String _fmt(double value) {
    final rounded = value.toStringAsFixed(2);
    return rounded.endsWith('00')
        ? value.toStringAsFixed(0)
        : rounded.replaceFirst(RegExp(r'0$'), '');
  }
}
