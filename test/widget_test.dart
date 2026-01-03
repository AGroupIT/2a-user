import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:twoalogisticcabineuser/src/app/app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('App boots', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: App()));
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Главная'), findsWidgets);
  });
}
