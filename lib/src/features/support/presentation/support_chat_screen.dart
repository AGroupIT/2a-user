import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/ui/app_background.dart';
import '../../../core/services/push_notification_service.dart';
import '../../clients/application/client_codes_controller.dart';
import '../../invoices/data/fake_invoices_repository.dart';
import '../../invoices/domain/invoice_item.dart';
import '../../tracks/data/fake_tracks_repository.dart';
import '../../tracks/domain/track_item.dart';

class SupportChatScreen extends ConsumerStatefulWidget {
  const SupportChatScreen({super.key});

  @override
  ConsumerState<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends ConsumerState<SupportChatScreen>
    with WidgetsBindingObserver {
  late final InMemoryChatController _chatController;
  final _uuid = const Uuid();
  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();

  static const _currentUserId = 'user';
  static const _supportUserId = 'support';

  final bool _showQuickActions = false;
  AppLifecycleState _appLifecycleState = AppLifecycleState.resumed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _chatController = InMemoryChatController(messages: _getDemoMessages());
    _initNotifications();

    // Отмечаем что чат открыт
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(isChatScreenOpenProvider.notifier).set(true);
    });

    // Очищаем уведомления при открытии чата
    _clearNotifications();
  }

  Future<void> _initNotifications() async {
    final notificationService = ref.read(pushNotificationServiceProvider);
    await notificationService.initialize();
  }

  Future<void> _clearNotifications() async {
    final notificationService = ref.read(pushNotificationServiceProvider);
    await notificationService.cancelAllNotifications();
  }

  @override
  void dispose() {
    // Отмечаем что чат закрыт
    ref.read(isChatScreenOpenProvider.notifier).set(false);
    WidgetsBinding.instance.removeObserver(this);
    _textController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    _chatController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Отслеживаем состояние приложения
    _appLifecycleState = state;
    debugPrint('App lifecycle state changed to: $state');

    // Очищаем уведомления при возврате в приложение
    if (state == AppLifecycleState.resumed) {
      _clearNotifications();
    }
  }

  bool get _isAppInBackground =>
      _appLifecycleState == AppLifecycleState.paused ||
      _appLifecycleState == AppLifecycleState.inactive ||
      _appLifecycleState == AppLifecycleState.hidden;

  List<TextMessage> _getDemoMessages() {
    final now = DateTime.now().toUtc();

    // Хронологический порядок (старые первые, новые последние)
    return [
      // Самое старое сообщение первое
      TextMessage(
        id: _uuid.v4(),
        authorId: _supportUserId,
        createdAt: now.subtract(const Duration(days: 1, hours: 2)),
        text:
            'Здравствуйте! Добро пожаловать в чат поддержки 2A Logistic. Чем мы можем вам помочь?',
      ),
      TextMessage(
        id: _uuid.v4(),
        authorId: _currentUserId,
        createdAt: now.subtract(const Duration(days: 1, hours: 1, minutes: 55)),
        text:
            'Здравствуйте! Хотел уточнить статус моего груза по накладной 2A-12345',
      ),
      TextMessage(
        id: _uuid.v4(),
        authorId: _supportUserId,
        createdAt: now.subtract(const Duration(days: 1, hours: 1, minutes: 50)),
        text:
            'Сейчас проверю информацию по вашей накладной. Одну минуту, пожалуйста.',
      ),
      TextMessage(
        id: _uuid.v4(),
        authorId: _supportUserId,
        createdAt: now.subtract(const Duration(days: 1, hours: 1, minutes: 48)),
        text:
            'Ваш груз по накладной 2A-12345 находится на складе в Алматы. Ожидаемая дата доставки — завтра до 18:00.',
      ),
      TextMessage(
        id: _uuid.v4(),
        authorId: _currentUserId,
        createdAt: now.subtract(const Duration(days: 1, hours: 1, minutes: 45)),
        text: 'Спасибо за информацию! А можно ускорить доставку?',
      ),
      TextMessage(
        id: _uuid.v4(),
        authorId: _supportUserId,
        createdAt: now.subtract(const Duration(days: 1, hours: 1, minutes: 40)),
        text:
            'К сожалению, в данном случае ускорить доставку не получится, так как груз уже запланирован на завтрашний рейс. Но я отмечу ваш заказ как приоритетный — доставим в первую очередь!',
      ),
      TextMessage(
        id: _uuid.v4(),
        authorId: _currentUserId,
        createdAt: now.subtract(const Duration(days: 1, hours: 1, minutes: 35)),
        text: 'Хорошо, спасибо!',
      ),
      // Самое новое сообщение последнее (будет внизу экрана)
      TextMessage(
        id: _uuid.v4(),
        authorId: _supportUserId,
        createdAt: now.subtract(const Duration(days: 1, hours: 1, minutes: 30)),
        text:
            'Пожалуйста! Если возникнут ещё вопросы — пишите, мы всегда на связи 🙂',
      ),
    ];
  }

  void _handleMessageSend(String text) {
    if (text.trim().isEmpty) return;

    HapticFeedback.lightImpact();

    final message = TextMessage(
      id: _uuid.v4(),
      authorId: _currentUserId,
      createdAt: DateTime.now().toUtc(),
      text: text,
    );

    _chatController.insertMessage(message);
    _textController.clear();
    setState(() {}); // Обновляем UI

    // Имитация ответа поддержки через 30 секунд
    Future.delayed(const Duration(seconds: 30), () {
      if (mounted) {
        _sendSupportReply(text);
      }
    });
  }

  void _sendSupportReply(String userMessage) {
    String replyText;

    // Умные ответы в зависимости от содержимого сообщения
    if (userMessage.contains('📦') &&
        userMessage.contains('Информация о треке')) {
      final replies = [
        'Спасибо за предоставленную информацию о треке! Я вижу все детали. Есть ли ещё что-то, что вас интересует по этому грузу?',
        'Отлично! Информация о треке получена. Могу подтвердить, что всё в порядке. Если возникнут вопросы — пишите!',
        'Благодарю за детали по треку. Вижу статус и дату доставки. Всё выглядит хорошо. Чем ещё могу помочь?',
        'Информация о треке принята! Если нужно уточнить статус или есть другие вопросы — обращайтесь.',
      ];
      replyText = replies[DateTime.now().second % replies.length];
    } else if (userMessage.contains('🧾') &&
        userMessage.contains('Информация о счёте')) {
      final replies = [
        'Спасибо за информацию о счёте! Все данные получены. Стоимость и параметры груза в порядке. Если есть вопросы по оплате — сообщите.',
        'Отлично! Счёт получен. Вижу все детали по весу, объёму и стоимости. Всё корректно. Чем ещё могу помочь?',
        'Благодарю за предоставленную информацию по счёту. Все параметры проверены. Если нужна дополнительная информация — обращайтесь!',
        'Информация о счёте принята! Вижу итоговую сумму и параметры груза. Если возникнут вопросы по доставке или оплате — пишите.',
      ];
      replyText = replies[DateTime.now().second % replies.length];
    } else if (userMessage.toLowerCase().contains('привет') ||
        userMessage.toLowerCase().contains('здравствуй')) {
      replyText = 'Здравствуйте! Рад вас видеть. Чем могу помочь сегодня?';
    } else if (userMessage.toLowerCase().contains('спасибо')) {
      replyText =
          'Пожалуйста! Всегда рад помочь. Если возникнут ещё вопросы — обращайтесь! 😊';
    } else if (userMessage.toLowerCase().contains('помощь') ||
        userMessage.toLowerCase().contains('помог')) {
      replyText =
          'Конечно! Я здесь, чтобы помочь вам с любыми вопросами по грузоперевозкам. Что именно вас интересует?';
    } else if (userMessage.toLowerCase().contains('где') ||
        userMessage.toLowerCase().contains('статус')) {
      replyText =
          'Проверяю информацию о статусе вашего груза. Обычно это занимает 1-2 минуты. Пожалуйста, ожидайте...';
    } else if (userMessage.toLowerCase().contains('цена') ||
        userMessage.toLowerCase().contains('стоимость') ||
        userMessage.toLowerCase().contains('сколько')) {
      replyText =
          'По вопросам стоимости доставки я могу предоставить актуальную информацию. Укажите, пожалуйста, направление и параметры груза.';
    } else if (userMessage.toLowerCase().contains('когда') ||
        userMessage.toLowerCase().contains('срок')) {
      replyText =
          'Уточняю сроки доставки для вашего груза. Обычно это занимает несколько минут. Подожду информации от склада.';
    } else {
      // Общие ответы
      final replies = [
        'Спасибо за сообщение! Я проверю информацию и свяжусь с вами в ближайшее время.',
        'Принято! Обрабатываю ваш запрос. Пожалуйста, ожидайте ответа от нашего специалиста.',
        'Благодарю за обращение! Ваш вопрос передан в работу. Среднее время ответа — 15 минут.',
        'Сообщение получено! Наш менеджер скоро свяжется с вами для уточнения деталей.',
        'Спасибо за ваше терпение! Проверяю информацию по вашему запросу...',
        'Получил ваше сообщение. Сейчас уточню детали и обязательно отвечу.',
      ];
      replyText = replies[DateTime.now().second % replies.length];
    }

    final reply = TextMessage(
      id: _uuid.v4(),
      authorId: _supportUserId,
      createdAt: DateTime.now().toUtc(),
      text: replyText,
    );

    HapticFeedback.mediumImpact();
    _chatController.insertMessage(reply);
    setState(() {}); // Обновляем UI

    // Отправляем push-уведомление, если приложение в фоне
    // Не отправляем если экран чата открыт (проверяем через isChatScreenOpenProvider)
    final isChatOpen = ref.read(isChatScreenOpenProvider);
    debugPrint(
      'Sending reply. App in background: $_isAppInBackground, state: $_appLifecycleState, chat open: $isChatOpen',
    );
    if (_isAppInBackground && !isChatOpen) {
      final notificationService = ref.read(pushNotificationServiceProvider);
      notificationService.showChatMessageNotification(
        senderName: 'Алексей Смирнов',
        message: replyText,
      );
      debugPrint('Notification sent!');
    }
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

    buffer.writeln('📦 **Информация о треке**');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('🔢 Номер: ${track.code}');
    buffer.writeln('📊 Статус: ${track.status}');
    buffer.writeln('📅 Дата: ${dateFormat.format(track.date)}');

    if (track.comment != null) {
      buffer.writeln('💬 Комментарий: ${track.comment}');
    }

    if (track.group != null) {
      buffer.writeln('');
      buffer.writeln('📁 **Группа сборки:** ${track.groupId}');
      buffer.writeln('   • Категория: ${track.group!.category}');
      buffer.writeln('   • Упаковка: ${track.group!.packing.join(', ')}');
      if (track.group!.insurance) {
        buffer.writeln(
          '   • Страховка: ${track.group!.insuranceAmount?.toStringAsFixed(0)} ₽',
        );
      }
    }

    if (track.photoReportUrls.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('📸 Фото отчёт: ${track.photoReportUrls.length} фото');
    }

    if (track.photoTaskStatus != null) {
      buffer.writeln('📷 Запрос фото: ${track.photoTaskStatus!.label}');
    }

    _handleMessageSend(buffer.toString());
  }

  void _sendInvoiceInfo(InvoiceItem invoice) {
    final dateFormat = DateFormat('dd.MM.yyyy');
    final buffer = StringBuffer();

    buffer.writeln('🧾 **Информация о счёте**');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('🔢 Номер: ${invoice.invoiceNumber}');
    buffer.writeln('📊 Статус: ${invoice.status}');
    buffer.writeln('📅 Дата отправки: ${dateFormat.format(invoice.sendDate)}');
    buffer.writeln('');
    buffer.writeln('📦 **Параметры груза:**');
    buffer.writeln('   • Мест: ${invoice.placesCount}');
    buffer.writeln('   • Вес: ${invoice.weight.toStringAsFixed(1)} кг');
    buffer.writeln('   • Объём: ${invoice.volume.toStringAsFixed(2)} м³');
    buffer.writeln(
      '   • Плотность: ${invoice.density.toStringAsFixed(0)} кг/м³',
    );

    if (invoice.deliveryType != null) {
      buffer.writeln('   • Доставка: ${invoice.deliveryType}');
    }
    if (invoice.tariffType != null) {
      buffer.writeln('   • Тариф: ${invoice.tariffType}');
    }

    buffer.writeln('');
    buffer.writeln('💰 **Стоимость:**');
    if (invoice.tariffCost != null) {
      buffer.writeln('   • Тариф: \$${invoice.tariffCost!.toStringAsFixed(2)}');
    }
    if (invoice.insuranceCost != null) {
      buffer.writeln(
        '   • Страховка: \$${invoice.insuranceCost!.toStringAsFixed(2)}',
      );
    }
    if (invoice.packagingCost != null) {
      buffer.writeln(
        '   • Упаковка: \$${invoice.packagingCost!.toStringAsFixed(2)}',
      );
    }
    buffer.writeln(
      '   • **Итого:** ${invoice.totalCostRub.toStringAsFixed(0)} ₽',
    );

    if (invoice.scalePhotoUrls.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('📸 Фото: ${invoice.scalePhotoUrls.length} шт.');
    }

    _handleMessageSend(buffer.toString());
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;

    return Stack(
      children: [
        // Градиентный фон как на других страницах
        const Positioned.fill(child: AppBackground()),

        SafeArea(
          bottom: false,
          child: Column(
            children: [
              // Отступ сверху для навигации
              const SizedBox(height: 60),

              // Список сообщений
              Expanded(child: _buildMessagesList()),

              // Панель быстрых действий
              if (_showQuickActions) _buildQuickActionsBar(),

              // Поле ввода
              _buildInputField(bottomInset),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMessagesList() {
    final messages = _chatController.messages.toList();

    if (messages.isEmpty) {
      return _buildEmptyState();
    }

    // Сортируем по дате создания (старые сверху, новые снизу)
    messages.sort((a, b) {
      final aDate = a.createdAt ?? DateTime.now();
      final bDate = b.createdAt ?? DateTime.now();
      return aDate.compareTo(bDate);
    });

    // Используем ScrollController для автопрокрутки вниз
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        if (message is TextMessage) {
          return _buildMessageBubble(message);
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildMessageBubble(TextMessage message) {
    final isMe = message.authorId == _currentUserId;
    final dateFormat = DateFormat('HH:mm');

    // Имена для отображения
    final authorName = isMe ? 'Иванов Иван Иванович' : 'Алексей Смирнов';

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
                      colors: [Color(0xFFfe3301), Color(0xFFff5f02)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.support_agent_rounded,
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
                        ? const LinearGradient(
                            colors: [Color(0xFFfe3301), Color(0xFFff5f02)],
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
                      Text(
                        message.text,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.4,
                          color: isMe ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dateFormat.format(
                          message.createdAt?.toLocal() ?? DateTime.now(),
                        ),
                        style: TextStyle(
                          fontSize: 11,
                          color: isMe ? Colors.white70 : Colors.black45,
                        ),
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
                  child: const Icon(
                    Icons.person_rounded,
                    color: Color(0xFFfe3301),
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
                colors: [Color(0xFFfe3301), Color(0xFFff5f02)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.support_agent_rounded,
              color: Colors.white,
              size: 40,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Чат поддержки',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'Напишите нам и мы поможем решить любой вопрос',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.black54),
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
              label: 'Отправить трек',
              onTap: _showQuickSendSheet,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _QuickActionButton(
              icon: Icons.receipt_long_rounded,
              label: 'Отправить счёт',
              onTap: _showQuickSendSheet,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField(double bottomInset) {
    return Container(
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
        child: Row(
          children: [
            // Кнопка быстрых действий
            GestureDetector(
              onTap: _showQuickSendSheet,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFfe3301), Color(0xFFff5f02)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: 24,
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
                  decoration: const InputDecoration(
                    hintText: 'Введите ваше сообщение...',
                    hintStyle: TextStyle(color: Colors.black38, fontSize: 15),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  style: const TextStyle(fontSize: 15, color: Colors.black87),
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: _handleMessageSend,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Кнопка отправки
            GestureDetector(
              onTap: () => _handleMessageSend(_textController.text),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFfe3301), Color(0xFFff5f02)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
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
          color: const Color(0xFFFFF5F2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFfe3301).withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: const Color(0xFFfe3301)),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFFfe3301),
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
                const Text(
                  'Быстрая отправка',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  'Выберите трек или счёт для отправки в чат',
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
                  hintText: 'Поиск по номеру...',
                  hintStyle: TextStyle(color: Colors.grey[500]),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: Colors.grey,
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
                  colors: [Color(0xFFfe3301), Color(0xFFff5f02)],
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
              tabs: const [
                Tab(text: 'Треки'),
                Tab(text: 'Счета'),
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
    final tracksAsync = ref.watch(tracksListProvider(clientCode));

    return tracksAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: Color(0xFFfe3301)),
      ),
      error: (e, _) => Center(child: Text('Ошибка: $e')),
      data: (tracks) {
        final filtered = tracks
            .where(
              (t) =>
                  t.code.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                  t.status.toLowerCase().contains(_searchQuery.toLowerCase()),
            )
            .toList();

        if (filtered.isEmpty) {
          return const Center(
            child: Text(
              'Треки не найдены',
              style: TextStyle(color: Colors.grey),
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
        child: CircularProgressIndicator(color: Color(0xFFfe3301)),
      ),
      error: (e, _) => Center(child: Text('Ошибка: $e')),
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
          return const Center(
            child: Text(
              'Счета не найдены',
              style: TextStyle(color: Colors.grey),
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
                color: const Color(0xFFFFF5F2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.local_shipping_rounded,
                color: Color(0xFFfe3301),
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
                  colors: [Color(0xFFfe3301), Color(0xFFff5f02)],
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
                color: const Color(0xFFFFF5F2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.receipt_long_rounded,
                color: Color(0xFFfe3301),
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
                    '${invoice.status} • ${dateFormat.format(invoice.sendDate)} • ${invoice.totalCostRub.toStringAsFixed(0)} ₽',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFfe3301), Color(0xFFff5f02)],
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
