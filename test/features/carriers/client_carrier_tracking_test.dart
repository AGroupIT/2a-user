import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twoalogisticcabineuser/src/core/network/api_client.dart';
import 'package:twoalogisticcabineuser/src/core/ui/app_colors.dart';
import 'package:twoalogisticcabineuser/src/features/assemblies/domain/box.dart';
import 'package:twoalogisticcabineuser/src/features/auth/data/auth_provider.dart';
import 'package:twoalogisticcabineuser/src/features/carriers/data/client_carrier_tracking.dart';
import 'package:twoalogisticcabineuser/src/features/carriers/presentation/client_carrier_tracking_panel.dart';

const assembly = (assemblyId: 5494, invoiceId: null);
const invoice = (assemblyId: null, invoiceId: 5851);
const boxes = [
  Box(
    id: 1,
    number: 1,
    height: 0,
    width: 0,
    length: 0,
    weight: 1,
    orderNumber: 'AA-84-DY-10-14-2',
  ),
  Box(
    id: 2,
    number: 2,
    height: 0,
    width: 0,
    length: 0,
    weight: 1,
    orderNumber: 'AA-84-DY-10-14-2',
  ),
  Box(
    id: 3,
    number: 3,
    height: 0,
    width: 0,
    length: 0,
    weight: 1,
    orderNumber: 'AA-84-DY-10-14-3',
  ),
  Box(
    id: 4,
    number: 4,
    height: 0,
    width: 0,
    length: 0,
    weight: 1,
    orderNumber: 'AA-84-DY-10-14-4',
  ),
];
Map<String, dynamic> shipment({int id = 1, bool pending = false}) => {
  'id': id, 'number': 'AA-84-DY-10-14-${id + 1}',
  'boxIds': id == 1 ? [1, 2] : [3], 'placesCount': id == 1 ? 2 : 1,
  'trackedPlaces': pending ? 0 : (id == 1 ? 2 : 1),
  'arrivedPlaces': id == 1 ? 0 : 1,
  'labelRu': id == 1 ? 'Передано на таможню' : 'Прибыло на склад выдачи',
  'labelZh': id == 1 ? '已送交海关' : '已到达提货仓库',
  'trackingPending': pending, 'stale': pending,
  'updatedAt': '2026-10-26T10:42:44Z',
  'eta': '2026-11-01',
  'events': pending
      ? []
      : [
          {
            'labelRu': 'Принято на складе перевозчика',
            'labelZh': '承运商仓库已收货',
            'date': '2026-10-16',
            'timePrecision': 'date',
          },
          {
            'labelRu': 'Передано на таможню',
            'labelZh': '已送交海关',
            'date': '2026-10-24 14:30:00',
            'timePrecision': 'datetime',
          },
          {
            'labelRu': 'Ожидается прибытие',
            'labelZh': '预计到达',
            'date': '2026-11-01',
            'timePrecision': 'date',
            'isForecast': true,
          },
        ],
  // Ignore even if a future server regression adds confidential fields.
  'rate': {'amount': 'SECRET-RATE'},
  'billing': {'freightCostUsd': 'SECRET-COST'},
};
Map<String, dynamic> page() => {
  'shipments': [shipment(id: 2), shipment()],
  'summary': {'partial': true},
};

class _Auth extends AuthNotifier {
  @override
  AuthState build() =>
      const AuthState(isLoggedIn: true, isLoading: false, clientId: 10);
  void clearSession() => state = const AuthState(isLoading: false);
  void switchClient() =>
      state = const AuthState(isLoggedIn: true, isLoading: false, clientId: 20);
}

class _Api extends ApiClient {
  final requests = <Map<String, dynamic>?>[];
  Map<String, dynamic> data = page();
  Completer<Map<String, dynamic>>? pending;
  bool fail = false;
  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    expect(path, '/carriers/shipments');
    requests.add(queryParameters);
    if (fail) {
      throw DioException(
        requestOptions: RequestOptions(path: path),
        type: DioExceptionType.connectionError,
      );
    }
    final result = pending == null ? data : await pending!.future;
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
      data: result as T,
    );
  }
}

