# CI/CD Setup Guide

Эта документация описывает настройку и использование GitHub Actions для автоматизации тестирования, сборки и деплоя приложения 2a-user.

## Обзор Workflows

### 1. Tests & Lint (`test.yml`)
Автоматически запускается при push и pull request в ветки `main` и `develop`.

**Что делает:**
- Проверяет форматирование кода
- Запускает статический анализ (flutter analyze)
- Выполняет все unit тесты
- Генерирует coverage report
- Проверяет минимальный порог покрытия (70%)
- Загружает отчет в Codecov

**Как использовать:**
```bash
# Локально перед коммитом
dart format .
flutter analyze
flutter test --coverage
```

### 2. Build Android (`build-android.yml`)
Запускается при создании тега версии или вручную через workflow_dispatch.

**Что делает:**
- Запускает тесты
- Собирает APK и AAB файлы
- Подписывает релизы (если настроен keystore)
- Загружает артефакты
- Создает GitHub Release (для тегов)

**Как использовать:**

**Автоматическая сборка при релизе:**
```bash
git tag v1.0.0
git push origin v1.0.0
```

**Ручная сборка:**
1. Перейти в Actions → Build Android
2. Нажать "Run workflow"
3. Опционально указать SENTRY_DSN
4. Скачать APK/AAB из Artifacts

### 3. Deploy Web (`deploy-web.yml`)
Автоматически запускается при push в ветку `main` или вручную.

**Что делает:**
- Запускает тесты
- Собирает web версию
- Копирует firebase-messaging-sw.js
- Деплоит на FTP сервер
- Генерирует deployment summary

**Как использовать:**
```bash
# Автоматический деплой
git push origin main

# Результат будет доступен по адресу вашего FTP сервера
```

## Настройка GitHub Secrets

Для работы workflows необходимо настроить следующие secrets в репозитории:

### Обязательные для всех workflows:
- `SENTRY_DSN` - Sentry DSN для error tracking (опционально)

### Для Android сборки:
- `KEYSTORE_BASE64` - Base64-encoded keystore файл для подписи APK
- `KEYSTORE_PASSWORD` - Пароль keystore
- `KEY_PASSWORD` - Пароль ключа
- `KEY_ALIAS` - Alias ключа

### Для Web деплоя:
- `FTP_HOST` - FTP хост (например: ftp.example.com)
- `FTP_USER` - FTP пользователь
- `FTP_PASSWORD` - FTP пароль
- `FTP_SERVER_DIR` - Директория на сервере (по умолчанию: /home/administrator_cabinetapp/)

## Как настроить Secrets

1. Перейти в Settings репозитория
2. Выбрать Secrets and variables → Actions
3. Нажать "New repository secret"
4. Добавить каждый secret из списка выше

### Пример: создание KEYSTORE_BASE64

```bash
# Конвертировать keystore в base64
base64 -i upload-keystore.jks | pbcopy

# Вставить в GitHub Secret с именем KEYSTORE_BASE64
```

## Структура проекта

```
.github/
├── workflows/
│   ├── test.yml           # Тесты и линтинг
│   ├── build-android.yml  # Android сборка
│   └── deploy-web.yml     # Web деплой
└── CICD_SETUP.md          # Эта документация
```

## Workflow Triggers

### test.yml
- **Push** в `main` или `develop`
- **Pull Request** в `main` или `develop`

### build-android.yml
- **Tag** с префиксом `v*` (например: v1.0.0, v2.1.3)
- **Manual dispatch** (ручной запуск)

### deploy-web.yml
- **Push** в `main`
- **Manual dispatch** (ручной запуск)

## Проверка статуса workflows

1. Перейти в раздел **Actions** репозитория
2. Выбрать нужный workflow
3. Посмотреть статус выполнения
4. Скачать artifacts (APK, coverage reports) если нужно

## Coverage Reports

Coverage reports генерируются автоматически при каждом запуске тестов:

- **Codecov**: Автоматически загружается (если настроен)
- **HTML Report**: Доступен в Artifacts → `coverage-report`

**Локальная генерация:**
```bash
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

## Troubleshooting

### Тесты падают в CI
```bash
# Проверить локально
flutter test

# Проверить coverage
flutter test --coverage
```

### Android сборка не подписывается
- Убедитесь что `KEYSTORE_BASE64` правильно закодирован
- Проверьте что все секреты настроены (KEYSTORE_PASSWORD, KEY_PASSWORD, KEY_ALIAS)
- Проверьте что файл `key.properties` создается корректно

### Web деплой не работает
- Убедитесь что FTP_HOST, FTP_USER, FTP_PASSWORD настроены
- Проверьте что FTP_SERVER_DIR существует на сервере
- Проверьте права доступа к директории на FTP

### Sentry не работает
- Убедитесь что SENTRY_DSN настроен в secrets
- Проверьте что DSN передается через --dart-define
- Sentry работает только в release builds

## Best Practices

1. **Всегда запускайте тесты локально** перед push
2. **Используйте feature branches** и создавайте pull requests
3. **Создавайте теги** только для релизных версий
4. **Проверяйте coverage** перед merge в main
5. **Используйте semantic versioning** для тегов (v1.0.0, v1.1.0, v2.0.0)

## Примеры использования

### Релиз новой версии

```bash
# 1. Убедиться что все тесты проходят
flutter test

# 2. Создать и запушить тег
git tag v1.0.0
git push origin v1.0.0

# 3. GitHub Actions автоматически:
#    - Запустит тесты
#    - Соберет APK и AAB
#    - Создаст GitHub Release
#    - Прикрепит файлы к релизу

# 4. Скачать файлы из GitHub Releases
```

### Hotfix в production

```bash
# 1. Создать hotfix branch
git checkout -b hotfix/critical-bug main

# 2. Исправить баг и закоммитить
git commit -am "fix: critical bug"

# 3. Запушить и создать PR
git push origin hotfix/critical-bug

# 4. GitHub Actions автоматически запустит тесты

# 5. После merge в main - создать новый тег
git tag v1.0.1
git push origin v1.0.1
```

### Тестирование перед релизом

```bash
# 1. Создать feature branch
git checkout -b feature/new-feature

# 2. Разработать фичу
# ... код ...

# 3. Запушить и создать PR в develop
git push origin feature/new-feature

# 4. GitHub Actions автоматически:
#    - Проверит форматирование
#    - Запустит анализ кода
#    - Выполнит все тесты
#    - Проверит coverage

# 5. После проверок - merge в develop
# 6. Тестировать в develop
# 7. Когда готово - merge develop в main
# 8. Создать release tag
```

## Monitoring

- **GitHub Actions**: Статус всех workflows
- **Codecov**: Code coverage trends
- **Sentry**: Production errors (если настроен)
- **GitHub Releases**: История релизов и downloads

## Полезные команды

```bash
# Проверить что workflows валидны
act -l  # Если установлен act для локального тестирования

# Запустить все проверки локально
flutter analyze && flutter test --coverage

# Сгенерировать coverage report
genhtml coverage/lcov.info -o coverage/html

# Создать релизный тег
git tag -a v1.0.0 -m "Release version 1.0.0"
git push origin v1.0.0

# Удалить тег (если ошиблись)
git tag -d v1.0.0
git push origin :refs/tags/v1.0.0
```

## Контакты

При возникновении проблем с CI/CD:
1. Проверьте раздел Troubleshooting
2. Посмотрите логи в GitHub Actions
3. Создайте issue в репозитории
