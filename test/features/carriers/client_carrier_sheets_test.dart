import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:twoalogisticcabineuser/src/core/network/api_client.dart';
import 'package:twoalogisticcabineuser/src/core/ui/app_colors.dart';
import 'package:twoalogisticcabineuser/src/features/assemblies/domain/box.dart';
import 'package:twoalogisticcabineuser/src/features/auth/data/auth_provider.dart';
import 'package:twoalogisticcabineuser/src/features/carriers/presentation/client_carrier_tracking_panel.dart';
import 'package:twoalogisticcabineuser/src/features/clients/application/client_codes_controller.dart';
import 'package:twoalogisticcabineuser/src/features/invoices/data/invoices_provider.dart';
import 'package:twoalogisticcabineuser/src/features/invoices/domain/invoice_item.dart';
import 'package:twoalogisticcabineuser/src/features/invoices/presentation/invoices_screen.dart';
import 'package:twoalogisticcabineuser/src/features/payments/data/payment_operator_status.dart';
import 'package:twoalogisticcabineuser/src/features/referral/data/referral_provider.dart';
import 'package:twoalogisticcabineuser/src/features/tracks/data/tracks_provider.dart';
import 'package:twoalogisticcabineuser/src/features/tracks/domain/track_item.dart';
import 'package:twoalogisticcabineuser/src/features/tracks/presentation/tracks_screen.dart';

class _Auth extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
    isLoggedIn: true,
    isLoading: false,
    clientId: 7,
    userDomain: 'client.test',
  );
}

const _boxes = [
  Box(
    id: 11,
    number: 1,
    height: 10,
    width: 10,
    length: 10,
    weight: 1,
    orderNumber: 'WB-A',
  ),
  Box(
    id: 12,
    number: 2,
    height: 10,
    width: 10,
    length: 10,
    weight: 1,
    orderNumber: 'WB-A',
  ),
  Box(
    id: 13,
    number: 3,
    height: 10,
    width: 10,
    length: 10,
    weight: 1,
    orderNumber: 'WB-B',
  ),
];

Map<String, dynamic> _shipment(int id, String number, List<int> boxIds) => {
  'id': id,
  'number': number,
  'boxIds': boxIds,
  'placesCount': boxIds.length,
  'trackedPlaces': boxIds.length,
  'arrivedPlaces': 0,
  'labelRu': id == 1
      ? 'Передано на таможню'
      : 'Отправлено со склада перевозчика',
  'labelZh': id == 1 ? '已交海关' : '已从承运商仓库发出',
  'trackingPending': false,
  'events': [
    {
      'labelRu': 'Принято на складе перевозчика',
      'labelZh': '承运商仓库已收货',
      'date': '2026-10-14',
      'timePrecision': 'date',
    },
  ],
};

