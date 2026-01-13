import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/api_client.dart';
import '../data/auth_provider.dart';

/// Этапы восстановления пароля
enum ResetStep {
  enterPhone, // Ввод номера телефона
  waitingCall, // Ожидание звонка
  enterPassword, // Ввод нового пароля
  success, // Успешно
}

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _phoneCtrl = TextEditingController();
  final _domainCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  
  /// Маска для ввода телефона: +7 (999) 123-45-67
  final _phoneMask = MaskTextInputFormatter(
    mask: '+7 (###) ###-##-##',
    filter: {'#': RegExp(r'[0-9]')},
    type: MaskAutoCompletionType.lazy,
  );
  
  String? _phoneError;
  String? _domainError;

  ResetStep _currentStep = ResetStep.enterPhone;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  // Данные для звонка
  String? _checkId;
  String? _callPhone;
  String? _callPhonePretty;
  DateTime? _expiresAt;
  String? _resetToken;
  Timer? _pollTimer;
  Timer? _countdownTimer;
  int _secondsLeft = 300; // 5 минут

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _domainCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    _pollTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  /// Валидация телефона для SMS.RU (формат: 79XXXXXXXXX)
  String? _validatePhone() {
    final digits = _phoneMask.getUnmaskedText();
    
    if (digits.isEmpty) {
      return 'Введите номер телефона';
    }
    
    if (digits.length != 10) {
      return 'Введите полный номер телефона (10 цифр после +7)';
    }
    
    if (!RegExp(r'^[0-9]+$').hasMatch(digits)) {
      return 'Номер должен содержать только цифры';
    }
    
    return null;
  }
  
  /// Валидация домена компании
  String? _validateDomain() {
    final domain = _domainCtrl.text.trim();
    
    if (domain.isEmpty) {
      return 'Введите домен компании';
    }
    
    return null;
  }
  
  /// Получить телефон в формате для SMS.RU: 79XXXXXXXXX
  String _getPhoneForApi() {
    final digits = _phoneMask.getUnmaskedText();
    return '7$digits'; // +7 уже в маске, добавляем 7 к 10 цифрам
  }

  /// Шаг 1: Запросить восстановление
  Future<void> _requestReset() async {
    final phoneError = _validatePhone();
    final domainError = _validateDomain();
    
    if (phoneError != null || domainError != null) {
      setState(() {
        _phoneError = phoneError;
        _domainError = domainError;
      });
      return;
    }
    
    setState(() {
      _phoneError = null;
      _domainError = null;
      _isLoading = true;
    });
    
    final phone = _getPhoneForApi();
    final domain = _domainCtrl.text.trim();

    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.post(
        '/password-reset/request',
        data: {'phone': phone, 'domain': domain},
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        setState(() {
          _checkId = data['checkId'];
          _callPhone = data['callPhone'];
          _callPhonePretty = data['callPhonePretty'];
          _expiresAt = DateTime.tryParse(data['expiresAt'] ?? '');
          _currentStep = ResetStep.waitingCall;
          _secondsLeft = 300;
          _isLoading = false;
        });

        // Запускаем polling для проверки звонка
        _startPolling();
        _startCountdown();
      } else {
        final error = response.data?['error'] ?? 'Ошибка запроса';
        _showError(error);
        setState(() => _isLoading = false);
      }
    } catch (e) {
      _showError('Не удалось отправить запрос');
      setState(() => _isLoading = false);
    }
  }

  /// Polling для проверки статуса звонка
  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _checkCallStatus();
    });
  }

  /// Обратный отсчёт
  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_secondsLeft > 0) {
        setState(() => _secondsLeft--);
      } else {
        _countdownTimer?.cancel();
        _pollTimer?.cancel();
        _showError('Время истекло. Попробуйте снова.');
        setState(() => _currentStep = ResetStep.enterPhone);
      }
    });
  }

  /// Проверить статус звонка
  Future<void> _checkCallStatus() async {
    if (_checkId == null) return;

    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.post(
        '/password-reset/verify',
        data: {'checkId': _checkId},
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;

        if (data['confirmed'] == true) {
          _pollTimer?.cancel();
          _countdownTimer?.cancel();
          _resetToken = data['resetToken'];
          HapticFeedback.heavyImpact();
          setState(() => _currentStep = ResetStep.enterPassword);
        } else if (data['expired'] == true) {
          _pollTimer?.cancel();
          _countdownTimer?.cancel();
          _showError('Время истекло. Попробуйте снова.');
          setState(() => _currentStep = ResetStep.enterPhone);
        }
      }
    } catch (e) {
      // Игнорируем ошибки polling
    }
  }

  /// Шаг 3: Установить новый пароль
  Future<void> _setNewPassword() async {
    final password = _passwordCtrl.text;
    final confirm = _confirmPasswordCtrl.text;

    if (password.length < 6) {
      _showError('Пароль должен быть не менее 6 символов');
      return;
    }

    if (password != confirm) {
      _showError('Пароли не совпадают');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.post(
        '/password-reset/complete',
        data: {'resetToken': _resetToken, 'newPassword': password},
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        final token = data['token'] as String?;
        final userData = data['user'] as Map<String, dynamic>?;
        
        HapticFeedback.heavyImpact();
        
        // Если есть токен - авторизуем пользователя
        if (token != null && userData != null) {
          final success = await ref.read(authProvider.notifier).loginWithData(
            token: token,
            userData: userData,
          );
          
          if (success && mounted) {
            // Перенаправляем в приложение
            context.go('/');
            return;
          }
        }
        
        // Если авторизация не удалась - показываем экран успеха
        setState(() {
          _currentStep = ResetStep.success;
          _isLoading = false;
        });
      } else {
        final error = response.data?['error'] ?? 'Ошибка';
        _showError(error);
        setState(() => _isLoading = false);
      }
    } catch (e) {
      _showError('Не удалось установить пароль');
      setState(() => _isLoading = false);
    }
  }

  /// Позвонить на номер
  Future<void> _makeCall() async {
    if (_callPhone == null) return;

    final uri = Uri.parse('tel:$_callPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
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
                  onTap: () {
                    if (_currentStep == ResetStep.enterPhone ||
                        _currentStep == ResetStep.success) {
                      context.pop();
                    } else {
                      _pollTimer?.cancel();
                      _countdownTimer?.cancel();
                      setState(() => _currentStep = ResetStep.enterPhone);
                    }
                  },
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
              Center(child: _buildIcon()),
              const SizedBox(height: 24),

              // Title
              Text(
                _getTitle(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _getSubtitle(),
                textAlign: TextAlign.center,
                style: const TextStyle(
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
                child: _buildContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcon() {
    IconData icon;
    Color color;

    switch (_currentStep) {
      case ResetStep.enterPhone:
        icon = Icons.lock_reset_rounded;
        color = const Color(0xFFfe3301);
      case ResetStep.waitingCall:
        icon = Icons.phone_callback_rounded;
        color = Colors.blue;
      case ResetStep.enterPassword:
        icon = Icons.key_rounded;
        color = Colors.purple;
      case ResetStep.success:
        icon = Icons.check_circle_rounded;
        color = Colors.green;
    }

    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Icon(icon, size: 40, color: color),
    );
  }

  String _getTitle() {
    switch (_currentStep) {
      case ResetStep.enterPhone:
        return 'Вход по телефону';
      case ResetStep.waitingCall:
        return 'Подтвердите номер';
      case ResetStep.enterPassword:
        return 'Новый пароль';
      case ResetStep.success:
        return 'Вход выполнен!';
    }
  }

  String _getSubtitle() {
    switch (_currentStep) {
      case ResetStep.enterPhone:
        return 'Введите номер телефона, привязанный к вашему аккаунту';
      case ResetStep.waitingCall:
        return 'Позвоните на указанный номер для подтверждения';
      case ResetStep.enterPassword:
        return 'Установите новый пароль для входа';
      case ResetStep.success:
        return 'Вы успешно авторизовались';
    }
  }

  Widget _buildContent() {
    switch (_currentStep) {
      case ResetStep.enterPhone:
        return _buildPhoneStep();
      case ResetStep.waitingCall:
        return _buildCallStep();
      case ResetStep.enterPassword:
        return _buildPasswordStep();
      case ResetStep.success:
        return _buildSuccessStep();
    }
  }

  Widget _buildPhoneStep() {
    final hasPhoneError = _phoneError != null;
    final hasDomainError = _domainError != null;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Поле домена компании
        const Text(
          'Домен компании',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: hasDomainError ? Colors.red.shade400 : const Color(0xFFE0E0E0),
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: _domainCtrl,
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.next,
            onChanged: (_) {
              if (_domainError != null) {
                setState(() => _domainError = null);
              }
            },
            decoration: InputDecoration(
              hintText: 'example-company',
              hintStyle: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 14),
              prefixIcon: Icon(
                Icons.business_rounded,
                color: hasDomainError ? Colors.red.shade400 : const Color(0xFF999999),
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
        if (hasDomainError) ...[
          const SizedBox(height: 8),
          Text(
            _domainError!,
            style: TextStyle(
              fontSize: 12,
              color: Colors.red.shade600,
            ),
          ),
        ],
        const SizedBox(height: 16),
        
        // Поле номера телефона
        const Text(
          'Номер телефона',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: hasPhoneError ? Colors.red.shade400 : const Color(0xFFE0E0E0),
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            inputFormatters: [_phoneMask],
            onChanged: (_) {
              if (_phoneError != null) {
                setState(() => _phoneError = null);
              }
            },
            decoration: InputDecoration(
              hintText: '+7 (999) 123-45-67',
              hintStyle: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 14),
              prefixIcon: Icon(
                Icons.phone_rounded,
                color: hasPhoneError ? Colors.red.shade400 : const Color(0xFF999999),
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
        if (hasPhoneError) ...[
          const SizedBox(height: 8),
          Text(
            _phoneError!,
            style: TextStyle(
              fontSize: 12,
              color: Colors.red.shade600,
            ),
          ),
        ],
        const SizedBox(height: 20),
        // Информация о процессе
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.help_outline, color: Color(0xFF666666), size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Как это работает?',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF333333),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildStep('1', 'Введите номер телефона'),
              const SizedBox(height: 8),
              _buildStep('2', 'Позвоните на указанный номер (бесплатно)'),
              const SizedBox(height: 8),
              _buildStep('3', 'Установите новый пароль'),
              const SizedBox(height: 8),
              _buildStep('4', 'Войдите в приложение'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lightbulb_outline, color: Colors.amber, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Изменить пароль на постоянный можно в настройках профиля',
                        style: TextStyle(fontSize: 11, color: Color(0xFF666666)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _isLoading ? null : _requestReset,
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
                  'Продолжить',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
        ),
      ],
    );
  }

  Widget _buildCallStep() {
    final minutes = _secondsLeft ~/ 60;
    final seconds = _secondsLeft % 60;

    return Column(
      children: [
        // Номер для звонка
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Column(
            children: [
              const Text(
                'Позвоните на номер:',
                style: TextStyle(fontSize: 14, color: Color(0xFF666666)),
              ),
              const SizedBox(height: 8),
              Text(
                _callPhonePretty ?? _callPhone ?? '',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _makeCall,
                  icon: const Icon(Icons.phone),
                  label: const Text('Позвонить'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue,
                    side: const BorderSide(color: Colors.blue),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Обратный отсчёт
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.timer_outlined,
                size: 20,
                color: Color(0xFF666666),
              ),
              const SizedBox(width: 8),
              Text(
                'Осталось: ${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF333333),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Анимация ожидания
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text(
              'Ожидаем ваш звонок...',
              style: TextStyle(fontSize: 14, color: Color(0xFF666666)),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Важное предупреждение
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red.shade600, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Звоните с номера ${_formatPhoneDisplay()}\nИначе звонок не будет засчитан',
                  style: TextStyle(fontSize: 13, color: Colors.red.shade700, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Инструкция
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.shade200),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.amber, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Звонок бесплатный. После соединения можете сразу положить трубку.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF666666)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  /// Форматирование номера для отображения
  String _formatPhoneDisplay() {
    final digits = _phoneMask.getUnmaskedText();
    if (digits.length == 10) {
      return '+7 (${digits.substring(0, 3)}) ${digits.substring(3, 6)}-${digits.substring(6, 8)}-${digits.substring(8, 10)}';
    }
    return _phoneCtrl.text;
  }

  Widget _buildPasswordStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Новый пароль
        const Text(
          'Новый пароль',
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
            controller: _passwordCtrl,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              hintText: 'Минимум 6 символов',
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
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: const Color(0xFF999999),
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Подтверждение пароля
        const Text(
          'Подтвердите пароль',
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
            controller: _confirmPasswordCtrl,
            obscureText: _obscureConfirm,
            decoration: InputDecoration(
              hintText: 'Повторите пароль',
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
                  _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                  color: const Color(0xFF999999),
                ),
                onPressed: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),

        FilledButton(
          onPressed: _isLoading ? null : _setNewPassword,
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
                  'Установить пароль',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
        ),
      ],
    );
  }

  Widget _buildSuccessStep() {
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
          'Готово!',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        const Text(
          'Теперь вы можете войти в приложение\nс установленным паролем',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Color(0xFF666666), height: 1.4),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.blue.shade100),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue, size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Вы можете изменить пароль на постоянный в разделе «Профиль» → «Настройки»',
                  style: TextStyle(fontSize: 12, color: Color(0xFF666666)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => context.go('/login'),
          child: const Text(
            'Войти',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildStep(String number, String text) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: const Color(0xFFfe3301).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFFfe3301),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 13, color: Color(0xFF555555)),
          ),
        ),
      ],
    );
  }
}
