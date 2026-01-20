import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:excel/excel.dart' as xls;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'dart:typed_data';

import '../../../core/services/auto_refresh_service.dart';
import '../../../core/services/app_language_service.dart';
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

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with AutoRefreshMixin {
  // Showcase keys
  final _showcaseKeyPersonalData = GlobalKey();
  final _showcaseKeyStats = GlobalKey();
  final _showcaseKeyExport = GlobalKey();

  // Export button keys for sharePositionOrigin on iPad
  final _invoicesExportButtonKey = GlobalKey();
  final _tracksExportButtonKey = GlobalKey();

  // Флаг чтобы showcase не запускался повторно при rebuild
  bool _showcaseStarted = false;

  @override
  void initState() {
    super.initState();
    _setupAutoRefresh();
  }

  void _startShowcaseIfNeeded(BuildContext showcaseContext) {
    // Проверяем локальный флаг чтобы не запускать повторно при rebuild
    if (_showcaseStarted) return;
    
    final showcaseState = ref.read(showcaseProvider(ShowcasePage.profile));
    if (!showcaseState.shouldShow) return;
    
    _showcaseStarted = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      
      ShowCaseWidget.of(showcaseContext).startShowCase([
        _showcaseKeyPersonalData,
        _showcaseKeyStats,
        _showcaseKeyExport,
      ]);
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
              
              // Запускаем showcase если нужно
              _startShowcaseIfNeeded(showcaseContext);
              
              final companyDomain = profile.agent?.domain ?? '';
              final stats = statsAsync.when(
                data: (s) => s,
                loading: () => ClientStats.empty,
                error: (_, _) => ClientStats.empty,
              );
              final appLanguage = ref.watch(appLanguageProvider);

              return RefreshIndicator(
                onRefresh: onRefresh,
                color: context.brandPrimary,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
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
                    description: 'Ваши контактные данные (только просмотр).',
                    targetPadding: const EdgeInsets.all(8),
                    tooltipPosition: TooltipPosition.bottom,
                    onTargetClick: () {
                      if (mounted) {
                        ShowCaseWidget.of(showcaseContext).next();
                      }
                    },
                    disposeOnTap: false,
                    child: _buildSectionCard(
                      title: 'Личные данные',
                      children: [
                        _buildReadonlyField(label: 'ФИО', value: profile.fullName),
                        const SizedBox(height: 12),
                        _buildReadonlyField(
                          label: 'Телефон',
                          value: (profile.phone?.isNotEmpty ?? false) ? profile.phone! : '—',
                        ),
                        const SizedBox(height: 12),
                        _buildReadonlyField(label: 'Email', value: profile.email),
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

            // Language Section
            _buildSectionCard(
              title: 'Язык',
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFDDDDDD)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<AppLanguage>(
                      value: appLanguage,
                      isExpanded: true,
                      items: AppLanguage.values
                          .map(
                            (lang) => DropdownMenuItem(
                              value: lang,
                              child: Text(
                                lang.labelRu,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        ref.read(appLanguageProvider.notifier).setLanguage(value);
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Statistics Section
            Showcase(
              key: _showcaseKeyStats,
              title: 'Статистика',
              description: 'Ваша статистика по трек-номерам, счетам, запросам фото и вопросам.',
              targetPadding: const EdgeInsets.all(8),
              tooltipPosition: TooltipPosition.bottom,
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
              targetPadding: const EdgeInsets.all(8),
              tooltipPosition: TooltipPosition.top,
              onBarrierClick: _onShowcaseComplete,
              onToolTipClick: _onShowcaseComplete,
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

  Rect? _getSharePositionOrigin(GlobalKey key) {
    final renderBox = key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return null;
    final position = renderBox.localToGlobal(Offset.zero);
    return Rect.fromLTWH(position.dx, position.dy, renderBox.size.width, renderBox.size.height);
  }

  Future<void> _exportInvoices(GlobalKey buttonKey) async {
    final clientCode = ref.read(activeClientCodeProvider);
    if (clientCode == null) {
      _showStyledSnackBar(context, 'Сначала выберите код клиента', isError: true);
      return;
    }
    
    try {
      // Получаем все счета из реального провайдера
      final invoices = await ref.read(invoicesListProvider(clientCode).future);
      
      if (!mounted) return;
      
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
      
      final uint8Bytes = Uint8List.fromList(bytes);
      
      final dir = await getTemporaryDirectory();
      final fileName = 'Счета_${clientCode}_${DateFormat('yyyy-MM-dd_HH-mm').format(DateTime.now())}.xlsx';
      final tempFile = File('${dir.path}/$fileName');
      await tempFile.writeAsBytes(uint8Bytes);
      
      // Используем Share для экспорта файла (работает на iOS и Android)
      final result = await Share.shareXFiles(
        [XFile(tempFile.path)],
        subject: 'Экспорт счетов',
        sharePositionOrigin: _getSharePositionOrigin(buttonKey),
      );
      
      if (!mounted) return;
      if (result.status == ShareResultStatus.success) {
        _showStyledSnackBar(context, 'Экспортировано ${invoices.length} счетов');
      }
    } catch (e) {
      if (!mounted) return;
      _showStyledSnackBar(context, 'Ошибка экспорта: $e', isError: true);
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
      
      final uint8Bytes = Uint8List.fromList(bytes);
      
      final dir = await getTemporaryDirectory();
      final fileName = 'Треки_${clientCode}_${DateFormat('yyyy-MM-dd_HH-mm').format(DateTime.now())}.xlsx';
      final tempFile = File('${dir.path}/$fileName');
      await tempFile.writeAsBytes(uint8Bytes);
      
      // Используем Share для экспорта файла (работает на iOS и Android)
      final result = await Share.shareXFiles(
        [XFile(tempFile.path)],
        subject: 'Экспорт треков',
        sharePositionOrigin: _getSharePositionOrigin(buttonKey),
      );
      
      if (!mounted) return;
      if (result.status == ShareResultStatus.success) {
        _showStyledSnackBar(context, 'Экспортировано ${tracks.length} треков');
      }
    } catch (e) {
      if (!mounted) return;
      _showStyledSnackBar(context, 'Ошибка экспорта: $e', isError: true);
    }
  }
}
