---
name: flutter-state-management
description: Используй при работе с Flutter-состоянием. Триггеры — setState, StatefulWidget, StatelessWidget, Provider, Riverpod, Bloc, ChangeNotifier, ValueNotifier, StreamBuilder, FutureBuilder, async gaps, mounted, dispose.
---

# Flutter — State Management rules

## Первое, что делаешь

Перед редактированием State-логики — **определи, какое средство управления состоянием используется в этом репо**.

Проверки по порядку:
1. Поиск по `pubspec.yaml`: `flutter_riverpod`, `provider`, `flutter_bloc`, `get_it`, `mobx`?
2. Если ничего — проверь `lib/main.dart` и корневой виджет.
3. Только после этого редактируй.

**Не смешивай подходы в одном репо.** Если везде Riverpod — не используй Provider в новом экране.

## Async gap правило

После **любого** `await` в `State<T>`:

```dart
Future<void> onTap() async {
  final result = await api.fetchData();
  if (!mounted) return;  // ← ОБЯЗАТЕЛЬНО
  setState(() => _data = result);
}
```

Без `mounted` check — crash при уходе со страницы до завершения запроса.

## setState в dispose

```dart
@override
void dispose() {
  _controller.dispose();
  // НИКАКОГО setState здесь. Виджет уже не в дереве.
  super.dispose();
}
```

## StreamBuilder / FutureBuilder

- Всегда обрабатывай `connectionState: waiting` → loading UI
- Всегда обрабатывай `snapshot.hasError` → error UI
- Никогда не полагайся только на `snapshot.hasData` — проверяй и `connectionState`

## Riverpod (если используется)

- `ref.read` в event handlers, `ref.watch` в build-методах
- `AutoDispose` по умолчанию для UI-состояний
- Изолируй business logic в `Notifier` / `AsyncNotifier`, не в виджете

## Bloc (если используется)

- Events → Bloc → States, однонаправленный поток
- Не мутируй state — создавай новый (`state.copyWith(...)`)
- `BlocProvider` на уровне Route, `BlocBuilder` точечно

## Provider (если используется)

- `Provider.of<T>(context, listen: false)` в event handlers
- `context.watch<T>()` только в build
- `ChangeNotifier.notifyListeners()` — после изменения state, не до

## Типовые баги, которые надо ловить

1. `setState` после `dispose` → crash
2. `Navigator.pop(context)` после `await` без `mounted` check → crash
3. Подписка на Stream без `cancel` в `dispose` → memory leak
4. `TextEditingController` без `dispose` → memory leak
5. Тяжёлые вычисления в `build()` → jank → использовать `memoization` или вынести в state
