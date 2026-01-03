import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:excel/excel.dart' as xls;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'dart:io';

import '../../auth/data/auth_provider.dart';
import '../../../core/ui/app_layout.dart';
import '../../tracks/data/fake_tracks_repository.dart';
import '../../invoices/data/fake_invoices_repository.dart';
import '../../clients/application/client_codes_controller.dart';

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
          : const Color(0xFFfe3301),
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
  // Controllers for editable fields
  final _nameCtrl = TextEditingController(text: 'Иванов Иван Иванович');
  final _phoneCtrl = TextEditingController(text: '+7 (999) 123-45-67');
  final _emailCtrl = TextEditingController(text: 'user@example.com');

  // Edit mode flags
  bool _editingName = false;
  bool _editingPhone = false;
  bool _editingEmail = false;

  // Phone validation error
  String? _phoneError;

  // Mock data
  final String _companyDomain = '2a-logistics.ru';

  // Mock statistics
  final Map<String, int> _trackStats = {
    'На складе': 12,
    'Отправлен': 5,
    'Прибыл на терминал': 3,
    'Сформирован к выдаче': 2,
    'Получен': 45,
  };

  final Map<String, int> _invoiceStats = {
    'Требует оплаты': 2,
    'Оплачен': 15,
    'Частично оплачен': 1,
  };

  final Map<String, int> _photoRequestStats = {
    'В ожидании': 3,
    'Выполнен': 8,
    'Отклонён': 1,
  };

  final Map<String, int> _questionStats = {'Ожидает ответа': 2, 'Отвечен': 12};

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPad = AppLayout.topBarTotalHeight(context);
    final bottomPad = AppLayout.bottomScrollPadding(context);

    return ListView(
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
        _buildSectionCard(
          title: 'Личные данные',
          children: [
            _buildEditableField(
              label: 'ФИО',
              controller: _nameCtrl,
              isEditing: _editingName,
              onEdit: () => setState(() => _editingName = true),
              onSave: () => setState(() => _editingName = false),
              onCancel: () => setState(() => _editingName = false),
            ),
            const SizedBox(height: 12),
            _buildEditableField(
              label: 'Телефон',
              controller: _phoneCtrl,
              isEditing: _editingPhone,
              keyboardType: TextInputType.phone,
              inputFormatters: [_PhoneInputFormatter()],
              error: _phoneError,
              onEdit: () => setState(() => _editingPhone = true),
              onSave: () {
                if (_validatePhone(_phoneCtrl.text)) {
                  setState(() {
                    _editingPhone = false;
                    _phoneError = null;
                  });
                } else {
                  setState(() => _phoneError = 'Неверный формат телефона');
                }
              },
              onCancel: () => setState(() {
                _editingPhone = false;
                _phoneError = null;
              }),
            ),
            const SizedBox(height: 12),
            _buildEditableField(
              label: 'Email',
              controller: _emailCtrl,
              isEditing: _editingEmail,
              keyboardType: TextInputType.emailAddress,
              onEdit: () => setState(() => _editingEmail = true),
              onSave: () => setState(() => _editingEmail = false),
              onCancel: () => setState(() => _editingEmail = false),
            ),
            const SizedBox(height: 16),
            _buildChangePasswordButton(),
          ],
        ),
        const SizedBox(height: 16),

        // Company Info Section
        _buildSectionCard(
          title: 'Компания',
          children: [
            _buildReadonlyField(label: 'Домен компании', value: _companyDomain),
          ],
        ),
        const SizedBox(height: 16),

        // Statistics Section
        _buildSectionCard(
          title: 'Статистика',
          children: [
            _buildStatsGroup('Трек-номера', _trackStats),
            const SizedBox(height: 16),
            _buildStatsGroup('Счета', _invoiceStats),
            const SizedBox(height: 16),
            _buildStatsGroup('Запросы фото', _photoRequestStats),
            const SizedBox(height: 16),
            _buildStatsGroup('Заданные вопросы', _questionStats),
          ],
        ),
        const SizedBox(height: 16),

        // Export Section
        _buildSectionCard(
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
    );
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
                  gradient: const LinearGradient(
                    colors: [Color(0xFFfe3301), Color(0xFFff5f02)],
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
                      onPressed: onCancel,
                      child: const Text('Отмена'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: onSave,
                      child: const Text('Сохранить'),
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
                color: const Color(0xFFfe3301),
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
                gradient: const LinearGradient(
                  colors: [Color(0xFFfe3301), Color(0xFFff5f02)],
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
              color: const Color(0xFFfe3301).withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFFfe3301),
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
                  onPressed: () {
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
                    Navigator.pop(context);
                    _showStyledSnackBar(this.context, 'Пароль успешно изменён');
                  },
                  child: const Text('Сохранить'),
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
      // Получаем все счета
      final repo = ref.read(invoicesRepositoryProvider);
      final invoices = await repo.fetchInvoices(clientCode: clientCode);
      
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
        xls.TextCellValue('Дата отправки'),
        xls.TextCellValue('Статус'),
        xls.TextCellValue('Тип доставки'),
        xls.TextCellValue('Тип тарифа'),
        xls.TextCellValue('Мест'),
        xls.TextCellValue('Вес (кг)'),
        xls.TextCellValue('Объём (м³)'),
        xls.TextCellValue('Плотность'),
        xls.TextCellValue('Сумма (руб)'),
        xls.TextCellValue('Сумма (USD)'),
        xls.TextCellValue('Курс'),
      ]);
      
      // Данные
      final dateFormat = DateFormat('dd.MM.yyyy');
      for (final invoice in invoices) {
        sheet.appendRow([
          xls.TextCellValue(invoice.invoiceNumber),
          xls.TextCellValue(dateFormat.format(invoice.sendDate)),
          xls.TextCellValue(invoice.status),
          xls.TextCellValue(invoice.deliveryType ?? ''),
          xls.TextCellValue(invoice.tariffType ?? ''),
          xls.IntCellValue(invoice.placesCount),
          xls.DoubleCellValue(invoice.weight),
          xls.DoubleCellValue(invoice.volume),
          xls.DoubleCellValue(invoice.density),
          xls.DoubleCellValue(invoice.totalCostRub),
          invoice.totalCostUsd != null ? xls.DoubleCellValue(invoice.totalCostUsd!) : xls.TextCellValue(''),
          invoice.rate != null ? xls.DoubleCellValue(invoice.rate!) : xls.TextCellValue(''),
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
      final fileName = 'Счета_${DateFormat('yyyy-MM-dd_HH-mm').format(DateTime.now())}.xlsx';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);
      
      // Шарим файл
      await Share.shareXFiles([XFile(file.path)], text: 'Экспорт счетов');
      
      _showStyledSnackBar(context, 'Экспортировано ${invoices.length} счетов');
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
      // Получаем все треки
      final repo = ref.read(tracksRepositoryProvider);
      final tracks = await repo.fetchTracks(clientCode: clientCode);
      
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
        xls.TextCellValue('Дата'),
        xls.TextCellValue('ID сборки'),
        xls.TextCellValue('Комментарий'),
      ]);
      
      // Данные
      final dateFormat = DateFormat('dd.MM.yyyy');
      for (final track in tracks) {
        sheet.appendRow([
          xls.TextCellValue(track.code),
          xls.TextCellValue(track.status),
          xls.TextCellValue(dateFormat.format(track.date)),
          xls.TextCellValue(track.groupId ?? ''),
          xls.TextCellValue(track.comment ?? ''),
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
      final fileName = 'Треки_${DateFormat('yyyy-MM-dd_HH-mm').format(DateTime.now())}.xlsx';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);
      
      // Шарим файл
      await Share.shareXFiles([XFile(file.path)], text: 'Экспорт треков');
      
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
