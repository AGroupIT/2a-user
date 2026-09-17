import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:twoalogisticcabineuser/src/core/network/api_client.dart';
import 'package:twoalogisticcabineuser/src/core/ui/app_colors.dart';
import 'package:twoalogisticcabineuser/src/core/persistence/shared_preferences_provider.dart';
import 'package:twoalogisticcabineuser/src/features/clients/application/client_codes_controller.dart';
import 'package:twoalogisticcabineuser/src/features/payments/data/payment_operator_status.dart';
import 'package:twoalogisticcabineuser/src/features/self_buyout/data/self_buyout_models.dart';
import 'package:twoalogisticcabineuser/src/features/self_buyout/data/self_buyout_service.dart';
import 'package:twoalogisticcabineuser/src/features/self_buyout/presentation/self_buyout_screen.dart';
import 'package:twoalogisticcabineuser/src/features/training/application/training_tour_provider.dart';
import 'package:twoalogisticcabineuser/src/features/training/data/training_tour_controller.dart';
import 'package:twoalogisticcabineuser/src/features/training/presentation/training_target.dart';
import 'package:twoalogisticcabineuser/src/features/training/presentation/training_tour_host.dart';

const _request = SelfBuyoutRequest(
  id: 77,
  requestNumber: 'SB-TRAINING-77',
  status: 'awaiting_payment',
  clientCodeId: 20,
  requestedCnyAmount: 100,
  paymentRubAmount: 1200,
  clientCnyRubRate: 12,
  amountEnteredIn: 'cny',
);

class _TourService extends SelfBuyoutService {
  _TourService({this.available = true}) : super(ApiClient());
  final bool available;
  int writes = 0;

  @override
  Future<SelfBuyoutAvailability> getAvailability() async =>
      SelfBuyoutAvailability(
        available: available,
        reason: available ? null : 'no_rate',
        clientCnyRubRate: available ? 12 : null,
        firstExchangeActive: true,
        showFirstExchangeOnboarding: true,
        requiresAlipayExperienceAnswer: true,
      );

  @override
  Future<List<SelfBuyoutRequest>> getRequests() async => [_request];

  @override
  Future<SelfBuyoutDetail> getDetail(int requestId) async =>
      const SelfBuyoutDetail(request: _request);

  @override
  Future<SelfBuyoutRequest> createRequest({
    required int clientCodeId,
    required String amountEnteredIn,
    required double amount,
    required bool warningAccepted,
    bool? alipayTopUpExperienced,
    required Uint8List fileBytes,
    required String fileName,
    required String fileMime,
  }) async {
    writes++;
    throw StateError('Training must not create a request');
  }
}

final _boundaryKey = GlobalKey();

