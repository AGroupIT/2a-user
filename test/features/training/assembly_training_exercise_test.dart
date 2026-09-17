import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:twoalogisticcabineuser/src/core/persistence/shared_preferences_provider.dart';
import 'package:twoalogisticcabineuser/src/features/auth/data/auth_provider.dart';
import 'package:twoalogisticcabineuser/src/features/clients/application/client_codes_controller.dart';
import 'package:twoalogisticcabineuser/src/features/tracks/presentation/tracks_screen.dart';
import 'package:twoalogisticcabineuser/src/features/tracks/presentation/widgets/client_track_compact_card.dart';
import 'package:twoalogisticcabineuser/src/features/training/application/assembly_training_provider.dart';
import 'package:twoalogisticcabineuser/src/features/training/application/training_tour_provider.dart';
import 'package:twoalogisticcabineuser/src/features/training/data/assembly_training_session.dart';
import 'package:twoalogisticcabineuser/src/features/training/data/training_progress.dart';
import 'package:twoalogisticcabineuser/src/features/training/presentation/assembly_practice_screen.dart';
import 'package:twoalogisticcabineuser/src/features/training/presentation/assembly_practice_steps.dart';
import 'package:twoalogisticcabineuser/src/features/training/presentation/training_target.dart';
import 'package:twoalogisticcabineuser/src/features/training/presentation/training_tour_host.dart';

class _Auth extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
    isLoggedIn: true,
    isLoading: false,
    clientId: 17,
    userDomain: 'real-account',
  );
}

