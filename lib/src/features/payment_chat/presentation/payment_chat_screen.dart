// ignore_for_file: deprecated_member_use
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:twoalogisticcabineuser/src/core/ui/app_toast.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import '../../../core/ui/tutorial_card.dart';

import '../../../core/ui/app_background.dart';
import '../../../core/ui/app_colors.dart';
import '../../../core/ui/app_page_header.dart';
import '../../../core/ui/fullscreen_image_overlay.dart';
import '../../../core/ui/pdf_preview_overlay.dart';
import '../../../core/services/push_notification_service.dart';
import '../../../core/services/chat_presence_service.dart';
import '../../../core/network/api_config.dart';
import '../../../core/utils/locale_text.dart';
import '../../clients/application/client_codes_controller.dart';
import '../../invoices/data/invoices_provider.dart';
import '../../invoices/domain/invoice_item.dart';
import '../../notifications/application/notifications_controller.dart';
import '../../notifications/domain/notification_item.dart';
import '../../tracks/data/tracks_provider.dart';
import '../../tracks/domain/track_item.dart';
import 'package:twoalogistic_shared/twoalogistic_shared.dart';
import '../data/payment_chat_provider.dart';

class PaymentChatScreen extends ConsumerStatefulWidget {
  final String? initialMessage;
  final String? invoiceId;
  final String? invoiceNumber;
  final double? amount;
  final double? totalCostCny;
  final double? totalCostRub;
  final double? clientRubRate;
  final double? clientYuanRate;

  const PaymentChatScreen({
    super.key,
    this.initialMessage,
    this.invoiceId,
    this.invoiceNumber,
    this.amount,
    this.totalCostCny,
    this.totalCostRub,
    this.clientRubRate,
    this.clientYuanRate,
  });

  @override
  ConsumerState<PaymentChatScreen> createState() => _PaymentChatScreenState();
}

