import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:twoalogisticcabineuser/src/app/router.dart';
import 'package:twoalogisticcabineuser/src/core/network/api_client.dart';
import 'package:twoalogisticcabineuser/src/features/auth/data/auth_provider.dart';
import 'package:twoalogisticcabineuser/src/features/auth/data/client_partner_invite_provider.dart';
import 'package:twoalogisticcabineuser/src/features/auth/presentation/auth_visuals.dart';
import 'package:twoalogisticcabineuser/src/features/auth/presentation/client_partner_invite_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const token =
      '123e4567-e89b-12d3-a456-426614174000.1.AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';

  testWidgets('публичная партнёрская ссылка ведёт в защищённую регистрацию', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final api = _InviteApiClient();
    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(api),
        authProvider.overrideWith(_LoggedOutAuthNotifier.new),
      ],
    );
    final router = container.read(routerProvider);
    router.go('/client-partner/invite/$token');
    addTearDown(() {
      router.dispose();
      container.dispose();
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    for (var attempt = 0; attempt < 30; attempt += 1) {
      if (container.read(clientPartnerInviteProvider).isValidated) break;
      await tester.pump(const Duration(milliseconds: 30));
    }
    await tester.pump(const Duration(milliseconds: 350));
    final inviteState = container.read(clientPartnerInviteProvider);
    expect(
      inviteState.isValidated,
      isTrue,
      reason: '${inviteState.phase}: ${inviteState.error}',
    );

    expect(
      router.routeInformationProvider.value.uri.path,
      contains('/client-partner/invite/'),
    );
    expect(find.text('Ссылка подтверждена'), findsOneWidget);
    expect(find.text('Партнёр Иван'), findsOneWidget);
    expect(find.text('Agent A'), findsNWidgets(2));
    final brandedTheme = Theme.of(tester.element(find.byType(FilledButton)));
    expect(brandedTheme.colorScheme.primary, const Color(0xFF123456));
    expect(brandedTheme.colorScheme.secondary, const Color(0xFFABCDEF));

    final registerButton = find.text('Зарегистрироваться');
    await tester.ensureVisible(registerButton);
    await tester.pump();
    await tester.tap(registerButton);
    await tester.pump(const Duration(milliseconds: 50));
    expect(router.routeInformationProvider.value.uri.path, '/register');
    expect(
      container.read(clientPartnerInviteProvider).hasPendingInvite,
      isTrue,
    );
    final key = container
        .read(clientPartnerInviteProvider)
        .registrationIdempotencyKey;

    router.go('/client-partner/invite/$token');
    for (var attempt = 0; attempt < 30; attempt += 1) {
      await tester.pump(const Duration(milliseconds: 30));
      if (api.requestedPaths.length == 2 &&
          container.read(clientPartnerInviteProvider).isValidated) {
        break;
      }
    }
    expect(api.requestedPaths, hasLength(2));
    expect(
      container.read(clientPartnerInviteProvider).registrationIdempotencyKey,
      key,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('ZH retry работает на 320 px, неверные цвета дают fallback', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final api = _InviteApiClient(
      failFirst: true,
      colorPrimary: 'javascript:alert(1)',
      colorSecondary: '#12',
    );
    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(api),
        authProvider.overrideWith(_LoggedOutAuthNotifier.new),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          locale: Locale('zh'),
          supportedLocales: [Locale('ru'), Locale('zh')],
          localizationsDelegates: [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: ClientPartnerInviteScreen(token: token),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('合作伙伴邀请'), findsOneWidget);
    expect(find.text('无法验证合作伙伴邀请链接'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('重试'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('邀请链接已验证'), findsOneWidget);
    expect(find.text('注册'), findsOneWidget);
    final fallbackTheme = Theme.of(tester.element(find.byType(FilledButton)));
    expect(fallbackTheme.colorScheme.primary, AuthVisuals.fallbackPrimary);
    expect(fallbackTheme.colorScheme.secondary, AuthVisuals.fallbackSecondary);
    expect(api.requestedPaths, hasLength(2));
    expect(tester.takeException(), isNull);
  });
}

class _LoggedOutAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(isLoggedIn: false, isLoading: false);
}

class _InviteApiClient extends ApiClient {
  _InviteApiClient({
    this.failFirst = false,
    this.colorPrimary = '#123456',
    this.colorSecondary = '#ABCDEF',
  });

  final bool failFirst;
  final String colorPrimary;
  final String colorSecondary;
  final requestedPaths = <String>[];
  var _attempt = 0;

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    requestedPaths.add(path);
    _attempt += 1;
    if (failFirst && _attempt == 1) {
      throw DioException(requestOptions: RequestOptions(path: path));
    }
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
      data:
          {
                'data': {
                  'partnerName': 'Партнёр Иван',
                  'agentName': 'Agent A',
                  'agentDomain': 'agent-a.test',
                  'colorPrimary': colorPrimary,
                  'colorSecondary': colorSecondary,
                  'prefix': 'PA',
                  'shortCode': 'ABCDEFGH',
                },
              }
              as T,
    );
  }
}