class _Api extends ApiClient {
  final trackingQueries = <Map<String, dynamic>>[];

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    dynamic data = {'data': []};
    if (path == '/carriers/shipments') {
      trackingQueries.add({...?queryParameters});
      data = {
        'shipments': [
          _shipment(1, 'WB-A', [11, 12]),
          if (queryParameters?['assemblyId'] != null)
            _shipment(2, 'WB-B', [13]),
        ],
      };
    }
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
      data: data as T,
    );
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  setUpAll(() => initializeDateFormatting('ru'));

  testWidgets(
    'invoice detail requests only its invoice and keeps carrier history separate from payment',
    (tester) async {
      final api = _Api();
      final invoice = InvoiceItem.fromJson({
        'id': 88,
        'invoiceNumber': 'INV-88',
        'status': 'paid',
        'statusName': 'Оплачен',
        'placesCount': 2,
        'weight': 2,
        'totalCostUSD': 10,
        'totalCostRUB': 1000,
        'boxes': [
          for (final box in _boxes.take(2))
            {
              'id': box.id,
              'number': box.number,
              'orderNumber': box.orderNumber,
              'weight': box.weight,
            },
        ],
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(api),
            authProvider.overrideWith(_Auth.new),
            brandColorsProvider.overrideWithValue(BrandColors.defaultColors),
            activeClientCodeProvider.overrideWithValue('TEST'),
            referralProvider.overrideWith(
              (_) async => const ReferralData(
                referralKgBalance: 0,
                referrals: [],
                transactions: [],
              ),
            ),
            invoiceStatusesProvider.overrideWith((_) async => []),
            invoiceByIdProvider.overrideWith((_, _) async => invoice),
            paymentOperatorStatusProvider.overrideWith(
              (_) => Stream.value(
                PaymentOperatorStatus(sleeping: false, reachable: true),
              ),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('ru'),
            supportedLocales: const [Locale('ru')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: Scaffold(
              body: SingleChildScrollView(
                child: ClientInvoiceTile(item: invoice, clientCode: 'TEST'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(api.trackingQueries, isEmpty);
      await tester.tap(find.text('INV-88'));
      await tester.pumpAndSettle();
      expect(api.trackingQueries, [
        {'invoiceId': 88},
      ]);
      expect(find.byType(ClientCarrierTrackingPanel), findsOneWidget);
      expect(find.text('Движение груза'), findsOneWidget);
      expect(find.text('WB-A'), findsOneWidget);
      expect(find.text('WB-B'), findsNothing);
      expect(find.text('Передано на таможню'), findsOneWidget);
      expect(find.text('Оплачен'), findsWidgets);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'assembly main and places show separate same-number box groups via assembly scope',
    (tester) async {
      final api = _Api();
      const assembly = TrackAssembly(
        id: 42,
        number: 'ASM-42',
        status: 'shipped',
        statusName: 'В пути',
        boxes: _boxes,
        trackCount: 1,
      );
      final now = DateTime(2026, 10, 14);
      final track = TrackItem(
        code: 'YT-42',
        status: 'В сборке',
        statusCode: 'in_assembly',
        date: now,
        createdAt: now,
        updatedAt: now,
        groupId: '42',
        assembly: assembly,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(api),
            authProvider.overrideWith(_Auth.new),
            brandColorsProvider.overrideWithValue(BrandColors.defaultColors),
            activeClientCodeProvider.overrideWithValue('TEST'),
            trackStatusesProvider.overrideWith((_) async => []),
            assemblyStatusesProvider.overrideWith((_) async => []),
          ],
          child: MaterialApp(
            locale: const Locale('ru'),
            supportedLocales: const [Locale('ru')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: Scaffold(
              body: TracksScreen.embedded(tracks: [track], asAssembly: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(api.trackingQueries, isEmpty);
      await tester.tap(find.text('ASM-42'));
      await tester.pumpAndSettle();
      expect(api.trackingQueries, isNotEmpty);
      expect(
        api.trackingQueries.every(
          (q) => q.length == 1 && q['assemblyId'] == 42,
        ),
        isTrue,
      );
      expect(find.text('WB-A'), findsOneWidget);
      expect(find.text('WB-B'), findsOneWidget);
      expect(find.text('Коробки № 1, 2'), findsOneWidget);
      expect(find.text('Коробки № 3'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byWidgetPredicate(
            (widget) => widget.runtimeType.toString() == '_AssemblyDetailTabs',
          ),
          matching: find.text('Места'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ClientCarrierTrackingPanel), findsOneWidget);
      for (final number in ['WB-A', 'WB-B']) {
        expect(
          find.descendant(
            of: find.byType(ClientCarrierTrackingPanel),
            matching: find.text(number),
          ),
          findsOneWidget,
        );
      }
      expect(find.text('Коробки № 1, 2'), findsOneWidget);
      expect(
        api.trackingQueries.every(
          (q) => q.length == 1 && q['assemblyId'] == 42,
        ),
        isTrue,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
