import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:twoalogisticcabineuser/src/app/router.dart';
import 'package:twoalogisticcabineuser/src/features/auth/data/auth_provider.dart';

class _Auth extends AuthNotifier {
  @override
  AuthState build() =>
      const AuthState(isLoggedIn: true, isLoading: false, clientId: 17);
}

Page<void> _withTestChild(Page<dynamic> configuredPage, Widget child) {
  // Exercise the registered production page builders without loading business
  // data. The real navigator, global keys and route transition lifecycle remain.
  expect(configuredPage, isA<NoTransitionPage<void>>());
  return NoTransitionPage<void>(key: configuredPage.key, child: child);
}

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final redirectPath in ['/splash', '/login']) {
      testWidgets('shell survives rapid $redirectPath redirect on $platform', (
        t,
      ) async {
        SharedPreferences.setMockInitialValues({});
        final container = ProviderContainer(
          overrides: [authProvider.overrideWith(_Auth.new)],
        );
        final productionRouter = container.read(routerProvider);
        final routes = productionRouter.configuration.routes;
        final authRoute = routes.whereType<GoRoute>().firstWhere(
          (r) => r.path == redirectPath,
        );
        final shellRoute = routes.whereType<StatefulShellRoute>().first;
        addTearDown(() {
          productionRouter.dispose();
          container.dispose();
        });
        final loading = ValueNotifier(false);
        final router = GoRouter(
          refreshListenable: loading,
          redirect: (context, state) => loading.value
              ? state.uri.path == redirectPath
                    ? null
                    : redirectPath
              : state.uri.path == redirectPath
              ? '/'
              : null,
          routes: [
            GoRoute(
              path: redirectPath,
              pageBuilder: (context, state) => _withTestChild(
                authRoute.pageBuilder!(context, state),
                const Scaffold(body: Text('Loading')),
              ),
            ),
            StatefulShellRoute.indexedStack(
              pageBuilder: (context, state, shell) => _withTestChild(
                shellRoute.pageBuilder!(context, state, shell),
                Scaffold(
                  body: AnimatedPadding(
                    duration: const Duration(milliseconds: 260),
                    padding: const EdgeInsets.only(top: 62),
                    child: shell,
                  ),
                ),
              ),
              branches: [
                StatefulShellBranch(
                  routes: [
                    GoRoute(
                      path: '/',
                      builder: (_, _) => const Center(child: Text('Home')),
                    ),
                  ],
                ),
              ],
            ),
          ],
        );
        addTearDown(router.dispose);
        addTearDown(loading.dispose);
        await t.pumpWidget(
          MaterialApp.router(
            theme: ThemeData(platform: platform),
            routerConfig: router,
          ),
        );
        await t.pumpAndSettle();
        for (var i = 0; i < 3; i++) {
          loading.value = true;
          await t.pump();
          await t.pump(const Duration(milliseconds: 20));
          loading.value = false;
          await t.pump();
          await t.pump(const Duration(milliseconds: 20));
        }
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        expect(find.text('Home'), findsOneWidget);
      });
    }
  }
}
