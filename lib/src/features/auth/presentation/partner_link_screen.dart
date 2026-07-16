import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/app_background.dart';
import '../data/auth_provider.dart';
import '../data/partner_link_provider.dart';
import 'auth_visuals.dart';

class PartnerLinkScreen extends ConsumerStatefulWidget {
  const PartnerLinkScreen({required this.token, super.key});

  final String token;

  @override
  ConsumerState<PartnerLinkScreen> createState() => _PartnerLinkScreenState();
}

class _PartnerLinkScreenState extends ConsumerState<PartnerLinkScreen> {
  bool _started = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    if (_started || !mounted) return;
    _started = true;
    final notifier = ref.read(partnerLinkProvider.notifier);
    final captured = await notifier.captureToken(widget.token);
    if (!mounted || !captured) return;
    final valid = await notifier.validate();
    if (!mounted || !valid) return;
    if (!ref.read(authProvider).isLoggedIn) {
      context.go('/login');
      return;
    }
    final completed = await notifier.complete();
    if (!mounted || !completed) return;
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (mounted) context.go('/');
  }

  Future<void> _retry() async {
    setState(() => _started = false);
    await _run();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(partnerLinkProvider);
    final isError = state.phase == PartnerLinkPhase.error;
    final isCompleted = state.phase == PartnerLinkPhase.completed;
    final accent = AuthVisuals.primary(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const AppBackground(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: AuthResponsiveContent(
                  child: AuthFormCard(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            color: (isError ? Colors.red : accent).withValues(
                              alpha: 0.12,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isError
                                ? Icons.link_off_rounded
                                : isCompleted
                                ? Icons.verified_rounded
                                : Icons.link_rounded,
                            color: isError ? Colors.red.shade700 : accent,
                            size: 34,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          isError
                              ? 'Не удалось привязать аккаунт'
                              : isCompleted
                              ? 'Аккаунт привязан'
                              : 'Привязываем аккаунт',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          isError
                              ? state.error ??
                                    'Проверьте ссылку и повторите попытку.'
                              : isCompleted
                              ? 'Код ${state.clientCode ?? 'клиента'} успешно передан сервису партнёра.'
                              : 'Это займёт несколько секунд. Дополнительное подтверждение не требуется.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF666666),
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (isError)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              FilledButton.icon(
                                onPressed: _retry,
                                style: AuthVisuals.primaryButtonStyle(context),
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('Повторить'),
                              ),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: () async {
                                  await ref
                                      .read(partnerLinkProvider.notifier)
                                      .clear();
                                  if (context.mounted) context.go('/');
                                },
                                child: const Text('Продолжить без привязки'),
                              ),
                            ],
                          )
                        else if (!isCompleted)
                          CircularProgressIndicator(color: accent),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
