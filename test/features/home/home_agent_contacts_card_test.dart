import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twoalogisticcabineuser/src/features/home/presentation/home_agent_contacts_card.dart';
import 'package:twoalogisticcabineuser/src/features/profile/data/profile_provider.dart';

void main() {
  const populatedAgent = AgentInfo(
    id: 1,
    name: '2A Logistic',
    phone: '+7 900 000-00-00',
    email: 'hello@example.com',
    companyWebsiteUrl: 'https://example.com/',
    companyTelegramUrl: '@manager',
    companyTelegramChannelUrl: 'https://t.me/company',
    companyWhatsappUrl: '+7 911 111-11-11',
    companyVkUrl: 'vk.com/company',
  );

  testWidgets('shows every published company contact on Home', (tester) async {
    await _pumpCard(tester, populatedAgent);

    expect(
      find.byKey(const ValueKey('home-agent-contacts-card')),
      findsOneWidget,
    );
    expect(find.text('Контакты'), findsOneWidget);
    expect(find.text('2A Logistic'), findsOneWidget);
    expect(find.text('Телефон'), findsOneWidget);
    expect(find.text('+7 900 000-00-00'), findsOneWidget);
    expect(find.text('hello@example.com'), findsOneWidget);
    expect(find.text('Telegram'), findsOneWidget);
    expect(find.text('Telegram-канал'), findsOneWidget);
    expect(find.text('WhatsApp'), findsOneWidget);
    expect(find.text('VK'), findsOneWidget);
    expect(find.text('Сайт'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses Chinese labels when the system language is Chinese', (
    tester,
  ) async {
    await _pumpCard(tester, populatedAgent, locale: const Locale('zh'));

    expect(find.text('联系方式'), findsOneWidget);
    expect(find.text('电话'), findsOneWidget);
    expect(find.text('Telegram 频道'), findsOneWidget);
    expect(find.text('网站'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('does not render an empty contact block', (tester) async {
    await _pumpCard(tester, const AgentInfo(id: 2, name: 'Empty'));

    expect(
      find.byKey(const ValueKey('home-agent-contacts-card')),
      findsNothing,
    );
    expect(find.text('Контакты'), findsNothing);
  });

  testWidgets('keeps the contact card usable at 320px', (tester) async {
    await _pumpCard(tester, populatedAgent, width: 320);

    expect(
      find.byKey(const ValueKey('home-agent-contacts-card')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpCard(
  WidgetTester tester,
  AgentInfo agent, {
  Locale locale = const Locale('ru'),
  double width = 390,
}) {
  return tester.pumpWidget(
    MaterialApp(
      locale: locale,
      supportedLocales: const [Locale('ru'), Locale('zh')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(
        body: SingleChildScrollView(
          child: Center(
            child: SizedBox(
              width: width,
              child: HomeAgentContactsCard(agent: agent),
            ),
          ),
        ),
      ),
    ),
  );
}
