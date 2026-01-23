# Testing Guide для 2A Logistic User App

## Структура тестов

```
test/
├── helpers/               # Helper файлы для тестов
│   ├── pump_app.dart     # Extension для упрощенного тестирования виджетов
│   └── mock_data.dart    # Mock данные для тестов
├── core/                  # Тесты для core слоя
│   ├── network/          # Тесты для сетевого слоя
│   └── services/         # Тесты для сервисов
├── features/             # Тесты для features
│   ├── auth/            # Тесты авторизации
│   ├── support/         # Тесты чата поддержки
│   └── ...
└── widget_test.dart      # Базовый smoke test
```

## Типы тестов

### Unit Tests
Тестирование отдельных функций, методов и классов в изоляции.

**Примеры:**
- Тесты моделей данных
- Тесты бизнес-логики провайдеров
- Тесты утилитных функций

**Запуск:**
```bash
flutter test test/core/
flutter test test/features/auth/data/
```

### Widget Tests
Тестирование отдельных виджетов и их взаимодействия.

**Примеры:**
- Тесты UI компонентов
- Тесты экранов
- Тесты взаимодействия с пользователем

**Запуск:**
```bash
flutter test test/features/auth/presentation/
```

### Integration Tests
Тестирование полных сценариев использования приложения.

**Примеры:**
- Полный flow авторизации
- Отправка сообщения в чат
- Просмотр треков и оплата

**Запуск:**
```bash
flutter test integration_test/
```

## Запуск тестов

### Все тесты
```bash
flutter test
```

### С coverage
```bash
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

### Конкретный файл
```bash
flutter test test/features/support/data/chat_provider_test.dart
```

### Конкретный test case
```bash
flutter test test/features/support/data/chat_provider_test.dart --name "loadConversation"
```

## Best Practices

1. **Используйте helper файлы**
   - `pump_app.dart` для инициализации виджетов с провайдерами
   - `mock_data.dart` для создания тестовых данных

2. **Именование тестов**
   - Файл: `{class_name}_test.dart`
   - Группа: `group('{ClassName}', () {...})`
   - Тест: `test('should do something when condition', () {...})`

3. **Структура теста (AAA pattern)**
   ```dart
   test('description', () {
     // Arrange - подготовка данных
     final input = MockData.createMockMessage();

     // Act - выполнение действия
     final result = processMessage(input);

     // Assert - проверка результата
     expect(result.isRead, true);
   });
   ```

4. **Используйте mocktail для моков**
   ```dart
   class MockChatRepository extends Mock implements ChatRepository {}

   test('example', () {
     final mockRepo = MockChatRepository();
     when(() => mockRepo.getMessages()).thenAnswer((_) async => []);
   });
   ```

5. **Проверяйте coverage**
   - Цель: минимум 70% покрытия
   - Приоритет: core логика, провайдеры, критичные features

## Зависимости

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  mockito: ^5.4.4
  build_runner: ^2.4.13
  mocktail: ^1.0.4
```

## CI/CD Integration

Тесты автоматически запускаются в GitHub Actions при каждом PR:
- Unit tests
- Widget tests
- Coverage check (минимум 70%)

См. `.github/workflows/test.yml` для деталей.
