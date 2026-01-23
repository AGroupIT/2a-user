import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:twoalogisticcabineuser/src/core/persistence/shared_preferences_provider.dart';

/// Extension для упрощения тестирования виджетов
extension PumpApp on WidgetTester {
  /// Оборачивает виджет в MaterialApp с необходимыми провайдерами
  Future<void> pumpApp(
    Widget widget, {
    List overrides = const [],
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          ...overrides,
        ],
        child: MaterialApp(
          home: widget,
        ),
      ),
    );
  }
}
