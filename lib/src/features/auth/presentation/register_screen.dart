import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/registration_provider.dart';

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
  final _referralCodeCtrl = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(registrationProvider.notifier).reset();
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    _referralCodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty) {
      _showError('Введите ваше ФИО');
      return;
    }
    if (_phoneCtrl.text.trim().isEmpty) {
      _showError('Введите номер телефона');
      return;
    }
    if (_emailCtrl.text.trim().isEmpty) {
      _showError('Введите email');
      return;
    }
    if (_passwordCtrl.text.isEmpty) {
      _showError('Введите пароль');
      return;
    }
    if (_passwordCtrl.text.length < 6) {
      _showError('Пароль должен быть не менее 6 символов');
      return;
    }
    if (_passwordCtrl.text != _confirmPasswordCtrl.text) {
      _showError('Пароли не совпадают');
      return;
    }

    final success = await ref.read(registrationProvider.notifier).register(
          fullName: _nameCtrl.text,
          phone: _phoneCtrl.text,
          email: _emailCtrl.text,
          password: _passwordCtrl.text,
          confirmPassword: _confirmPasswordCtrl.text,
          referralCode: _referralCodeCtrl.text,
        );

    if (!mounted) return;

    if (!success) {
      final error = ref.read(registrationProvider).error;
      _showError(error ?? 'Не удалось зарегистрироваться');
    }
    // При успехе: loginWithData меняет authState → роутер сам редиректит на главную
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(registrationProvider);
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final topPadding = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            24,
            topPadding + 20,
            24,
            bottomPadding + 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Back button
              Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: () => context.go('/login'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0A000000),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.arrow_back_ios_rounded,
                          size: 16,
                          color: Color(0xFF666666),
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Назад',
                          style: TextStyle(
                            color: Color(0xFF666666),
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Logo
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFfe3301), Color(0xFFff5f02)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.local_shipping_rounded,
                      color: Colors.white,
                      size: 42,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Title
              const Text(
                'Регистрация',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              const Text(
                'Создайте аккаунт и получите код клиента',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Color(0xFF666666)),
              ),
              const SizedBox(height: 24),

              // Form card
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 24,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
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
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _emailCtrl,
                      label: 'Email *',
                      hint: 'example@mail.com',
                      prefixIcon: Icons.email_rounded,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    _buildPasswordField(
                      controller: _passwordCtrl,
                      label: 'Пароль *',
                      hint: 'Не менее 6 символов',
                      obscure: _obscurePassword,
                      onToggle: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    const SizedBox(height: 16),
                    _buildPasswordField(
                      controller: _confirmPasswordCtrl,
                      label: 'Подтвердите пароль *',
                      hint: 'Повторите пароль',
                      obscure: _obscureConfirm,
                      onToggle: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _referralCodeCtrl,
                      label: 'Реферальный код (необязательно)',
                      hint: 'ABC123',
                      prefixIcon: Icons.card_giftcard_rounded,
                      textCapitalization: TextCapitalization.characters,
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: state.isLoading ? null : _submit,
                      child: state.isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Зарегистрироваться',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Login link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Уже есть аккаунт? ',
                    style: TextStyle(color: Color(0xFF666666)),
                  ),
                  GestureDetector(
                    onTap: () => context.go('/login'),
                    child: const Text(
                      'Войти',
                      style: TextStyle(
                        color: Color(0xFFfe3301),
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
            border: Border.all(color: const Color(0xFFE0E0E0)),
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
                color: const Color(0xFF999999),
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
            border: Border.all(color: const Color(0xFFE0E0E0)),
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
              prefixIcon: const Icon(
                Icons.lock_rounded,
                color: Color(0xFF999999),
                size: 20,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
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
