import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:twoalogisticcabineuser/src/features/tariffs/data/tariffs_provider.dart';
import 'package:twoalogisticcabineuser/src/features/tariffs/presentation/tariffs_screen.dart';
import 'package:twoalogisticcabineuser/src/features/training/application/training_tour_provider.dart';
import 'package:twoalogisticcabineuser/src/features/training/data/training_tour_controller.dart';
import 'package:twoalogisticcabineuser/src/features/training/presentation/training_target.dart';
import 'package:twoalogisticcabineuser/src/features/training/presentation/training_tour_host.dart';
import 'package:twoalogisticcabineuser/src/features/training/presentation/training_home_invitation.dart';

// Actual TariffsScreen + actual host, with fictional provider data and no API.
// TRAINING_RENDER_DIR=/absolute/output flutter test --no-pub tools/training/render_tour_test.dart
void main() {
  testWidgets('render real-screen tour on mobile and desktop', (tester) async {
    final previousShadows = debugDisableShadows;
    debugDisableShadows = false;
    addTearDown(() => debugDisableShadows = previousShadows);
    // The real tariff hero continuously animates; settle would never finish.
    Future<void> pumpFrames() async {
      for (var frame = 0; frame < 10; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    final output = Platform.environment['TRAINING_RENDER_DIR'];
    expect(output, isNotNull, reason: 'Set TRAINING_RENDER_DIR');
    final directory = Directory(output!);
    await tester.runAsync(() => directory.create(recursive: true));
    // Explicit flutter_test harness outside test/.
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    final controller = TrainingTourController(
      await SharedPreferences.getInstance(),
      scopeKey: 'visual-only',
    );
    addTearDown(controller.dispose);
    await (FontLoader('Gilroy')
          ..addFont(rootBundle.load('assets/fonts/gilroy/Gilroy-Regular.ttf'))
          ..addFont(rootBundle.load('assets/fonts/gilroy/Gilroy-Bold.ttf')))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    final router = GoRouter(
      initialLocation: '/tariffs',
      routes: [
        GoRoute(
          path: '/tariffs',
          builder: (_, _) => const Scaffold(
            body: TrainingTarget(id: 'route.tariffs', child: TariffsScreen()),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    final boundaryKey = GlobalKey();
    final lightBrand = ValueNotifier<bool>(false);
    addTearDown(lightBrand.dispose);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trainingTourControllerProvider.overrideWithValue(controller),
          userTariffsProvider.overrideWith(
            (_) async => const UserTariffsData(
              deliveryTariffs: [
                UserDeliveryTariff(
                  id: 1,
                  name: 'Учебный тариф',
                  baseCost: 4,
                  allowedItems:
                      'Демонстрационные данные для проверки интерфейса',
                  weightTiers: [
                    UserWeightTier(minWeight: 0, maxWeight: 50, pricePerKg: 4),
                    UserWeightTier(minWeight: 50, pricePerKg: 3.5),
                  ],
                ),
              ],
              packagingTypes: [
                UserPackagingType(id: 1, name: 'Учебная упаковка', baseCost: 2),
              ],
            ),
          ),
        ],
        child: RepaintBoundary(
          key: boundaryKey,
          child: ValueListenableBuilder<bool>(
            valueListenable: lightBrand,
            builder: (_, light, _) => MaterialApp.router(
              debugShowCheckedModeBanner: false,
              routerConfig: router,
              locale: const Locale('ru'),
              supportedLocales: const [Locale('ru'), Locale('zh')],
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              theme: ThemeData(
                colorScheme: light
                    ? ColorScheme.fromSeed(
                        seedColor: Colors.amber,
                      ).copyWith(primary: const Color(0xFFFFE8A3))
                    : ColorScheme.fromSeed(seedColor: const Color(0xFF6B7280)),
                scaffoldBackgroundColor: const Color(0xFFF2F2F7),
                fontFamily: 'Gilroy',
                useMaterial3: true,
              ),
              builder: (_, child) =>
                  TrainingTourHost(router: router, child: child!),
            ),
          ),
        ),
      ),
    );
    await pumpFrames();
    controller.start(['tariffs:0']);
    await pumpFrames();
    await tester.pump(const Duration(milliseconds: 500));
    await pumpFrames();

    Future<void> capture(String name) async {
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final boundary =
            boundaryKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '${directory.path}/$name.png',
        ).writeAsBytes(png!.buffer.asUint8List());
        image.dispose();
      });
    }

    expect(find.byKey(const Key('tour-spotlight')), findsOneWidget);
    await capture('07-tour-tariffs-mobile');
    lightBrand.value = true;
    await pumpFrames();
    await capture('11-tour-light-brand');
    lightBrand.value = false;
    await pumpFrames();
    await tester.tap(find.byKey(const Key('tour-collapse')));
    await pumpFrames();
    await capture('08-tour-collapsed-mobile');
    await tester.tap(find.byKey(const Key('tour-collapse')));
    tester.view.physicalSize = const Size(1024, 900);
    await pumpFrames();
    await tester.pump(const Duration(milliseconds: 500));
    await pumpFrames();
    await capture('09-tour-tariffs-desktop');
    controller.next();
    await pumpFrames();
    await capture('10-tour-completed');
    await controller.settled;
    await tester.pumpWidget(const SizedBox.shrink());
    tester.view.physicalSize = const Size(390, 844);
    final preferences = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: const Locale('ru'),
          supportedLocales: const [Locale('ru'), Locale('zh')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF6B7280),
            ),
            scaffoldBackgroundColor: const Color(0xFFF2F2F7),
            fontFamily: 'Gilroy',
            useMaterial3: true,
          ),
          home: Scaffold(
            body: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: TrainingInvitationCard(
                  preferences: preferences,
                  accountKey: 'visual-invitation',
                  onStart: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await capture('12-home-invitation-mobile');
    tester.view.physicalSize = const Size(1024, 900);
    await tester.pumpAndSettle();
    await capture('13-home-invitation-desktop');
    await tester.pumpWidget(const SizedBox.shrink());
    debugDisableShadows = previousShadows;
  });
}
