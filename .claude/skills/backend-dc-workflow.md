---
name: backend-dc-workflow
description: Используй при работе с бэкендом 2a-logistic (Next.js на удалённом сервере). Триггеры — API, endpoint, route, backend, Next.js, middleware, эндпоинт, 188.124.54.40, pm2, nginx, сервер.
---

# Backend (Next.js) через Desktop Commander

## Ключевое

Бэкенд живёт на сервере `administrator@188.124.54.40`, путь `~/web/2alogistic.2a-marketing.ru/public_html/backend`.

**Весь доступ — через wrapper `ssh-2a-backend`**, не через прямой `ssh`.

Wrapper:
- Автоматически логирует каждую команду в `~/Library/Logs/2a-logistic/backend-commands.log`
- Использует настроенный SSH-ключ
- Подставляет правильный хост

## Использование через Desktop Commander

В Cowork вызываешь tool `start_process` или `execute_command`:

```
start_process({command: "ssh-2a-backend 'ls -la ~/web/...'"})
```

Для команд которые выдают много вывода — добавь `--nostream` или `tail`:

```
start_process({command: "ssh-2a-backend 'pm2 logs backend --lines 50 --nostream'"})
```

## Типовой workflow добавления эндпоинта

### Шаг 1. Разведка
```
start_process({command: "ssh-2a-backend 'ls ~/web/.../backend/app/api'"})
```
Посмотри существующую структуру эндпоинтов.

### Шаг 2. Прочитать похожий эндпоинт
```
start_process({command: "ssh-2a-backend 'cat ~/web/.../backend/app/api/orders/route.ts'"})
```
Понять стиль, паттерны, импорты.

### Шаг 3. Предложить план пользователю
```
Планирую создать:
- Файл: app/api/orders/[id]/status/route.ts
- Методы: GET (получить статус), PATCH (обновить)
- Валидация: через zod
- Аутентификация: middleware уже стоит

Продолжить?
```

Дождись "да".

### Шаг 4. Создать файл через heredoc
```
start_process({command: "ssh-2a-backend \"cat > ~/web/.../backend/app/api/orders/[id]/status/route.ts <<'ENDOFFILE'
import { NextRequest, NextResponse } from 'next/server';
...
ENDOFFILE\""})
```

**Важно:** используй маркер `ENDOFFILE` или другой уникальный, а не `EOF` — если в контенте есть `EOF`, команда сломается.

### Шаг 5. Перестроить и проверить
```
start_process({command: "ssh-2a-backend 'cd ~/web/.../backend && npm run build'"})
```

Если сборка ок — restart:
```
start_process({command: "ssh-2a-backend 'pm2 restart backend'"})
```

### Шаг 6. Проверка
```
start_process({command: "ssh-2a-backend 'pm2 logs backend --lines 20 --nostream'"})
```

Проверь, что нет ошибок и эндпоинт отвечает:
```
start_process({command: "curl -s https://2alogistic.2a-marketing.ru/api/orders/test/status"})
```

## Типовой workflow fix'а бага

### Шаг 1. Повторить баг
```
start_process({command: "ssh-2a-backend 'pm2 logs backend --lines 100 --nostream | grep -i error | tail -30'"})
```

### Шаг 2. Найти код
```
start_process({command: "ssh-2a-backend 'grep -rn \"<keyword>\" ~/web/.../backend/app/api/'"})
```

### Шаг 3. Прочитать подозрительный файл
```
start_process({command: "ssh-2a-backend 'cat ~/web/.../backend/app/api/path/route.ts'"})
```

### Шаг 4. Показать пользователю что меняешь
Покажи diff текстом: старый код → новый код. Дождись "да".

### Шаг 5. Применить через heredoc
```
start_process({command: "ssh-2a-backend \"cat > file <<'ENDOFFILE' ... ENDOFFILE\""})
```

### Шаг 6. Restart + проверить
```
start_process({command: "ssh-2a-backend 'pm2 restart backend && sleep 2 && pm2 logs backend --lines 20 --nostream'"})
```

## Шаблоны полезных команд

### Бэкапы перед опасными операциями
```
ssh-2a-backend "tar -czf ~/backups/backend-$(date +%Y%m%d-%H%M%S).tgz ~/web/.../backend/app ~/web/.../backend/lib"
```

### Проверка ресурсов сервера
```
ssh-2a-backend "df -h && echo --- && free -m && echo --- && pm2 status"
```

### Git-операции
```
ssh-2a-backend "cd ~/web/.../backend && git status"
ssh-2a-backend "cd ~/web/.../backend && git log --oneline -10"
ssh-2a-backend "cd ~/web/.../backend && git diff HEAD"
```

### Очистка кешей Next.js (если сборка странная)
```
ssh-2a-backend "cd ~/web/.../backend && rm -rf .next && npm run build"
```
⚠️ Предупреди пользователя: сборка займёт несколько минут, сервис будет недоступен.

## Чего избегать

- Прямой `ssh administrator@...` — не логируется, аудит ломается
- `rm -rf` без предварительного `ls` для проверки
- `npm install` без явного согласия пользователя (может упасть production)
- `sudo` без явного согласия
- Применять изменения без показа diff пользователю
- Использовать `EOF` как маркер heredoc, если в контенте файла может быть `EOF`

## Если что-то пошло не так

**Сервис не отвечает после restart:**
```
ssh-2a-backend "pm2 logs backend --lines 200 --nostream | tail -50"
ssh-2a-backend "pm2 describe backend"
```

Если нужно откатиться — через git:
```
ssh-2a-backend "cd ~/web/.../backend && git log --oneline -5"
ssh-2a-backend "cd ~/web/.../backend && git checkout <hash> -- <file>"
ssh-2a-backend "pm2 restart backend"
```

**SSH не отвечает:**
Wrapper вернёт таймаут. Проверь локально:
```
start_process({command: "ssh -o ConnectTimeout=5 administrator@188.124.54.40 'echo test'"})
```

Если нет ответа — возможно сервер недоступен, пользователю надо проверить извне.

## Аудит

Все команды, которые ушли на бэкенд через wrapper, лежат в:
```
~/Library/Logs/2a-logistic/backend-commands.log
```

Можно посмотреть последние 50 в любой момент:
```
start_process({command: "tail -50 ~/Library/Logs/2a-logistic/backend-commands.log"})
```
