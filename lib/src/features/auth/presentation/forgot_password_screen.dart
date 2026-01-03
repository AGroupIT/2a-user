import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _loginCtrl = TextEditingController();
  bool _isLoading = false;
  bool _isSent = false;

  @override
  void dispose() {
    _loginCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendReset() async {
    if (_loginCtrl.text.isEmpty) {
      _showError('Введите email или телефон');
      return;
    }

    setState(() => _isLoading = true);

    // Demo: simulate sending
    await Future.delayed(const Duration(seconds: 1));

    setState(() {
      _isLoading = false;
      _isSent = true;
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
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
            topPadding + 40,
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
              const SizedBox(height: 32),

              // Icon
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFFfe3301).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.lock_reset_rounded,
                    size: 40,
                    color: Color(0xFFfe3301),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Title
              const Text(
                'Восстановление пароля',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              const Text(
                'Введите email или телефон, на который будет отправлен новый пароль',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF666666),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),

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
                child: _isSent ? _buildSuccessContent() : _buildFormContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Email или телефон',
          style: TextStyle(
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
            controller: _loginCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              hintText: 'user@example.com или +7 (999) 123-45-67',
              hintStyle: TextStyle(color: Color(0xFFAAAAAA), fontSize: 14),
              prefixIcon: Icon(
                Icons.alternate_email_rounded,
                color: Color(0xFF999999),
                size: 20,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _isLoading ? null : _sendReset,
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
                  'Отправить',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
        ),
      ],
    );
  }

  Widget _buildSuccessContent() {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.check_rounded,
            size: 32,
            color: Colors.green.shade600,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Письмо отправлено!',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          'Новый пароль отправлен на\n${_loginCtrl.text}',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF666666),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => context.go('/login'),
          child: const Text(
            'Вернуться к входу',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
        ),
      ],
    );
  }
}
