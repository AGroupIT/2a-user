#!/bin/bash
# =============================================================
# PreToolUse hook: блокирует git_commit, пока не выполнены проверки
# =============================================================
# Вызывается Claude Code перед тем, как он попытается сделать git commit.
# Если возвращает exit code != 0 — Claude видит сообщение и не коммитит.

# Читаем JSON input от Claude Code через stdin
INPUT=$(cat)

# Проверяем: команда действительно git commit?
COMMAND=$(echo "$INPUT" | grep -o '"command":[[:space:]]*"[^"]*"' | head -1)
if ! echo "$COMMAND" | grep -q "git commit"; then
  exit 0  # не git commit — пропускаем
fi

REPO=$(git rev-parse --show-toplevel 2>/dev/null)
if [[ -z "$REPO" ]]; then
  exit 0  # не в репо — пропускаем
fi

# 1. Есть ли индекс CRG?
if [[ ! -f "$REPO/.code-review-graph/graph.db" ]]; then
  cat <<EOF >&2
⚠️  Индекс code-review-graph не найден.
Запусти: code-review-graph build
И потом повтори коммит.
EOF
  exit 2  # блокируем commit
fi

# 2. Запускался ли detect_changes в этой сессии? Проверяем через маркер
MARKER="$HOME/.2a-logistic/last-detect-$(basename "$REPO").marker"
if [[ ! -f "$MARKER" ]] || [[ $(($(date +%s) - $(stat -f %m "$MARKER" 2>/dev/null || echo 0))) -gt 600 ]]; then
  cat <<EOF >&2
⚠️  За последние 10 минут не был запущен detect_changes.
Перед коммитом проверь: что меняется и какой blast radius.
Запусти: crg_detect_changes (или через MCP — tool "crg_detect_changes")
Если всё ок — создай маркер: touch "$MARKER"
EOF
  exit 2  # блокируем commit
fi

# Всё ок — пропускаем
exit 0
