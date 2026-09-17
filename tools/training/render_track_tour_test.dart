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
import 'package:twoalogisticcabineuser/src/features/tracks/presentation/widgets/client_track_compact_card.dart';
import 'package:twoalogisticcabineuser/src/features/training/application/training_tour_provider.dart';
import 'package:twoalogisticcabineuser/src/features/training/data/training_tour_controller.dart';
import 'package:twoalogisticcabineuser/src/features/training/presentation/training_tour_host.dart';

// Actual compact card and tour, fictional data and no API or business writes.
void main() {
  testWidgets('render exact return and transfer buttons', (tester) async {
    final output = Platform.environment['TRAINING_RENDER_DIR'];
    expect(output, isNotNull);
    final directory = Directory(output!);
    await tester.runAsync(() => directory.create(recursive: true));
    final previousShadows = debugDisableShadows;
    debugDisableShadows = false;
    addTearDown(() => debugDisableShadows = previousShadows);
    // Explicit visual helper outside test/.
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    final controller = TrainingTourController(
      await SharedPreferences.getInstance(),
      scopeKey: 'visual-track',
    );
    addTearDown(controller.dispose);
    await (FontLoader('Gilroy')
          ..addFont(rootBundle.load('assets/fonts/gilroy/Gilroy-Regular.ttf'))
          ..addFont(rootBundle.load('assets/fonts/gilroy/Gilroy-Bold.ttf')))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    var businessActions = 0;
    final router = GoRouter(
      initialLocation: '/tracks',
      routes: [
        GoRoute(
          path: '/tracks',
          builder: (_, _) => Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 80, 16, 16),
              child: ClientTrackCompactCard(
                trackNumber: 'TRAINING-001',
                status: 'На складе',
                statusColor: Colors.green,
                productName: 'Учебная посылка',
                selectable: true,
                selected: false,
                onToggleSelection: () => businessActions++,
                onCopyTrack: () {},
                onOpenDetails: (_) {},
                indicators: const [],
                actions: [
                  ClientTrackQuickAction(
                    icon: Icons.swap_horiz,
                    label: 'Перенести',
                    trainingTargetId: 'track.transfer',
                    onTap: () => businessActions++,
                  ),
                  ClientTrackQuickAction(
                    icon: Icons.assignment_return,
                    label: 'Возврат',
                    trainingTargetId: 'track.return',
                    onTap: () => businessActions++,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    final boundaryKey = GlobalKey();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trainingTourControllerProvider.overrideWithValue(controller),
        ],
        child: RepaintBoundary(
          key: boundaryKey,
          child: MaterialApp.router(
            debugShowCheckedModeBanner: false,
            routerConfig: router,
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
            builder: (_, child) =>
                TrainingTourHost(router: router, child: child!),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    controller.start(['track_actions:3', 'track_actions:4']);
    Future<void> capture(String name) async {
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('tour-spotlight')), findsOneWidget);
      await tester.runAsync(() async {
        final boundary =
            boundaryKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '${directory.path}/$name.png',
        ).writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
    }

    await capture('14-exact-return-button');
    controller.next();
    await capture('15-exact-transfer-button');
    expect(businessActions, 0);
    await controller.settled;
    await tester.pumpWidget(const SizedBox.shrink());
    debugDisableShadows = previousShadows;
  });
}
