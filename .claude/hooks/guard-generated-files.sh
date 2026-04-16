#!/bin/bash
# =============================================================
# PreToolUse hook: блокирует редактирование генерируемых Flutter-файлов
# =============================================================

INPUT=$(cat)

# Извлекаем путь к файлу, который Claude собирается редактировать
FILE_PATH=$(echo "$INPUT" | grep -o '"file_path":[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/')

if [[ -z "$FILE_PATH" ]]; then
  exit 0
fi

# Проверяем паттерны генерируемых файлов
if echo "$FILE_PATH" | grep -qE '\.(g|freezed|mocks|config)\.dart$'; then
  cat <<EOF >&2
🚫 Попытка отредактировать генерируемый файл:
   $FILE_PATH

Эти файлы создаются через build_runner / freezed / mockito.
Исходник — это соответствующий файл БЕЗ суффикса .g/.freezed/.mocks.

Отредактируй исходный файл, затем запусти:
   flutter pub run build_runner build --delete-conflicting-outputs
EOF
  exit 2  # блокируем
fi

# Проверяем путь на build/ и .dart_tool/
if echo "$FILE_PATH" | grep -qE '(^|/)(build|\.dart_tool|\.flutter-plugins|android/\.gradle|ios/Pods)/'; then
  cat <<EOF >&2
🚫 Попытка отредактировать файл в build/кеш-директории:
   $FILE_PATH

Эти директории регенерируются автоматически. Редактировать их нет смысла.
EOF
  exit 2
fi

exit 0
