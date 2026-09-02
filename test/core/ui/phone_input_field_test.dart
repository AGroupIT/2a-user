import 'package:flutter_test/flutter_test.dart';
import 'package:phone_form_field/phone_form_field.dart';
import 'package:twoalogisticcabineuser/src/core/ui/phone_input_field.dart';

void main() {
  group('PhoneInputField.internationalValue', () {
    test('keeps the existing Russian flow in E.164 format', () {
      const phone = PhoneNumber(isoCode: IsoCode.RU, nsn: '9991234567');

      expect(PhoneInputField.internationalValue(phone), '+79991234567');
    });

    test('supports international numbers selected by country', () {
      const chinesePhone = PhoneNumber(isoCode: IsoCode.CN, nsn: '13800138000');
      const kazakhstanPhone = PhoneNumber(
        isoCode: IsoCode.KZ,
        nsn: '7011234567',
      );

      expect(
        PhoneInputField.internationalValue(chinesePhone),
        '+8613800138000',
      );
      expect(
        PhoneInputField.internationalValue(kazakhstanPhone),
        '+77011234567',
      );
    });

    test('rejects incomplete phone numbers', () {
      const phone = PhoneNumber(isoCode: IsoCode.CN, nsn: '123');

      expect(PhoneInputField.internationalValue(phone), isNull);
    });
  });
}