const colors = BrandColors(
  primary: Color(0xFFF35A1F),
  primaryDark: Color(0xFFEB4A12),
  primaryLight: Color(0xFFF98A32),
);
const previewKey = ValueKey('carrier-preview');

Widget panel({
  ClientCarrierTarget target = assembly,
  List<Box> localBoxes = boxes,
}) => ClientCarrierTrackingPanel(
  target: target,
  boxes: localBoxes,
  sectionBuilder: (context, child) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Движение груза',
          style: TextStyle(
            fontFamily: 'Gilroy',
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
        child,
      ],
    ),
  ),
);

Future<ProviderContainer> pump(
  WidgetTester t,
  ApiClient api, {
  String locale = 'ru',
  double width = 390,
  double textScale = 1,
  ClientCarrierTarget target = assembly,
  List<Box> localBoxes = boxes,
}) async {
  t.view.physicalSize = Size(width, 1100);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(api),
        authProvider.overrideWith(_Auth.new),
        brandColorsProvider.overrideWithValue(colors),
      ],
      child: MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: colors.primary,
          ).copyWith(primary: colors.primary, secondary: colors.primaryLight),
          fontFamily: 'Gilroy',
        ),
        locale: Locale(locale),
        supportedLocales: const [Locale('ru'), Locale('zh')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: RepaintBoundary(
            key: previewKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: panel(target: target, localBoxes: localBoxes),
            ),
          ),
        ),
      ),
    ),
  );
  await t.pump();
  return ProviderScope.containerOf(
    t.element(find.byType(ClientCarrierTrackingPanel)),
  );
}

