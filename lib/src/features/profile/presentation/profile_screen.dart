import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:excel/excel.dart' as xls;
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:typed_data';

import '../../../core/network/api_client.dart';
import '../../../core/utils/file_download_helper.dart';

import '../../../core/ui/app_colors.dart';
import '../../../core/ui/scroll_to_top_button.dart';
import '../../../core/ui/tutorial_card.dart';
import '../../auth/data/auth_provider.dart';
import '../../../core/ui/app_layout.dart';
import '../../tracks/data/tracks_provider.dart';
import '../../invoices/data/invoices_provider.dart';
import '../../clients/application/client_codes_controller.dart';
import '../data/profile_provider.dart';

void _showStyledSnackBar(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(
    SnackBar(
      content: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => messenger.hideCurrentSnackBar(),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isError
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_outline_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
      behavior: SnackBarBehavior.floating,
      backgroundColor: isError
          ? const Color(0xFFE53935)
          : context.brandPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 15),
      duration: const Duration(seconds: 3),
    ),
  );
}

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  // Export button keys for sharePositionOrigin on iPad
  final ScrollController _scrollController = ScrollController();
  final _invoicesExportButtonKey = GlobalKey();
  final _tracksExportButtonKey = GlobalKey();

  final GlobalKey _personalDataKey = GlobalKey();
  final GlobalKey _statsKey = GlobalKey();
  final GlobalKey _exportKey = GlobalKey();
  final GlobalKey _logoutKey = GlobalKey();

  // Editing state
  bool _isEditing = false;
  bool _isSaving = false;
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  ClientTerminal? _selectedTerminal;

  // Password change state
  bool _isChangingPassword = false;
  bool _isSavingPassword = false;
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPad = AppLayout.topBarTotalHeight(context);
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final clientCode = ref.watch(activeClientCodeProvider);
    // Загружаем профиль и статистику
    final profileAsync = ref.watch(clientProfileProvider);
    final statsAsync = ref.watch(clientStatsProvider(clientCode));

    Future<void> onRefresh() async {
      ref.invalidate(clientProfileProvider);
      ref.invalidate(clientStatsProvider(clientCode));
      await Future.wait([
        ref.read(clientProfileProvider.future),
        ref.read(clientStatsProvider(clientCode).future),
      ]);
    }

    return profileAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Ошибка загрузки профиля: $e'),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => ref.invalidate(clientProfileProvider),
                    child: const Text('Повторить'),
                  ),
                ],
              ),
            ),
            data: (profile) {
              if (profile == null) {
                return const Center(child: Text('Профиль не найден'));
              }

              final companyDomain = profile.agent?.domain ?? '';
              final stats = statsAsync.when(
                data: (s) => s,
                loading: () => ClientStats.empty,
                error: (_, _) => ClientStats.empty,
              );

              return TutorialScreenWrapper(
                screenKey: 'profile',
                steps: [
                  TutorialStep(
                    icon: Icons.person_rounded,
                    title: 'Личные данные',
                    description: 'Ваше имя, email и телефон. «Редактировать» — обновить данные. «Сменить пароль» — изменить пароль входа.',
                    targetKey: _personalDataKey,
                  ),
                  TutorialStep(
                    icon: Icons.bar_chart_rounded,
                    title: 'Статистика',
                    description: 'Сколько треков, счетов и фотозапросов было создано. Удобно для отслеживания активности.',
                    targetKey: _statsKey,
                  ),
                  TutorialStep(
                    icon: Icons.file_download_rounded,
                    title: 'Выгрузка данных',
                    description: 'Скачайте все счета или треки в формате Excel — удобно для бухгалтерии и архивирования.',
                    targetKey: _exportKey,
                  ),
                  TutorialStep(
                    icon: Icons.logout_rounded,
                    title: 'Выход из аккаунта',
                    description: 'Кнопка выхода находится внизу страницы. Все данные будут удалены с устройства.',
                    targetKey: _logoutKey,
                  ),
                ],
                child: Stack(
                children: [
                RefreshIndicator(
                onRefresh: onRefresh,
                color: context.brandPrimary,
                child: ListView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(16, topPad * 0.7 + 16, 16, 24 + bottomPad),
                  children: [
                  Text(
                    'Профиль',
                    style: Theme.of(
                      context,
                    ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 18),

                  // Personal Info Section
                  KeyedSubtree(key: _personalDataKey, child: _buildPersonalDataSection(profile)),
                  const SizedBox(height: 16),

                  // Password Change Section
                  _buildPasswordSection(),
                  const SizedBox(height: 16),

            // Company Info Section
            _buildSectionCard(
              title: 'Компания',
              children: [
                _buildReadonlyField(label: 'Домен компании', value: companyDomain),
              ],
            ),
            const SizedBox(height: 16),


            // Statistics Section
            KeyedSubtree(
              key: _statsKey,
              child: _buildSectionCard(
                title: 'Статистика',
                children: [
                  _buildStatsGroup('Трек-номера', stats.tracks),
                  const SizedBox(height: 16),
                  _buildStatsGroup('Счета', stats.invoices),
                  const SizedBox(height: 16),
                  _buildStatsGroup('Запросы фото', stats.photoRequests),
                  const SizedBox(height: 16),
                  _buildStatsGroup('Заданные вопросы', stats.questions),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Export Section
            KeyedSubtree(
              key: _exportKey,
              child: _buildSectionCard(
                title: 'Выгрузка данных',
                children: [
                  _buildExportButton(
                    key: _invoicesExportButtonKey,
                    icon: Icons.receipt_long_rounded,
                    label: 'Выгрузить счета в Excel',
                    onPressed: () => _exportInvoices(_invoicesExportButtonKey),
                  ),
                  const SizedBox(height: 10),
                  _buildExportButton(
                    key: _tracksExportButtonKey,
                    icon: Icons.local_shipping_rounded,
                    label: 'Выгрузить треки в Excel',
                    onPressed: () => _exportTracks(_tracksExportButtonKey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Logout Button
            Container(
                key: _logoutKey,
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
                child: Material(
                  type: MaterialType.transparency,
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: _logout,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.logout_rounded,
                            color: Colors.red.shade600,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Выйти из аккаунта',
                            style: TextStyle(
                              color: Colors.red.shade600,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // App version
            const SizedBox(height: 24),
            FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox.shrink();
                final info = snapshot.data!;
                return Center(
                  child: Text(
                    'Версия ${info.version} (${info.buildNumber})',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade500,
                    ),
                  ),
                );
              },
            ),
          ],
                ),
              ),
                ScrollToTopButton(controller: _scrollController),
                ],
              ));
            },
          );
  }

  // ===== PERSONAL DATA EDITING =====

  void _startEditing(ClientProfile profile) {
    setState(() {
      _isEditing = true;
      _fullNameController.text = profile.fullName;
      _phoneController.text = profile.phone ?? '';
      _emailController.text = profile.email;
      _selectedTerminal = profile.terminal;
    });
  }

  void _cancelEditing() {
    setState(() {
      _isEditing = false;
    });
  }

  Future<void> _saveProfile() async {
    final fullName = _fullNameController.text.trim();
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();

    if (fullName.isEmpty) {
      _showStyledSnackBar(context, 'Введите ФИО', isError: true);
      return;
    }

    setState(() => _isSaving = true);

    try {
      await ref.read(profileRepositoryProvider).updateProfile(
        fullName: fullName,
        phone: phone,
        email: email,
        terminal: _selectedTerminal,
        clearTerminal: _selectedTerminal == null,
      );

      ref.invalidate(clientProfileProvider);

      if (mounted) {
        setState(() {
          _isEditing = false;
          _isSaving = false;
        });
        _showStyledSnackBar(context, 'Профиль обновлён');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        _showStyledSnackBar(context, 'Ошибка: $e', isError: true);
      }
    }
  }

  Widget _buildPersonalDataSection(ClientProfile profile) {
    if (_isEditing) {
      return Container(
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Личные данные',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
                TextButton(
                  onPressed: _cancelEditing,
                  child: const Text('Отмена'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _buildEditableField(
              controller: _fullNameController,
              label: 'ФИО',
              icon: Icons.person_outline_rounded,
            ),
            const SizedBox(height: 12),
            _buildEditableField(
              controller: _phoneController,
              label: 'Телефон',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            _buildEditableField(
              controller: _emailController,
              label: 'Email',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            _buildTerminalSelector(),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _isSaving ? null : _saveProfile,
                style: FilledButton.styleFrom(
                  backgroundColor: context.brandPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Сохранить',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Личные данные',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                onPressed: () => _startEditing(profile),
                icon: Icon(
                  Icons.edit_outlined,
                  size: 20,
                  color: context.brandPrimary,
                ),
                tooltip: 'Редактировать',
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildReadonlyField(label: 'ФИО', value: profile.fullName),
          const SizedBox(height: 12),
          _buildReadonlyField(
            label: 'Телефон',
            value: (profile.phone?.isNotEmpty ?? false) ? profile.phone! : '—',
          ),
          const SizedBox(height: 12),
          _buildReadonlyField(label: 'Email', value: profile.email),
          const SizedBox(height: 12),
          _buildReadonlyField(
            label: 'Терминал получения груза',
            value: profile.terminal?.nameRu ?? 'Не выбрано',
          ),
        ],
      ),
    );
  }

  Widget _buildEditableField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: context.brandPrimary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildTerminalSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Терминал получения груза',
          style: TextStyle(
            fontSize: 12,
            color: Color(0xFF666666),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _TerminalChip(
                label: 'Не выбрано',
                selected: _selectedTerminal == null,
                onTap: () => setState(() => _selectedTerminal = null),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _TerminalChip(
                label: ClientTerminal.lyublino.nameRu,
                selected: _selectedTerminal == ClientTerminal.lyublino,
                onTap: () => setState(() => _selectedTerminal = ClientTerminal.lyublino),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _TerminalChip(
                label: ClientTerminal.km19.nameRu,
                selected: _selectedTerminal == ClientTerminal.km19,
                onTap: () => setState(() => _selectedTerminal = ClientTerminal.km19),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ===== PASSWORD CHANGE =====

  Widget _buildPasswordSection() {
    return Container(
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Безопасность',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
              Icon(
                Icons.shield_outlined,
                size: 20,
                color: Colors.grey.shade400,
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_isChangingPassword) ...[
            _buildPasswordField(
              controller: _currentPasswordController,
              label: 'Текущий пароль',
              obscure: _obscureCurrentPassword,
              onToggle: () => setState(() => _obscureCurrentPassword = !_obscureCurrentPassword),
            ),
            const SizedBox(height: 12),
            _buildPasswordField(
              controller: _newPasswordController,
              label: 'Новый пароль',
              obscure: _obscureNewPassword,
              onToggle: () => setState(() => _obscureNewPassword = !_obscureNewPassword),
            ),
            const SizedBox(height: 12),
            _buildPasswordField(
              controller: _confirmPasswordController,
              label: 'Подтвердите новый пароль',
              obscure: _obscureConfirmPassword,
              onToggle: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSavingPassword ? null : () {
                      setState(() {
                        _isChangingPassword = false;
                        for (final c in [_currentPasswordController, _newPasswordController, _confirmPasswordController]) {
                          c.selection = const TextSelection.collapsed(offset: 0);
                          c.clear();
                        }
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Отмена'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: _isSavingPassword ? null : _savePassword,
                    style: FilledButton.styleFrom(
                      backgroundColor: context.brandPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _isSavingPassword
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Сменить пароль',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _isChangingPassword = true),
                icon: const Icon(Icons.lock_outline_rounded, size: 20),
                label: const Text(
                  'Сменить пароль',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline, size: 20),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            size: 20,
          ),
          onPressed: onToggle,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: context.brandPrimary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Future<void> _savePassword() async {
    final currentPassword = _currentPasswordController.text;
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (currentPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty) {
      _showStyledSnackBar(context, 'Заполните все поля', isError: true);
      return;
    }

    if (newPassword.length < 6) {
      _showStyledSnackBar(context, 'Новый пароль должен быть не менее 6 символов', isError: true);
      return;
    }

    if (newPassword != confirmPassword) {
      _showStyledSnackBar(context, 'Пароли не совпадают', isError: true);
      return;
    }

    setState(() => _isSavingPassword = true);

    try {
      await ref.read(profileRepositoryProvider).changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );

      if (mounted) {
        setState(() {
          _isSavingPassword = false;
          _isChangingPassword = false;
          for (final c in [_currentPasswordController, _newPasswordController, _confirmPasswordController]) {
            c.selection = const TextSelection.collapsed(offset: 0);
            c.clear();
          }
        });
        _showStyledSnackBar(context, 'Пароль успешно изменён');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSavingPassword = false);
        String errorMsg = e.toString().replaceAll('Exception: ', '');
        _showStyledSnackBar(context, errorMsg, isError: true);
      }
    }
  }

  void _logout() {
    // Сохраняем context перед открытием bottom sheet
    final navigatorContext = context;

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final bottomPadding = MediaQuery.paddingOf(context).bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Icon(Icons.logout_rounded, size: 48, color: Colors.red.shade400),
              const SizedBox(height: 16),
              const Text(
                'Выйти из аккаунта?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                'Вы уверены, что хотите выйти?',
                style: TextStyle(color: Color(0xFF666666)),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Отмена'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () async {
                        // Закрываем bottom sheet
                        Navigator.pop(context);

                        // Вызываем logout
                        await ref.read(authProvider.notifier).logout();

                        // Используем сохранённый context для навигации
                        if (navigatorContext.mounted) {
                          navigatorContext.go('/login');
                        }
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                      ),
                      child: const Text('Выйти'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionCard({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _buildReadonlyField({required String label, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF666666),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(
              Icons.lock_outline_rounded,
              size: 18,
              color: Color(0xFF999999),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsGroup(String title, Map<String, int> stats) {
    final total = stats.values.fold(0, (a, b) => a + b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [context.brandPrimary, context.brandSecondary],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$total',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: stats.entries
              .map((e) => _buildStatChip(e.key, e.value))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildStatChip(String label, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF666666)),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: context.brandPrimary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: context.brandPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExportButton({
    Key? key,
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      key: key,
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(label),
      ),
    );
  }

  Future<void> _exportInvoices(GlobalKey buttonKey) async {
    final clientCode = ref.read(activeClientCodeProvider);
    if (clientCode == null) {
      _showStyledSnackBar(context, 'Сначала выберите код клиента', isError: true);
      return;
    }

    try {
      // PU-H9: для экспорта тянем ВСЕ счета батчами через fetchAllInvoicesForExport.
      // invoicesListProvider обрезается на 100 — раньше юзеры с >100 счетов
      // получали неполный Excel. Передаём ApiClient напрямую — функция
      // не привязана к Ref/WidgetRef, чтобы её было удобно мокать в тестах.
      final invoices = await fetchAllInvoicesForExport(
        ref.read(apiClientProvider),
        clientCode,
      );

      if (!mounted) return;

      if (invoices.isEmpty) {
        if (mounted) _showStyledSnackBar(context, 'Нет счетов для экспорта', isError: true);
        return;
      }

      // Создаём Excel файл
      final excel = xls.Excel.createExcel();
      final sheet = excel['Счета'];

      // PU-H8: единый список headers, чтобы можно было asserт-нуть длину
      // против количества values ниже. Если кто-то добавит колонку в
      // headers, но забудет про values (или наоборот) — assert упадёт в
      // debug, и баг «всё съехало на одну колонку» не уйдёт в прод.
      const exportHeaders = <String>[
        '№ счёта',
        'Дата',
        'Статус',
        'Тариф',
        'Метод расчёта',
        'Мест',
        'Вес (кг)',
        'Объём (м³)',
        'Плотность',
        'Перевалка USD',
        'Страховка USD',
        'Скидка USD',
        'Упаковка USD',
        'Доставка USD',
        'Курс',
        'К оплате RUB',
      ];

      sheet.appendRow(exportHeaders.map(xls.TextCellValue.new).toList());

      // Данные
      final dateFormat = DateFormat('dd.MM.yyyy');
      for (final invoice in invoices) {
        final row = <xls.CellValue>[
          xls.TextCellValue(invoice.invoiceNumber),
          xls.TextCellValue(invoice.sendDate != null ? dateFormat.format(invoice.sendDate!) : ''),
          xls.TextCellValue(invoice.statusName ?? invoice.status),
          xls.TextCellValue(invoice.tariffName ?? ''),
          xls.TextCellValue(invoice.calculationMethod ?? ''),
          xls.IntCellValue(invoice.placesCount),
          xls.DoubleCellValue(invoice.weight),
          xls.DoubleCellValue(invoice.volume),
          xls.DoubleCellValue(invoice.density),
          xls.DoubleCellValue(invoice.transshipmentCost ?? 0),
          xls.DoubleCellValue(invoice.insuranceCost ?? 0),
          xls.DoubleCellValue(invoice.discountAmount ?? 0),
          xls.DoubleCellValue(invoice.packagingCostTotal ?? 0),
          xls.DoubleCellValue(invoice.totalCostUsd),
          invoice.clientRubRate != null ? xls.DoubleCellValue(invoice.clientRubRate!) : xls.TextCellValue(''),
          xls.DoubleCellValue(invoice.totalCostRub),
        ];
        // PU-H8: страховка от «съехавшей» колонки.
        assert(
          row.length == exportHeaders.length,
          'Excel export: row.length(${row.length}) != headers.length(${exportHeaders.length})',
        );
        sheet.appendRow(row);
      }

      // Удаляем дефолтный лист
      excel.delete('Sheet1');

      // Сохраняем
      final bytes = excel.encode();
      if (bytes == null) {
        if (mounted) _showStyledSnackBar(context, 'Ошибка генерации файла', isError: true);
        return;
      }

      final uint8Bytes = Uint8List.fromList(bytes);
      final fileName = 'Счета_${clientCode}_${DateFormat('yyyy-MM-dd_HH-mm').format(DateTime.now())}.xlsx';

      if (!mounted) return;

      final success = await downloadFile(
        bytes: uint8Bytes,
        fileName: fileName,
        shareButtonKey: buttonKey,
      );

      if (!mounted) return;
      if (success) {
        _showStyledSnackBar(context, 'Экспортировано ${invoices.length} счетов');
      }
    } catch (e) {
      if (mounted) {
        _showStyledSnackBar(context, 'Ошибка экспорта: $e', isError: true);
      }
    }
  }

  Future<void> _exportTracks(GlobalKey buttonKey) async {
    final clientCode = ref.read(activeClientCodeProvider);
    if (clientCode == null) {
      _showStyledSnackBar(context, 'Сначала выберите код клиента', isError: true);
      return;
    }

    try {
      // Получаем все треки - используем пагинированный провайдер
      final notifier = ref.read(paginatedTracksProvider(clientCode));
      // Загружаем если нужно
      if (notifier.state.tracks.isEmpty && !notifier.state.isLoading) {
        await notifier.loadInitial();
      }
      final tracks = notifier.state.tracks;

      if (!mounted) return;

      if (tracks.isEmpty) {
        if (mounted) _showStyledSnackBar(context, 'Нет треков для экспорта', isError: true);
        return;
      }

      // Создаём Excel файл по шаблону
      final excel = xls.Excel.createExcel();
      final sheet = excel['Треки'];

      // Стиль для заголовков
      final headerStyle = xls.CellStyle(
        bold: true,
        horizontalAlign: xls.HorizontalAlign.Center,
        verticalAlign: xls.VerticalAlign.Center,
        textWrapping: xls.TextWrapping.WrapText,
      );

      // Row 1: Основные заголовки
      // A1: Трек номер (merged A1:A2)
      sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
        ..value = xls.TextCellValue('Трек номер')
        ..cellStyle = headerStyle;

      // B1: Статус (merged B1:B2)
      sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 0))
        ..value = xls.TextCellValue('Статус')
        ..cellStyle = headerStyle;

      // C1: О товаре (merged C1:D1)
      sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 0))
        ..value = xls.TextCellValue('О товаре')
        ..cellStyle = headerStyle;

      // E1: Вопрос по треку (merged E1:F1)
      sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: 0))
        ..value = xls.TextCellValue('Вопрос по треку')
        ..cellStyle = headerStyle;

      // G1: Комментарий по треку (merged G1:G2)
      sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: 0))
        ..value = xls.TextCellValue('Комментарий по треку')
        ..cellStyle = headerStyle;

      // H1: Сборка (merged H1:L1)
      sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: 0))
        ..value = xls.TextCellValue('Сборка')
        ..cellStyle = headerStyle;

      // Row 2: Подзаголовки
      // C2: Наименование
      sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 1))
        ..value = xls.TextCellValue('Наименование')
        ..cellStyle = headerStyle;

      // D2: Количество
      sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 1))
        ..value = xls.TextCellValue('Количество')
        ..cellStyle = headerStyle;

      // E2: Вопрос
      sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: 1))
        ..value = xls.TextCellValue('Вопрос')
        ..cellStyle = headerStyle;

      // F2: Ответ
      sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: 1))
        ..value = xls.TextCellValue('Ответ')
        ..cellStyle = headerStyle;

      // H2: Наименование сборки
      sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: 1))
        ..value = xls.TextCellValue('Наименование сборки')
        ..cellStyle = headerStyle;

      // I2: Наименование тарифа
      sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: 1))
        ..value = xls.TextCellValue('Наименование тарифа')
        ..cellStyle = headerStyle;

      // J2: Стоимость тарифа
      sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: 1))
        ..value = xls.TextCellValue('Стоимость тарифа')
        ..cellStyle = headerStyle;

      // K2: Тип упаковки
      sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: 1))
        ..value = xls.TextCellValue('Тип упаковки')
        ..cellStyle = headerStyle;

      // L2: Стоимость упаковки
      sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 11, rowIndex: 1))
        ..value = xls.TextCellValue('Стоимость упаковки')
        ..cellStyle = headerStyle;

      // Merge cells для заголовков
      sheet.merge(xls.CellIndex.indexByString('A1'), xls.CellIndex.indexByString('A2')); // Трек номер
      sheet.merge(xls.CellIndex.indexByString('B1'), xls.CellIndex.indexByString('B2')); // Статус
      sheet.merge(xls.CellIndex.indexByString('C1'), xls.CellIndex.indexByString('D1')); // О товаре
      sheet.merge(xls.CellIndex.indexByString('E1'), xls.CellIndex.indexByString('F1')); // Вопрос по треку
      sheet.merge(xls.CellIndex.indexByString('G1'), xls.CellIndex.indexByString('G2')); // Комментарий
      sheet.merge(xls.CellIndex.indexByString('H1'), xls.CellIndex.indexByString('L1')); // Сборка

      // Данные начинаются с row 3 (index 2)
      int rowIndex = 2;
      for (final track in tracks) {
        // A: Трек номер
        sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex))
          .value = xls.TextCellValue(track.code);

        // B: Статус
        sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex))
          .value = xls.TextCellValue(track.status);

        // C: Наименование товара
        sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex))
          .value = xls.TextCellValue(track.productInfo?.name ?? '');

        // D: Количество
        final quantity = track.productInfo?.quantity ?? 0;
        sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex))
          .value = quantity > 0 ? xls.IntCellValue(quantity) : xls.TextCellValue('');

        // E: Вопрос (собираем все вопросы)
        final questions = track.questions
            .where((q) => q.status != 'cancelled')
            .map((q) => q.question)
            .join('\n');
        sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex))
          .value = xls.TextCellValue(questions);

        // F: Ответ (собираем все ответы)
        final answers = track.questions
            .where((q) => q.status != 'cancelled' && q.answer != null && q.answer!.isNotEmpty)
            .map((q) => q.answer!)
            .join('\n');
        sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex))
          .value = xls.TextCellValue(answers);

        // G: Комментарий по треку
        sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex))
          .value = xls.TextCellValue(track.comment ?? '');

        // H: Наименование сборки
        final assemblyName = track.assembly?.name ?? track.assembly?.number ?? '';
        sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: rowIndex))
          .value = xls.TextCellValue(assemblyName);

        // I: Наименование тарифа
        sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: rowIndex))
          .value = xls.TextCellValue(track.assembly?.tariffName ?? '');

        // J: Стоимость тарифа
        final tariffCost = track.assembly?.tariffCost;
        sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: rowIndex))
          .value = tariffCost != null ? xls.DoubleCellValue(tariffCost) : xls.TextCellValue('');

        // K: Тип упаковки
        final packagingTypes = track.assembly?.packagingTypes.join(', ') ?? '';
        sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: rowIndex))
          .value = xls.TextCellValue(packagingTypes);

        // L: Стоимость упаковки
        final packagingCost = track.assembly?.packagingCost;
        sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 11, rowIndex: rowIndex))
          .value = packagingCost != null ? xls.DoubleCellValue(packagingCost) : xls.TextCellValue('');

        rowIndex++;
      }

      // Устанавливаем ширину колонок
      sheet.setColumnWidth(0, 20);  // A: Трек номер
      sheet.setColumnWidth(1, 15);  // B: Статус
      sheet.setColumnWidth(2, 25);  // C: Наименование
      sheet.setColumnWidth(3, 12);  // D: Количество
      sheet.setColumnWidth(4, 30);  // E: Вопрос
      sheet.setColumnWidth(5, 30);  // F: Ответ
      sheet.setColumnWidth(6, 25);  // G: Комментарий
      sheet.setColumnWidth(7, 20);  // H: Наименование сборки
      sheet.setColumnWidth(8, 20);  // I: Наименование тарифа
      sheet.setColumnWidth(9, 15);  // J: Стоимость тарифа
      sheet.setColumnWidth(10, 25); // K: Тип упаковки
      sheet.setColumnWidth(11, 18); // L: Стоимость упаковки

      // Удаляем дефолтный лист
      excel.delete('Sheet1');

      // Сохраняем
      final bytes = excel.encode();
      if (bytes == null) {
        if (mounted) _showStyledSnackBar(context, 'Ошибка генерации файла', isError: true);
        return;
      }

      final uint8Bytes = Uint8List.fromList(bytes);
      final fileName = 'Треки_${clientCode}_${DateFormat('yyyy-MM-dd_HH-mm').format(DateTime.now())}.xlsx';

      if (!mounted) return;

      final success = await downloadFile(
        bytes: uint8Bytes,
        fileName: fileName,
        shareButtonKey: buttonKey,
      );

      if (!mounted) return;
      if (success) {
        _showStyledSnackBar(context, 'Экспортировано ${tracks.length} треков');
      }
    } catch (e) {
      if (mounted) {
        _showStyledSnackBar(context, 'Ошибка экспорта: $e', isError: true);
      }
    }
  }
}

class _TerminalChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TerminalChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? context.brandPrimary : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? context.brandPrimary : const Color(0xFFE0E0E0),
          ),
        ),
        child: Center(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : const Color(0xFF333333),
            ),
          ),
        ),
      ),
    );
  }
}
