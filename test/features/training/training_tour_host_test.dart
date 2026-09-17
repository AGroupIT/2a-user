import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:twoalogisticcabineuser/src/features/training/application/training_tour_provider.dart';
import 'package:twoalogisticcabineuser/src/features/training/data/training_tour_controller.dart';
import 'package:twoalogisticcabineuser/src/features/training/presentation/training_target.dart';
import 'package:twoalogisticcabineuser/src/features/training/presentation/training_tour_host.dart';
import 'package:twoalogisticcabineuser/src/features/training/presentation/training_tour_overlay.dart';

class _ControllerSlot extends Notifier<TrainingTourController?> {
  @override
  TrainingTourController? build() => null;

  void replace(TrainingTourController? controller) => state = controller;
}

final _controllerSlotProvider =
    NotifierProvider<_ControllerSlot, TrainingTourController?>(
      _ControllerSlot.new,
    );

class _DraftPage extends StatefulWidget {
  final VoidCallback onMount;
  final VoidCallback onDispose;

  const _DraftPage({required this.onMount, required this.onDispose});

  @override
  State<_DraftPage> createState() => _DraftPageState();
}

class _DraftPageState extends State<_DraftPage> {
  final controller = TextEditingController();
  int localActions = 0;

  @override
  void initState() {
    super.initState();
    widget.onMount();
  }