Future<void> _capture(WidgetTester tester, String name) async {
  final output = Platform.environment['TRAINING_RENDER_DIR'];
  if (output == null) return;
  await tester.pump();
  await tester.runAsync(() async {
    final directory = Directory(output);
    await directory.create(recursive: true);
    final boundary =
        _boundaryKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await File('$output/$name.png').writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

Future<void> _next(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('tour-next')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('tour-next')));
  await tester.pumpAndSettle();
  await tester.pump(const Duration(milliseconds: 600));
}

Future<void> _allowAutomaticAction(WidgetTester tester) async {
  for (var tick = 0; tick < 12; tick++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
  await tester.pumpAndSettle();
}

Finder _target(String id) => find.byWidgetPredicate(
  (widget) => widget is TrainingTarget && widget.id == id,
);

Future<(TrainingTourController, TrainingTargetRegistry)> _pumpTour(
  WidgetTester tester,
  _TourService service, {
  bool operatorsSleeping = false,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  if (Platform.environment['TRAINING_RENDER_DIR'] != null) {
    await (FontLoader('Gilroy')
          ..addFont(rootBundle.load('assets/fonts/gilroy/Gilroy-Regular.ttf'))
          ..addFont(rootBundle.load('assets/fonts/gilroy/Gilroy-Bold.ttf')))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  }
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final controller = TrainingTourController(preferences, scopeKey: 'test:77:A');
  final registry = TrainingTargetRegistry();
  final router = GoRouter(
    initialLocation: '/self-buyout',
    routes: [
      GoRoute(
        path: '/self-buyout',
        builder: (_, _) => const Scaffold(body: SelfBuyoutScreen()),
      ),
    ],
  );
  addTearDown(controller.dispose);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        trainingTourControllerProvider.overrideWithValue(controller),
        trainingTargetRegistryProvider.overrideWithValue(registry),
        selfBuyoutServiceProvider.overrideWithValue(service),
        activeClientCodeProvider.overrideWithValue('A-001'),
        activeClientCodeIdProvider.overrideWithValue(20),
        paymentOperatorStatusProvider.overrideWith(
          (_) => Stream.value(
            PaymentOperatorStatus(sleeping: operatorsSleeping, reachable: true),
          ),
        ),
      ],
      child: RepaintBoundary(
        key: _boundaryKey,
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            fontFamily: 'Gilroy',
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.brandOrange,
            ).copyWith(primary: AppColors.brandOrange),
            scaffoldBackgroundColor: const Color(0xFFF2F2F7),
          ),
          routerConfig: router,
          locale: const Locale('ru'),
          supportedLocales: const [Locale('ru')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          builder: (_, child) =>
              TrainingTourHost(router: router, child: child!),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  controller.start([for (var step = 1; step <= 6; step++) 'self_buyout:$step']);
  await tester.pumpAndSettle();
  await tester.pump(const Duration(milliseconds: 600));
  return (controller, registry);
}

void main() {
  for (final experienced in [false, true]) {
    testWidgets(
      'tour automatically opens form and details but waits for answer=$experienced',
      (tester) async {
        final service = _TourService();
        final (controller, registry) = await _pumpTour(tester, service);
        expect(registry.contextFor('selfbuyout.terms'), isNull);
        expect(registry.contextFor('selfbuyout.create'), isNotNull);
        await _allowAutomaticAction(tester);
        expect(find.text('QR-код для получения юаней'), findsOneWidget);
        expect(registry.contextFor('selfbuyout.instruction.continue'), isNull);
        expect(registry.contextFor('selfbuyout.experience.yes'), isNotNull);
        await _allowAutomaticAction(tester);
        expect(find.text('Новая заявка'), findsNothing);
        for (final id in [
          'selfbuyout.experience.yes',
          'selfbuyout.experience.no',
        ]) {
          expect(tester.widget<TrainingTarget>(_target(id)).onActivate, isNull);
        }
        final answer = _target(
          experienced
              ? 'selfbuyout.experience.yes'
              : 'selfbuyout.experience.no',
        );
        await tester.ensureVisible(answer);
        await tester.pumpAndSettle();
        await tester.tap(answer);
        await tester.pumpAndSettle();
        expect(
          registry.contextFor('selfbuyout.instruction.continue'),
          isNotNull,
        );
        await _allowAutomaticAction(tester);
        expect(find.text('Новая заявка'), findsOneWidget);
        expect(registry.contextFor('selfbuyout.terms'), isNotNull);
        expect(registry.contextFor('selfbuyout.requisites'), isNotNull);
        expect(registry.contextFor('selfbuyout.amount'), isNotNull);
        for (final id in [
          'selfbuyout.amount',
          'selfbuyout.requisites',
          'selfbuyout.terms',
          'selfbuyout.submit',
        ]) {
          expect(tester.widget<TrainingTarget>(_target(id)).onActivate, isNull);
        }
        if (!experienced) await _capture(tester, 'self-buyout-amount-mobile');
        final amount = find.descendant(
          of: _target('selfbuyout.amount'),
          matching: find.byType(TextField),
        );
        await tester.ensureVisible(amount);
        await tester.pumpAndSettle();
        await tester.enterText(amount, '100');
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        expect(tester.widget<TextField>(amount).controller!.text, '100');
        await _next(tester);
        expect(controller.currentId, 'self_buyout:2');
        await tester.tap(_target('selfbuyout.requisites'));
        await tester.pumpAndSettle();
        expect(find.text('Выбрать из фото'), findsOneWidget);
        expect(find.text('Выбрать из файлов'), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        await _next(tester);
        expect(controller.currentId, 'self_buyout:3');
        await tester.tap(_target('selfbuyout.terms'));
        await tester.pumpAndSettle();
        await _next(tester);
        expect(controller.currentId, 'self_buyout:4');
        expect(registry.contextFor('selfbuyout.submit'), isNotNull);
        // This is an explanation: never press the real submit button.
        await _next(tester);
        expect(controller.currentId, 'self_buyout:5');
        expect(registry.contextFor('selfbuyout.request.open'), isNull);
        expect(registry.contextFor('selfbuyout.sheet.dismiss'), isNotNull);
        await _allowAutomaticAction(tester);
        expect(registry.contextFor('selfbuyout.request.open'), isNotNull);
        // Step 5 explains the list; step 6 opens the existing request itself.
        await _allowAutomaticAction(tester);
        expect(find.text('Продолжить оплату'), findsNothing);
        await _next(tester);
        expect(controller.currentId, 'self_buyout:6');
        await _allowAutomaticAction(tester);
        expect(find.text('Продолжить оплату'), findsOneWidget);
        expect(registry.contextFor('selfbuyout.request.status'), isNotNull);
        if (!experienced) await _capture(tester, 'self-buyout-status-mobile');
        expect(service.writes, 0);
        expect(tester.takeException(), isNull);
        controller.stop();
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('sleeping operators expose an explanation instead of create', (
    tester,
  ) async {
    final service = _TourService();
    final (controller, registry) = await _pumpTour(
      tester,
      service,
      operatorsSleeping: true,
    );
    expect(registry.contextFor('selfbuyout.create'), isNull);
    expect(registry.contextFor('selfbuyout.operators.unavailable'), isNotNull);
    await _allowAutomaticAction(tester);
    expect(find.text('Новая заявка'), findsNothing);
    expect(
      tester
          .widget<TrainingTarget>(_target('selfbuyout.operators.unavailable'))
          .onActivate,
      isNull,
    );
    expect(service.writes, 0);
    controller.stop();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('missing rate does not expose an actionable create target', (
    tester,
  ) async {
    final service = _TourService(available: false);
    final (controller, registry) = await _pumpTour(tester, service);
    expect(registry.contextFor('selfbuyout.create'), isNull);
    expect(registry.contextFor('selfbuyout.create.unavailable'), isNotNull);
    await _allowAutomaticAction(tester);
    expect(
      tester
          .widget<TrainingTarget>(_target('selfbuyout.create.unavailable'))
          .onActivate,
      isNull,
    );
    expect(find.text('Новая заявка'), findsNothing);
    expect(service.writes, 0);
    controller.stop();
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
