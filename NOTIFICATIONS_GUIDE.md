# 📱 Руководство по Push-Уведомлениям в 2A Logistic

## Обзор Системы

Система push-уведомлений в 2A Logistic обеспечивает мгновенную доставку уведомлений клиентам и администраторам на всех поддерживаемых платформах.

### Поддерживаемые Платформы

- ✅ **iOS** - через Apple Push Notification Service (APNs) via Firebase
- ✅ **Android** - через Firebase Cloud Messaging (FCM)
- ✅ **Web** - через Web Push API + Service Workers
- ✅ **macOS** - через flutter_local_notifications
- ✅ **Windows** - через flutter_local_notifications

---

## Архитектура

```
┌─────────────────┐
│  2a-user        │  (Клиентское приложение)
│  FCM Project:   │
│  a-user         │
│  ID: 949693718080│
└─────────────────┘
        ↓
┌─────────────────┐
│  Firebase       │
│  Cloud          │
│  Messaging      │
└─────────────────┘
        ↓
┌─────────────────┐
│  Next.js        │
│  Backend        │
│  (notifications.│
│   ts)           │
└─────────────────┘
        ↓
┌─────────────────┐
│  PostgreSQL     │
│  (Prisma)       │
│  - Notification │
│  - DeviceToken  │
│  - PushDelivery │
└─────────────────┘
```

---

## Типы Уведомлений для Клиентов

### 1. Треки (Track Notifications)

#### 1.1 Новый трек создан
```typescript
NotificationTypes.TRACK_CREATED = 'track_created'
```
**Когда:** Трек-номер привязан к коду клиента
**Пример:** "📦 Новый трек добавлен - Трек-номер ABC123 привязан к вашему коду"

#### 1.2 Статус трека изменен
```typescript
NotificationTypes.TRACK_STATUS_CHANGED = 'track_status_changed'
```
**Когда:** Статус трека изменился (на складе, отправлен, доставлен и т.д.)
**Пример:** "📦 Статус трека изменён - Трек ABC123 изменил статус на 'На складе'"

#### 1.3 Трек прибыл на склад
```typescript
NotificationTypes.TRACK_ARRIVED_WAREHOUSE = 'track_arrived_warehouse'
```
**Пример:** "📦 Трек прибыл на склад - ABC123"

#### 1.4 Трек отправлен
```typescript
NotificationTypes.TRACK_SHIPPED = 'track_shipped'
```
**Пример:** "📦 Трек отправлен - ABC123"

#### 1.5 Трек доставлен
```typescript
NotificationTypes.TRACK_DELIVERED = 'track_delivered'
```
**Пример:** "📦 Трек доставлен - ABC123"

### 2. Фотоотчеты (Photo Reports)

#### 2.1 Фотоотчет готов
```typescript
NotificationTypes.PHOTO_REQUEST_COMPLETED = 'photo_request_completed'
```
**Когда:** Сотрудник загрузил фотографии
**Пример:** "📸 Фотоотчёт готов - Фотоотчёт для трека ABC123 готов"

### 3. Вопросы (Questions)

#### 3.1 Ответ на вопрос получен
```typescript
NotificationTypes.QUESTION_ANSWERED = 'question_answered'
```
**Когда:** Сотрудник ответил на вопрос клиента
**Пример:** "💬 Ответ на вопрос - Получен ответ на ваш вопрос по треку ABC123"

### 4. Счета (Invoices)

#### 4.1 Новый счет создан
```typescript
NotificationTypes.INVOICE_CREATED = 'invoice_created'
```
**Пример:** "💵 Новый счет - Счет #INV-2025-0001 на сумму 15000₽"

#### 4.2 Счет оплачен
```typescript
NotificationTypes.INVOICE_PAID = 'invoice_paid'
```
**Пример:** "✅ Счет оплачен - Счет #INV-2025-0001 оплачен"

