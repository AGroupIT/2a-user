import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:twoalogisticcabineuser/src/core/services/update_gate_provider.dart';
import 'package:twoalogisticcabineuser/src/core/services/update_service.dart';
import 'package:twoalogisticcabineuser/src/core/ui/app_update_gate.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'required update заменяет интерфейс фирменным блокирующим экраном',
    (tester) async {
      const update = UpdateInfo(
        latestVersion: '1.2.26+57',
        minVersion: '1.2.25+56',
        downloadUrl: 'https://example.test/user.apk',
        storeUrl: '',
        rustoreUrl: '',
        size: 1024,
        sha256: '',
        changelog: 'Исправлена стабильность приложения',
        isForced: true,
      );
      final container = ProviderContainer(
        overrides: [
          appUpdateCheckerProvider.overrideWithValue(() async => update),
        ],
      );
      addTearDown(container.dispose);
      await container
          .read(appUpdateGateProvider.notifier)
          .check(reason: 'test');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: AppUpdateGate(child: Text('Основной интерфейс')),
          ),
        ),
      );

      expect(find.text('Необходимо обновить приложение'), findsOneWidget);
      expect(find.text('Основной интерфейс'), findsNothing);
      expect(find.text('Обновить приложение'), findsOneWidget);
      expect(find.text('Связаться с поддержкой'), findsOneWidget);
    },
  );

  testWidgets(
    'optional update показывает компактный banner поверх приложения',
    (tester) async {
      const update = UpdateInfo(
        latestVersion: '1.2.26+57',
        minVersion: '1.0.0',
        downloadUrl: 'https://example.test/user.apk',
        storeUrl: '',
        rustoreUrl: '',
        size: 0,
        sha256: '',
        changelog: '',
        isForced: false,
      );
      final container = ProviderContainer(
        overrides: [
          appUpdateCheckerProvider.overrideWithValue(() async => update),
        ],
      );
      addTearDown(container.dispose);
      await container
          .read(appUpdateGateProvider.notifier)
          .check(reason: 'test');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: AppUpdateGate(child: Text('Основной интерфейс')),
          ),
        ),
      );

      expect(find.text('Основной интерфейс'), findsOneWidget);
      expect(find.text('Доступно обновление 1.2.26+57'), findsOneWidget);
      expect(find.text('Обновить'), findsOneWidget);
    },
  );
}
