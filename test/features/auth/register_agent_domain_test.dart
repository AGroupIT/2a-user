import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_form_field/phone_form_field.dart';
import 'package:twoalogisticcabineuser/src/core/network/api_client.dart';
import 'package:twoalogisticcabineuser/src/core/services/agent_domain_resolver.dart';
import 'package:twoalogisticcabineuser/src/core/ui/app_colors.dart';
import 'package:twoalogisticcabineuser/src/core/ui/phone_input_field.dart';
import 'package:twoalogisticcabineuser/src/features/auth/data/client_partner_invite_provider.dart';
import 'package:twoalogisticcabineuser/src/features/auth/data/partner_link_provider.dart';
import 'package:twoalogisticcabineuser/src/features/auth/presentation/register_screen.dart';

class _PartnerLink extends PartnerLinkNotifier {
  @override
  PartnerLinkState build() =>
      const PartnerLinkState(phase: PartnerLinkPhase.idle);
}

class _Invite extends ClientPartnerInviteNotifier {
  @override
  ClientPartnerInviteState build() =>
      const ClientPartnerInviteState(phase: ClientPartnerInvitePhase.idle);
}

class _Api implements ApiClient {
  Map<String, dynamic>? registration;

  @override
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    final body = switch (path) {
      '/register/phone-verification/request' => {
        'verificationToken': 'pending-test-phone',
        'callPhone': '+78005553535',
      },
      '/register/phone-verification/verify' => {
        'confirmed': true,
        'phoneVerificationToken': 'verified-test-phone',
      },
      '/register' => {'error': 'Test only: account not created'},
      _ => throw StateError('Unexpected test request: $path'),
    };
    if (path == '/register') {
      registration = Map<String, dynamic>.from(data as Map);
    }
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      statusCode: path == '/register' ? 400 : 200,
      data: body as T,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Finder _field(String hint) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.hintText == hint,
);

Future<void> _tap(WidgetTester tester, String text) async {
  final target = find.text(text).last;
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<_Api> _openCodes(WidgetTester tester, String? domain) async {
  tester.view.physicalSize = const Size(1200, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final api = _Api();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentAgentDomainProvider.overrideWithValue(domain),
        apiClientProvider.overrideWithValue(api),
        brandColorsProvider.overrideWithValue(BrandColors.defaultColors),
        partnerLinkProvider.overrideWith(_PartnerLink.new),
        clientPartnerInviteProvider.overrideWith(_Invite.new),
      ],
      child: const MaterialApp(home: RegisterScreen()),
    ),
  );
  await tester.pumpAndSettle();
  await tester.enterText(_field('Иванов Иван Иванович'), 'Test Client');
  await tester.enterText(_field('example@mail.com'), 'test@example.test');
  final phone = tester.widget<PhoneInputField>(find.byType(PhoneInputField));
  phone.controller!.value = const PhoneNumber(
    isoCode: IsoCode.RU,
    nsn: '9991112233',
  );
  phone.onChanged?.call(phone.controller!.value);
  await tester.pump();
  await _tap(tester, 'Подтвердить телефон звонком');
  await _tap(tester, 'Проверить');
  await _tap(tester, 'Продолжить');
  final passwords = find.byWidgetPredicate(
    (widget) => widget is TextField && widget.obscureText,
  );
  expect(passwords, findsNWidgets(2));
  await tester.enterText(passwords.at(0), 'password123');
  await tester.enterText(passwords.at(1), 'password123');
  await _tap(tester, 'Продолжить');
  expect(_field('Код агента'), findsOneWidget);
  return api;
}

void main() {
  testWidgets('cabinet agent is prefilled and sent with registration', (
    tester,
  ) async {
    final api = await _openCodes(tester, 'keshadostavka.ru');
    expect(
      tester.widget<TextField>(_field('Код агента')).controller!.text,
      'keshadostavka.ru',
    );
    await _tap(tester, 'Зарегистрироваться');
    expect(api.registration?['agentCode'], 'keshadostavka.ru');
    expect(api.registration?['phoneVerificationToken'], 'verified-test-phone');
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('native or unknown host leaves the agent optional', (
    tester,
  ) async {
    final api = await _openCodes(tester, null);
    expect(
      tester.widget<TextField>(_field('Код агента')).controller!.text,
      isEmpty,
    );
    await _tap(tester, 'Зарегистрироваться');
    expect(api.registration, isNotNull);
    expect(api.registration!.containsKey('agentCode'), isFalse);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('manual override survives going back and forward', (
    tester,
  ) async {
    final api = await _openCodes(tester, 'keshadostavka.ru');
    await tester.enterText(_field('Код агента'), 'MANUAL');
    await _tap(tester, 'Назад');
    await _tap(tester, 'Продолжить');
    expect(
      tester.widget<TextField>(_field('Код агента')).controller!.text,
      'MANUAL',
    );
    await _tap(tester, 'Зарегистрироваться');
    expect(api.registration?['agentCode'], 'MANUAL');
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
