import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/help_dialog.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  final _domainCtrl = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  bool _agreePersonalData = false;
  bool _agreePrivacyPolicy = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    _domainCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_nameCtrl.text.isEmpty ||
        _phoneCtrl.text.isEmpty ||
        _emailCtrl.text.isEmpty ||
        _passwordCtrl.text.isEmpty ||
        _domainCtrl.text.isEmpty) {
      _showError('Заполните все поля');
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

    if (!_agreePersonalData) {
      _showError('Необходимо согласие на обработку персональных данных');
      return;
    }

    if (!_agreePrivacyPolicy) {
      _showError('Необходимо согласие с политикой обработки данных');
      return;
    }

    setState(() => _isLoading = true);

    // Demo: simulate registration
    await Future.delayed(const Duration(seconds: 1));

    setState(() => _isLoading = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Регистрация успешна! Войдите в систему.'),
          backgroundColor: Colors.green,
        ),
      );
      context.go('/login');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
    );
  }

  void _showPersonalDataConsent() {
    showHelpDialog(
      context,
      title: 'Согласие на обработку персональных данных',
      content: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Я даю согласие на обработку моих персональных данных в соответствии с Федеральным законом от 27.07.2006 № 152-ФЗ «О персональных данных».',
            style: TextStyle(height: 1.5),
          ),
          SizedBox(height: 12),
          Text(
            'Персональные данные включают:',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 8),
          Text('• Фамилия, имя, отчество'),
          Text('• Номер телефона'),
          Text('• Адрес электронной почты'),
          SizedBox(height: 12),
          Text(
            'Данные обрабатываются в целях:',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 8),
          Text('• Идентификации пользователя'),
          Text('• Оказания услуг по доставке грузов'),
          Text('• Связи с пользователем'),
          Text('• Направления уведомлений о статусе грузов'),
          SizedBox(height: 12),
          Text(
            'Согласие действует до момента его отзыва путём направления письменного уведомления.',
            style: TextStyle(height: 1.5),
          ),
        ],
      ),
    );
  }

  void _showPrivacyPolicy() {
    showHelpDialog(
      context,
      title: 'Политика обработки персональных данных',
      content: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '1. Общие положения',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 8),
          Text(
            'Настоящая политика определяет порядок обработки персональных данных пользователей сервиса 2A Logistic.',
            style: TextStyle(height: 1.5),
          ),
          SizedBox(height: 12),
          Text('2. Сбор данных', style: TextStyle(fontWeight: FontWeight.w700)),
          SizedBox(height: 8),
          Text(
            'Мы собираем только те данные, которые необходимы для оказания услуг: ФИО, контактные данные, информация о грузах.',
            style: TextStyle(height: 1.5),
          ),
          SizedBox(height: 12),
          Text(
            '3. Хранение данных',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 8),
          Text(
            'Данные хранятся на защищённых серверах и не передаются третьим лицам без согласия пользователя, за исключением случаев, предусмотренных законом.',
            style: TextStyle(height: 1.5),
          ),
          SizedBox(height: 12),
          Text(
            '4. Права пользователя',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 8),
          Text('• Получение информации о своих данных'),
          Text('• Изменение или удаление данных'),
          Text('• Отзыв согласия на обработку'),
          SizedBox(height: 12),
          Text('5. Контакты', style: TextStyle(fontWeight: FontWeight.w700)),
          SizedBox(height: 8),
          Text(
            'По вопросам обработки данных: privacy@2a-logistics.ru',
            style: TextStyle(height: 1.5),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                  onTap: () => context.pop(),
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

              // Title
              const Text(
                'Регистрация',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              const Text(
                'Создайте аккаунт для доступа к личному кабинету',
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
                      label: 'ФИО',
                      hint: 'Иванов Иван Иванович',
                      prefixIcon: Icons.person_rounded,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _phoneCtrl,
                      label: 'Номер телефона',
                      hint: '+7 (999) 123-45-67',
                      prefixIcon: Icons.phone_rounded,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [_PhoneInputFormatter()],
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _emailCtrl,
                      label: 'Email',
                      hint: 'user@example.com',
                      prefixIcon: Icons.email_rounded,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _passwordCtrl,
                      label: 'Пароль',
                      hint: 'Минимум 6 символов',
                      prefixIcon: Icons.lock_rounded,
                      obscureText: _obscurePassword,
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
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _confirmPasswordCtrl,
                      label: 'Подтверждение пароля',
                      hint: 'Повторите пароль',
                      prefixIcon: Icons.lock_outline_rounded,
                      obscureText: _obscureConfirmPassword,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          color: const Color(0xFF999999),
                          size: 20,
                        ),
                        onPressed: () => setState(
                          () => _obscureConfirmPassword =
                              !_obscureConfirmPassword,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _domainCtrl,
                      label: 'Домен компании',
                      hint: 'example-company',
                      prefixIcon: Icons.business_rounded,
                    ),
                    const SizedBox(height: 20),

                    // Checkboxes
                    _buildCheckbox(
                      value: _agreePersonalData,
                      onChanged: (v) =>
                          setState(() => _agreePersonalData = v ?? false),
                      label: 'Согласие на обработку персональных данных',
                      onTapLink: _showPersonalDataConsent,
                    ),
                    const SizedBox(height: 12),
                    _buildCheckbox(
                      value: _agreePrivacyPolicy,
                      onChanged: (v) =>
                          setState(() => _agreePrivacyPolicy = v ?? false),
                      label:
                          'Политика в отношении обработки персональных данных',
                      onTapLink: _showPrivacyPolicy,
                    ),
                    const SizedBox(height: 24),

                    FilledButton(
                      onPressed: _isLoading ? null : _register,
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
    bool obscureText = false,
    Widget? suffixIcon,
    List<TextInputFormatter>? inputFormatters,
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
            obscureText: obscureText,
            inputFormatters: inputFormatters,
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

  Widget _buildCheckbox({
    required bool value,
    required ValueChanged<bool?> onChanged,
    required String label,
    required VoidCallback onTapLink,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFFfe3301),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: onTapLink,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: label,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFFfe3301),
                      decoration: TextDecoration.underline,
                      decorationColor: Color(0xFFfe3301),
                      height: 1.4,
                    ),
                  ),
                ],
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

    // Format as +7 (XXX) XXX-XX-XX
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