#### 4.3 Статус счета изменен
```typescript
NotificationTypes.INVOICE_STATUS_CHANGED = 'invoice_status_changed'
```
**Пример:** "💵 Статус счета изменён - Счет #INV-2025-0001"

### 5. Чаты (Chat Messages)

#### 5.1 Новое сообщение от поддержки
```typescript
NotificationTypes.CHAT_MESSAGE = 'chat_message'
```
**Когда:** Сотрудник отправил сообщение в чат поддержки
**Пример:** "💬 Новое сообщение от поддержки - Ответ на ваш запрос..."
**Особенность:** Не отправляется если клиент находится в открытом чате (chat presence detection)

#### 5.2 Новое сообщение по оплате
```typescript
NotificationTypes.PAYMENT_CHAT_MESSAGE = 'payment_chat_message'
```
**Когда:** Бухгалтер отправил сообщение в чат по оплате
**Пример:** "💰 Новое сообщение по оплате - Подтверждение платежа..."

### 6. Новости (News)

#### 6.1 Новая новость
```typescript
NotificationTypes.NEWS_CREATED = 'news_created'
```
**Когда:** Администратор опубликовал новую новость
**Пример:** "📰 Новая новость - Изменение тарифов с 1 февраля"

### 7. Правила сервиса (Service Rules)

#### 7.1 Новые правила
```typescript
NotificationTypes.SERVICE_RULE_CREATED = 'service_rule_created'
```
**Когда:** Администратор опубликовал новые правила оказания услуг
**Пример:** "📋 Новые правила - Обновлены правила оказания услуг"

---

## Типы Уведомлений для Администраторов

### 1. Чаты от Клиентов

#### 1.1 Новое сообщение в support chat
```typescript
type: 'chat_message'
```
**Когда:** Клиент отправил сообщение в чат поддержки
**Пример:** "💬 Сообщение от Иван Петров - Когда прибудет мой трек?"
**Фильтр:** Только сотрудники того же agentId что и клиент

#### 1.2 Новое сообщение в payment chat
```typescript
type: 'payment_chat_message'
```
**Когда:** Клиент отправил сообщение в чат по оплате
**Пример:** "💰 Сообщение по оплате от Иван Петров - Оплатил счет..."

### 2. Запросы Фото

```typescript
NotificationTypes.PHOTO_REQUEST_CREATED = 'photo_request_created'
```
**Когда:** Клиент создал новый запрос фотоотчета
**Пример:** "📸 Запрос фотоотчёта - Иван Петров запросил фотоотчёт для трека ABC123"
**Кому:** Всем активным сотрудникам агента

### 3. Вопросы по Трекам

```typescript
NotificationTypes.QUESTION_CREATED = 'question_created'
```
**Когда:** Клиент задал вопрос по треку
**Пример:** "💬 Новый вопрос - Иван Петров задал вопрос по треку ABC123"
**Кому:** Всем активным сотрудникам агента

### 4. Сборки (Assemblies)

#### 4.1 Новая сборка создана клиентом
```typescript
NotificationTypes.ASSEMBLY_CREATED = 'assembly_created'
```
**Когда:** Клиент создал новую сборку
**Пример:** "📦 Новая сборка от клиента - Иван Петров создал сборку SB-2025-0001 (3 трека)"
**Кому:** Всем активным сотрудникам агента

#### 4.2 Трек добавлен в сборку
```typescript
NotificationTypes.TRACK_ADDED_TO_ASSEMBLY = 'track_added_to_assembly'
```
**Когда:** Клиент добавил трек в существующую сборку
**Пример:** "📦 Трек добавлен в сборку - Трек ABC123 добавлен в сборку SB-2025-0001"
**Кому:** Всем активным сотрудникам агента

---

## Настройка Платформ

### iOS

**Требования:**
- Xcode 14+
- Apple Developer Account с Push Notification capability
- APNs Auth Key загружен в Firebase Console

**Файлы конфигурации:**
- `ios/Runner/GoogleService-Info.plist` - Firebase config
- `firebase_options.dart` - Firebase options для iOS

