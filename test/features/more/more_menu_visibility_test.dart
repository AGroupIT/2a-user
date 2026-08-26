import 'package:flutter_test/flutter_test.dart';
import 'package:twoalogisticcabineuser/src/features/more/presentation/more_sheet.dart';

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
}