void main() {
  setUpAll(() async {
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await (FontLoader('Gilroy')
          ..addFont(rootBundle.load('assets/fonts/gilroy/Gilroy-Regular.ttf'))
          ..addFont(rootBundle.load('assets/fonts/gilroy/Gilroy-Bold.ttf')))
        .load();
  });

  test(
    'dates preserve carrier calendar day, wall clock and forecast precision',
    () {
      expect(carrierTrackingDate('2026-10-16', dateOnly: true), '16.10.2026');
      expect(carrierTrackingDate('2026-10-24 14:30:00'), '24.10.2026 14:30');
      expect(carrierTrackingDate('invalid'), '—');
      expect(
        carrierTrackingDate('2026-10-16', dateOnly: true, local: true),
        '16.10.2026',
      );
    },
  );

  testWidgets(
    'assembly groups same-number boxes; forecast separate; no carrier costs',
    (t) async {
      final api = _Api();
      await pump(t, api);
      await t.pumpAndSettle();
      expect(api.requests, [
        {'assemblyId': 5494},
      ]);
      expect(find.text('AA-84-DY-10-14-2'), findsOneWidget);
      expect(find.text('Коробки № 1, 2'), findsOneWidget);
      expect(find.text('Коробки № 3'), findsOneWidget);
      expect(
        t.getTopLeft(find.text('AA-84-DY-10-14-2')).dy,
        lessThan(t.getTopLeft(find.text('AA-84-DY-10-14-3')).dy),
      );
      expect(find.textContaining('AA-84-DY-10-14-4'), findsOneWidget);
      await t.tap(find.text('AA-84-DY-10-14-2'));
      await t.pumpAndSettle();
      expect(find.text('16.10.2026'), findsOneWidget);
      expect(find.text('24.10.2026 14:30'), findsOneWidget);
      expect(find.text('Ожидается прибытие · прогноз'), findsOneWidget);
      expect(find.textContaining('SECRET-'), findsNothing);
      expect(find.textContaining('USD'), findsNothing);
      expect(t.takeException(), isNull);
      const destination = String.fromEnvironment('CARRIER_PREVIEW_DIR');
      if (destination.isNotEmpty) {
        await t.runAsync(() async {
          final boundary = t.renderObject<RenderRepaintBoundary>(
            find.byKey(previewKey),
          );
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '$destination/client-carrier-tracking.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    },
  );

  testWidgets(
    'invoice query scopes tracking to exact invoice and retry reads server snapshot',
    (t) async {
      final api = _Api()..fail = true;
      await pump(t, api, target: invoice);
      await t.pumpAndSettle();
      expect(api.requests.single, {'invoiceId': 5851});
      expect(find.text('Повторить'), findsOneWidget);
      api.fail = false;
      await t.tap(find.text('Повторить'));
      await t.pumpAndSettle();
      expect(api.requests.length, 2);
      expect(find.text('Коробки № 1, 2'), findsOneWidget);
    },
  );

  testWidgets(
    'disabled or unmatched integration has no empty delivery section',
    (t) async {
      final api = _Api()..data = {'shipments': []};
      await pump(t, api);
      await t.pumpAndSettle();
      expect(find.text('Движение груза'), findsNothing);
    },
  );

  testWidgets('pending first history is not described as stale', (t) async {
    final api = _Api()
      ..data = {
        'shipments': [shipment(pending: true)],
      };
    await pump(t, api);
    await t.pumpAndSettle();
    expect(find.text('Ожидается загрузка истории'), findsOneWidget);
    await t.tap(find.text('AA-84-DY-10-14-2'));
    await t.pumpAndSettle();
    expect(find.textContaining('Данные давно'), findsNothing);
    expect(find.textContaining('Обновлено:'), findsNothing);
  });

  testWidgets('partial arrival with complete tracking is not missing history', (
    t,
  ) async {
    await pump(t, _Api(), localBoxes: boxes.take(3).toList());
    await t.pumpAndSettle();
    expect(find.text('Коробки № 1, 2'), findsOneWidget);
    expect(find.text('Коробки № 3'), findsOneWidget);
    expect(find.text('Прибыло 0 из 2 мест'), findsOneWidget);
    expect(find.text('Прибыло 1 из 1 мест'), findsOneWidget);
    expect(find.textContaining('По части коробок'), findsNothing);
  });

  testWidgets('logout hides history even when old request completes later', (
    t,
  ) async {
    final completer = Completer<Map<String, dynamic>>();
    final api = _Api()..pending = completer;
    final container = await pump(t, api);
    (container.read(authProvider.notifier) as _Auth).clearSession();
    await t.pump();
    completer.complete(page());
    await t.pumpAndSettle();
    expect(find.textContaining('AA-84'), findsNothing);
    expect(find.text('Движение груза'), findsNothing);
  });

  testWidgets('switching client hides previous account history while loading', (
    t,
  ) async {
    final api = _Api();
    final container = await pump(t, api);
    await t.pumpAndSettle();
    expect(find.text('AA-84-DY-10-14-2'), findsOneWidget);
    final next = Completer<Map<String, dynamic>>();
    api.pending = next;
    (container.read(authProvider.notifier) as _Auth).switchClient();
    await t.pump();
    expect(find.textContaining('AA-84'), findsNothing);
    next.complete({'shipments': []});
    await t.pumpAndSettle();
    expect(api.requests.length, 2);
  });

  for (final locale in ['ru', 'zh']) {
    testWidgets('tracking fits narrow $locale display with large text', (
      t,
    ) async {
      await pump(t, _Api(), locale: locale, width: 320, textScale: 1.4);
      await t.pumpAndSettle();
      await t.tap(find.text('AA-84-DY-10-14-2'));
      await t.pumpAndSettle();
      expect(
        find.text(
          locale == 'ru' ? 'Принято на складе перевозчика' : '承运商仓库已收货',
        ),
        findsOneWidget,
      );
      expect(t.takeException(), isNull);
    });
  }
}