**Permissions:** Запрашиваются автоматически при первом запуске

### Android

**Требования:**
- Android SDK 21+ (Lollipop)
- Firebase Cloud Messaging включен

**Файлы конфигурации:**
- `android/app/google-services.json` - Firebase config
- `firebase_options.dart` - Firebase options для Android

**Notification Channels:**
- `track_status_channel` - Статусы треков
- `assembly_status_channel` - Статусы сборок
- `photo_report_channel` - Фотоотчёты
- `question_channel` - Ответы на вопросы
- `chat_channel` - Чат поддержки
- `payment_chat_channel` - Чат по оплате
- `news_channel` - Новости
- `service_rules_channel` - Правила оказания услуг
- `invoice_channel` - Счета

### Web

**Требования:**
- HTTPS (обязательно для Service Workers)
- VAPID Key для Web Push

**Service Worker:** `/web/firebase-messaging-sw.js`

**Регистрация:** Автоматическая в `/web/index.html`

**VAPID Key:**
```
BN84z0kGwWRFRalLMJ-HlMPVYBp5Tu7QnsGiACoT-ODg7VkwtFV_kdDhFHapsr5BguDgeBs0E6Pe2aY2_0fMshQ
```

**Браузеры:**
- ✅ Chrome 50+
- ✅ Firefox 44+
- ✅ Safari 16+ (macOS Ventura+)
- ✅ Edge 79+

### macOS

**Требования:**
- macOS 10.14+
- App Sandbox capability для уведомлений

**Permissions:** Запрашиваются через `flutter_local_notifications`

### Windows

**Требования:**
- Windows 10+
- Windows Toast Notifications

**Плагин:** `flutter_local_notifications` v19.5.0+

---

## Код Интеграции

### Инициализация в main.dart

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Инициализировать Firebase (включая FCM)
  await PushNotificationService.initializeFirebase();

  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const App(),
    ),
  );
}
```

### Инициализация в App Widget

```dart
class _AppState extends ConsumerState<App> {
  @override
  void initState() {
    super.initState();
    _initializePushNotifications();
  }

  Future<void> _initializePushNotifications() async {
    final pushService = ref.read(pushNotificationServiceProvider);

    // Инициализировать локальные уведомления
    await pushService.initialize(
      onTap: (route) {
        if (route != null) {
          // Navigate to route
          router.go(route);
        }
      },
    );

    // Получить FCM токен
    final token = await PushNotificationService.getFCMToken();
    if (token != null) {
      debugPrint('FCM Token: $token');
      // Отправить токен на сервер
      await _registerDeviceToken(token);
    }

    // Установить callback для обработки сообщений
    PushNotificationService.onFCMMessageReceived = (message) {
      // Обработать FCM сообщение
      _handleFCMMessage(message);
    };
  }
}
```

### Регистрация Device Token на Сервере

```dart
Future<void> _registerDeviceToken(String token) async {
  final apiClient = ref.read(apiClientProvider);

  await apiClient.post('/device-tokens', data: {
    'token': token,
    'platform': _getPlatformName(),
    'deviceName': await _getDeviceName(),
    'appVersion': await _getAppVersion(),
  });
}

String _getPlatformName() {
  if (kIsWeb) return 'web';
  if (Platform.isAndroid) return 'android';
  if (Platform.isIOS) return 'ios';
  if (Platform.isMacOS) return 'macos';
  if (Platform.isWindows) return 'windows';
  if (Platform.isLinux) return 'linux';
  return 'unknown';
}
```

### Показ Локального Уведомления

```dart
// Автоматически из FCM
PushNotificationService.onFCMMessageReceived = (message) {
  // Уведомление будет показано автоматически
};

// Вручную из NotificationItem
final notificationService = ref.read(pushNotificationServiceProvider);
await notificationService.showNotification(notificationItem);
```

---

## Backend API

### Отправка Уведомления Клиенту

```typescript
import { createClientNotification } from '@/lib/notifications';

