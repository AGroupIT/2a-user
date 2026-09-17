import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:twoalogisticcabineuser/src/features/training/presentation/training_home_invitation.dart';

Future<void> _pumpInvitation(
  WidgetTester tester,
  SharedPreferences preferences, {
  String account = 'company-a:17',
  String language = 'ru',
  required VoidCallback onStart,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: Locale(language),
      supportedLocales: const [Locale('ru'), Locale('zh')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: Scaffold(
        body: SingleChildScrollView(
          child: TrainingInvitationCard(
            key: ValueKey(account),
            preferences: preferences,
            accountKey: account,
            onStart: onStart,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final language in ['ru', 'zh']) {
    testWidgets('$language invitation fits 320px and starts only on tap', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 740));
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(() {
        tester.binding.setSurfaceSize(null);
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });
      final preferences = await SharedPreferences.getInstance();
      var starts = 0;
      await _pumpInvitation(
        tester,
        preferences,
        language: language,
        onStart: () => starts++,
      );
      expect(starts, 0);
      expect(tester.takeException(), isNull);
      expect(
        find.text(language == 'ru' ? 'Начать экскурсию' : '开始导览'),
        findsOneWidget,
      );
      expect(
        find.text(language == 'ru' ? 'Больше не показывать' : '不再显示'),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 2));
      expect(starts, 0);
      final start = find.byKey(const Key('training-home-start'));
      await tester.ensureVisible(start);
      await tester.tap(start);
      await tester.pumpAndSettle();
      expect(starts, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'dismissal persists for one account and leaves other accounts visible',
    (tester) async {
      final preferences = await SharedPreferences.getInstance();
      var starts = 0;
      await _pumpInvitation(tester, preferences, onStart: () => starts++);
      final dismiss = find.byKey(const Key('training-home-dismiss'));
      await tester.ensureVisible(dismiss);
      await tester.tap(dismiss);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('training-home-start')), findsNothing);
      expect(starts, 0);

      // Fully dispose the card to prove persistence rather than retained State.
      await tester.pumpWidget(const SizedBox.shrink());
      await preferences.reload();
      await _pumpInvitation(tester, preferences, onStart: () => starts++);
      expect(find.byKey(const Key('training-home-start')), findsNothing);

      for (final account in ['company-a:18', 'company-b:17']) {
        await _pumpInvitation(
          tester,
          preferences,
          account: account,
          onStart: () => starts++,
        );
        expect(find.byKey(const Key('training-home-start')), findsOneWidget);
        expect(find.byKey(const Key('training-home-dismiss')), findsOneWidget);
      }
      await _pumpInvitation(tester, preferences, onStart: () => starts++);
      expect(find.byKey(const Key('training-home-start')), findsNothing);
      expect(starts, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