class _PaymentChatScreenState extends ConsumerState<PaymentChatScreen>
    with WidgetsBindingObserver {
  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();
  Timer? _pollingTimer;

  final bool _showQuickActions = false;
  AppLifecycleState _appLifecycleState = AppLifecycleState.resumed;
  bool _isInfoBannerExpanded = false;

  // Локальный флаг защиты от двойной отправки (синхронный, выставляется раньше isSending в контроллере)
  bool _isSendingLocally = false;

  // Флаг защиты от вызова ref после disposal
  bool _isDisposed = false;
  late final IsPaymentChatScreenOpenNotifier _screenOpenNotifier;
  late final ChatPresenceService _chatPresenceService;
  late final PushNotificationService _notificationService;

  final GlobalKey _infoBannerKey = GlobalKey();
  final GlobalKey _messagesAreaKey = GlobalKey();
  final GlobalKey _inputAreaKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _screenOpenNotifier = ref.read(isPaymentChatScreenOpenProvider.notifier);
    _chatPresenceService = ref.read(chatPresenceServiceProvider);
    _notificationService = ref.read(pushNotificationServiceProvider);
    WidgetsBinding.instance.addObserver(this);
    _initNotifications();

    // Загружаем чат и запускаем polling
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!_canUseRef) return;
      _screenOpenNotifier.set(true);
      unawaited(
        ref.read(notificationsControllerProvider.notifier).markTypesRead({
          NotificationType.paymentChatMessage,
        }),
      );
      await ref.read(paymentChatControllerProvider.notifier).loadConversation();
      if (!_canUseRef) return;

      // Если есть начальное сообщение об оплате счёта - отправляем его сразу
      if (widget.invoiceId != null && widget.initialMessage != null) {
        await _sendInitialInvoiceMessage();
        if (!_canUseRef) return;
      } else if (widget.initialMessage != null &&
          widget.initialMessage!.isNotEmpty) {
        // Просто устанавливаем текст в поле (старое поведение)
        _textController.text = widget.initialMessage!;
      }

      // Запускаем polling для новых сообщений
      _startPolling();

      // Уведомляем сервер что чат открыт (для блокировки push-уведомлений)
      _notifyServerChatOpened();
    });

    // Очищаем уведомления при открытии чата
    _clearNotifications();
  }

  bool get _canUseRef => mounted && !_isDisposed;

  /// Уведомить сервер что чат открыт
  Future<void> _notifyServerChatOpened() async {
    if (!_canUseRef) return;
    final chatState = ref.read(paymentChatControllerProvider);
    final conversationId = chatState.conversation?.id;
    await _chatPresenceService.openChat(
      ChatType.payment,
      conversationId: conversationId,
    );
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted && !_isAppInBackground) {
        _pollMessages();
      }
    });
  }

  void _pollMessages() {
    if (!_canUseRef) return;
    ref.read(paymentChatControllerProvider.notifier).pollNewMessages();
  }

  Future<void> _initNotifications() async {
    await _notificationService.initialize();
  }

  Future<void> _clearNotifications() async {
    await _notificationService.cancelAllNotifications();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _pollingTimer?.cancel();

    try {
      _screenOpenNotifier.set(false);
      _chatPresenceService.closeChat(ChatType.payment);
    } catch (_) {}

    WidgetsBinding.instance.removeObserver(this);
    _textController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted || _isDisposed) return;
    _appLifecycleState = state;
    debugPrint('App lifecycle state changed to: $state');

    if (state == AppLifecycleState.resumed) {
      _clearNotifications();
      // Обновляем сообщения при возврате в приложение
      ref.read(paymentChatControllerProvider.notifier).pollNewMessages();
      // Уведомляем сервер что чат снова открыт
      _notifyServerChatOpened();
    } else if (state == AppLifecycleState.paused) {
      // Уведомляем сервер что приложение ушло в фон
      _chatPresenceService.onAppPaused();
    }
  }

  bool get _isAppInBackground =>
      _appLifecycleState == AppLifecycleState.paused ||
      _appLifecycleState == AppLifecycleState.inactive ||
      _appLifecycleState == AppLifecycleState.hidden;

  // Флаг чтобы отправить начальное сообщение только один раз
  bool _initialMessageSent = false;

  Future<void> _handleMessageSend(
    String text, {
    Map<String, dynamic>? metadata,
  }) async {
    if (!_canUseRef) return;
    if (_isSendingLocally) return;

    final chatState = ref.read(paymentChatControllerProvider);
    final pendingAttachments = chatState.pendingAttachments;

    // Если нет текста и нет вложений - ничего не делаем
    if (text.trim().isEmpty && pendingAttachments.isEmpty) return;

    _isSendingLocally = true;
    try {
      HapticFeedback.lightImpact();
      _textController.selection = const TextSelection.collapsed(offset: 0);
      _textController.clear();

      // Собираем ID вложений
      final attachmentIds = pendingAttachments
          .map((a) => a['id'] as int)
          .toList();

      final success = await ref
          .read(paymentChatControllerProvider.notifier)
          .sendMessage(
            text.isEmpty ? tr(context, ru: 'Файл', zh: '文件') : text,
            metadata: metadata,
            attachmentIds: attachmentIds,
          );

      if (success && _canUseRef) {
        // Очищаем pending attachments
        ref
            .read(paymentChatControllerProvider.notifier)
            .clearPendingAttachments();
        // Прокрутка вниз после отправки
        _scrollToBottom();
      }
    } finally {
      _isSendingLocally = false;
    }
  }

  /// Показать диалог выбора типа вложения
  void _showAttachmentPicker() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E2E),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              tr(context, ru: 'Прикрепить файл', zh: '附加文件'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.camera_alt, color: Colors.blue),
              ),
              title: Text(
                tr(context, ru: 'Камера', zh: '相机'),
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                tr(context, ru: 'Сделать фото', zh: '拍照'),
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickImageFromCamera();
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.photo_library, color: Colors.green),
              ),
              title: Text(
                tr(context, ru: 'Галерея', zh: '图库'),
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                tr(context, ru: 'Выбрать изображение', zh: '选择图片'),
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickImageFromGallery();
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.insert_drive_file,
                  color: Colors.orange,
                ),
              ),
              title: Text(
                tr(context, ru: 'Документ', zh: '文档'),
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                tr(
                  context,
                  ru: 'PDF, Word, Excel и другие',
                  zh: 'PDF、Word、Excel等',
                ),
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickDocumentFile();
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  /// Выбрать изображение с камеры
  Future<void> _pickImageFromCamera() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
        requestFullMetadata: false, // Конвертирует HEIC в JPEG на iOS
      );
      if (image != null) {
        // Читаем bytes напрямую из XFile для избежания проблем с iOS sandbox
        final bytes = await image.readAsBytes();
        final fileName = image.name.isNotEmpty
            ? image.name
            : 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
        await _uploadFileFromBytes(bytes, fileName);
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackbar(
          '${tr(context, ru: 'Ошибка при съёмке', zh: '拍照时出错')}: $e',
        );
      }
    }
  }

  /// Выбрать изображение из галереи (используем file_picker для обхода iOS HDR проблемы)
  Future<void> _pickImageFromGallery() async {
    debugPrint('📷 [Gallery] Starting file picker for images...');
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        allowCompression: false,
        compressionQuality: 0,
      );

      debugPrint(
        '📷 [Gallery] FilePicker returned: ${result != null ? "${result.files.length} files" : "null/cancelled"}',
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        debugPrint('📷 [Gallery] File: ${file.name}, size: ${file.size}');

        final bytes = await file.xFile.readAsBytes();

        if (bytes.isEmpty) {
          debugPrint('📷 [Gallery] ERROR: could not read file bytes');
          if (mounted) {
            _showErrorSnackbar(
              tr(context, ru: 'Не удалось прочитать файл', zh: '无法读取文件'),
            );
          }
          return;
        }

        debugPrint('📷 [Gallery] Read ${bytes.length} bytes');

        final fileName = file.name.isNotEmpty
            ? file.name
            : 'image_${DateTime.now().millisecondsSinceEpoch}.jpg';

        debugPrint(
          '📷 [Gallery] Uploading $fileName (${bytes.length} bytes)...',
        );
        await _uploadFileFromBytes(bytes, fileName);
        debugPrint('📷 [Gallery] Upload completed');
      }
    } catch (e, stack) {
      debugPrint('📷 [Gallery] ERROR: $e');
      debugPrint('📷 [Gallery] Stack: $stack');
      if (mounted) {
        _showErrorSnackbar(
          '${tr(context, ru: 'Ошибка при выборе изображения', zh: '选择图片时出错')}: $e',
        );
      }
    }
  }

  /// Выбрать документ (PDF, Word, Excel и др.)
  Future<void> _pickDocumentFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'pdf',
          'doc',
          'docx',
          'xls',
          'xlsx',
          'csv',
          'ppt',
          'pptx',
          'txt',
          'rtf',
          'zip',
          'rar',
          '7z',
        ],
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;

        final bytes = await file.xFile.readAsBytes();

        if (bytes.isEmpty) {
          if (mounted) {
            _showErrorSnackbar(
              tr(context, ru: 'Не удалось прочитать файл', zh: '无法读取文件'),
            );
          }
          return;
        }

        // Проверка размера (10MB)
        if (bytes.length > 10 * 1024 * 1024) {
          if (mounted) {
            _showErrorSnackbar(
              tr(
                context,
                ru: 'Файл слишком большой. Максимум 10 МБ',
                zh: '文件太大。最大10 MB',
              ),
            );
          }
          return;
        }

        final fileName = file.name.isNotEmpty
            ? file.name
            : 'document_${DateTime.now().millisecondsSinceEpoch}.pdf';

        await _uploadFileFromBytes(bytes, fileName);
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackbar(
          '${tr(context, ru: 'Ошибка при выборе файла', zh: '选择文件时出错')}: $e',
        );
      }
    }
  }

  /// Загрузить файл из bytes на сервер (для iOS)
  Future<void> _uploadFileFromBytes(Uint8List bytes, String fileName) async {
    if (!_canUseRef) return;
    final chatState = ref.read(paymentChatControllerProvider);
    final conversationId = chatState.conversation?.id;

    if (conversationId == null) {
      if (mounted) {
        _showErrorSnackbar(
          tr(context, ru: 'Чат не инициализирован', zh: '聊天未初始化'),
        );
      }
      return;
    }

    if (bytes.isEmpty) {
      if (mounted) {
        _showErrorSnackbar(tr(context, ru: 'Файл пустой', zh: '文件为空'));
      }
      return;
    }

    final result = await ref
        .read(paymentChatControllerProvider.notifier)
        .uploadFileFromBytes(bytes, fileName, conversationId);

    if (result == null) {
      if (!mounted || _isDisposed) return;
      _showErrorSnackbar(
        tr(context, ru: 'Ошибка при загрузке файла', zh: '文件上传失败'),
      );
    }
  }

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    AppToast.showFromSnackBar(
      context,
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.fixed,
      ),
    );
  }

  /// Отправить начальное сообщение с информацией о счёте (если есть)
  Future<void> _sendInitialInvoiceMessage() async {
    if (_initialMessageSent) return;
    if (widget.initialMessage == null || widget.initialMessage!.isEmpty) return;

    _initialMessageSent = true;

    Map<String, dynamic>? metadata;
    if (widget.invoiceId != null) {
      metadata = {
        'type': 'invoice_payment_request',
        'invoiceId': widget.invoiceId,
        'invoiceNumber': widget.invoiceNumber,
        'amount': widget.amount,
        if (widget.totalCostCny != null) 'totalCostCny': widget.totalCostCny,
        if (widget.totalCostRub != null) 'totalCostRub': widget.totalCostRub,
        if (widget.clientRubRate != null) 'clientRubRate': widget.clientRubRate,
        if (widget.clientYuanRate != null)
          'clientYuanRate': widget.clientYuanRate,
      };
    }

    await _handleMessageSend(widget.initialMessage!, metadata: metadata);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showQuickSendSheet() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (context) => _QuickSendSheet(
        onTrackSelected: _sendTrackInfo,
        onInvoiceSelected: _sendInvoiceInfo,
      ),
    );
  }

  void _sendTrackInfo(TrackItem track) {
    final dateFormat = DateFormat('dd.MM.yyyy HH:mm');
    final buffer = StringBuffer();

    if (isZh(context)) {
      buffer.writeln('📦 **运单信息**');
      buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
      buffer.writeln('🔢 编号: ${track.code}');
      buffer.writeln('📊 状态: ${track.status}');
      buffer.writeln('📅 日期: ${dateFormat.format(track.date)}');

      if (track.comment != null) {
        buffer.writeln('💬 备注: ${track.comment}');
      }

      if (track.assembly != null) {
        buffer.writeln('');
        buffer.writeln('📁 **组装:** ${track.assembly!.number}');
        buffer.writeln(
          '   • 状态: ${track.assembly!.statusName ?? track.assembly!.status}',
        );
      }

      if (track.photoReportUrls.isNotEmpty) {
        buffer.writeln('');
        buffer.writeln('📸 照片报告: ${track.photoReportUrls.length} 张');
      }

      final activePhoto = track.activePhotoRequest;
      if (activePhoto != null) {
        buffer.writeln('📷 照片请求: ${activePhoto.status}');
      }
    } else {
      buffer.writeln('📦 **Информация о треке**');
      buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
      buffer.writeln('🔢 Номер: ${track.code}');
      buffer.writeln('📊 Статус: ${track.status}');
      buffer.writeln('📅 Дата: ${dateFormat.format(track.date)}');

      if (track.comment != null) {
        buffer.writeln('💬 Комментарий: ${track.comment}');
      }

      if (track.assembly != null) {
        buffer.writeln('');
        buffer.writeln('📁 **Сборка:** ${track.assembly!.number}');
        buffer.writeln(
          '   • Статус: ${track.assembly!.statusName ?? track.assembly!.status}',
        );
      }

      if (track.photoReportUrls.isNotEmpty) {
        buffer.writeln('');
        buffer.writeln('📸 Фото отчёт: ${track.photoReportUrls.length} фото');
      }

      final activePhoto = track.activePhotoRequest;
      if (activePhoto != null) {
        buffer.writeln('📷 Запрос фото: ${activePhoto.status}');
      }
    }

    _handleMessageSend(buffer.toString());
  }

  void _sendInvoiceInfo(InvoiceItem invoice) {
    final dateFormat = DateFormat('dd.MM.yyyy');
    final buffer = StringBuffer();

    if (isZh(context)) {
      buffer.writeln('🧾 **发票信息**');
      buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
      buffer.writeln('🔢 编号: ${invoice.invoiceNumber}');
      buffer.writeln('📊 状态: ${invoice.status}');
      if (invoice.sendDate != null) {
        buffer.writeln('📅 发货日期: ${dateFormat.format(invoice.sendDate!)}');
      }
      buffer.writeln('');
      buffer.writeln('📦 **货物参数:**');
      buffer.writeln('   • 件数: ${invoice.placesCount}');
      buffer.writeln('   • 重量: ${invoice.weight.toStringAsFixed(1)} 公斤');
      buffer.writeln('   • 体积: ${invoice.volume.toStringAsFixed(2)} 立方米');
      buffer.writeln('   • 密度: ${invoice.density.toStringAsFixed(0)} 公斤/立方米');

      if (invoice.tariffName != null) {
        buffer.writeln('   • 费率: ${invoice.tariffName}');
      }

      buffer.writeln('');
      buffer.writeln('💰 **费用:**');
      if (invoice.tariffBaseCost != null && invoice.tariffBaseCost! > 0) {
        buffer.writeln(
          '   • 费率: \$${invoice.tariffBaseCost!.toStringAsFixed(2)}/公斤',
        );
      }
      if (invoice.insuranceCost != null && invoice.insuranceCost! > 0) {
        buffer.writeln(
          '   • 保险: \$${invoice.insuranceCost!.toStringAsFixed(2)}',
        );
      }
      final packagingTotal = invoice.resolvedPackagingCostTotal;
      if (packagingTotal != null && packagingTotal > 0) {
        buffer.writeln('   • 包装: \$${packagingTotal.toStringAsFixed(2)}');
      }
      buffer.writeln(
        '   • **合计:** ${invoice.totalCostRub.toStringAsFixed(0)} ₽',
      );

      if (invoice.scalePhotoUrls.isNotEmpty) {
        buffer.writeln('');
        buffer.writeln('📸 照片: ${invoice.scalePhotoUrls.length} 张');
      }
    } else {
      buffer.writeln('🧾 **Информация о счёте**');
      buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
      buffer.writeln('🔢 Номер: ${invoice.invoiceNumber}');
      buffer.writeln('📊 Статус: ${invoice.status}');
      if (invoice.sendDate != null) {
        buffer.writeln(
          '📅 Дата отправки: ${dateFormat.format(invoice.sendDate!)}',
        );
      }
      buffer.writeln('');
      buffer.writeln('📦 **Параметры груза:**');
      buffer.writeln('   • Мест: ${invoice.placesCount}');
      buffer.writeln('   • Вес: ${invoice.weight.toStringAsFixed(1)} кг');
      buffer.writeln('   • Объём: ${invoice.volume.toStringAsFixed(2)} м³');
      buffer.writeln(
        '   • Плотность: ${invoice.density.toStringAsFixed(0)} кг/м³',
      );

      if (invoice.tariffName != null) {
        buffer.writeln('   • Тариф: ${invoice.tariffName}');
      }

      buffer.writeln('');
      buffer.writeln('💰 **Стоимость:**');
      if (invoice.tariffBaseCost != null && invoice.tariffBaseCost! > 0) {
        buffer.writeln(
          '   • Тариф: \$${invoice.tariffBaseCost!.toStringAsFixed(2)}/кг',
        );
      }
      if (invoice.insuranceCost != null && invoice.insuranceCost! > 0) {
        buffer.writeln(
          '   • Страховка: \$${invoice.insuranceCost!.toStringAsFixed(2)}',
        );
      }
      final packagingTotal = invoice.resolvedPackagingCostTotal;
      if (packagingTotal != null && packagingTotal > 0) {
        buffer.writeln('   • Упаковка: \$${packagingTotal.toStringAsFixed(2)}');
      }
      buffer.writeln(
        '   • **Итого:** ${invoice.totalCostRub.toStringAsFixed(0)} ₽',
      );

      if (invoice.scalePhotoUrls.isNotEmpty) {
        buffer.writeln('');
        buffer.writeln('📸 Фото: ${invoice.scalePhotoUrls.length} шт.');
      }
    }

    _handleMessageSend(buffer.toString());
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;

    return TutorialScreenWrapper(
      screenKey: 'payment_chat',
      steps: [
        TutorialStep(
          icon: Icons.payments_rounded,
          title: 'Чат по оплате',
          description:
              'Здесь обсуждается оплата счетов. Напишите, если есть вопросы по сумме или реквизитам.',
          targetKey: _messagesAreaKey,
        ),
        TutorialStep(
          icon: Icons.receipt_rounded,
          title: 'Прикрепить чек',
          description:
              'После оплаты нажмите значок скрепки и прикрепите скриншот или чек — это ускорит подтверждение платежа.',
          targetKey: _inputAreaKey,
        ),
        TutorialStep(
          icon: Icons.info_outline_rounded,
          title: 'Баннер с инструкцией',
          description:
              'Вверху чата — кнопка с инструкцией по оплате. Откройте её, чтобы узнать доступные способы.',
          targetKey: _infoBannerKey,
        ),
      ],
      child: Stack(
        children: [
          // Градиентный фон как на других страницах
          const Positioned.fill(child: AppBackground()),

          SafeArea(
            top: false, // Контент скроллится под топ-меню
            bottom: false,
            child: Column(
              children: [
                // Отступ от верха экрана
                const SizedBox(height: 65),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: AppPageHeader(title: 'Чат по оплате', showBack: true),
                ),
                const SizedBox(height: 12),
                // Информационный блок о назначении чата
                _buildInfoBanner(),

                // Список сообщений
                Expanded(key: _messagesAreaKey, child: _buildMessagesList()),

                // Панель быстрых действий
                if (_showQuickActions) _buildQuickActionsBar(),

                // Поле ввода
                _buildInputField(bottomInset),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
    final chatState = ref.watch(paymentChatControllerProvider);

    if (chatState.isLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(context.brandPrimary),
        ),
      );
    }

    if (chatState.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              chatState.error!,
              style: const TextStyle(color: Colors.black54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                ref
                    .read(paymentChatControllerProvider.notifier)
                    .loadConversation();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: context.brandPrimary,
              ),
              child: Text(
                tr(context, ru: 'Повторить', zh: '重试'),
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );
    }

    final messages = chatState.messages;

    if (messages.isEmpty) {
      return _buildEmptyState();
    }

    // Автопрокрутка вниз
    _scrollToBottom();

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: messages.length,
      addAutomaticKeepAlives: false,
      addSemanticIndexes: false,
      itemBuilder: (context, index) {
        final message = messages[index];
        return _buildMessageBubble(message);
      },
    );
  }

  /// Информационный баннер о назначении чата
  Widget _buildInfoBanner() {
    return GestureDetector(
      key: _infoBannerKey,
      onTap: () =>
          setState(() => _isInfoBannerExpanded = !_isInfoBannerExpanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8E1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFFFE0B2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.orange.shade700,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    tr(
                      context,
                      ru: 'Чат только для оплаты счетов',
                      zh: '此聊天仅用于支付发票',
                    ),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.orange.shade800,
                      fontSize: 12,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: _isInfoBannerExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    color: Colors.orange.shade700,
                    size: 18,
                  ),
                ),
              ],
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  tr(
                    context,
                    ru:
                        '• Специалист не сможет ответить на вопросы, не касающиеся приёма оплаты\n'
                        '• Отправьте скриншот платежа для подтверждения\n'
                        '• Статус счёта обновится после проверки',
                    zh:
                        '• 专员无法回答与付款无关的问题\n'
                        '• 请发送付款截图以确认\n'
                        '• 发票状态将在审核后更新',
                  ),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.orange.shade800,
                    height: 1.3,
                  ),
                ),
              ),
              crossFadeState: _isInfoBannerExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    // Специальный рендер для запроса оплаты счёта — показываем актуальные данные
    final meta = message.metadata;
    if (meta != null && meta['type'] == 'invoice_payment_request') {
      final invoiceId = meta['invoiceId']?.toString();
      if (invoiceId != null) {
        return _InvoicePaymentBubble(message: message, invoiceId: invoiceId);
      }
    }

    final isMe = message.isFromClient;
    final dateFormat = DateFormat('dd.MM.yyyy HH:mm');

    // Используем реальное имя из сообщения
    final authorName = message.senderName;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: isMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          // Имя автора сообщения
          Padding(
            padding: EdgeInsets.only(
              left: isMe ? 0 : 40,
              right: isMe ? 40 : 0,
              bottom: 4,
            ),
            child: Text(
              authorName,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.black.withValues(alpha: 0.6),
              ),
            ),
          ),

          // Сообщение
          Row(
            mainAxisAlignment: isMe
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isMe) ...[
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4CAF50), Color(0xFF8BC34A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 8),
              ],

              Flexible(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    gradient: isMe
                        ? LinearGradient(
                            colors: [
                              context.brandPrimary,
                              context.brandSecondary,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: isMe ? null : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(isMe ? 20 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Отображаем вложения
                      if (message.attachments.isNotEmpty)
                        _buildMessageAttachments(message.attachments, isMe),

                      // Текст сообщения (если это не просто "Файл")
                      if (message.content.isNotEmpty &&
                          message.content != 'Файл' &&
                          message.content != '文件')
                        MarkdownBody(
                          data: message.content.replaceAll('\n', '  \n'),
                          selectable: true,
                          styleSheet: MarkdownStyleSheet(
                            p: TextStyle(
                              fontFamily: 'Gilroy',
                              fontSize: 15,
                              height: 1.4,
                              color: isMe ? Colors.white : Colors.black87,
                            ),
                            strong: TextStyle(
                              fontFamily: 'Gilroy',
                              fontSize: 15,
                              height: 1.4,
                              fontWeight: FontWeight.bold,
                              color: isMe ? Colors.white : Colors.black87,
                            ),
                            em: TextStyle(
                              fontFamily: 'Gilroy',
                              fontSize: 15,
                              height: 1.4,
                              fontStyle: FontStyle.italic,
                              color: isMe ? Colors.white : Colors.black87,
                            ),
                            a: TextStyle(
                              fontFamily: 'Gilroy',
                              fontSize: 15,
                              height: 1.4,
                              color: isMe ? Colors.white : context.brandPrimary,
                              decoration: TextDecoration.underline,
                            ),
                            code: TextStyle(
                              fontFamily: 'Gilroy',
                              fontSize: 14,
                              color: isMe ? Colors.white : Colors.black87,
                              backgroundColor: isMe
                                  ? Colors.white.withValues(alpha: 0.2)
                                  : Colors.grey.withValues(alpha: 0.2),
                            ),
                            listBullet: TextStyle(
                              fontFamily: 'Gilroy',
                              fontSize: 15,
                              color: isMe ? Colors.white : Colors.black87,
                            ),
                          ),
                          onTapLink: (text, href, title) {
                            if (href != null) {
                              launchUrl(
                                Uri.parse(href),
                                mode: LaunchMode.externalApplication,
                              );
                            }
                          },
                        ),
                      if (message.content.isNotEmpty &&
                          message.content != 'Файл' &&
                          message.content != '文件')
                        const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (message.isEdited) ...[
                            Text(
                              'изм.',
                              style: TextStyle(
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                                color: isMe ? Colors.white54 : Colors.black38,
                              ),
                            ),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            dateFormat.format(message.createdAt.toLocal()),
                            style: TextStyle(
                              fontSize: 11,
                              color: isMe ? Colors.white70 : Colors.black45,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              if (isMe) ...[
                const SizedBox(width: 8),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.person_rounded,
                    color: context.brandPrimary,
                    size: 18,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// Отображение вложений в сообщении
  Widget _buildMessageAttachments(List<ChatAttachment> attachments, bool isMe) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: attachments.map((attachment) {
        final isImage = attachment.fileType.startsWith('image/');
        final isPdf = _isPdfAttachment(
          attachment.fileName,
          attachment.fileType,
        );
        final fullUrl = ApiConfig.getMediaUrl(attachment.url);

        if (isImage) {
          return GestureDetector(
            onTap: () => _showFullImage(fullUrl, attachment.fileName),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              constraints: const BoxConstraints(maxWidth: 200, maxHeight: 200),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: fullUrl,
                  fit: BoxFit.cover,
                  memCacheWidth: 360,
                  memCacheHeight: 360,
                  maxWidthDiskCache: 720,
                  maxHeightDiskCache: 720,
                  fadeInDuration: Duration.zero,
                  fadeOutDuration: Duration.zero,
                  useOldImageOnUrlChange: false,
                  filterQuality: FilterQuality.low,
                  placeholder: (context, url) => Container(
                    width: 150,
                    height: 150,
                    color: isMe
                        ? Colors.white.withValues(alpha: 0.2)
                        : Colors.grey.withValues(alpha: 0.2),
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: 150,
                    height: 100,
                    color: isMe
                        ? Colors.white.withValues(alpha: 0.2)
                        : Colors.grey.withValues(alpha: 0.2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.broken_image,
                          color: isMe ? Colors.white70 : Colors.black45,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tr(context, ru: 'Ошибка загрузки', zh: '加载错误'),
                          style: TextStyle(
                            fontSize: 12,
                            color: isMe ? Colors.white70 : Colors.black45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        } else {
          // Документ (PDF, Word, Excel и др.)
          final docIcon = _getDocumentIcon(attachment.fileName);
          final docColor = _getDocumentColor(attachment.fileName);
          return GestureDetector(
            onTap: isPdf
                ? () => _showPdfPreview(fullUrl, attachment.fileName)
                : () => _downloadFile(fullUrl, attachment.fileName),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isMe
                    ? Colors.white.withValues(alpha: 0.15)
                    : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isMe
                          ? Colors.white.withValues(alpha: 0.2)
                          : docColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      docIcon,
                      color: isMe ? Colors.white : docColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          attachment.fileName,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: isMe ? Colors.white : Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (attachment.fileSize != null)
                          Text(
                            _formatFileSize(attachment.fileSize!),
                            style: TextStyle(
                              fontSize: 12,
                              color: isMe ? Colors.white70 : Colors.black45,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.download_rounded,
                    color: isMe ? Colors.white70 : docColor,
                    size: 20,
                  ),
                ],
              ),
            ),
          );
        }
      }).toList(),
    );
  }

  /// Иконка документа по расширению файла
  IconData _getDocumentIcon(String fileName) {
    final ext = fileName.toLowerCase().split('.').last;
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
      case 'rtf':
        return Icons.description;
      case 'xls':
      case 'xlsx':
      case 'csv':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'zip':
      case 'rar':
      case '7z':
        return Icons.folder_zip;
      case 'txt':
        return Icons.article;
      default:
        return Icons.insert_drive_file;
    }
  }

  /// Цвет иконки документа по расширению
  Color _getDocumentColor(String fileName) {
    final ext = fileName.toLowerCase().split('.').last;
    switch (ext) {
      case 'pdf':
        return Colors.red;
      case 'doc':
      case 'docx':
      case 'rtf':
        return Colors.blue;
      case 'xls':
      case 'xlsx':
      case 'csv':
        return Colors.green;
      case 'ppt':
      case 'pptx':
        return Colors.orange;
      case 'zip':
      case 'rar':
      case '7z':
        return Colors.amber;
      case 'txt':
        return Colors.grey;
      default:
        return context.brandPrimary;
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Показать изображение на весь экран
  void _showFullImage(String url, String fileName) {
    showFullscreenImageOverlay(
      context: context,
      imageUrl: url,
      fileName: fileName,
      onDownload: () => _downloadFile(url, fileName),
    );
  }

  bool _isPdfAttachment(String fileName, String fileType) {
    return fileType.toLowerCase() == 'application/pdf' ||
        fileName.toLowerCase().endsWith('.pdf');
  }

  void _showPdfPreview(String url, String fileName) {
    showPdfPreviewOverlay(
      context: context,
      url: url,
      fileName: fileName,
      onDownload: () => _downloadFile(url, fileName),
    );
  }

  /// Скачать файл
  Future<void> _downloadFile(String url, String fileName) async {
    try {
      // Показываем индикатор загрузки
      AppToast.showFromSnackBar(
        context,
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Text(tr(context, ru: 'Загрузка файла...', zh: '正在下载文件...')),
            ],
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.fixed,
        ),
      );

      if (kIsWeb) {
        final opened = await launchUrl(
          Uri.parse(url),
          webOnlyWindowName: '_blank',
        );
        if (!opened) {
          throw Exception('Could not open file URL');
        }
        if (!mounted) return;
        AppToast.hide();
        return;
      }

      // Получаем директорию для сохранения
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$fileName';

      // Скачиваем файл
      final dio = Dio();
      await dio.download(url, filePath);

      if (!mounted) return;

      final savedText = tr(context, ru: 'Файл сохранён', zh: '文件已保存');
      final openText = tr(context, ru: 'Открыть', zh: '打开');

      AppToast.hide();
      AppToast.showFromSnackBar(
        context,
        SnackBar(
          content: Text('$savedText: $fileName'),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.fixed,
          action: SnackBarAction(
            label: openText,
            textColor: Colors.white,
            onPressed: () {
              // Открываем файл
              launchUrl(Uri.file(filePath));
            },
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      AppToast.hide();
      AppToast.showFromSnackBar(
        context,
        SnackBar(
          content: Text(
            '${tr(context, ru: 'Ошибка загрузки', zh: '下载错误')}: $e',
          ),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.fixed,
        ),
      );
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4CAF50), Color(0xFF8BC34A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.account_balance_wallet_rounded,
              color: Colors.white,
              size: 40,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            tr(context, ru: 'Чат по оплате', zh: '付款聊天'),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              tr(
                context,
                ru: 'Напишите нам по любым вопросам оплаты счетов и доставки',
                zh: '如有任何发票支付和配送问题，请联系我们',
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
      ),
      child: Row(
        children: [
          Expanded(
            child: _QuickActionButton(
              icon: Icons.local_shipping_rounded,
              label: tr(context, ru: 'Отправить трек', zh: '发送运单'),
              onTap: _showQuickSendSheet,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _QuickActionButton(
              icon: Icons.receipt_long_rounded,
              label: tr(context, ru: 'Отправить счёт', zh: '发送发票'),
              onTap: _showQuickSendSheet,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField(double bottomInset) {
    final chatState = ref.watch(paymentChatControllerProvider);
    final pendingAttachments = chatState.pendingAttachments;
    final isUploading = chatState.isUploading;

    return Container(
      key: _inputAreaKey,
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: 12 + bottomInset,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Preview прикреплённых файлов
            if (pendingAttachments.isNotEmpty || isUploading)
              _buildPendingAttachments(pendingAttachments, isUploading),

            Row(
              children: [
                // Кнопка прикрепления файла
                GestureDetector(
                  onTap: _showAttachmentPicker,
                  onLongPress: _showQuickSendSheet,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4CAF50), Color(0xFF8BC34A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.attach_file_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Поле ввода
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F8F8),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: TextField(
                      controller: _textController,
                      focusNode: _focusNode,
                      minLines: 1,
                      maxLines: 5,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        hintText: tr(
                          context,
                          ru: 'Введите ваше сообщение...',
                          zh: '输入您的消息...',
                        ),
                        hintStyle: const TextStyle(
                          color: Colors.black38,
                          fontSize: 15,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      style: const TextStyle(
                        fontSize: 15,
                        color: Colors.black87,
                      ),
                      textCapitalization: TextCapitalization.sentences,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Кнопка отправки с индикатором загрузки
                Builder(
                  builder: (context) {
                    final isSending = ref.watch(
                      paymentChatControllerProvider.select((s) => s.isSending),
                    );
                    return GestureDetector(
                      onTap: (isSending || isUploading)
                          ? null
                          : () => _handleMessageSend(_textController.text),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: (isSending || isUploading)
                                ? [Colors.grey, Colors.grey.shade400]
                                : [
                                    context.brandPrimary,
                                    context.brandSecondary,
                                  ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: (isSending || isUploading)
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Icon(
                                Icons.send_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Виджет для отображения прикреплённых файлов перед отправкой
  Widget _buildPendingAttachments(
    List<Map<String, dynamic>> attachments,
    bool isUploading,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Показываем загружаемый файл
            if (isUploading)
              Container(
                width: 80,
                height: 80,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F0F0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF4CAF50),
                      ),
                    ),
                  ),
                ),
              ),

            // Показываем уже загруженные файлы
            ...attachments.map((attachment) {
              final fileType = attachment['fileType'] as String? ?? '';
              final fileName = attachment['fileName'] as String? ?? 'file';
              final url = attachment['url'] as String? ?? '';
              final isImage = fileType.startsWith('image/');

              return Container(
                width: 80,
                height: 80,
                margin: const EdgeInsets.only(right: 8),
                child: Stack(
                  children: [
                    // Превью файла
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: isImage
                          ? CachedNetworkImage(
                              imageUrl: ApiConfig.getMediaUrl(url),
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                              memCacheWidth: 160,
                              memCacheHeight: 160,
                              maxWidthDiskCache: 320,
                              maxHeightDiskCache: 320,
                              fadeInDuration: Duration.zero,
                              fadeOutDuration: Duration.zero,
                              useOldImageOnUrlChange: false,
                              filterQuality: FilterQuality.low,
                              placeholder: (context, url) => Container(
                                color: const Color(0xFFF0F0F0),
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: const Color(0xFFF0F0F0),
                                child: const Icon(Icons.error),
                              ),
                            )
                          : Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: _getDocumentColor(
                                  fileName,
                                ).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _getDocumentIcon(fileName),
                                    color: _getDocumentColor(fileName),
                                    size: 28,
                                  ),
                                  const SizedBox(height: 4),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    child: Text(
                                      fileName,
                                      style: const TextStyle(
                                        fontSize: 8,
                                        color: Colors.black54,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),

                    // Кнопка удаления
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () {
                          final id = attachment['id']?.toString();
                          if (id != null) {
                            ref
                                .read(paymentChatControllerProvider.notifier)
                                .removePendingAttachment(id);
                          }
                        },
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF4CAF50).withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: const Color(0xFF4CAF50)),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF4CAF50),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickSendSheet extends ConsumerStatefulWidget {
  final Function(TrackItem) onTrackSelected;
  final Function(InvoiceItem) onInvoiceSelected;

  const _QuickSendSheet({
    required this.onTrackSelected,
    required this.onInvoiceSelected,
  });

  @override
  ConsumerState<_QuickSendSheet> createState() => _QuickSendSheetState();
}

class _QuickSendSheetState extends ConsumerState<_QuickSendSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clientCodeAsync = ref.watch(clientCodesControllerProvider);
    final clientCode = clientCodeAsync.value?.activeCode ?? '';

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  tr(context, ru: 'Быстрая отправка', zh: '快速发送'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tr(
                    context,
                    ru: 'Выберите трек или счёт для отправки в чат',
                    zh: '选择运单或发票发送到聊天',
                  ),
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            ),
          ),

          // Search
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8F8F8),
                borderRadius: BorderRadius.circular(14),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _searchQuery = value),
                decoration: InputDecoration(
                  hintText: tr(
                    context,
                    ru: 'Поиск по номеру...',
                    zh: '按编号搜索...',
                  ),
                  hintStyle: TextStyle(color: Colors.grey[500]),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: Colors.grey,
                    size: 26,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Tabs
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F8F8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4CAF50), Color(0xFF8BC34A)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.black54,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              padding: const EdgeInsets.all(4),
              tabs: [
                Tab(
                  text: tr(context, ru: 'Треки', zh: '运单'),
                ),
                Tab(
                  text: tr(context, ru: 'Счета', zh: '发票'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTracksList(clientCode),
                _buildInvoicesList(clientCode),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTracksList(String clientCode) {
    final tracksAsync = ref.watch(tracksSimpleListProvider(clientCode));

    return tracksAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: Color(0xFF4CAF50)),
      ),
      error: (e, _) => Center(
        child: Text('${tr(context, ru: 'Ошибка', zh: '错误')}: $e'),
      ),
      data: (tracks) {
        final filtered = tracks
            .where(
              (t) =>
                  t.code.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                  t.status.toLowerCase().contains(_searchQuery.toLowerCase()),
            )
            .toList();

        if (filtered.isEmpty) {
          return Center(
            child: Text(
              tr(context, ru: 'Треки не найдены', zh: '未找到运单'),
              style: const TextStyle(color: Colors.grey),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final track = filtered[index];
            return _TrackListTile(
              track: track,
              onTap: () {
                widget.onTrackSelected(track);
                Navigator.pop(context);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildInvoicesList(String clientCode) {
    final invoicesAsync = ref.watch(invoicesListProvider(clientCode));

    return invoicesAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: Color(0xFF4CAF50)),
      ),
      error: (e, _) => Center(
        child: Text('${tr(context, ru: 'Ошибка', zh: '错误')}: $e'),
      ),
      data: (invoices) {
        final filtered = invoices
            .where(
              (i) =>
                  i.invoiceNumber.toLowerCase().contains(
                    _searchQuery.toLowerCase(),
                  ) ||
                  i.status.toLowerCase().contains(_searchQuery.toLowerCase()),
            )
            .toList();

        if (filtered.isEmpty) {
          return Center(
            child: Text(
              tr(context, ru: 'Счета не найдены', zh: '未找到发票'),
              style: const TextStyle(color: Colors.grey),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final invoice = filtered[index];
            return _InvoiceListTile(
              invoice: invoice,
              onTap: () {
                widget.onInvoiceSelected(invoice);
                Navigator.pop(context);
              },
            );
          },
        );
      },
    );
  }
}

class _TrackListTile extends StatelessWidget {
  final TrackItem track;
  final VoidCallback onTap;

  const _TrackListTile({required this.track, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd.MM.yyyy');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFEEEEEE)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.local_shipping_rounded,
                color: Color(0xFF4CAF50),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.code,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${track.status} • ${dateFormat.format(track.date)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4CAF50), Color(0xFF8BC34A)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.send_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InvoiceListTile extends StatelessWidget {
  final InvoiceItem invoice;
  final VoidCallback onTap;

  const _InvoiceListTile({required this.invoice, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd.MM.yyyy');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFEEEEEE)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.receipt_long_rounded,
                color: Color(0xFF4CAF50),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    invoice.invoiceNumber,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${invoice.status}${invoice.sendDate != null ? ' • ${dateFormat.format(invoice.sendDate!)}' : ''} • ${invoice.totalCostRub.toStringAsFixed(0)} ₽',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4CAF50), Color(0xFF8BC34A)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.send_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Виджет для отображения запроса оплаты счёта с актуальными данными из сервера
class _InvoicePaymentBubble extends ConsumerWidget {
  final ChatMessage message;
  final String invoiceId;

  const _InvoicePaymentBubble({required this.message, required this.invoiceId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoiceAsync = ref.watch(invoiceByIdProvider(invoiceId));
    final isMe = message.isFromClient;
    final moneyFmt = NumberFormat.decimalPattern('ru');
    final dateFormat = DateFormat('dd.MM.yyyy HH:mm');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: isMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(
              left: isMe ? 0 : 40,
              right: isMe ? 40 : 0,
              bottom: 4,
            ),
            child: Text(
              message.senderName,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.black.withValues(alpha: 0.6),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: isMe
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isMe) ...[
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4CAF50), Color(0xFF8BC34A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                  ),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: isMe
                        ? LinearGradient(
                            colors: [
                              context.brandPrimary,
                              context.brandSecondary,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: isMe ? null : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(isMe ? 20 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: invoiceAsync.when(
                    loading: () => _InvoicePaymentContent(
                      message: message,
                      invoice: null,
                      isMe: isMe,
                      moneyFmt: moneyFmt,
                      dateFormat: dateFormat,
                      isLoading: true,
                    ),
                    error: (_, e) => _InvoicePaymentContent(
                      message: message,
                      invoice: null,
                      isMe: isMe,
                      moneyFmt: moneyFmt,
                      dateFormat: dateFormat,
                      isLoading: false,
                    ),
                    data: (invoice) => _InvoicePaymentContent(
                      message: message,
                      invoice: invoice,
                      isMe: isMe,
                      moneyFmt: moneyFmt,
                      dateFormat: dateFormat,
                      isLoading: false,
                    ),
                  ),
                ),
              ),
              if (isMe) ...[
                const SizedBox(width: 8),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.person_rounded,
                    color: context.brandPrimary,
                    size: 18,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _InvoicePaymentContent extends StatelessWidget {
  final ChatMessage message;
  final InvoiceItem? invoice;
  final bool isMe;
  final NumberFormat moneyFmt;
  final DateFormat dateFormat;
  final bool isLoading;

  const _InvoicePaymentContent({
    required this.message,
    required this.invoice,
    required this.isMe,
    required this.moneyFmt,
    required this.dateFormat,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isMe ? Colors.white : Colors.black87;
    final subColor = isMe ? Colors.white70 : Colors.black54;
    final meta = message.metadata!;

    // Актуальные данные из invoice, fallback на metadata
    final invoiceNumber =
        invoice?.invoiceNumber ?? meta['invoiceNumber']?.toString() ?? '—';
    final statusName = invoice?.statusName ?? invoice?.status ?? '—';
    final totalUsd =
        invoice?.totalCostUsd ?? (meta['amount'] as num?)?.toDouble() ?? 0.0;
    final totalCny =
        invoice?.totalCostCny ??
        (meta['totalCostCny'] as num?)?.toDouble() ??
        0.0;
    final totalRub =
        invoice?.totalCostRub ??
        (meta['totalCostRub'] as num?)?.toDouble() ??
        0.0;
    final rubRate =
        invoice?.clientRubRate ?? (meta['clientRubRate'] as num?)?.toDouble();
    final yuanRate =
        invoice?.clientYuanRate ?? (meta['clientYuanRate'] as num?)?.toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.receipt_long_rounded,
              size: 16,
              color: isMe ? Colors.white : context.brandPrimary,
            ),
            const SizedBox(width: 6),
            Text(
              'Запрос на оплату',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
            if (isLoading) ...[
              const SizedBox(width: 8),
              SizedBox(
                width: 10,
                height: 10,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: isMe ? Colors.white54 : Colors.grey,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '№ $invoiceNumber',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        Text(statusName, style: TextStyle(fontSize: 12, color: subColor)),
        const SizedBox(height: 10),
        _AmountRow(
          label: 'К оплате \$',
          value: '\$${moneyFmt.format(totalUsd.round())}',
          isMe: isMe,
        ),
        if (totalCny > 0)
          _AmountRow(
            label: 'К оплате ¥',
            value: '¥${moneyFmt.format(totalCny.round())}',
            isMe: isMe,
          ),
        if (totalRub > 0)
          _AmountRow(
            label: 'К оплате ₽',
            value: '${moneyFmt.format(totalRub.round())} ₽',
            isMe: isMe,
          ),
        if (rubRate != null || yuanRate != null) ...[
          const SizedBox(height: 6),
          Divider(height: 1, color: isMe ? Colors.white24 : Colors.black12),
          const SizedBox(height: 6),
          if (rubRate != null)
            _AmountRow(
              label: 'Курс \$/₽',
              value: rubRate.toStringAsFixed(2),
              isMe: isMe,
              small: true,
            ),
          if (yuanRate != null)
            _AmountRow(
              label: 'Курс \$/¥',
              value: yuanRate.toStringAsFixed(2),
              isMe: isMe,
              small: true,
            ),
        ],
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            dateFormat.format(message.createdAt.toLocal()),
            style: TextStyle(fontSize: 11, color: subColor),
          ),
        ),
      ],
    );
  }
}

class _AmountRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isMe;
  final bool small;

  const _AmountRow({
    required this.label,
    required this.value,
    required this.isMe,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isMe ? Colors.white : Colors.black87;
    final subColor = isMe ? Colors.white70 : Colors.black54;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: small ? 12 : 13, color: subColor),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: small ? 12 : 13,
              fontWeight: small ? FontWeight.w500 : FontWeight.w700,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