// В API endpoint после изменения статуса трека
await createClientNotification(
  clientId,
  'track_status_changed',
  '📦 Статус трека изменён',
  `Трек ${trackNumber} изменил статус на "${newStatus}"`,
  {
    trackId: track.id.toString(),
    trackNumber: track.trackNumber,
    status: newStatus,
  }
);
```

### Отправка Уведомления Всем Сотрудникам Агента

```typescript
import { createAllEmployeesNotification } from '@/lib/notifications';

// В API endpoint после создания запроса фото
await createAllEmployeesNotification(
  agentId,
  'photo_request_created',
  '📸 Запрос фотоотчёта',
  `${clientName} запросил фотоотчёт для трека ${trackNumber}`,
  {
    photoRequestId: photoRequest.id.toString(),
    trackId: track.id.toString(),
    clientId: client.id.toString(),
  }
);
```

### Chat Presence Detection

Система автоматически не отправляет push-уведомления, если пользователь находится в активном чате:

```typescript
import { isClientInChat } from '@/lib/chat-presence';

// Проверить перед отправкой
const isInChat = await isClientInChat(clientId);
if (isInChat) {
  console.log('Skipping push - client is in active chat');
  return { success: true, pushSkipped: true };
}
```

---

## Database Schema

### Notification Table
```prisma
model Notification {
  id            Int      @id @default(autoincrement())
  agentId       Int?
  recipientType ChatParticipantType  // client | employee
  recipientId   Int
  type          String   // track_created, invoice_paid, etc.
  title         String
  body          String
  data          Json?    // Additional data for handling
  isRead        Boolean  @default(false)
  isPushed      Boolean  @default(false)  // Track if push was sent
  createdAt     DateTime @default(now())
  readAt        DateTime?

  pushDeliveries PushDelivery[]
}
```

### DeviceToken Table
```prisma
model DeviceToken {
  id                    Int      @id @default(autoincrement())
  ownerType             ChatParticipantType  // client | employee
  ownerId               Int
  platform              DevicePlatform  // ios, android, web, macos, windows, linux
  token                 String   // FCM/APNs/Web Push token
  deviceId              String?  // For deduplication
  deviceName            String?  // "iPhone 15", "Chrome Windows"
  notificationsEnabled  Boolean  @default(true)
  isActive              Boolean  @default(true)
  lastActiveAt          DateTime?

  // Web Push specific fields
  endpoint              String?  // Web Push endpoint URL
  p256dh                String?  // Web Push public key
  auth                  String?  // Web Push auth secret

  @@unique([ownerType, ownerId, token])
}
```

### PushDelivery Table
```prisma
model PushDelivery {
  id               Int      @id @default(autoincrement())
  notificationId   Int
  deviceTokenId    Int
  status           PushStatus  // pending, sent, delivered, failed
  errorMessage     String?
  createdAt        DateTime @default(now())
  sentAt           DateTime?
  deliveredAt      DateTime?

  notification     Notification @relation(fields: [notificationId], references: [id])
  deviceToken      DeviceToken  @relation(fields: [deviceTokenId], references: [id])

  @@unique([notificationId, deviceTokenId])
}
```

---

## Отладка

### Проверка FCM Token

```dart
final token = await PushNotificationService.getFCMToken();
debugPrint('FCM Token: $token');
```

### Тест Локального Уведомления

```dart
final pushService = ref.read(pushNotificationServiceProvider);

await pushService.showChatMessageNotification(
  senderName: 'Тест',
  message: 'Тестовое уведомление',
);
```

### Проверка Service Worker (Web)

1. Открыть DevTools (F12)
2. Перейти в Application → Service Workers
3. Проверить что `firebase-messaging-sw.js` зарегистрирован
4. Перейти в Console
5. Должен быть лог: "Firebase Messaging SW registered: ..."

### Логи Backend

```bash
# Посмотреть логи уведомлений
grep "notification" /var/log/app.log

