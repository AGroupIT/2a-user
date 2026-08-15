import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twoalogisticcabineuser/src/core/network/api_client.dart';
import 'package:twoalogisticcabineuser/src/features/sp_finance/data/sp_v2_models.dart';
import 'package:twoalogisticcabineuser/src/features/sp_finance/data/sp_v2_provider.dart';
import 'package:twoalogisticcabineuser/src/features/sp_finance/data/sp_v2_repository.dart';
import 'package:twoalogisticcabineuser/src/features/sp_finance/presentation/sp_v2_bulk_actions_sheet.dart';

const _customer = SpV2Customer(id: 3, fullName: 'Анна');

final _purchase = SpV2Purchase(
  id: 7,
  title: 'Летняя закупка',
  status: 'open',
  statusLabel: 'Принимает товары',
  isAcceptingItems: true,
  items: [
    SpV2Item(
      id: 17,
      title: 'Футболка',
      status: 'requested',
      statusLabel: 'Запрошен',
      quantity: 1,
      totalDueRub: 320,
      updatedAt: DateTime.parse('2026-07-27T03:04:05.000Z'),
      customer: _customer,
      tracks: const [
        SpV2TrackRef(id: 9, trackNumber: 'TRACK-9', status: 'in_warehouse'),
      ],
    ),
    SpV2Item(
      id: 18,
      title: 'Сумка',
      status: 'approved',
      statusLabel: 'Подтверждён',
      quantity: 1,
      totalDueRub: 680,
      updatedAt: DateTime.parse('2026-07-27T03:04:06.000Z'),
      customer: _customer,
    ),
  ],
);

class _FakeRepository extends SpV2Repository {
  _FakeRepository() : super(ApiClient());

  @override
  Future<SpV2BulkOptions> getBulkOptions(int purchaseId) async {
    return const SpV2BulkOptions(
      purchaseId: 7,
      maxItems: 500,
      statuses: [
        SpV2BulkStatusOption(
          code: 'approved',
          nameRu: 'Подтверждён',
          sortOrder: 30,
        ),
        SpV2BulkStatusOption(
          code: 'purchased',
          nameRu: 'Выкуплен',
          sortOrder: 40,
        ),
      ],
      customers: [
        SpV2BulkCustomerOption(id: 3, name: 'Анна', isOrganizerSelf: false),
        SpV2BulkCustomerOption(id: 4, name: 'Борис', isOrganizerSelf: false),
      ],
      purchases: [
        SpV2BulkPurchaseOption(
          id: 8,
          title: 'Следующая закупка',
          status: 'open',
        ),
      ],
    );
  }
}

void main() {
  testWidgets('bulk actions inherit SP card style and fit 320 px', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(320, 800));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          spV2RepositoryProvider.overrideWithValue(_FakeRepository()),
        ],
        child: MaterialApp(
          home: Scaffold(body: SpV2BulkActionsSheet(purchase: _purchase)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Массовые действия'), findsOneWidget);
    expect(find.text('Вся закупка · 2'), findsOneWidget);
    expect(find.text('Статус'), findsOneWidget);
    expect(find.text('Клиент'), findsOneWidget);
    expect(find.text('Закупка'), findsOneWidget);
    expect(find.text('В архив'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -360));
    await tester.pumpAndSettle();
    expect(find.text('Подтверждён'), findsOneWidget);
    expect(find.text('1 товаров'), findsOneWidget);
    expect(find.text('320.00 ₽'), findsOneWidget);
    expect(find.text('1 треков'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
