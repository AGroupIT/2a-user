# AGENTS.md — 2A-Logistic

Этот файл читают Cursor, Codex и другие AI-инструменты (Claude Code читает `CLAUDE.md`, но если его нет — AGENTS.md).

> **См. `CLAUDE.md` для полного набора правил.** Этот файл содержит ключевые моменты и особенности для не-Claude инструментов.

## Scope

- **Reads:** весь репо, кроме `build/`, `.dart_tool/`, `ios/Pods/`, `android/.gradle/`, `*.g.dart`, `*.freezed.dart`.
- **Writes:** только то, что явно попросил пользователь.
- **Off-limits:** `pubspec.lock`, `.gitnexus/`, `.code-review-graph/`, `.codegraph/` — не трогать.

## Workflow

1. Impact analysis перед изменением (`gitnexus_impact`)
2. Plan для задач на 3+ файла
3. Detect changes перед коммитом (`crg_detect_changes`)

## Flutter

- `*.g.dart`, `*.freezed.dart`, `*.mocks.dart` — генерируемые, не редактировать
- После изменения моделей — напомнить про `flutter pub run build_runner build`
- `mounted` check после `await` в StatefulWidget

## Pixso Redesign Rules

- Редизайн `2a-user` выполнять строго по дизайну в Pixso.
- Не придумывать визуальные элементы, отступы, цвета, типографику, состояния или поведение без прямого указания пользователя.
- Если в Pixso не хватает экрана, состояния, адаптива, иконки, текста или поведения, сначала уточнить у пользователя.
- Любое отклонение от Pixso-дизайна допустимо только после явного подтверждения пользователя.

## Бэкенд

- На удалённом сервере — SSH only. Локально не редактировать.
- Готовить «bundle для SSH»: код + команды + чек-лист

## Validation commands

```bash
flutter analyze
dart format --set-exit-if-changed .
flutter test
```

## Model

В Cursor/Codex использовать явно указанную модель (не Auto), для воспроизводимости.
