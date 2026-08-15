import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twoalogisticcabineuser/src/features/sp_finance/data/sp_organizer_fulfillment_models.dart';
import 'package:twoalogisticcabineuser/src/features/sp_finance/data/sp_organizer_models.dart';
import 'package:twoalogisticcabineuser/src/features/sp_finance/data/sp_organizer_provider.dart';
import 'package:twoalogisticcabineuser/src/features/sp_finance/presentation/sp_organizer_fulfillment_panel.dart';

const _newStatus = SpOrganizerFulfillmentStatus(
  code: 'new',
  nameRu: 'Новая',
  nameZh: '新建',
  color: '#6D5BD0',
  sortOrder: 10,
);
const _warehouseStatus = SpOrganizerFulfillmentStatus(
  code: 'in_warehouse',
  nameRu: 'На складе',
  nameZh: '已入库',
  color: '#2563EB',
  sortOrder: 20,
);
const _packedStatus = SpOrganizerFulfillmentStatus(
  code: 'packed',
  nameRu: 'Упакована',
  nameZh: '已打包',
  color: '#239B63',
  sortOrder: 20,
);
const _shippedStatus = SpOrganizerFulfillmentStatus(
  code: 'shipped',
  nameRu: 'Отправлен',
  nameZh: '已发货',
  color: '#7C3AED',
  sortOrder: 30,
);
const _unpaidStatus = SpOrganizerFulfillmentStatus(
  code: 'unpaid',
  nameRu: 'Не оплачен',
  nameZh: '未付款',
  color: '#D97706',
  sortOrder: 10,
);

final _overview = SpOrganizerFulfillmentOverview(
  contractVersion: 1,
  mode: 'read_only',
  persisted: false,
  purchaseId: 1,
  items: [
    SpOrganizerFulfillmentItem(id: 4, title: 'Куртка'),
    SpOrganizerFulfillmentItem(id: 5, title: 'Брюки'),
  ],
  summary: SpOrganizerFulfillmentSummary(
    itemsCount: 2,
    selfBuyoutRequestsCount: 1,
    garageOrderItemsCount: 0,
    tracksCount: 2,
    photosCount: 3,
    photoRequestsCount: 1,
    assembliesCount: 1,
    invoicesCount: 1,
  ),
  selfBuyoutRequests: [
    SpOrganizerSelfBuyoutFulfillment(
      itemId: 4,
      itemTitle: 'Куртка',
      requestId: 9,
      requestNumber: 'SB-001',
      status: _newStatus,
    ),
  ],
  tracks: [
    SpOrganizerTrackFulfillment(
      itemId: 4,
      itemTitle: 'Куртка',
      trackId: 10,
      trackNumber: 'TRACK-001',
      status: _warehouseStatus,
      photosCount: 2,
      photoRequestsCount: 1,
    ),
    SpOrganizerTrackFulfillment(
      itemId: 5,
      itemTitle: 'Брюки',
      trackId: 13,
      trackNumber: 'GARAGE-TRACK-013',
      source: 'garage_product_info',
      status: _shippedStatus,
      photosCount: 1,
      photos: [
        SpOrganizerFulfillmentPhoto(
          id: 31,
          url: '/uploads/sp-e13/garage-track-photo.jpg',
          createdAt: DateTime.utc(2026, 7, 27, 8),
        ),
      ],
    ),
  ],
  assemblies: [
    SpOrganizerAssemblyFulfillment(
      id: 11,
      number: 'ASM-001',
      source: 'explicit',
      status: _packedStatus,
      tracksCount: 1,
      invoicesCount: 1,
    ),
  ],
  invoices: [
    SpOrganizerInvoiceFulfillment(
      id: 12,
      invoiceNumber: 'INV-001',
      source: 'assembly',
      status: _unpaidStatus,
      totalCostRub: 1250,
    ),
  ],
  warnings: ['read_only_overview'],
);

const _readOnlyCapabilities = SpOrganizerCapabilities(
  contractVersion: 1,
  organizerV2: true,
  purchaseKinds: true,
  participants: true,
  products: true,
  calculationProfiles: true,
  fulfillmentOverview: true,
  selfBuyoutLinks: false,
  selfBuyout: SpOrganizerActionCapability.unavailable,
  garageImport: false,
  trackLinks: false,
  assemblyLinks: false,
  invoiceLinks: false,
  analytics: false,
);

const _linkCapabilities = SpOrganizerCapabilities(
  contractVersion: 1,
  organizerV2: true,
  purchaseKinds: true,
  participants: true,
  products: true,
  calculationProfiles: true,
  fulfillmentOverview: true,
  selfBuyoutLinks: true,
  selfBuyout: SpOrganizerActionCapability.unavailable,
  garageImport: true,
  trackLinks: true,
  assemblyLinks: true,
  invoiceLinks: true,
  analytics: false,
);

Future<void> _pumpPanel(
  WidgetTester tester, {
  required Size size,
  required Locale locale,
  bool canLink = false,
}) async {
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.binding.setSurfaceSize(size);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        spOrganizerCapabilitiesProvider.overrideWith(
          (ref) async => canLink ? _linkCapabilities : _readOnlyCapabilities,
        ),
        spOrganizerFulfillmentOverviewProvider(
          1,
        ).overrideWith((ref) async => _overview),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: const [Locale('ru'), Locale('zh')],
        home: const Scaffold(
          body: SingleChildScrollView(
            padding: EdgeInsets.all(8),
            child: SpOrganizerFulfillmentPanel(purchaseId: 1),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 150));
}

void main() {
  testWidgets('read-only fulfillment overview fits 320 px in Russian', (
    tester,
  ) async {
    await _pumpPanel(
      tester,
      size: const Size(320, 1200),
      locale: const Locale('ru'),
    );

    expect(find.text('Логистика 2A'), findsOneWidget);
    expect(find.textContaining('Самовыкуп SB-001'), findsOneWidget);
    expect(find.text('Треки и фото по товарам'), findsOneWidget);
    expect(find.text('Из Garage автоматически'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('sp-fulfillment-garage-track-13')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('sp-fulfillment-photo-13-31')),
      findsOneWidget,
    );
    expect(find.textContaining('Только просмотр'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('read-only fulfillment overview uses Chinese at 390 px', (
    tester,
  ) async {
    await _pumpPanel(
      tester,
      size: const Size(390, 1200),
      locale: const Locale('zh'),
    );

    expect(find.text('2A 履约'), findsOneWidget);
    expect(find.text('已入库'), findsOneWidget);
    expect(find.textContaining('仅查看'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('link capability exposes additive action without overflow', (
    tester,
  ) async {
    await _pumpPanel(
      tester,
      size: const Size(320, 1200),
      locale: const Locale('ru'),
      canLink: true,
    );

    expect(find.byIcon(Icons.add_link_rounded), findsOneWidget);
    expect(find.textContaining('только добавить связь'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fulfillment fits desktop and exposes track/photo semantics', (
    tester,
  ) async {
    await _pumpPanel(
      tester,
      size: const Size(1024, 1200),
      locale: const Locale('ru'),
    );

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'Открыть трек GARAGE-TRACK-013' &&
            widget.properties.button == true,
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'Открыть фотоотчёт' &&
            widget.properties.button == true,
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