void main() {
  for (final width in [390.0, 1280.0]) {
    testWidgets('actual assembly practice end to end at $width', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'active_client_code': 'REAL-CODE',
      });
      final prefs = await SharedPreferences.getInstance();
      await initializeDateFormatting('ru');
      await (FontLoader('Gilroy')
            ..addFont(rootBundle.load('assets/fonts/gilroy/Gilroy-Regular.ttf'))
            ..addFont(rootBundle.load('assets/fonts/gilroy/Gilroy-Bold.ttf')))
          .load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authProvider.overrideWith(_Auth.new),
          activeClientCodeProvider.overrideWithValue('REAL-CODE'),
        ],
      );
      addTearDown(container.dispose);
      final mainTour = container.read(trainingTourControllerProvider)!;
      mainTour.start(['cabinet:0', 'cabinet:1'], initialStepId: 'cabinet:1');
      mainTour.stop();
      await mainTour.settled;
      final router = GoRouter(
        initialLocation: assemblyPracticeRoute,
        routes: [
          GoRoute(
            path: assemblyPracticeRoute,
            builder: (_, _) => const Scaffold(body: AssemblyPracticeScreen()),
          ),
          GoRoute(
            path: '/training',
            builder: (_, _) => const Scaffold(body: Text('Catalog')),
          ),
        ],
      );
      addTearDown(router.dispose);
      final boundary = GlobalKey();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            theme: ThemeData(fontFamily: 'Gilroy'),
            routerConfig: router,
            locale: const Locale('ru'),
            supportedLocales: const [Locale('ru'), Locale('zh')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            builder: (_, child) => RepaintBoundary(
              key: boundary,
              child: TrainingTourHost(router: router, child: child!),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final session = container.read(assemblyTrainingSessionProvider);
      final registry = container.read(trainingTargetRegistryProvider);
      final controller = container.read(assemblyPracticeControllerProvider)!;
      Future<void> tick() async {
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();
      }

      Finder target(String id) {
        final context = registry.contextFor(id);
        expect(
          context,
          isNotNull,
          reason: 'Target $id at ${controller.currentId}',
        );
        return find.byWidget(context!.widget);
      }

      Future<void> tapTarget(String id) async {
        final finder = target(id);
        await tester.ensureVisible(finder);
        await tick();
        await tester.tap(finder);
        await tick();
      }

      Future<void> capture(String name) async {
        final output = Platform.environment['TRAINING_RENDER_DIR'];
        if (output == null) return;
        await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final dir = Directory(output);
          await dir.create(recursive: true);
          await File(
            '${dir.path}/${width.toInt()}-$name.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      expect(find.byType(TracksScreen), findsOneWidget);
      expect(find.byType(ClientTrackCompactCard), findsNWidgets(3));
      expect(session.assemblyCreated, isFalse);
      await capture('01-select-tracks');
      final cards = find.byType(ClientTrackCompactCard);
      for (final code in assemblyTrainingTrackCodes.take(2)) {
        final card = find.byWidgetPredicate(
          (widget) =>
              widget is ClientTrackCompactCard && widget.trackNumber == code,
        );
        final checkbox = find.descendant(
          of: card,
          matching: find.byKey(const ValueKey('client-track-selection')),
        );
        await tester.ensureVisible(checkbox);
        await tester.tap(checkbox);
        await tick();
      }
      expect(cards, findsNWidgets(3));
      expect(controller.currentId, 'assembly_practice:1');
      await tapTarget('assembly.submit');
      expect(controller.currentId, 'assembly_practice:2');
      await capture('02-real-tariff');
      await tester.ensureVisible(find.byKey(const Key('tour-next')));
      await tester.tap(find.byKey(const Key('tour-next')));
      await tick();
      expect(controller.currentId, 'assembly_practice:3');
      final description = find.descendant(
        of: target('assembly.goods-description'),
        matching: find.byType(TextField),
      );
      await tester.ensureVisible(description);
      await tester.enterText(description, 'Футболки, 2 шт.; носки, 3 пары');
      tester.testTextInput.hide();
      await tick();
      await capture('03-real-description');
      await tapTarget('assembly.wizard.next.0');
      expect(controller.currentId, 'assembly_practice:4');
      await tapTarget('assembly.places.single_if_possible');
      await capture('04-real-places');
      await tapTarget('assembly.wizard.next.1');
      expect(controller.currentId, 'assembly_practice:5');
      await tapTarget('assembly.packaging');
      await capture('05-real-packaging');
      await tapTarget('assembly.wizard.next.2');
      expect(controller.currentId, 'assembly_practice:6');
      expect(session.assemblyCreated, isFalse);
      await capture('06-real-review');
      await tapTarget('assembly.review');
      expect(session.assemblyCreated, isTrue);
      expect(
        session.submittedPayload!['trackIds'],
        assemblyTrainingTrackIds.take(2).toList(),
      );
      expect(controller.currentId, 'assembly_practice:7');
      await tapTarget('tracks.view.groups');
      expect(controller.currentId, 'assembly_practice:8');
      await capture('07-created-list');
      await tapTarget('assembly.open');
      expect(controller.currentId, 'assembly_practice:9');
      await capture('08-created-details');
      await tester.ensureVisible(find.byKey(const Key('tour-next')));
      await tester.tap(find.byKey(const Key('tour-next')));
      await tick();
      expect(controller.complete, isTrue);
      expect(
        TrainingProgressStore(
          prefs,
          accountKey: 'real-account:17',
        ).read().statuses['assembly'],
        TrainingLessonStatus.practiced,
      );
      expect(prefs.getString('active_client_code'), 'REAL-CODE');
      expect(session.rejectedRequests, isEmpty);
      await tester.tap(find.byKey(const Key('tour-exit')));
      await tick();
      expect(find.text('Catalog'), findsOneWidget);
      expect(container.read(activeClientCodeProvider), 'REAL-CODE');
      expect(mainTour.resumeId, 'cabinet:1');
      router.go(assemblyPracticeRoute);
      await tick();
      final restarted = container.read(assemblyTrainingSessionProvider);
      expect(identical(restarted, session), isFalse);
      expect(restarted.assemblyCreated, isFalse);
      expect(restarted.submittedPayload, isNull);
      expect(find.byType(ClientTrackCompactCard), findsNWidgets(3));
      await tester.tap(find.byKey(const Key('tour-exit')));
      await tick();
      expect(find.text('Catalog'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 600));
    });
  }
}