  @override
  void dispose() {
    widget.onDispose();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: TrainingTarget(
      id: 'route.home',
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(key: const Key('unsaved-draft'), controller: controller),
            TextButton(
              key: const Key('page-local-action'),
              onPressed: () => setState(() => localActions++),
              child: const Text('Локальное действие'),
            ),
          ],
        ),
      ),
    ),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'host preserves the Router page and unsaved text through tour and account changes',
    (tester) async {
      final preferences = await SharedPreferences.getInstance();
      final first = TrainingTourController(
        preferences,
        scopeKey: 'company:17:A',
      );
      final second = TrainingTourController(
        preferences,
        scopeKey: 'company:18:B',
      );
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      final container = ProviderContainer(
        overrides: [
          trainingTourControllerProvider.overrideWith(
            (ref) => ref.watch(_controllerSlotProvider),
          ),
        ],
      );
      addTearDown(container.dispose);
      var mounts = 0;
      var disposals = 0;
      // cabinet:0 uses the production home route '/'. Stay on it so navigation
      // cannot conceal a host-induced remount of the Router subtree.
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => _DraftPage(
              onMount: () => mounts++,
              onDispose: () => disposals++,
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
            locale: const Locale('ru'),
            supportedLocales: const [Locale('ru'), Locale('zh')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            builder: (context, child) =>
                TrainingTourHost(router: router, child: child!),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final originalState = tester.state<_DraftPageState>(
        find.byType(_DraftPage),
      );
      await tester.enterText(
        find.byKey(const Key('unsaved-draft')),
        'Unsent parcel notes',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();

      void expectDraftPreserved() {
        expect(
          identical(
            tester.state<_DraftPageState>(find.byType(_DraftPage)),
            originalState,
          ),
          isTrue,
        );
        expect(originalState.mounted, isTrue);
        expect(originalState.controller.text, 'Unsent parcel notes');
        expect(mounts, 1);
        expect(disposals, 0);
        expect(router.routeInformationProvider.value.uri.path, '/');
        expect(tester.takeException(), isNull);
      }

      final slot = container.read(_controllerSlotProvider.notifier);
      slot.replace(first);
      await tester.pumpAndSettle();
      expectDraftPreserved();
      first.start(['cabinet:0']);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byKey(const Key('training-coach-card')), findsOneWidget);
      expectDraftPreserved();
      expect(originalState.localActions, 0);
      final pageAction = find.byKey(const Key('page-local-action'));
      expect(pageAction.hitTestable(), findsOneWidget);
      await tester.tap(pageAction);
      await tester.pumpAndSettle();
      expect(
        originalState.localActions,
        1,
        reason: 'the host overlay must pass taps through to the Router page',
      );
      expectDraftPreserved();

      first.stop();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('training-coach-card')), findsNothing);
      expectDraftPreserved();

      first.start(['cabinet:0']);
      await tester.pumpAndSettle();
      slot.replace(second);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('training-coach-card')), findsNothing);
      expectDraftPreserved();
      second.start(['cabinet:0']);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('training-coach-card')), findsOneWidget);
      expectDraftPreserved();

      first.stop();
      await tester.pumpAndSettle();
      expect(second.active, isTrue);
      expect(find.byKey(const Key('training-coach-card')), findsOneWidget);
      expectDraftPreserved();
      slot.replace(null);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('training-coach-card')), findsNothing);
      expectDraftPreserved();
      await Future.wait([first.settled, second.settled]);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(disposals, 1);
    },
  );

  testWidgets('host follows imperative detail pushes and pops after layout', (
    tester,
  ) async {
    final controller = TrainingTourController(
      await SharedPreferences.getInstance(),
      scopeKey: 'route-test',
    );
    controller.start(['organizer:1']);
    final container = ProviderContainer(
      overrides: [trainingTourControllerProvider.overrideWithValue(controller)],
    );
    final router = GoRouter(
      initialLocation: '/sp-finance',
      routes: [
        GoRoute(
          path: '/sp-finance',
          builder: (context, state) => Scaffold(
            body: TrainingTarget(
              id: 'organizer.open',
              child: TextButton(
                key: const Key('open-purchase'),
                onPressed: () => context.push('/sp-finance/purchases/11'),
                child: const Text('Закупка'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/sp-finance/purchases/:id',
          builder: (context, state) => const Scaffold(
            body: TrainingTarget(
              id: 'organizer.tab.participants',
              child: Text('Участники'),
            ),
          ),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const Scaffold(body: Text('Профиль')),
        ),
      ],
    );
    addTearDown(controller.dispose);
    addTearDown(container.dispose);
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('ru'),
          supportedLocales: const [Locale('ru'), Locale('zh')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          builder: (context, child) =>
              TrainingTourHost(router: router, child: child!),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('open-purchase')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      tester
          .widget<TrainingTourOverlay>(find.byType(TrainingTourOverlay))
          .currentPath,
      '/sp-finance/purchases/11',
    );
    expect(find.byKey(const Key('tour-spotlight')), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('tour-next'))).onPressed,
      isNotNull,
    );
    router.push('/profile');
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TrainingTourOverlay>(find.byType(TrainingTourOverlay))
          .currentPath,
      '/profile',
    );
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('tour-next'))).onPressed,
      isNull,
    );
    router.pop();
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TrainingTourOverlay>(find.byType(TrainingTourOverlay))
          .currentPath,
      '/sp-finance/purchases/11',
    );
    router.pop();
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TrainingTourOverlay>(find.byType(TrainingTourOverlay))
          .currentPath,
      '/sp-finance',
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await controller.settled;
  });

  test(
    'service access distinguishes loading, failure, allowed and unavailable',
    () {
      var checks = 0;
      bool allowed(bool value) {
        checks++;
        return value;
      }

      expect(
        trainingAccess(const AsyncLoading<bool>(), allowed),
        TrainingServiceAccess.checking,
      );
      expect(
        trainingAccess(
          AsyncError<bool>(StateError('offline'), StackTrace.current),
          allowed,
        ),
        TrainingServiceAccess.failed,
      );
      expect(
        checks,
        0,
        reason: 'absence or failure must not evaluate availability',
      );
      expect(
        trainingAccess(const AsyncData(true), allowed),
        TrainingServiceAccess.available,
      );
      expect(
        trainingAccess(const AsyncData(false), allowed),
        TrainingServiceAccess.unavailable,
      );
      expect(checks, 2);
    },
  );
}
