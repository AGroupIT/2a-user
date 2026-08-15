import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:twoalogisticcabineuser/src/app/router.dart';
import 'package:twoalogisticcabineuser/src/core/services/demo_mode_provider.dart';
import 'package:twoalogisticcabineuser/src/features/auth/data/auth_provider.dart';
import 'package:twoalogisticcabineuser/src/features/auth/data/partner_link_provider.dart';
import 'package:twoalogisticcabineuser/src/features/sp_finance/data/sp_organizer_models.dart';
import 'package:twoalogisticcabineuser/src/features/sp_finance/data/sp_organizer_provider.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('разделы СП собраны в stateful shell-вкладки, а не вложены в /news', () {
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(_AuthenticatedAuthNotifier.new),
        partnerLinkProvider.overrideWith(_IdlePartnerLinkNotifier.new),
        demoModeProvider.overrideWith(_EnabledDemoModeNotifier.new),
        spOrganizerCapabilitiesProvider.overrideWith(
          (ref) async => SpOrganizerCapabilities.unavailable,
        ),
      ],
    );
    final router = container.read(routerProvider);
    addTearDown(() {
      router.dispose();
      container.dispose();
    });

    final spShell = router.configuration.routes
        .whereType<StatefulShellRoute>()
        .singleWhere(
          (route) => route.branches.any(
            (branch) => branch.routes.whereType<GoRoute>().any(
              (route) => route.path == '/sp-finance',
            ),
          ),
        );
    final spBranchRoutes = spShell.branches
        .expand((branch) => branch.routes)
        .whereType<GoRoute>()
        .toList(growable: false);
    final purchasesRoute = spBranchRoutes.singleWhere(
      (route) => route.path == '/sp-finance',
    );
    final customerRoute = spBranchRoutes.singleWhere(
      (route) => route.path == '/sp-finance/customers',
    );
    final productRoute = spBranchRoutes.singleWhere(
      (route) => route.path == '/sp-finance/products',
    );
    final analyticsRoute = spBranchRoutes.singleWhere(
      (route) => route.path == '/sp-finance/analytics',
    );
    final newsRoute = router.configuration.routes
        .whereType<GoRoute>()
        .singleWhere((route) => route.path == '/news');

    expect(spShell.branches, hasLength(4));
    expect(purchasesRoute.name, 'sp-finance');
    expect(customerRoute.name, 'sp-organizer-customers');
    expect(productRoute.name, 'sp-organizer-products');
    expect(analyticsRoute.name, 'sp-organizer-analytics');

    expect(
      customerRoute.routes.whereType<GoRoute>().map((route) => route.path),
      contains(':id'),
    );
    expect(
      newsRoute.routes.whereType<GoRoute>().map((route) => route.path),
      isNot(contains('/sp-finance/customers')),
    );
    expect(
      productRoute.routes.whereType<GoRoute>().map((route) => route.path),
      contains(':id'),
    );
    expect(
      router.namedLocation('sp-organizer-customers'),
      '/sp-finance/customers',
    );
    expect(
      router.namedLocation(
        'sp-organizer-customer-detail',
        pathParameters: {'id': '42'},
      ),
      '/sp-finance/customers/42',
    );
    expect(
      router.namedLocation(
        'sp-organizer-product-detail',
        pathParameters: {'id': '42'},
      ),
      '/sp-finance/products/42',
    );
  });

  testWidgets('SP deep links reject non-canonical positive IDs without API', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(_AuthenticatedAuthNotifier.new),
        partnerLinkProvider.overrideWith(_IdlePartnerLinkNotifier.new),
        demoModeProvider.overrideWith(_EnabledDemoModeNotifier.new),
        spOrganizerCapabilitiesProvider.overrideWith(
          (ref) async => SpOrganizerCapabilities.unavailable,
        ),
      ],
    );
    final router = container.read(routerProvider);
    addTearDown(() {
      router.dispose();
      container.dispose();
    });

    router.go('/sp-finance/purchases/0');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('ru'),
          supportedLocales: const [Locale('ru'), Locale('zh')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
        ),
      ),
    );

    final cases = <String, String>{
      '/sp-finance/purchases/0': 'Некорректный ID совместной покупки',
      '/sp-finance/purchases/-1': 'Некорректный ID совместной покупки',
      '/sp-finance/purchases/+12': 'Некорректный ID совместной покупки',
      '/sp-finance/customers/0': 'Некорректный ID клиента СП',
      '/sp-finance/customers/-1': 'Некорректный ID клиента СП',
      '/sp-finance/products/0': 'Некорректный ID товара СП',
      '/sp-finance/products/-1': 'Некорректный ID товара СП',
      '/sp-finance/assemblies/0': 'Некорректный ID сборки',
      '/sp-finance/tracks/0?assemblyId=1': 'Некорректный ID трека',
      '/sp-finance/tracks/1?assemblyId=0': 'Не указана сборка для трека.',
    };
    for (final entry in cases.entries) {
      router.go(entry.key);
      await tester.pumpAndSettle();
      expect(find.textContaining(entry.value), findsWidgets, reason: entry.key);
    }
  });

  testWidgets('SP invalid deep link is localized to Chinese', (tester) async {
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(_AuthenticatedAuthNotifier.new),
        partnerLinkProvider.overrideWith(_IdlePartnerLinkNotifier.new),
        demoModeProvider.overrideWith(_EnabledDemoModeNotifier.new),
        spOrganizerCapabilitiesProvider.overrideWith(
          (ref) async => SpOrganizerCapabilities.unavailable,
        ),
      ],
    );
    final router = container.read(routerProvider);
    addTearDown(() {
      router.dispose();
      container.dispose();
    });
    router.go('/sp-finance/products/0');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('zh'),
          supportedLocales: const [Locale('ru'), Locale('zh')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('共同采购商品ID无效'), findsOneWidget);
    expect(find.textContaining('Некорректный'), findsNothing);
  });
}

class _AuthenticatedAuthNotifier extends AuthNotifier {
  @override
  AuthState build() {
    return const AuthState(
      isLoggedIn: true,
      isLoading: false,
      clientId: 1,
      userEmail: 'router-test@example.test',
      userDomain: 'router-test.example.test',
    );
  }
}

class _IdlePartnerLinkNotifier extends PartnerLinkNotifier {
  @override
  PartnerLinkState build() => const PartnerLinkState();
}

class _EnabledDemoModeNotifier extends DemoModeNotifier {
  @override
  bool build() => true;
}
