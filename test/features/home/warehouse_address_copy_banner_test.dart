import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twoalogisticcabineuser/src/features/home/presentation/warehouse_address_copy_banner.dart';

void main() {
  testWidgets('показывает модальное подтверждение на русском', (tester) async {
    await _pumpLauncher(tester, const Locale('ru'));

    await tester.tap(find.text('Показать'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('Адрес склада скопирован'), findsOneWidget);
    expect(
      find.textContaining('Приложение автоматически сравнит'),
      findsOneWidget,
    );
    expect(find.text('Проверить заполнение'), findsNothing);
    expect(find.text('Понятно'), findsOneWidget);

    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);

    await tester.ensureVisible(find.text('Понятно'));
    await tester.tap(find.text('Понятно'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('показывает китайский текст для zh locale', (tester) async {
    await _pumpLauncher(tester, const Locale('zh'));

    await tester.tap(find.text('Показать'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('仓库地址已复制'), findsOneWidget);
    expect(find.textContaining('应用会自动比较截图中的仓库地址'), findsOneWidget);
    expect(find.text('检查填写'), findsNothing);
    expect(find.text('明白了'), findsOneWidget);

    await tester.ensureVisible(find.text('明白了'));
    await tester.tap(find.text('明白了'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
  });
}

Future<void> _pumpLauncher(WidgetTester tester, Locale locale) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      supportedLocales: const [Locale('ru'), Locale('zh')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => showWarehouseAddressCopyBanner(context),
              child: const Text('Показать'),
            ),
          ),
        ),
      ),
    ),
  );
}
