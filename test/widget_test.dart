import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:twoalogisticcabineuser/src/app/app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('App boots without crashing', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: App()));
    // Give time for initial routing/navigation
    await tester.pumpAndSettle(const Duration(seconds: 2));
    // App should render something - MaterialApp should be present
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
