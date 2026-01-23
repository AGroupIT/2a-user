# 2A Logistic - User Application

Flutter приложение для клиентов логистической компании 2A Logistic.

## Возможности

- Отслеживание посылок в реальном времени
- Чат с поддержкой через WebSocket
- Push-уведомления о статусах
- Управление накладными и сборками
- Интеграция с Sentry для error tracking

## Технологический стек

- **Flutter** 3.38.6
- **Riverpod** - State management
- **Dio** - HTTP client
- **Socket.IO** - Real-time WebSocket communication
- **Sentry** - Error tracking and monitoring
- **2a-shared** - Shared models package

## Начало работы

### Требования

- Flutter SDK 3.38.6+
- Dart SDK
- Android Studio / VS Code
- Xcode (для iOS)

### Установка

```bash
# Клонировать репозиторий
git clone <repository-url>
cd 2a-user

# Установить зависимости
flutter pub get

# Запустить приложение
flutter run
```

## Development

### Запуск тестов

```bash
# Все тесты
flutter test

# С coverage
flutter test --coverage

# Coverage report
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

### Форматирование и анализ

```bash
# Форматирование
dart format .

# Статический анализ
flutter analyze
```

### Сборка

**Android:**
```bash
# Debug
flutter build apk --debug

# Release
flutter build apk --release --dart-define=SENTRY_DSN=your-dsn

# AAB для Google Play
flutter build appbundle --release --dart-define=SENTRY_DSN=your-dsn
```

**Web:**
```bash
flutter build web --release --dart-define=SENTRY_DSN=your-dsn
```

**iOS:**
```bash
flutter build ios --release --dart-define=SENTRY_DSN=your-dsn
```

## CI/CD

Проект использует GitHub Actions для автоматизации:

- **Tests & Lint** - Автоматические тесты при каждом push/PR
- **Build Android** - Сборка APK/AAB при создании тега
- **Deploy Web** - Автоматический деплой на FTP при push в main

Подробнее: [CI/CD Setup Guide](.github/CICD_SETUP.md)

### Quick Start

```bash
# Создать релиз
git tag v1.0.0
git push origin v1.0.0

# GitHub Actions автоматически соберет и опубликует релиз
```

## Структура проекта

```
lib/
├── src/
│   ├── app/                 # App configuration & routing
│   ├── core/                # Core utilities
│   │   ├── config/          # Configuration (Sentry, etc.)
│   │   ├── network/         # API client
│   │   └── services/        # Services (Push, WebSocket, etc.)
│   └── features/            # Feature modules
│       ├── auth/            # Authentication
│       ├── support/         # Support chat
│       ├── payment_chat/    # Payment chat
│       ├── tracks/          # Package tracking
│       ├── invoices/        # Invoices management
│       └── profile/         # User profile
test/
├── core/                    # Core tests
├── features/                # Feature tests
└── helpers/                 # Test helpers
.github/
└── workflows/               # CI/CD workflows
```

## Архитектурные решения

### State Management
Используется **Riverpod** для управления состоянием с паттерном Provider + Notifier.

### Networking
- **Dio** для HTTP запросов
- **Socket.IO** для real-time коммуникации
- Автоматический retry и error handling
- Sentry interceptor для отслеживания ошибок

### Error Tracking
- **Sentry** интегрирован для production error tracking
- Автоматический захват HTTP ошибок (5xx)
- Фильтрация чувствительных данных
- Breadcrumbs для контекста ошибок

### Testing
- **79+ unit tests** с coverage >70%
- Mock-based testing с mocktail
- Автоматический запуск в CI/CD

## Environment Variables

```bash
# Sentry DSN (опционально)
--dart-define=SENTRY_DSN=https://your-dsn@sentry.io/project
```

## Связанные проекты

- **2a-shared** - Общие модели данных
- **2a-admin** - Админская панель
- **Backend** - Next.js API сервер

## Troubleshooting

### Ошибки сборки
```bash
# Очистить build
flutter clean
flutter pub get

# Пересобрать
flutter build apk
```

### Проблемы с зависимостями
```bash
# Обновить зависимости
flutter pub upgrade

# Проверить конфликты
flutter pub deps
```

### WebSocket не подключается
- Проверить URL бэкенда в ApiConfig
- Убедиться что бэкенд запущен
- Проверить CORS настройки

## Лицензия

Proprietary - 2A Logistic © 2024

## Контакты

- Website: https://2alogistic.2a-marketing.ru
- Support: support@2alogistic.ru
