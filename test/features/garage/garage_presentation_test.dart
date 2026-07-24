import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:twoalogisticcabineuser/src/features/clients/application/client_codes_controller.dart';
import 'package:twoalogisticcabineuser/src/features/garage/application/garage_providers.dart';
import 'package:twoalogisticcabineuser/src/features/garage/data/garage_repository.dart';
import 'package:twoalogisticcabineuser/src/features/garage/domain/garage_models.dart';
import 'package:twoalogisticcabineuser/src/features/garage/presentation/garage_conversation_card.dart';
import 'package:twoalogisticcabineuser/src/features/garage/presentation/garage_invoice_card.dart';
import 'package:twoalogisticcabineuser/src/features/garage/presentation/garage_order_detail_screen.dart';
import 'package:twoalogisticcabineuser/src/features/garage/presentation/garage_request_detail_screen.dart';
import 'package:twoalogisticcabineuser/src/features/garage/presentation/garage_request_form_screen.dart';
import 'package:twoalogisticcabineuser/src/features/garage/presentation/garage_screen.dart';
import 'package:twoalogisticcabineuser/src/features/garage/presentation/garage_ui.dart';

void main() {
  test('Garage purchase result exposes only pending and purchased states', () {
    expect(garagePurchaseStatus('pending'), 'pending');
    expect(garagePurchaseStatus('purchasing'), 'pending');
    expect(garagePurchaseStatus('unavailable'), 'pending');
    expect(garagePurchaseStatus('purchased'), 'purchased');
    expect(garageStatusLabel('purchased'), 'Куплено');
  });

  testWidgets('Garage route remains closed when availability is false', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          garageAvailabilityProvider.overrideWith(
            (ref) async => const GarageAvailability(
              available: false,
              reason: 'client_disabled',
              processorAgentId: 2,
              vinLookupConfigured: true,
            ),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: GarageScreen())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Гараж пока недоступен'), findsOneWidget);
    expect(
      find.text('Агент ещё не включил Гараж для вашего аккаунта.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'Garage start uses standard back header and request-first sections',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(390, 844));
      final repository = _MockGarageRepository();
      when(repository.getVehicles).thenAnswer((_) async => const []);
      when(repository.getRequests).thenAnswer(
        (_) async => [
          GarageRequest.fromJson({
            'id': 11,
            'requestNumber': 'GAR-A-11',
            'vehicleId': 7,
            'status': 'new',
            'createdAt': '2026-07-24T10:00:00.000Z',
            'vehicleSnapshot': {
              'make': 'Toyota',
              'model': 'Camry',
              'modelYear': 2020,
            },
            'items': [
              {
                'id': 101,
                'requestId': 11,
                'orderNumber': 1,
                'partName': 'Фильтр',
                'quantity': 1,
              },
            ],
          }),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeClientCodeProvider.overrideWithValue('A-001'),
            garageRepositoryProvider.overrideWithValue(repository),
            garageAvailabilityProvider.overrideWith(
              (ref) async => const GarageAvailability(
                available: true,
                reason: null,
                processorAgentId: 2,
                vinLookupConfigured: true,
              ),
            ),
            garageRequestStatusesProvider.overrideWith(
              (ref) async => const <GarageRequestStatusDefinition>[],
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: GarageScreen())),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);
      expect(find.text('Автомобили'), findsOneWidget);
      expect(find.text('Заявки'), findsOneWidget);
      expect(find.text('Заказы'), findsNothing);
      await tester.tap(find.text('Заявки'));
      await tester.pumpAndSettle();
      expect(find.text('GAR-A-11'), findsOneWidget);
      expect(find.textContaining('1 запчасть'), findsOneWidget);
      expect(find.textContaining('24.07.2026'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Garage invoice is separate and exposes Bank QR action', (
    tester,
  ) async {
    var paid = false;
    final order = GarageOrder.fromJson({
      'id': 44,
      'orderNumber': 'GO-A-01',
      'requestId': 11,
      'status': 'awaiting_payment',
      'goodsTotalCny': '90',
      'chinaDeliveryTotalCny': '5',
      'serviceFeeTotalCny': '5',
      'totalCny': '100',
      'totalRub': '12500',
    });
    final invoice = GarageInvoice.fromJson({
      'id': 55,
      'invoiceNumber': 'GI-A-01',
      'orderId': 44,
      'status': 'unpaid',
      'clientCnyRubRateSnapshot': '125',
      'totalCny': '100',
      'totalRub': '12500',
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GarageInvoiceCard(
            invoice: invoice,
            order: order,
            onPay: () => paid = true,
          ),
        ),
      ),
    );

    expect(find.text('Счёт GI-A-01'), findsOneWidget);
    expect(find.text('Оплатить по Bank QR'), findsOneWidget);
    await tester.tap(find.text('Оплатить по Bank QR'));
    expect(paid, isTrue);
  });

  testWidgets('Garage conversation shows unread question and answer composer', (
    tester,
  ) async {
    final repository = _MockGarageRepository();
    final request = GarageRequest.fromJson({
      'id': 11,
      'requestNumber': 'GAR-A-01',
      'vehicleId': 7,
      'status': 'needs_clarification',
      'items': <Map<String, dynamic>>[],
    });
    final page = GarageMessagePage.fromJson({
      'messages': [
        {
          'id': 71,
          'requestId': 11,
          'senderType': 'employee',
          'senderId': 5,
          'senderName': 'Менеджер',
          'messageType': 'question',
          'requiresResponseFrom': 'client',
          'content': '原厂件可以吗？',
          'contentRu': 'Подойдёт оригинал?',
          'createdAt': '2026-07-23T10:00:00.000Z',
        },
      ],
      'unreadCount': 1,
      'lastReadMessageId': 60,
    });
    when(
      () => repository.getRequestMessages(11, cursor: null, take: 100),
    ).thenAnswer((_) async => page);
    when(
      () => repository.markRequestMessagesRead(11, lastReadMessageId: 71),
    ).thenAnswer(
      (_) async => const GarageMessageReadCursor(
        lastReadMessageId: 71,
        lastReadAt: null,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [garageRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          home: Scaffold(body: GarageConversationCard(request: request)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Новых: 1'), findsOneWidget);
    expect(find.text('Подойдёт оригинал?'), findsOneWidget);
    await tester.tap(find.text('Ответить'));
    await tester.pump();
    expect(find.textContaining('Ответ на вопрос:'), findsOneWidget);
    expect(find.text('Введите ответ сотруднику'), findsOneWidget);
  });

  testWidgets('Garage conversation silently refreshes on message timestamp', (
    tester,
  ) async {
    final repository = _MockGarageRepository();
    var loadCount = 0;
    when(
      () => repository.getRequestMessages(11, cursor: null, take: 100),
    ).thenAnswer((_) async {
      loadCount += 1;
      return GarageMessagePage.fromJson({
        'messages': [
          {
            'id': loadCount == 1 ? 71 : 72,
            'requestId': 11,
            'senderType': 'employee',
            'senderId': 5,
            'senderName': 'Менеджер',
            'messageType': 'comment',
            'content': loadCount == 1 ? 'Первое сообщение' : 'Новое сообщение',
            'createdAt': '2026-07-23T10:00:00.000Z',
          },
        ],
        'unreadCount': 0,
        'lastReadMessageId': loadCount == 1 ? 71 : 72,
      });
    });
    final key = GlobalKey<_ConversationHarnessState>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [garageRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          home: Scaffold(
            body: _ConversationHarness(
              key: key,
              request: _conversationRequest(
                lastMessageAt: '2026-07-23T10:00:00.000Z',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Первое сообщение'), findsOneWidget);

    key.currentState!.update(
      _conversationRequest(lastMessageAt: '2026-07-23T10:01:00.000Z'),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Новое сообщение'), findsOneWidget);
    expect(find.text('Первое сообщение'), findsNothing);
    expect(loadCount, 2);
  });

  testWidgets('Garage request status chip uses database definition', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: GarageStatusChip(
          status: 'new',
          definition: GarageRequestStatusDefinition(
            code: 'new',
            nameRu: 'Новая из БД',
            color: '#123456',
            sortOrder: 2,
          ),
        ),
      ),
    );

    expect(find.text('Новая из БД'), findsOneWidget);
    final text = tester.widget<Text>(find.text('Новая из БД'));
    expect(text.style?.color, const Color(0xFF123456));
  });

  testWidgets('Garage vehicle picker fits a narrow form and opens modal', (
    tester,
  ) async {
    final repository = _MockGarageRepository();
    when(repository.getVehicles).thenAnswer(
      (_) async => [
        GarageVehicle.fromJson({
          'id': 7,
          'vinNormalized': 'JTDKN3DU0D1234567',
          'nickname': 'Очень длинное название семейного автомобиля',
          'make': 'Toyota',
          'model': 'Prius Plug-in Hybrid Executive',
          'modelYear': 2026,
        }),
      ],
    );
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(400, 800));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeClientCodeProvider.overrideWithValue('A-001'),
          garageRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(
          home: Scaffold(body: GarageRequestFormScreen(initialVehicleId: 7)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(DropdownButtonFormField<int>), findsNothing);
    expect(find.byKey(const ValueKey('garage-vehicle-picker')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('garage-vehicle-picker')));
    await tester.pumpAndSettle();
    expect(find.text('Выберите автомобиль'), findsOneWidget);
    expect(
      find.textContaining('Очень длинное название семейного автомобиля'),
      findsWidgets,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Garage draft form loads existing request for editing', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(600, 1600));
    final repository = _MockGarageRepository();
    when(repository.getVehicles).thenAnswer(
      (_) async => [
        GarageVehicle.fromJson({
          'id': 7,
          'vinNormalized': 'JTDKN3DU0D1234567',
          'nickname': 'Семейный',
          'make': 'Toyota',
          'model': 'Prius',
          'modelYear': 2026,
        }),
      ],
    );
    when(() => repository.getRequest(11)).thenAnswer(
      (_) async => GarageRequest.fromJson({
        'id': 11,
        'requestNumber': 'GAR-A-11',
        'vehicleId': 7,
        'clientCodeId': 3,
        'status': 'draft',
        'clientComment': 'Проверить совместимость',
        'items': [
          {
            'id': 101,
            'requestId': 11,
            'orderNumber': 1,
            'partName': 'Тормозные колодки',
            'partNumber': '04465-33480',
            'preference': 'original',
            'existUrl': 'https://exist.ru/item',
            'quantity': 2,
            'side': 'Передняя',
            'position': 'Передняя ось',
            'clientComment': 'Нужны срочно',
          },
        ],
      }),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeClientCodeProvider.overrideWithValue('A-001'),
          garageRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(
          home: Scaffold(body: GarageRequestFormScreen(requestId: 11)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Редактирование заявки'), findsOneWidget);
    expect(find.text('Тормозные колодки'), findsOneWidget);
    expect(find.text('Передняя ось'), findsOneWidget);
    expect(find.text('Сохранить изменения'), findsOneWidget);
    expect(find.text('Сохранить и отправить'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Garage offer allows multiple variants of one item and quantity per variant',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(700, 1800));
      final repository = _MockGarageRepository();
      final request = GarageRequest.fromJson({
        'id': 11,
        'requestNumber': 'GAR-A-11',
        'vehicleId': 7,
        'status': 'offer_ready',
        'currentOfferId': 88,
        'items': [
          {
            'id': 101,
            'requestId': 11,
            'orderNumber': 1,
            'partName': 'Тормозные колодки',
            'partNumber': '04465-33480',
            'preference': 'any',
            'existUrl': 'https://exist.ru/item',
            'quantity': 1,
          },
        ],
        'currentOffer': {
          'id': 88,
          'requestId': 11,
          'version': 1,
          'status': 'published',
          'clientCnyRubRateSnapshot': '12.5',
          'validUntil': '2026-08-10T00:00:00.000Z',
          'options': [
            {
              'id': 501,
              'offerId': 88,
              'requestItemId': 101,
              'manufacturer': '丰田',
              'manufacturerRu': 'Toyota',
              'partNumber': '04465-33480',
              'optionType': 'original',
              'imageUrl': '/uploads/garage-options/brakes.jpg',
              'imageUrls': [
                '/uploads/garage-options/brakes.jpg',
                '/uploads/garage-options/brakes-side.jpg',
              ],
              'description': '原厂刹车片',
              'descriptionRu': 'Оригинальные тормозные колодки',
              'employeeComment': '推荐用于日常驾驶',
              'employeeCommentRu': 'Рекомендуем для ежедневной езды',
              'availabilityStatus': 'available',
              'clientUnitPriceCny': '100',
              'clientUnitPriceRub': '1250',
            },
            {
              'id': 502,
              'offerId': 88,
              'requestItemId': 101,
              'manufacturer': 'Akebono',
              'partNumber': 'AN-123',
              'optionType': 'analog',
              'availabilityStatus': 'available',
              'clientUnitPriceCny': '80',
              'clientUnitPriceRub': '1000',
            },
          ],
        },
      });
      when(() => repository.getRequest(11)).thenAnswer((_) async => request);
      when(
        () => repository.getRequestMessages(11, cursor: null, take: 100),
      ).thenAnswer(
        (_) async => GarageMessagePage.fromJson({
          'messages': <Map<String, dynamic>>[],
          'unreadCount': 0,
        }),
      );
      when(() => repository.calculateOffer(11, 88, any())).thenAnswer(
        (_) async => GarageOfferCalculation.fromJson({
          'offerId': 88,
          'totals': {
            'goodsTotalCny': '360',
            'chinaDeliveryTotalCny': '10',
            'serviceFeeTotalCny': '20',
            'totalCny': '390',
            'totalRub': '4875',
            'clientCnyRubRateSnapshot': '12.5',
          },
        }),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeClientCodeProvider.overrideWithValue('A-001'),
            garageRepositoryProvider.overrideWithValue(repository),
            garageRequestStatusesProvider.overrideWith(
              (ref) async => const <GarageRequestStatusDefinition>[],
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: GarageRequestDetailScreen(requestId: 11)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Запчасти'));
      await tester.pumpAndSettle();
      expect(find.text('Toyota 04465-33480'), findsOneWidget);
      expect(find.text('Оригинальные тормозные колодки'), findsOneWidget);
      expect(find.text('Рекомендуем для ежедневной езды'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('garage-option-501-image-0')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('garage-option-501-image-1')),
        findsOneWidget,
      );
      final first = find.byKey(const ValueKey('garage-option-501-checkbox'));
      final second = find.byKey(const ValueKey('garage-option-502-checkbox'));
      await tester.ensureVisible(first);
      await tester.tap(first);
      await tester.pump();
      await tester.ensureVisible(second);
      await tester.tap(second);
      await tester.pump();

      expect(tester.widget<Checkbox>(first).value, isTrue);
      expect(tester.widget<Checkbox>(second).value, isTrue);
      final plus = find.byKey(const ValueKey('garage-option-501-plus'));
      await tester.ensureVisible(plus);
      await tester.tap(plus);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('garage-option-501-quantity')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('garage-option-501-quantity')),
            )
            .data,
        '2',
      );
      expect(tester.widget<Checkbox>(second).value, isTrue);
      expect(find.text('Пересчитать'), findsNothing);
      expect(find.text('Комиссия'), findsNothing);
      expect(find.text('390.00 ¥ · 4875.00 ₽'), findsOneWidget);
      verify(() => repository.calculateOffer(11, 88, any())).called(1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Garage paid order keeps selected option image and hides empty refund',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(390, 1000));
      final repository = _MockGarageRepository();
      final order = GarageOrder.fromJson({
        'id': 45,
        'orderNumber': 'GO-45',
        'requestId': 12,
        'status': 'paid',
        'refundState': 'none',
        'totalCny': '100',
        'totalRub': '1250',
        'vehicleSnapshot': {
          'make': 'Toyota',
          'model': 'Camry',
          'modelYear': 2020,
        },
        'items': [
          {
            'id': 601,
            'orderId': 45,
            'requestItemId': 102,
            'partName': 'Масляный фильтр',
            'quantity': 2,
            'lineTotalCny': '100',
            'lineTotalRub': '1250',
            'purchaseStatus': 'pending',
            'selectedOption': {
              'id': 503,
              'manufacturer': 'Toyota',
              'partNumber': '90915-YZZD2',
              'imageUrl': '/uploads/garage-options/filter.jpg',
              'imageUrls': [
                '/uploads/garage-options/filter.jpg',
                '/uploads/garage-options/filter-box.jpg',
              ],
            },
          },
        ],
        'invoice': {
          'id': 701,
          'invoiceNumber': 'GI-701',
          'orderId': 45,
          'status': 'paid',
          'totalCny': '100',
          'totalRub': '1250',
          'paidAt': '2026-07-24T10:00:00.000Z',
        },
        'paidAt': '2026-07-24T10:00:00.000Z',
      });
      when(() => repository.getOrder(45)).thenAnswer((_) async => order);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeClientCodeProvider.overrideWithValue('A-001'),
            garageRepositoryProvider.overrideWithValue(repository),
          ],
          child: const MaterialApp(
            home: Scaffold(body: GarageOrderDetailScreen(orderId: 45)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Возврат'), findsNothing);
      expect(find.text('Ожидает оплаты'), findsOneWidget);
      expect(find.text('Оплачено'), findsOneWidget);
      expect(find.text('Выкупаем'), findsOneWidget);
      expect(find.text('Завершено'), findsOneWidget);

      expect(
        find.byKey(const ValueKey('garage-order-item-601-image-1')),
        findsOneWidget,
      );
      final image = find.byKey(const ValueKey('garage-order-item-601-image-0'));
      await tester.ensureVisible(image);
      await tester.tap(image);
      await tester.pump();
      expect(find.byIcon(Icons.download_rounded), findsOneWidget);
      expect(find.text('filter.jpg'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded).last);
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Garage offer locks selection and quantity after receipt upload',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(390, 1000));
      final repository = _MockGarageRepository();
      final request = GarageRequest.fromJson({
        'id': 12,
        'requestNumber': 'GAR-A-12',
        'vehicleId': 7,
        'status': 'converted_to_order',
        'currentOfferId': 89,
        'items': [
          {
            'id': 102,
            'requestId': 12,
            'orderNumber': 1,
            'partName': 'Масляный фильтр',
            'partNumber': '90915-YZZD2',
            'preference': 'original',
            'existUrl': 'https://exist.ru/item',
            'quantity': 1,
          },
        ],
        'currentOffer': {
          'id': 89,
          'requestId': 12,
          'version': 1,
          'status': 'accepted',
          'clientCnyRubRateSnapshot': '12.5',
          'options': [
            {
              'id': 503,
              'offerId': 89,
              'requestItemId': 102,
              'manufacturer': 'Toyota',
              'partNumber': '90915-YZZD2',
              'optionType': 'original',
              'availabilityStatus': 'available',
              'clientUnitPriceCny': '50',
              'clientUnitPriceRub': '625',
            },
          ],
        },
        'order': {
          'id': 45,
          'orderNumber': 'GO-45',
          'requestId': 12,
          'clientId': 1,
          'agentId': 1,
          'processorAgentId': 1,
          'status': 'payment_review',
          'totalCny': '100',
          'totalRub': '1250',
          'items': [
            {
              'id': 601,
              'orderId': 45,
              'requestItemId': 102,
              'selectedOptionId': 503,
              'partNameSnapshot': 'Масляный фильтр',
              'quantitySnapshot': 2,
              'purchaseStatus': 'pending',
            },
          ],
          'invoice': {
            'id': 701,
            'invoiceNumber': 'GI-701',
            'orderId': 45,
            'status': 'payment_review',
            'totalCny': '100',
            'totalRub': '1250',
          },
        },
      });
      when(() => repository.getRequest(12)).thenAnswer((_) async => request);
      when(
        () => repository.getRequestMessages(12, cursor: null, take: 100),
      ).thenAnswer(
        (_) async => GarageMessagePage.fromJson({
          'messages': <Map<String, dynamic>>[],
          'unreadCount': 0,
        }),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeClientCodeProvider.overrideWithValue('A-001'),
            garageRepositoryProvider.overrideWithValue(repository),
            garageRequestStatusesProvider.overrideWith(
              (ref) async => const <GarageRequestStatusDefinition>[],
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: GarageRequestDetailScreen(requestId: 12)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Запчасти'));
      await tester.pumpAndSettle();
      final checkbox = tester.widget<Checkbox>(
        find.byKey(const ValueKey('garage-option-503-checkbox')),
      );
      expect(checkbox.value, isTrue);
      expect(checkbox.onChanged, isNull);
      expect(find.text('2'), findsOneWidget);
      expect(
        find.text('Состав и количество зафиксированы после отправки оплаты.'),
        findsOneWidget,
      );
      expect(find.text('Сохранить и перейти к оплате'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

class _MockGarageRepository extends Mock implements GarageRepository {}

class _ConversationHarness extends StatefulWidget {
  final GarageRequest request;

  const _ConversationHarness({super.key, required this.request});

  @override
  State<_ConversationHarness> createState() => _ConversationHarnessState();
}

class _ConversationHarnessState extends State<_ConversationHarness> {
  late GarageRequest _request = widget.request;

  void update(GarageRequest request) {
    setState(() => _request = request);
  }

  @override
  Widget build(BuildContext context) {
    return GarageConversationCard(request: _request);
  }
}

GarageRequest _conversationRequest({required String lastMessageAt}) {
  return GarageRequest.fromJson({
    'id': 11,
    'requestNumber': 'GAR-A-01',
    'vehicleId': 7,
    'status': 'new',
    'lastMessageAt': lastMessageAt,
    'items': <Map<String, dynamic>>[],
  });
}
