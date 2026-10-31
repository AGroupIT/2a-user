import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twoalogisticcabineuser/src/core/network/api_client.dart';
import 'package:twoalogisticcabineuser/src/core/ui/app_colors.dart';
import 'package:twoalogisticcabineuser/src/features/auth/data/auth_provider.dart';
import 'package:twoalogisticcabineuser/src/features/self_buyout/data/self_buyout_models.dart';
import 'package:twoalogisticcabineuser/src/features/clients/application/client_codes_controller.dart';
import 'package:twoalogisticcabineuser/src/features/garage/application/garage_providers.dart';
import 'package:twoalogisticcabineuser/src/features/more/presentation/more_sheet.dart';
import 'package:twoalogisticcabineuser/src/features/partner_program/data/client_partner_program_provider.dart';
import 'package:twoalogisticcabineuser/src/features/profile/data/profile_provider.dart';
import 'package:twoalogisticcabineuser/src/features/self_buyout/data/self_buyout_service.dart';

class _MenuAuth extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
    isLoggedIn: true,
    isLoading: false,
    clientId: 41,
    userDomain: 'synthetic.test',
  );
}

class _MenuApi implements ApiClient {
  int tokenReads = 0;
  @override
  String get activeBaseUrl => 'https://synthetic.test/api';
  @override
  Future<String?> getToken() async {
    tokenReads++;
    return 'synthetic-token';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('No network expected');
}

void main() {
  group('shouldShowManualUpdateMenu', () {
    test('shows update check for direct Android builds', () {
      expect(
        shouldShowManualUpdateMenu(
          isAndroid: true,
          isRustoreDistribution: false,
        ),
        isTrue,
      );
    });

    test('hides update check for RuStore Android builds', () {
      expect(
        shouldShowManualUpdateMenu(
          isAndroid: true,
          isRustoreDistribution: true,
        ),
        isFalse,
      );
    });

    test('hides update check outside Android', () {
      expect(
        shouldShowManualUpdateMenu(
          isAndroid: false,
          isRustoreDistribution: false,
        ),
        isFalse,
      );
    });
  });

  testWidgets(
    'iOS translator sits right of self-buyout and keeps session owner mounted',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const channel = MethodChannel('com.twoalogistic.user/screen_translation');
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        calls.add(call);
        return true;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      final api = _MenuApi();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(api),
            authProvider.overrideWith(_MenuAuth.new),
            activeClientCodeProvider.overrideWithValue(null),
            clientProfileProvider.overrideWithValue(const AsyncData(null)),
            selfBuyoutAvailabilityProvider.overrideWithValue(
              const AsyncData(
                SelfBuyoutAvailability(
                  available: true,
                  firstExchangeActive: false,
                  showFirstExchangeOnboarding: false,
                  requiresAlipayExperienceAnswer: false,
                ),
              ),
            ),
            garageAvailabilityProvider.overrideWithValue(const AsyncLoading()),
            clientPartnerProgramProvider.overrideWithValue(
              const AsyncData(null),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: MoreSheet(screenTranslationEnabled: true)),
          ),
        ),
      );
      await tester.pump();
      final selfBuyout = tester.getCenter(find.text('Самовыкуп'));
      final translator = tester.getCenter(find.text('Переводчик'));
      expect(translator.dx, greaterThan(selfBuyout.dx));
      expect(translator.dy, closeTo(selfBuyout.dy, 0.1));
      expect(api.tokenReads, 0);
      expect(calls, isEmpty);
      await tester.tap(find.text('Переводчик'));
      await tester.pump();
      expect(find.byType(MoreSheet), findsOneWidget);
      expect(api.tokenReads, 1);
      expect(calls.map((call) => call.method), ['present']);
      expect(calls.single.arguments, {
        'endpoint': 'https://synthetic.test/api/screen-translate/v1',
        'accessToken': 'synthetic-token',
        'appearance': {
          'primary': Theme.of(
            tester.element(find.byType(MoreSheet)),
          ).colorScheme.primary.toARGB32(),
          'secondary': Theme.of(
            tester.element(find.byType(MoreSheet)),
          ).colorScheme.secondary.toARGB32(),
          'gradientStart': tester
              .element(find.byType(MoreSheet))
              .brandGradient
              .colors
              .first
              .toARGB32(),
          'language': 'en',
        },
      });
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(calls.map((call) => call.method), ['present', 'stop']);
      await tester.pump(const Duration(seconds: 10));
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'Android hides translator even when enabled without auth API or channel access',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const channel = MethodChannel('com.twoalogistic.user/screen_translation');
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        calls.add(call);
        return true;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWith(
              (ref) =>
                  throw StateError('Disabled translator must not read API'),
            ),
            authProvider.overrideWith(
              () => throw StateError('Disabled translator must not read auth'),
            ),
            activeClientCodeProvider.overrideWithValue(null),
            clientProfileProvider.overrideWithValue(const AsyncData(null)),
            selfBuyoutAvailabilityProvider.overrideWithValue(
              const AsyncLoading(),
            ),
            garageAvailabilityProvider.overrideWithValue(const AsyncLoading()),
            clientPartnerProgramProvider.overrideWithValue(
              const AsyncData(null),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: MoreSheet(screenTranslationEnabled: true)),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Переводчик'), findsNothing);
      expect(find.byIcon(Icons.translate_rounded), findsNothing);
      expect(find.text('Калькулятор'), findsOneWidget);
      expect(calls, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(calls, isEmpty);
      await tester.pump(const Duration(seconds: 10));
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets('shows the calculator entry in More', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeClientCodeProvider.overrideWithValue(null),
          clientProfileProvider.overrideWithValue(const AsyncData(null)),
          selfBuyoutAvailabilityProvider.overrideWithValue(
            const AsyncLoading(),
          ),
          garageAvailabilityProvider.overrideWithValue(const AsyncLoading()),
          clientPartnerProgramProvider.overrideWithValue(const AsyncData(null)),
        ],
        child: const MaterialApp(home: Scaffold(body: MoreSheet())),
      ),
    );

    expect(find.text('Калькулятор'), findsOneWidget);
    expect(find.text('Предварительный расчёт сборки'), findsOneWidget);
    expect(find.byIcon(Icons.calculate_rounded), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 10));
  });
}
