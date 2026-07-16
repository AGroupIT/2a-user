import 'dart:async';

import 'package:flutter/material.dart';
import 'package:twoalogisticcabineuser/src/core/ui/app_toast.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/api_client.dart';
import '../../../core/ui/app_background.dart';
import '../../../core/ui/app_colors.dart';
import '../data/partner_link_provider.dart';
import '../data/registration_provider.dart';
import 'auth_visuals.dart';

enum _PhoneVerificationStatus { idle, waiting, verified }

enum _RegistrationStep { contacts, password, codes }

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  final _agentCodeCtrl = TextEditingController();
  final _referralCodeCtrl = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isPhoneVerificationLoading = false;
  bool _isPhoneVerificationChecking = false;
  _RegistrationStep _currentStep = _RegistrationStep.contacts;

  _PhoneVerificationStatus _phoneVerificationStatus =
      _PhoneVerificationStatus.idle;
  String? _pendingPhoneVerificationToken;
  String? _confirmedPhoneVerificationToken;
  String? _verificationPhone;
  String? _verifiedPhone;
  String? _callPhone;
  String? _callPhonePretty;
  String? _phoneVerificationError;
  Timer? _phoneVerificationPollTimer;
  Timer? _phoneVerificationCountdownTimer;
  int _phoneVerificationSecondsLeft = 300;

  @override
  void initState() {
    super.initState();
    _phoneCtrl.addListener(_handlePhoneChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(registrationProvider.notifier).reset();
    });
  }

  @override
  void dispose() {
    _phoneCtrl.removeListener(_handlePhoneChanged);
    _cancelPhoneVerificationTimers();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    _agentCodeCtrl.dispose();
    _referralCodeCtrl.dispose();
    super.dispose();
  }

  void _cancelPhoneVerificationTimers() {
    _phoneVerificationPollTimer?.cancel();
    _phoneVerificationPollTimer = null;
    _phoneVerificationCountdownTimer?.cancel();
    _phoneVerificationCountdownTimer = null;
  }

  String? _normalizePhoneForApi() {
    final digits = _phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) return '7$digits';
    if (digits.length == 11 && digits.startsWith('8')) {
      return '7${digits.substring(1)}';
    }
    if (digits.length == 11 && digits.startsWith('7')) return digits;
    return null;
  }

  String? _validatePhone() {
    final digits = _phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return 'Введите номер телефона';
    if (_normalizePhoneForApi() == null) {
      return 'Введите полный номер телефона в формате +7 (999) 123-45-67';
    }
    return null;
  }

  void _handlePhoneChanged() {
    final currentPhone = _normalizePhoneForApi();
    final trackedPhone = _verifiedPhone ?? _verificationPhone;
    if (trackedPhone != null && currentPhone != trackedPhone) {
      _resetPhoneVerification();
    } else if (_phoneVerificationError != null && currentPhone != null) {
      setState(() => _phoneVerificationError = null);
    }
  }

  void _resetPhoneVerification({String? error}) {
    _cancelPhoneVerificationTimers();
    if (!mounted) return;
    setState(() {
      _phoneVerificationStatus = _PhoneVerificationStatus.idle;
      _pendingPhoneVerificationToken = null;
      _confirmedPhoneVerificationToken = null;
      _verificationPhone = null;
      _verifiedPhone = null;
      _callPhone = null;
      _callPhonePretty = null;
      _phoneVerificationError = error;
      _phoneVerificationSecondsLeft = 300;
      _isPhoneVerificationLoading = false;
      _isPhoneVerificationChecking = false;
    });
  }

  Future<void> _requestPhoneVerification() async {
    final phoneError = _validatePhone();
    if (phoneError != null) {
      setState(() => _phoneVerificationError = phoneError);
      return;
    }

    final phone = _normalizePhoneForApi()!;
    _cancelPhoneVerificationTimers();
    setState(() {
      _isPhoneVerificationLoading = true;
      _phoneVerificationError = null;
      _phoneVerificationStatus = _PhoneVerificationStatus.idle;
      _pendingPhoneVerificationToken = null;
      _confirmedPhoneVerificationToken = null;
      _verificationPhone = phone;
      _verifiedPhone = null;
      _callPhone = null;
      _callPhonePretty = null;
      _phoneVerificationSecondsLeft = 300;
    });

    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.post(
        '/register/phone-verification/request',
        data: {'phone': phone},
      );

      if (!mounted) return;

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final token = data['verificationToken'] as String?;
        final callPhone = data['callPhone'] as String?;

        if (token == null || callPhone == null) {
          throw StateError('Phone verification response is incomplete');
        }

        setState(() {
          _pendingPhoneVerificationToken = token;
          _callPhone = callPhone;
          _callPhonePretty = data['callPhonePretty'] as String? ?? callPhone;
          _phoneVerificationStatus = _PhoneVerificationStatus.waiting;
          _isPhoneVerificationLoading = false;
        });

        _startPhoneVerificationPolling();
        _startPhoneVerificationCountdown();
      } else {
        final error =
            response.data?['error'] as String? ??
            'Не удалось начать проверку телефона';
        _resetPhoneVerification(error: error);
      }
    } catch (_) {
      if (!mounted) return;
      _resetPhoneVerification(error: 'Не удалось начать проверку телефона');
    }
  }

  void _startPhoneVerificationPolling() {
    _phoneVerificationPollTimer?.cancel();
    _phoneVerificationPollTimer = Timer.periodic(const Duration(seconds: 3), (
      _,
    ) {
      _checkPhoneVerification();
    });
  }

  void _startPhoneVerificationCountdown() {
    _phoneVerificationCountdownTimer?.cancel();
    _phoneVerificationCountdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (!mounted) return;
        if (_phoneVerificationSecondsLeft > 0) {
          setState(() => _phoneVerificationSecondsLeft--);
        } else {
          _resetPhoneVerification(
            error: 'Время проверки истекло. Запросите новый звонок.',
          );
        }
      },
    );
  }

  Future<void> _checkPhoneVerification({
    bool showPendingMessage = false,
  }) async {
    final token = _pendingPhoneVerificationToken;
    if (token == null || _isPhoneVerificationChecking) return;

    _isPhoneVerificationChecking = true;
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.post(
        '/register/phone-verification/verify',
        data: {'verificationToken': token},
      );

      if (!mounted) return;

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        if (data['confirmed'] == true) {
          _cancelPhoneVerificationTimers();
          HapticFeedback.heavyImpact();
          setState(() {
            _confirmedPhoneVerificationToken =
                data['phoneVerificationToken'] as String?;
            _verifiedPhone = _verificationPhone;
            _phoneVerificationStatus = _PhoneVerificationStatus.verified;
            _phoneVerificationError = null;
          });
        } else if (data['expired'] == true) {
          _resetPhoneVerification(
            error: 'Время проверки истекло. Запросите новый звонок.',
          );
        } else if (showPendingMessage) {
          _showError('Звонок пока не подтверждён');
        }
      }
    } catch (_) {
      if (showPendingMessage && mounted) {
        _showError('Не удалось проверить статус звонка');
      }
    } finally {
      _isPhoneVerificationChecking = false;
    }
  }

  Future<void> _makeVerificationCall() async {
    final callPhone = _callPhone;
    if (callPhone == null) return;

    final uri = Uri(scheme: 'tel', path: callPhone);
    final canLaunch = await canLaunchUrl(uri);
    if (!mounted) return;

    if (canLaunch) {
      await launchUrl(uri);
    } else {
      _showError('Не удалось открыть приложение телефона');
    }
  }

  String _formatPhoneVerificationCountdown() {
    final minutes = _phoneVerificationSecondsLeft ~/ 60;
    final seconds = _phoneVerificationSecondsLeft % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  bool _validateContactsStep() {
    if (_nameCtrl.text.trim().isEmpty) {
      _showError('Введите ваше ФИО');
      return false;
    }
    final phoneError = _validatePhone();
    if (phoneError != null) {
      _showError(phoneError);
      return false;
    }
    final phoneForApi = _normalizePhoneForApi()!;
    if (_confirmedPhoneVerificationToken == null ||
        _verifiedPhone != phoneForApi) {
      _showError('Подтвердите номер телефона');
      return false;
    }
    if (_emailCtrl.text.trim().isEmpty) {
      _showError('Введите email');
      return false;
    }
    return true;
  }

  bool _validatePasswordStep() {
    if (_passwordCtrl.text.isEmpty) {
      _showError('Введите пароль');
      return false;
    }
    if (_passwordCtrl.text.length < 6) {
      _showError('Пароль должен быть не менее 6 символов');
      return false;
    }
    if (_passwordCtrl.text != _confirmPasswordCtrl.text) {
      _showError('Пароли не совпадают');
      return false;
    }
    return true;
  }

  void _goToPasswordStep() {
    if (!_validateContactsStep()) return;
    FocusScope.of(context).unfocus();
    setState(() => _currentStep = _RegistrationStep.password);
  }

  void _goToCodesStep() {
    if (!_validatePasswordStep()) return;
    FocusScope.of(context).unfocus();
    setState(() => _currentStep = _RegistrationStep.codes);
  }

  void _goToPreviousStep() {
    FocusScope.of(context).unfocus();
    setState(() {
      _currentStep = switch (_currentStep) {
        _RegistrationStep.contacts => _RegistrationStep.contacts,
        _RegistrationStep.password => _RegistrationStep.contacts,
        _RegistrationStep.codes => _RegistrationStep.password,
      };
    });
  }

  Future<void> _submit() async {
    if (!_validateContactsStep()) {
      setState(() => _currentStep = _RegistrationStep.contacts);
      return;
    }
    if (!_validatePasswordStep()) {
      setState(() => _currentStep = _RegistrationStep.password);
      return;
    }

    final partnerLink = ref.read(partnerLinkProvider);
    final success = await ref
        .read(registrationProvider.notifier)
        .register(
          fullName: _nameCtrl.text,
          phone: _phoneCtrl.text,
          email: _emailCtrl.text,
          password: _passwordCtrl.text,
          confirmPassword: _confirmPasswordCtrl.text,
          phoneVerificationToken: _confirmedPhoneVerificationToken!,
          agentCode: partnerLink.hasPendingToken ? null : _agentCodeCtrl.text,
          referralCode: _referralCodeCtrl.text,
          partnerLinkToken: partnerLink.hasPendingToken
              ? partnerLink.token
              : null,
        );

    if (!mounted) return;

    if (!success) {
      final error = ref.read(registrationProvider).error;
      _showError(error ?? 'Не удалось зарегистрироваться');
    }
    // При успехе: loginWithData меняет authState → роутер сам редиректит на главную
  }

  void _showError(String message) {
    AppToast.showFromSnackBar(
      context,
      SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(registrationProvider);
    final partnerLinkActive = ref.watch(
      partnerLinkProvider.select((value) => value.hasPendingToken),
    );
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final topPadding = MediaQuery.paddingOf(context).top;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
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
                bottomPadding + keyboardInset + 24,
              ),
              child: AuthResponsiveContent(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const AuthHeroHeader(
                      icon: Icons.how_to_reg_rounded,
                      title: 'Станьте клиентом',
                      subtitle:
                          'Зарегистрируйтесь, подтвердите телефон и сразу начинайте пользоваться нашим складом для работы с грузами.',
                    ),
                    const SizedBox(height: 24),

                    AuthFormCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildStepProgress(),
                          const SizedBox(height: 20),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 320),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            transitionBuilder: _stepTransition,
                            child: _buildCurrentStep(
                              state,
                              partnerLinkActive: partnerLinkActive,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Уже есть аккаунт? ',
                          style: TextStyle(color: Color(0xFF666666)),
                        ),
                        GestureDetector(
                          onTap: () => context.go('/login'),
                          child: Text(
                            'Войти',
                            style: TextStyle(
                              color: AuthVisuals.primary(context),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepProgress() {
    return Row(
      children: [
        Expanded(
          child: _buildStepChip(
            step: _RegistrationStep.contacts,
            label: 'Контакты',
            icon: Icons.person_pin_rounded,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStepChip(
            step: _RegistrationStep.password,
            label: 'Пароль',
            icon: Icons.lock_rounded,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStepChip(
            step: _RegistrationStep.codes,
            label: 'Коды',
            icon: Icons.card_giftcard_rounded,
          ),
        ),
      ],
    );
  }

  Widget _buildStepChip({
    required _RegistrationStep step,
    required String label,
    required IconData icon,
  }) {
    final accent = AuthVisuals.primary(context);
    final isActive = step == _currentStep;
    final isDone = step.index < _currentStep.index;
    final foreground = isActive || isDone
        ? accent
        : AppColors.textSecondary.withValues(alpha: 0.86);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
      decoration: BoxDecoration(
        color: isActive
            ? accent.withValues(alpha: 0.12)
            : isDone
            ? accent.withValues(alpha: 0.07)
            : Colors.white.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isActive
              ? accent.withValues(alpha: 0.28)
              : isDone
              ? accent.withValues(alpha: 0.16)
              : const Color(0xFF2F2F2F).withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isDone ? Icons.check_rounded : icon,
            color: foreground,
            size: 15,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: foreground,
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStep(
    RegistrationState state, {
    required bool partnerLinkActive,
  }) {
    return switch (_currentStep) {
      _RegistrationStep.contacts => _buildContactsStep(state),
      _RegistrationStep.password => _buildPasswordStep(state),
      _RegistrationStep.codes => _buildCodesStep(
        state,
        partnerLinkActive: partnerLinkActive,
      ),
    };
  }

  Widget _buildContactsStep(RegistrationState state) {
    return Column(
      key: const ValueKey('contacts-step'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildStepTitle(
          icon: Icons.person_pin_rounded,
          title: 'Контактные данные',
          subtitle: 'Сначала подтвердим, кто вы и куда отправлять уведомления.',
        ),
        const SizedBox(height: 18),
        _buildTextField(
          controller: _nameCtrl,
          label: 'ФИО *',
          hint: 'Иванов Иван Иванович',
          prefixIcon: Icons.person_rounded,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _phoneCtrl,
          label: 'Телефон *',
          hint: '+7 (999) 123-45-67',
          prefixIcon: Icons.phone_rounded,
          keyboardType: TextInputType.phone,
          inputFormatters: [_PhoneInputFormatter()],
        ),
        const SizedBox(height: 10),
        _buildPhoneVerificationSection(state),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _emailCtrl,
          label: 'Email *',
          hint: 'example@mail.com',
          prefixIcon: Icons.email_rounded,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: state.isLoading ? null : _goToPasswordStep,
          style: AuthVisuals.primaryButtonStyle(context),
          icon: const Icon(Icons.arrow_forward_rounded),
          label: const Text(
            'Продолжить',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordStep(RegistrationState state) {
    return Column(
      key: const ValueKey('password-step'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildStepTitle(
          icon: Icons.lock_rounded,
          title: 'Защита аккаунта',
          subtitle: 'Придумайте пароль для входа в личный кабинет.',
        ),
        const SizedBox(height: 18),
        _buildPasswordField(
          controller: _passwordCtrl,
          label: 'Пароль *',
          hint: 'Не менее 6 символов',
          obscure: _obscurePassword,
          onToggle: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
        const SizedBox(height: 16),
        _buildPasswordField(
          controller: _confirmPasswordCtrl,
          label: 'Подтвердите пароль *',
          hint: 'Повторите пароль',
          obscure: _obscureConfirm,
          onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            SizedBox(
              width: 96,
              child: OutlinedButton.icon(
                onPressed: state.isLoading ? null : _goToPreviousStep,
                style: AuthVisuals.outlinedButtonStyle(context),
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Назад',
                    maxLines: 1,
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: state.isLoading ? null : _goToCodesStep,
                style: AuthVisuals.primaryButtonStyle(context),
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text(
                  'Продолжить',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCodesStep(
    RegistrationState state, {
    required bool partnerLinkActive,
  }) {
    return Column(
      key: const ValueKey('codes-step'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildStepTitle(
          icon: Icons.card_giftcard_rounded,
          title: 'Коды и привязка',
          subtitle: partnerLinkActive
              ? 'Агент 2a-logistic.ru и код PL- будут назначены автоматически.'
              : 'Если кодов нет — просто оставьте поля пустыми.',
        ),
        const SizedBox(height: 18),
        if (partnerLinkActive)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AuthVisuals.primary(context).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AuthVisuals.primary(context).withValues(alpha: 0.2),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.verified_user_rounded, size: 21),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Регистрация по защищённой ссылке партнёра: агент и префикс нельзя изменить.',
                    style: TextStyle(fontSize: 13, height: 1.3),
                  ),
                ),
              ],
            ),
          )
        else ...[
          _buildTextField(
            controller: _agentCodeCtrl,
            label: 'Код агента',
            hint: 'Код агента',
            prefixIcon: Icons.badge_rounded,
            textCapitalization: TextCapitalization.characters,
          ),
          const SizedBox(height: 8),
          Text(
            'Если кода нет, оставьте поле пустым.',
            style: TextStyle(
              fontSize: 12,
              height: 1.25,
              color: AppColors.textSecondary.withValues(alpha: 0.9),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
        const SizedBox(height: 16),
        _buildTextField(
          controller: _referralCodeCtrl,
          label: 'Реферальный код (необязательно)',
          hint: 'ABC123',
          prefixIcon: Icons.card_giftcard_rounded,
          textCapitalization: TextCapitalization.characters,
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            SizedBox(
              width: 96,
              child: OutlinedButton.icon(
                onPressed: state.isLoading ? null : _goToPreviousStep,
                style: AuthVisuals.outlinedButtonStyle(context),
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Назад',
                    maxLines: 1,
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: state.isLoading ? null : _submit,
                style: AuthVisuals.primaryButtonStyle(context),
                icon: state.isLoading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.how_to_reg_rounded, size: 18),
                label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Зарегистрироваться',
                    maxLines: 1,
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStepTitle({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final accent = AuthVisuals.primary(context);

    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: accent, size: 21),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF2F2F2F),
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                  color: AppColors.textSecondary.withValues(alpha: 0.9),
                  fontSize: 12,
                  height: 1.25,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stepTransition(Widget child, Animation<double> animation) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    return FadeTransition(
      opacity: curved,
      child: SizeTransition(
        sizeFactor: curved,
        axisAlignment: -1,
        child: child,
      ),
    );
  }

  Widget _buildPhoneVerificationSection(RegistrationState registrationState) {
    final isBusy = registrationState.isLoading || _isPhoneVerificationLoading;
    final accent = AuthVisuals.primary(context);

    if (_phoneVerificationStatus == _PhoneVerificationStatus.verified) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFEFFAF3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFBFE8CC)),
        ),
        child: const Row(
          children: [
            Icon(Icons.verified_rounded, color: Color(0xFF1E8E3E), size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Телефон подтверждён. Можно завершить регистрацию.',
                style: TextStyle(
                  color: Color(0xFF166534),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_phoneVerificationStatus == _PhoneVerificationStatus.waiting) {
      final phoneText = _callPhonePretty ?? _callPhone ?? 'номер для звонка';
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.phone_callback_rounded, color: accent, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Подтвердите телефон звонком',
                    style: TextStyle(
                      color: accent,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  _formatPhoneVerificationCountdown(),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF444444),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Позвоните со своего номера на $phoneText. SMS.RU сразу сбросит звонок, поэтому он будет бесплатным. После подтверждения регистрация станет доступна.',
              style: const TextStyle(
                color: Color(0xFF4B5563),
                fontSize: 13,
                height: 1.32,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: _callPhone == null ? null : _makeVerificationCall,
                  style: AuthVisuals.primaryButtonStyle(context),
                  icon: const Icon(Icons.call_rounded, size: 18),
                  label: const Text('Позвонить'),
                ),
                OutlinedButton.icon(
                  onPressed: _isPhoneVerificationChecking
                      ? null
                      : () => _checkPhoneVerification(showPendingMessage: true),
                  style: AuthVisuals.outlinedButtonStyle(context),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Проверить'),
                ),
                TextButton(
                  onPressed: isBusy ? null : _requestPhoneVerification,
                  child: const Text('Отправить заново'),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: isBusy ? null : _requestPhoneVerification,
          style: AuthVisuals.outlinedButtonStyle(context),
          icon: _isPhoneVerificationLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.verified_user_rounded, size: 18),
          label: const Text('Подтвердить телефон звонком'),
        ),
        if (_phoneVerificationError != null) ...[
          const SizedBox(height: 6),
          Text(
            _phoneVerificationError!,
            style: TextStyle(
              color: Colors.red.shade700,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ] else ...[
          const SizedBox(height: 6),
          const Text(
            'После ввода номера нажмите кнопку: мы покажем бесплатный номер, на который нужно позвонить в течение 5 минут.',
            style: TextStyle(
              color: Color(0xFF777777),
              fontSize: 12,
              height: 1.25,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData prefixIcon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
    TextCapitalization textCapitalization = TextCapitalization.none,
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
            inputFormatters: inputFormatters,
            maxLines: maxLines,
            textCapitalization: textCapitalization,
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

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool obscure,
    required VoidCallback onToggle,
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
            obscureText: obscure,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                color: Color(0xFFAAAAAA),
                fontSize: 14,
              ),
              prefixIcon: Icon(
                Icons.lock_rounded,
                color: accent.withValues(alpha: 0.72),
                size: 20,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  obscure
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: const Color(0xFF999999),
                  size: 20,
                ),
                onPressed: onToggle,
              ),
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

class _PhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    final digits = text.replaceAll(RegExp(r'\D'), '');

    if (digits.isEmpty) return newValue.copyWith(text: '');

    final buffer = StringBuffer();
    int index = 0;

    if (digits.isNotEmpty) {
      buffer.write('+');
      buffer.write(digits[index++]);
    }
    if (index < digits.length) {
      buffer.write(' (');
      for (int i = 0; i < 3 && index < digits.length; i++) {
        buffer.write(digits[index++]);
      }
      buffer.write(')');
    }
    if (index < digits.length) {
      buffer.write(' ');
      for (int i = 0; i < 3 && index < digits.length; i++) {
        buffer.write(digits[index++]);
      }
    }
    if (index < digits.length) {
      buffer.write('-');
      for (int i = 0; i < 2 && index < digits.length; i++) {
        buffer.write(digits[index++]);
      }
    }
    if (index < digits.length) {
      buffer.write('-');
      for (int i = 0; i < 2 && index < digits.length; i++) {
        buffer.write(digits[index++]);
      }
    }

    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.length),
    );
  }
}
