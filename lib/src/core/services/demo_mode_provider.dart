import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Провайдер демо-режима (обучение).
/// true — показываются демо-данные, false — реальные данные.
final demoModeProvider = NotifierProvider<DemoModeNotifier, bool>(
  DemoModeNotifier.new,
);

class DemoModeNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void enable() => state = true;
  void disable() => state = false;
}
