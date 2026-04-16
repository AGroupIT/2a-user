#!/bin/bash
# =============================================================
# PostToolUse hook: ставит маркер после вызова detect_changes
# =============================================================
# Чтобы pre-commit-check знал, что detect_changes был недавно запущен.

INPUT=$(cat)

# Проверяем: использовался ли detect_changes?
TOOL=$(echo "$INPUT" | grep -o '"tool_name":[[:space:]]*"[^"]*"' | head -1)
if echo "$TOOL" | grep -qE "(detect_changes|crg_detect_changes|gitnexus_detect_changes)"; then
  REPO=$(git rev-parse --show-toplevel 2>/dev/null)
  if [[ -n "$REPO" ]]; then
    MARKER_DIR="$HOME/.2a-logistic"
    mkdir -p "$MARKER_DIR"
    touch "$MARKER_DIR/last-detect-$(basename "$REPO").marker"
  fi
fi

exit 0
