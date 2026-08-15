import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/app_colors.dart';
import '../../../core/utils/locale_text.dart';
import '../data/auth_provider.dart';
import '../data/client_partner_invite_provider.dart';
import 'auth_visuals.dart';

class ClientPartnerInviteScreen extends ConsumerStatefulWidget {
  const ClientPartnerInviteScreen({super.key, required this.token});

  final String token;

  @override
  ConsumerState<ClientPartnerInviteScreen> createState() =>
      _ClientPartnerInviteScreenState();
}

class _ClientPartnerInviteScreenState
    extends ConsumerState<ClientPartnerInviteScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final captured = await ref
          .read(clientPartnerInviteProvider.notifier)
          .captureToken(widget.token);
      if (captured) {
        await ref.read(clientPartnerInviteProvider.notifier).validate();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final invite = ref.watch(clientPartnerInviteProvider);
    final auth = ref.watch(authProvider);
    final loading =
        invite.phase == ClientPartnerInvitePhase.loading ||
        invite.phase == ClientPartnerInvitePhase.pending ||
        invite.phase == ClientPartnerInvitePhase.validating;
    final primary =
        _parseInviteColor(invite.colorPrimary) ?? AuthVisuals.fallbackPrimary;
    final secondary =
        _parseInviteColor(invite.colorSecondary) ??
        AuthVisuals.fallbackSecondary;
    final companyName = invite.agentName?.trim();
    final hasCompanyName = companyName != null && companyName.isNotEmpty;
    final baseTheme = Theme.of(context);

    return Theme(
      data: baseTheme.copyWith(
        colorScheme: baseTheme.colorScheme.copyWith(
          primary: primary,
          secondary: secondary,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            _InviteBrandBackground(primary: primary, secondary: secondary),
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: AuthResponsiveContent(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AuthHeroHeader(
                        icon: Icons.handshake_rounded,
                        title: invite.isValidated && hasCompanyName
                            ? companyName
                            : tr(
                                context,
                                ru: 'Приглашение партнёра',
                                zh: '合作伙伴邀请',
                              ),
                        subtitle: invite.isValidated && hasCompanyName
                            ? tr(
                                context,
                                ru: 'Защищённая регистрация в компании $companyName с автоматическим назначением клиентского префикса.',
                                zh: '在 $companyName 安全注册，系统会自动分配客户前缀。',
                              )
                            : tr(
                                context,
                                ru: 'Защищённая регистрация с автоматическим назначением компании и клиентского префикса.',
                                zh: '安全注册，系统会自动分配公司和客户前缀。',
                              ),
                      ),
                      const SizedBox(height: 24),
                      AuthFormCard(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: loading
                              ? const Padding(
                                  key: ValueKey('loading'),
                                  padding: EdgeInsets.symmetric(vertical: 36),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                )
                              : invite.isValidated
                              ? _validInvite(invite, auth.isLoggedIn)
                              : _invalidInvite(invite),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color? _parseInviteColor(String? rawValue) {
    final value = rawValue?.trim().replaceFirst('#', '');
    if (value == null || !RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(value)) {
      return null;
    }
    return Color(int.parse('FF$value', radix: 16));
  }

  Widget _validInvite(ClientPartnerInviteState invite, bool isLoggedIn) {
    return Column(
      key: const ValueKey('valid'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF2E9D68).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF2E9D68).withValues(alpha: 0.22),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.verified_user_rounded,
                    color: Color(0xFF2E9D68),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    tr(context, ru: 'Ссылка подтверждена', zh: '邀请链接已验证'),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _row(
                tr(context, ru: 'Партнёр', zh: '合作伙伴'),
                invite.partnerName ?? '—',
              ),
              _row(
                tr(context, ru: 'Компания', zh: '公司'),
                invite.agentName ?? '—',
              ),
              _row(
                tr(context, ru: 'Префикс клиента', zh: '客户前缀'),
                invite.prefix ?? '—',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          isLoggedIn
              ? tr(
                  context,
                  ru: 'Вы уже вошли в аккаунт. Партнёрская ссылка предназначена только для регистрации нового клиента и не переносит существующий аккаунт.',
                  zh: '您已登录。合作伙伴邀请链接仅用于注册新客户，不能转移现有账号。',
                )
              : tr(
                  context,
                  ru: 'Во время регистрации компания и префикс будут заполнены сервером. Изменить их вручную или подменить через ссылку нельзя.',
                  zh: '注册时，公司和客户前缀将由服务器填写，无法手动修改或通过链接替换。',
                ),
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: () => context.go(isLoggedIn ? '/' : '/register'),
          style: AuthVisuals.primaryButtonStyle(context),
          icon: Icon(
            isLoggedIn ? Icons.home_rounded : Icons.how_to_reg_rounded,
          ),
          label: Text(
            isLoggedIn
                ? tr(context, ru: 'Вернуться в кабинет', zh: '返回账户')
                : tr(context, ru: 'Зарегистрироваться', zh: '注册'),
          ),
        ),
        if (!isLoggedIn) ...[
          const SizedBox(height: 10),
          TextButton(
            onPressed: () async {
              await ref.read(clientPartnerInviteProvider.notifier).clear();
              if (mounted) context.go('/login');
            },
            child: Text(
              tr(context, ru: 'У меня уже есть аккаунт', zh: '我已有账号'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _invalidInvite(ClientPartnerInviteState invite) => Column(
    key: const ValueKey('invalid'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Icon(Icons.link_off_rounded, size: 48, color: Color(0xFFE53935)),
      const SizedBox(height: 14),
      Text(
        _localizedError(invite.error),
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 18),
      if (invite.token != null) ...[
        FilledButton.icon(
          onPressed: () =>
              ref.read(clientPartnerInviteProvider.notifier).validate(),
          style: AuthVisuals.primaryButtonStyle(context),
          icon: const Icon(Icons.refresh_rounded),
          label: Text(tr(context, ru: 'Повторить', zh: '重试')),
        ),
        const SizedBox(height: 10),
      ],
      OutlinedButton(
        onPressed: () => context.go('/login'),
        child: Text(tr(context, ru: 'Перейти ко входу', zh: '前往登录')),
      ),
    ],
  );

  String _localizedError(String? error) {
    if (error ==
        'Ссылка больше не активна. Попросите партнёра отправить новую.') {
      return tr(context, ru: error!, zh: '邀请链接已失效，请让合作伙伴发送新的链接。');
    }
    if (error == 'Не удалось проверить партнёрскую ссылку') {
      return tr(context, ru: error!, zh: '无法验证合作伙伴邀请链接');
    }
    if (error == 'Партнёрская ссылка недействительна' || error == null) {
      return tr(
        context,
        ru: error ?? 'Партнёрская ссылка недействительна',
        zh: '合作伙伴邀请链接无效',
      );
    }
    return error;
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );
}

class _InviteBrandBackground extends StatelessWidget {
  const _InviteBrandBackground({
    required this.primary,
    required this.secondary,
  });

  final Color primary;
  final Color secondary;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              primary.withValues(alpha: 0.10),
              Colors.white,
              secondary.withValues(alpha: 0.12),
            ],
          ),
        ),
      ),
    );
  }
}