# Проверить FCM отправку
grep "FCM" /var/log/app.log
```

---

## Troubleshooting

### iOS: Уведомления не приходят

1. Проверить что Push Notifications capability включен в Xcode
2. Проверить что APNs Auth Key загружен в Firebase Console
3. Проверить Bundle ID совпадает
4. Проверить что app запущен на реальном устройстве (не simulator)

### Android: Уведомления не показываются

1. Проверить что `google-services.json` актуален
2. Проверить notification permissions включены в настройках приложения
3. Проверить что battery optimization не блокирует уведомления

### Web: Service Worker не регистрируется

1. Проверить что сайт работает по HTTPS
2. Проверить путь к service worker файлу
3. Проверить Console для ошибок регистрации
4. Hard refresh страницы (Ctrl+Shift+R)

### macOS: Уведомления не работают

1. Проверить Notification permissions в System Settings
2. Проверить что App Sandbox включен
3. Перезапустить приложение

### Token не отправляется на сервер

1. Проверить сетевое подключение
2. Проверить авторизацию (token должен быть валидным)
3. Проверить endpoint `/device-tokens` работает
4. Проверить логи сервера

---

## Лучшие Практики

### 1. Не спамить уведомлениями

- Группировать похожие уведомления
- Использовать один notification ID для обновлений
- Уважать часовые пояса пользователей

### 2. Персонализировать контент

- Использовать имя клиента/сотрудника
- Указывать конкретные треки/счета
- Добавлять контекст (например, статус)

### 3. Обрабатывать ошибки

- Деактивировать невалидные токены
- Повторять отправку при временных ошибках
- Логировать все ошибки

### 4. Тестировать на всех платформах

- iOS и Android регулярно
- Web в разных браузерах
- Desktop на Windows и macOS

### 5. Мониторить метрики

- Delivery rate (% доставленных)
- Open rate (% открытых)
- Token expiration rate
- Error rate по платформам

---

## Метрики и Аналитика

### Отслеживаемые События

1. **Token Registration** - когда устройство регистрирует FCM токен
2. **Notification Created** - когда уведомление создано в БД
3. **Notification Sent** - когда push отправлен через FCM
4. **Notification Delivered** - когда FCM подтвердил доставку
5. **Notification Opened** - когда пользователь открыл уведомление
6. **Notification Failed** - когда отправка не удалась

### Dashboard Метрики

```sql
-- Delivery Rate за последние 7 дней
SELECT
  DATE(created_at) as date,
  COUNT(*) as total,
  SUM(CASE WHEN status = 'delivered' THEN 1 ELSE 0 END) as delivered,
  ROUND(100.0 * SUM(CASE WHEN status = 'delivered' THEN 1 ELSE 0 END) / COUNT(*), 2) as delivery_rate
FROM push_delivery
WHERE created_at >= NOW() - INTERVAL '7 days'
GROUP BY DATE(created_at)
ORDER BY date DESC;
```

---

## Обновление Токенов

### Автоматическое Обновление

FCM токены автоматически обновляются Firebase SDK. При получении нового токена:

```dart
FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
  debugPrint('FCM Token refreshed: $newToken');
  // Отправить новый токен на сервер
  _registerDeviceToken(newToken);
});
```

### Деактивация Старых Токенов

Backend автоматически деактивирует токены при ошибках:

```typescript
// В notifications.ts
if (response.failureCount > 0) {
  for (const error of response.responses) {
    if (error.error?.code === 'messaging/invalid-registration-token') {
      // Деактивировать токен
      await prisma.deviceToken.update({
        where: { token: invalidToken },
        data: { isActive: false },
      });
    }
  }
}
```

---

## Контакты Поддержки

При проблемах с уведомлениями:
- Проверить эту документацию
- Проверить логи приложения
- Проверить логи сервера
- Создать issue в репозитории проекта

---

**Версия документа:** 1.0
**Последнее обновление:** 21 января 2026
**Автор:** Claude Sonnet 4.5 + Команда 2A Logistic
