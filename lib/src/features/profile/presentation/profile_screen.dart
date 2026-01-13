import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:excel/excel.dart' as xls;
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:showcaseview/showcaseview.dart';
import 'dart:io';

import '../../../core/services/auto_refresh_service.dart';
import '../../../core/services/showcase_service.dart';
import '../../../core/ui/app_colors.dart';
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

class _ProfileScreenState extends ConsumerState<ProfileScreen> with AutoRefreshMixin {
  // Controllers for editable fields
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  // Edit mode flags
  bool _editingName = false;
  bool _editingPhone = false;
  bool _editingEmail = false;

  // Phone validation error
  String? _phoneError;

  // Saving states
  bool _savingName = false;
  bool _savingPhone = false;
  bool _savingEmail = false;

  // Original values for cancel
  String _originalName = '';
  String _originalPhone = '';
  String _originalEmail = '';

  // Showcase keys
  final _showcaseKeyPersonalData = GlobalKey();
  final _showcaseKeyStats = GlobalKey();
  final _showcaseKeyExport = GlobalKey();

  bool _showcaseStarted = false;

  // Flag to track if profile was loaded
  bool _profileLoaded = false;

  @override
  void initState() {
    super.initState();
    _setupAutoRefresh();
  }

  void _startShowcaseIfNeeded(BuildContext showcaseContext) {
    if (_showcaseStarted) return;
    _showcaseStarted = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      
      final showcaseState = ref.read(showcaseProvider(ShowcasePage.profile));
      if (showcaseState.shouldShow) {
        ShowCaseWidget.of(showcaseContext).startShowCase([
          _showcaseKeyPersonalData,
          _showcaseKeyStats,
          _showcaseKeyExport,
        ]);
      }
    });
  }

  void _onShowcaseComplete() {
    ref.read(showcaseNotifierProvider(ShowcasePage.profile)).markAsSeen();
  }

  void _setupAutoRefresh() {
    startAutoRefresh(() {
      final clientCode = ref.read(activeClientCodeProvider);
      ref.invalidate(clientProfileProvider);
      ref.invalidate(clientStatsProvider(clientCode));
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  /// Загрузить данные профиля в контроллеры
  void _loadProfileIntoControllers(ClientProfile profile) {
    if (!_profileLoaded) {
      _nameCtrl.text = profile.fullName;
      _phoneCtrl.text = profile.phone ?? '';
      _emailCtrl.text = profile.email;
      _originalName = profile.fullName;
      _originalPhone = profile.phone ?? '';
      _originalEmail = profile.email;
      _profileLoaded = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPad = AppLayout.topBarTotalHeight(context);
    final bottomPad = AppLayout.bottomScrollPadding(context);
    final clientCode = ref.watch(activeClientCodeProvider);
    
    // Загружаем профиль и статистику
    final profileAsync = ref.watch(clientProfileProvider);
    final statsAsync = ref.watch(clientStatsProvider(clientCode));

    Future<void> onRefresh() async {
      ref.invalidate(clientProfileProvider);
      ref.invalidate(clientStatsProvider(clientCode));
      _profileLoaded = false; // Сбросим флаг чтобы перезагрузить данные
      await Future.wait([
        ref.read(clientProfileProvider.future),
        ref.read(clientStatsProvider(clientCode).future),
      ]);
    }

    return ShowcaseWrapper(
      onComplete: _onShowcaseComplete,
      child: Builder(
        builder: (showcaseContext) {
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
              
              // Загружаем данные профиля в контроллеры
              _loadProfileIntoControllers(profile);
              
              // Запускаем showcase если нужно
              _startShowcaseIfNeeded(showcaseContext);
              
              final companyDomain = profile.agent?.domain ?? '';
              final stats = statsAsync.when(
                data: (s) => s,
                loading: () => ClientStats.empty,
                error: (_, __) => ClientStats.empty,
              );

              return RefreshIndicator(
                onRefresh: onRefresh,
                color: context.brandPrimary,
                child: ListView(
                  padding: EdgeInsets.fromLTRB(16, topPad * 0.7 + 6, 16, 24 + bottomPad),
                  children: [
                  Text(
                    'Профиль',
                    style: Theme.of(
                      context,
                    ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 18),

                  // Personal Info Section
                  Showcase(
                    key: _showcaseKeyPersonalData,
                    title: 'Личные данные',
                    description: 'Здесь вы можете редактировать ваши контактные данные и сменить пароль.',
                    onTargetClick: () {
                      if (mounted) {
                        ShowCaseWidget.of(showcaseContext).next();
                      }
                    },
                    disposeOnTap: false,
                    child: _buildSectionCard(
                      title: 'Личные данные',
                      children: [
                        _buildEditableField(
                          label: 'ФИО',
                          controller: _nameCtrl,
                          isEditing: _editingName,
                          isSaving: _savingName,
                          onEdit: () {
                            _originalName = _nameCtrl.text;
                            setState(() => _editingName = true);
                          },
                          onSave: () => _saveName(),
                    onCancel: () => setState(() {
                      _nameCtrl.text = _originalName;
                      _editingName = false;
                    }),
                  ),
                  const SizedBox(height: 12),
                  _buildEditableField(
                    label: 'Телефон',
                    controller: _phoneCtrl,
                    isEditing: _editingPhone,
                    isSaving: _savingPhone,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [_PhoneInputFormatter()],
                    error: _phoneError,
                    onEdit: () {
                      _originalPhone = _phoneCtrl.text;
                      setState(() => _editingPhone = true);
                    },
                    onSave: () => _savePhone(),
                    onCancel: () => setState(() {
                      _phoneCtrl.text = _originalPhone;
                      _editingPhone = false;
                      _phoneError = null;
                    }),
                  ),
                  const SizedBox(height: 12),
                  _buildEditableField(
                    label: 'Email',
                    controller: _emailCtrl,
                    isEditing: _editingEmail,
                    isSaving: _savingEmail,
                    keyboardType: TextInputType.emailAddress,
                    onEdit: () {
                      _originalEmail = _emailCtrl.text;
                      setState(() => _editingEmail = true);
                    },
                    onSave: () => _saveEmail(),
                    onCancel: () => setState(() {
                      _emailCtrl.text = _originalEmail;
                      _editingEmail = false;
                    }),
                  ),
                  const SizedBox(height: 16),
                  _buildChangePasswordButton(),
                ],
              ),
            ),
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
            Showcase(
              key: _showcaseKeyStats,
              title: 'Статистика',
              description: 'Ваша статистика по трек-номерам, счетам, запросам фото и вопросам.',
              onTargetClick: () {
                if (mounted) {
                  ShowCaseWidget.of(showcaseContext).next();
                }
              },
              disposeOnTap: false,
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
            Showcase(
              key: _showcaseKeyExport,
              title: 'Выгрузка данных',
              description: 'Экспортируйте счета и треки в Excel файл.',
              onBarrierClick: _onShowcaseComplete,
              onToolTipClick: _onShowcaseComplete,
              child: _buildSectionCard(
                title: 'Выгрузка данных',
                children: [
                  _buildExportButton(
                    icon: Icons.receipt_long_rounded,
                    label: 'Выгрузить счета в Excel',
                    onPressed: _exportInvoices,
                  ),
                  const SizedBox(height: 10),
                  _buildExportButton(
                    icon: Icons.local_shipping_rounded,
                    label: 'Выгрузить треки в Excel',
                    onPressed: _exportTracks,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Logout Button
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
          ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// Сохранить ФИО
  Future<void> _saveName() async {
    final newName = _nameCtrl.text.trim();
    if (newName.length < 2) {
      _showStyledSnackBar(context, 'ФИО должно содержать минимум 2 символа', isError: true);
      return;
    }

    setState(() => _savingName = true);
    try {
      final repo = ref.read(profileRepositoryProvider);
      await repo.updateProfile(fullName: newName);
      
      setState(() {
        _editingName = false;
        _originalName = newName;
      });
      ref.invalidate(clientProfileProvider);
      _showStyledSnackBar(context, 'ФИО успешно обновлено');
    } catch (e) {
      _showStyledSnackBar(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
    } finally {
      setState(() => _savingName = false);
    }
  }

  /// Сохранить телефон
  Future<void> _savePhone() async {
    final newPhone = _phoneCtrl.text.trim();
    if (!_validatePhone(newPhone)) {
      setState(() => _phoneError = 'Неверный формат телефона');
      return;
    }

    setState(() {
      _savingPhone = true;
      _phoneError = null;
    });
    try {
      final repo = ref.read(profileRepositoryProvider);
      await repo.updateProfile(phone: newPhone);
      
      setState(() {
        _editingPhone = false;
        _originalPhone = newPhone;
      });
      ref.invalidate(clientProfileProvider);
      _showStyledSnackBar(context, 'Телефон успешно обновлён');
    } catch (e) {
      _showStyledSnackBar(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
    } finally {
      setState(() => _savingPhone = false);
    }
  }

  /// Сохранить email
  Future<void> _saveEmail() async {
    final newEmail = _emailCtrl.text.trim();
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!emailRegex.hasMatch(newEmail)) {
      _showStyledSnackBar(context, 'Неверный формат email', isError: true);
      return;
    }

    setState(() => _savingEmail = true);
    try {
      final repo = ref.read(profileRepositoryProvider);
      await repo.updateProfile(email: newEmail);
      
      setState(() {
        _editingEmail = false;
        _originalEmail = newEmail;
      });
      ref.invalidate(clientProfileProvider);
      _showStyledSnackBar(context, 'Email успешно обновлён');
    } catch (e) {
      _showStyledSnackBar(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
    } finally {
      setState(() => _savingEmail = false);
    }
  }

  void _logout() {
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
                      onPressed: () {
                        Navigator.pop(context);
                        ref.read(authProvider.notifier).logout();
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

  Widget _buildEditableField({
    required String label,
    required TextEditingController controller,
    required bool isEditing,
    required VoidCallback onEdit,
    required VoidCallback onSave,
    required VoidCallback onCancel,
    bool isSaving = false,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? error,
  }) {
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
        if (isEditing)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [context.brandPrimary, context.brandSecondary],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(1.5),
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10.5),
                  ),
                  child: TextField(
                    controller: controller,
                    keyboardType: keyboardType,
                    inputFormatters: inputFormatters,
                    enabled: !isSaving,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 4),
                Text(
                  error,
                  style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: isSaving ? null : onCancel,
                      child: const Text('Отмена'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: isSaving ? null : onSave,
                      child: isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Сохранить'),
                    ),
                  ),
                ],
              ),
            ],
          )
        else
          Row(
            children: [
              Expanded(
                child: Text(
                  controller.text,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_rounded, size: 20),
                color: context.brandPrimary,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
      ],
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

  Widget _buildChangePasswordButton() {
    return OutlinedButton.icon(
      onPressed: _showChangePasswordDialog,
      icon: const Icon(Icons.lock_rounded, size: 18),
      label: const Text('Изменить пароль'),
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
              color: context.brandPrimary.withOpacity(0.15),
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
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(label),
      ),
    );
  }

  bool _validatePhone(String phone) {
    // Simple validation: must have at least 10 digits
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    return digits.length >= 10;
  }

  void _showChangePasswordDialog() {
    final currentPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    String? error;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final bottomPadding = MediaQuery.paddingOf(context).bottom;
        final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;

        return StatefulBuilder(
          builder: (context, setModalState) => Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              20 + bottomPadding + keyboardHeight,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                const SizedBox(height: 16),
                const Text(
                  'Изменить пароль',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 20),
                _buildPasswordField(currentPassCtrl, 'Текущий пароль'),
                const SizedBox(height: 12),
                _buildPasswordField(newPassCtrl, 'Новый пароль'),
                const SizedBox(height: 12),
                _buildPasswordField(confirmPassCtrl, 'Подтвердите пароль'),
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    error!,
                    style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: isSaving ? null : () async {
                    if (currentPassCtrl.text.isEmpty) {
                      setModalState(() => error = 'Введите текущий пароль');
                      return;
                    }
                    if (newPassCtrl.text.length < 6) {
                      setModalState(
                        () => error = 'Пароль должен быть не менее 6 символов',
                      );
                      return;
                    }
                    if (newPassCtrl.text != confirmPassCtrl.text) {
                      setModalState(() => error = 'Пароли не совпадают');
                      return;
                    }
                    
                    setModalState(() {
                      isSaving = true;
                      error = null;
                    });
                    
                    try {
                      final repo = ref.read(profileRepositoryProvider);
                      await repo.changePassword(
                        currentPassword: currentPassCtrl.text,
                        newPassword: newPassCtrl.text,
                      );
                      
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                      _showStyledSnackBar(this.context, 'Пароль успешно изменён');
                    } catch (e) {
                      setModalState(() {
                        isSaving = false;
                        error = e.toString().replaceFirst('Exception: ', '');
                      });
                    }
                  },
                  child: isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Сохранить'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPasswordField(TextEditingController controller, String hint) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFDDDDDD)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        obscureText: true,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFF999999), fontSize: 14),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  Future<void> _exportInvoices() async {
    final clientCode = ref.read(activeClientCodeProvider);
    if (clientCode == null) {
      _showStyledSnackBar(context, 'Сначала выберите код клиента', isError: true);
      return;
    }
    
    try {
      // Получаем все счета из реального провайдера
      final invoices = await ref.read(invoicesListProvider(clientCode).future);
      
      if (invoices.isEmpty) {
        _showStyledSnackBar(context, 'Нет счетов для экспорта', isError: true);
        return;
      }

      // Создаём Excel файл
      final excel = xls.Excel.createExcel();
      final sheet = excel['Счета'];
      
      // Заголовки
      sheet.appendRow([
        xls.TextCellValue('№ счёта'),
        xls.TextCellValue('Дата'),
        xls.TextCellValue('Статус'),
        xls.TextCellValue('Тариф'),
        xls.TextCellValue('Метод расчёта'),
        xls.TextCellValue('Мест'),
        xls.TextCellValue('Вес (кг)'),
        xls.TextCellValue('Объём (м³)'),
        xls.TextCellValue('Плотность'),
        xls.TextCellValue('Перевалка USD'),
        xls.TextCellValue('Страховка USD'),
        xls.TextCellValue('Скидка USD'),
        xls.TextCellValue('Упаковка USD'),
        xls.TextCellValue('Доставка USD'),
        xls.TextCellValue('Курс'),
        xls.TextCellValue('К оплате RUB'),
      ]);
      
      // Данные
      final dateFormat = DateFormat('dd.MM.yyyy');
      for (final invoice in invoices) {
        sheet.appendRow([
          xls.TextCellValue(invoice.invoiceNumber),
          xls.TextCellValue(dateFormat.format(invoice.sendDate)),
          xls.TextCellValue(invoice.statusName ?? invoice.status),
          xls.TextCellValue(invoice.tariffName ?? ''),
          xls.TextCellValue(invoice.calculationMethod ?? ''),
          xls.IntCellValue(invoice.placesCount),
          xls.DoubleCellValue(invoice.weight),
          xls.DoubleCellValue(invoice.volume),
          xls.DoubleCellValue(invoice.density),
          xls.DoubleCellValue(invoice.transshipmentCost ?? 0),
          xls.DoubleCellValue(invoice.insuranceCost ?? 0),
          xls.DoubleCellValue(invoice.discount ?? 0),
          xls.DoubleCellValue(invoice.packagingCostTotal ?? 0),
          xls.DoubleCellValue(invoice.deliveryCostUsd),
          invoice.rate != null ? xls.DoubleCellValue(invoice.rate!) : xls.TextCellValue(''),
          xls.DoubleCellValue(invoice.totalCostRub),
        ]);
      }
      
      // Удаляем дефолтный лист
      excel.delete('Sheet1');
      
      // Сохраняем
      final bytes = excel.encode();
      if (bytes == null) {
        _showStyledSnackBar(context, 'Ошибка генерации файла', isError: true);
        return;
      }
      
      final dir = await getTemporaryDirectory();
      final fileName = 'Счета_${clientCode}_${DateFormat('yyyy-MM-dd_HH-mm').format(DateTime.now())}.xlsx';
      final tempFile = File('${dir.path}/$fileName');
      await tempFile.writeAsBytes(bytes);
      
      // Спрашиваем куда сохранить
      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Сохранить счета',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );
      
      if (savePath == null) {
        // Пользователь отменил
        return;
      }
      
      // Копируем файл в выбранное место
      final saveFile = File(savePath);
      await saveFile.writeAsBytes(bytes);
      
      _showStyledSnackBar(context, 'Сохранено ${invoices.length} счетов');
    } catch (e) {
      _showStyledSnackBar(context, 'Ошибка экспорта: $e', isError: true);
    }
  }

  Future<void> _exportTracks() async {
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
      
      if (tracks.isEmpty) {
        _showStyledSnackBar(context, 'Нет треков для экспорта', isError: true);
        return;
      }

      // Создаём Excel файл
      final excel = xls.Excel.createExcel();
      final sheet = excel['Треки'];
      
      // Заголовки
      sheet.appendRow([
        xls.TextCellValue('Трек-номер'),
        xls.TextCellValue('Статус'),
        xls.TextCellValue('Дата создания'),
        xls.TextCellValue('Дата обновления'),
        xls.TextCellValue('Сборка'),
        xls.TextCellValue('Комментарий'),
        xls.TextCellValue('Товары'),
      ]);
      
      // Данные
      final dateFormat = DateFormat('dd.MM.yyyy HH:mm');
      for (final track in tracks) {
        // Собираем информацию о товарах
        String productsInfo = '';
        if (track.productInfo != null) {
          productsInfo = '${track.productInfo!.name ?? ''} (${track.productInfo!.quantity} шт)';
        }
        
        sheet.appendRow([
          xls.TextCellValue(track.code),
          xls.TextCellValue(track.status),
          xls.TextCellValue(dateFormat.format(track.createdAt)),
          xls.TextCellValue(dateFormat.format(track.updatedAt)),
          xls.TextCellValue(track.assembly?.number ?? ''),
          xls.TextCellValue(track.comment ?? ''),
          xls.TextCellValue(productsInfo),
        ]);
      }
      
      // Удаляем дефолтный лист
      excel.delete('Sheet1');
      
      // Сохраняем
      final bytes = excel.encode();
      if (bytes == null) {
        _showStyledSnackBar(context, 'Ошибка генерации файла', isError: true);
        return;
      }
      
      final dir = await getTemporaryDirectory();
      final fileName = 'Треки_${clientCode}_${DateFormat('yyyy-MM-dd_HH-mm').format(DateTime.now())}.xlsx';
      final tempFile = File('${dir.path}/$fileName');
      await tempFile.writeAsBytes(bytes);
      
      // Спрашиваем куда сохранить
      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Сохранить треки',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );
      
      if (savePath == null) {
        // Пользователь отменил
        return;
      }
      
      // Копируем файл в выбранное место
      final saveFile = File(savePath);
      await saveFile.writeAsBytes(bytes);
      
      _showStyledSnackBar(context, 'Экспортировано ${tracks.length} треков');
    } catch (e) {
      _showStyledSnackBar(context, 'Ошибка экспорта: $e', isError: true);
    }
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
