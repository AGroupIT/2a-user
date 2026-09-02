import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:twoalogisticcabineuser/src/core/network/api_client.dart';
import 'package:twoalogisticcabineuser/src/features/notifications/application/client_notification_preferences_controller.dart';
import 'package:twoalogisticcabineuser/src/features/notifications/data/client_notification_preferences_repository.dart';
import 'package:twoalogisticcabineuser/src/features/notifications/domain/client_notification_preference.dart';
import 'package:twoalogisticcabineuser/src/features/notifications/presentation/client_notification_preferences_section.dart';

class _MockApiClient extends Mock implements ApiClient {}

class _MockPreferencesRepository extends Mock
    implements ClientNotificationPreferencesRepository {}

void main() {
  test(
    'repository keeps mandatory policy and legacy enabled defaults',
    () async {
      final apiClient = _MockApiClient();
      when(
        () => apiClient.get<Map<String, dynamic>>(
          '/client/notification-preferences',
        ),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(
            path: '/client/notification-preferences',
          ),
          statusCode: 200,
          data: {
            'data': {
              'version': 1,
              'items': [
                {
                  'key': 'track_created',
                  'eventType': 'track_created',
                  'group': 'tracks',
                  'policy': 'configurable',
                  'enabled': false,
                },
                {
                  'key': 'invoice_created',
                  'eventType': 'invoice_created',
                  'group': 'invoices_payments',
                  'policy': 'mandatory',
                },
              ],
            },
          },
        ),
      );

      final repository = ClientNotificationPreferencesRepository(apiClient);
      final items = await repository.fetch();

      expect(items, hasLength(2));
      expect(items.first.enabled, isFalse);
      expect(items.first.isConfigurable, isTrue);
      expect(items.last.enabled, isTrue);
      expect(items.last.isConfigurable, isFalse);
    },
  );

  testWidgets('shows locked and configurable notifications without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    String? changedKey;
    bool? changedValue;
    await _pumpCard(
      tester,
      const Locale('ru'),
      onChanged: (key, enabled) async {
        changedKey = key;
        changedValue = enabled;
      },
    );

    expect(find.text('Настройки уведомлений'), findsOneWidget);
    expect(find.text('Добавлен новый трек'), findsOneWidget);
    expect(find.text('Создан новый счёт'), findsOneWidget);
    expect(find.text('Всегда включено'), findsNothing);
    expect(find.text('Можно отключить'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(
      find.byKey(const Key('client-push-preference-track_created')),
    );
    await tester.pump();
    expect(changedKey, 'track_created');
    expect(changedValue, isFalse);

    changedKey = null;
    await tester.tap(
      find.byKey(const Key('client-push-preference-invoice_created')),
    );
    await tester.pump();
    expect(changedKey, isNull);
    expect(tester.takeException(), isNull);
  });

  test(
    'controller rolls back an optimistic change when saving fails',
    () async {
      final repository = _MockPreferencesRepository();
      const original = ClientNotificationPreferenceItem(
        key: 'track_created',
        eventType: 'track_created',
        group: 'tracks',
        policy: ClientNotificationPreferencePolicy.configurable,
        enabled: true,
      );
      when(() => repository.fetch()).thenAnswer((_) async => [original]);
      when(
        () => repository.update(key: 'track_created', enabled: false),
      ).thenThrow(Exception('network'));

      final container = ProviderContainer(
        overrides: [
          clientNotificationPreferencesRepositoryProvider.overrideWithValue(
            repository,
          ),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        clientNotificationPreferencesControllerProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      await container.read(
        clientNotificationPreferencesControllerProvider.future,
      );

      await expectLater(
        container
            .read(clientNotificationPreferencesControllerProvider.notifier)
            .setEnabled('track_created', false),
        throwsA(isA<Exception>()),
      );

      final state = container
          .read(clientNotificationPreferencesControllerProvider)
          .requireValue;
      expect(state.items.single.enabled, isTrue);
      expect(state.savingKeys, isEmpty);
    },
  );

  testWidgets('uses Chinese labels for Chinese system language', (
    tester,
  ) async {
    await _pumpCard(tester, const Locale('zh'));

    expect(find.text('通知设置'), findsOneWidget);
    expect(find.text('已添加新运单'), findsOneWidget);
    expect(find.text('已创建新账单'), findsOneWidget);
    expect(find.text('始终开启'), findsNothing);
    expect(find.text('可关闭'), findsNothing);
  });
}

Future<void> _pumpCard(
  WidgetTester tester,
  Locale locale, {
  Future<void> Function(String key, bool enabled)? onChanged,
}) async {
  const state = ClientNotificationPreferencesState(
    items: [
      ClientNotificationPreferenceItem(
        key: 'track_created',
        eventType: 'track_created',
        group: 'tracks',
        policy: ClientNotificationPreferencePolicy.configurable,
        enabled: true,
      ),
      ClientNotificationPreferenceItem(
        key: 'invoice_created',
        eventType: 'invoice_created',
        group: 'invoices_payments',
        policy: ClientNotificationPreferencePolicy.mandatory,
        enabled: true,
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        locale: locale,
        supportedLocales: const [Locale('ru'), Locale('zh')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: ClientNotificationPreferencesCard(
              state: state,
              onChanged: onChanged ?? (_, _) async {},
            ),
          ),
        ),
      ),
    ),
  );
}
