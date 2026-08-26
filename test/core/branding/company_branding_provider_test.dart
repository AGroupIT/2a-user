import 'package:flutter_test/flutter_test.dart';
import 'package:twoalogisticcabineuser/src/core/branding/company_branding_provider.dart';

void main() {
  group('resolveCompanyName', () {
    test('prefers the current profile agent name', () {
      expect(
        resolveCompanyName(
          profileAgentName: 'IOP Cargo',
          authAgentName: 'Старое название',
        ),
        'IOP Cargo',
      );
    });

    test('uses cached authentication agent while profile is loading', () {
      expect(resolveCompanyName(authAgentName: 'TeamTime'), 'TeamTime');
    });

    test('never falls back to another company brand', () {
      expect(resolveCompanyName(), fallbackCompanyName);
    });
  });
}
