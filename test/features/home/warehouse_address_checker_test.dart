import 'package:flutter_test/flutter_test.dart';
import 'package:twoalogisticcabineuser/src/features/home/presentation/warehouse_address_checker.dart';

void main() {
  const expected = WarehouseAddressCheckData(
    clientCode: '2A-TEST',
    address: '广东省佛山市南海区里水镇仓库 18号(不要隐藏代码 2A-TEST)',
    phone: '+86 138 0013 8000',
  );

  test('подтверждает корректные данные при наличии подписей маркетплейса', () {
    final result = WarehouseAddressVerifier.verify(
      expected: expected,
      recognizedText: '''
收货人 2A-TEST
手机号码 13800138000
所在地区 广东省 佛山市 南海区 里水镇
详细地址 仓库18号
不要隐藏代码 2A-TEST
''',
    );

    expect(
      result.isValid,
      isTrue,
      reason: result.fields
          .map(
            (field) =>
                '${field.label}: ${field.matched}, found=${field.recognizedValue}',
          )
          .join(' | '),
    );
    expect(result.fields, hasLength(3));
    expect(result.fields.every((field) => field.matched), isTrue);
    expect(
      result.fields
          .singleWhere((field) => field.label == 'Телефон склада')
          .recognizedValue,
      contains('13800138000'),
    );
    expect(
      result.fields
          .singleWhere((field) => field.label == 'Адрес склада')
          .recognizedValue,
      contains('详细地址'),
    );
  });

  test('показывает конкретные поля с ошибками', () {
    final result = WarehouseAddressVerifier.verify(
      expected: expected,
      recognizedText: '''
收货人 2A-TSET
手机号码 13800138001
所在地区 广东省佛山市南海区里水镇
详细地址 仓库81号
''',
    );

    expect(result.isValid, isFalse);
    expect(
      result.fields
          .where((field) => !field.matched)
          .map((field) => field.label),
      containsAll(<String>['Код клиента', 'Телефон склада', 'Адрес склада']),
    );
    final address = result.fields.singleWhere(
      (field) => field.label == 'Адрес склада',
    );
    expect(address.matchPercent, lessThan(82));
    expect(address.missingFragment, isNotEmpty);
    expect(address.recognizedValue, contains('广东省佛山市南海区里水镇'));
  });

  test('нормализует пробелы, пунктуацию и полноширинные символы', () {
    final result = WarehouseAddressVerifier.verify(
      expected: expected,
      recognizedText: '''
客户代码：２Ａ－ＴＥＳＴ
电话：１３８－００１３－８０００
地址：广东省佛山市南海区里水镇仓库１８号（不要隐藏代码：２Ａ－ＴＥＳＴ）
''',
    );

    expect(
      result.isValid,
      isTrue,
      reason: result.fields
          .map(
            (field) =>
                '${field.label}: ${field.matched}, found=${field.recognizedValue}',
          )
          .join(' | '),
    );
  });

  test('не считает адрес правильным, если код найден только в другом поле', () {
    final result = WarehouseAddressVerifier.verify(
      expected: expected,
      recognizedText: '''
收货人 2A-TEST
手机号码 13800138000
所在地区 广东省佛山市南海区里水镇
详细地址 仓库18号
''',
    );

    final address = result.fields.singleWhere(
      (field) => field.label == 'Адрес склада',
    );
    expect(address.matched, isFalse);
    expect(address.missingFragment, contains('2A-TEST'));
  });

  test('объединяет адрес и код клиента с нескольких соседних строк', () {
    final result = WarehouseAddressVerifier.verify(
      expected: expected,
      recognizedText: '''
手机号码 13800138000
地址 广东省佛山市南海区
里水镇仓库18号
不要隐藏代码
2A-TEST
''',
    );

    final address = result.fields.singleWhere(
      (field) => field.label == 'Адрес склада',
    );
    expect(address.matched, isTrue, reason: address.recognizedValue);
    expect(address.recognizedValue, contains('2A-TEST'));
  });

  test('не приклеивает перенос к телефону и собирает разорванный код', () {
    const splitCodeExpected = WarehouseAddressCheckData(
      clientCode: '2A-712',
      address: '广东省广州市白云区均禾街罗岗环岗一路7号108仓 (不要隐藏代码 2A-712)',
      phone: '18142825560',
    );
    final result = WarehouseAddressVerifier.verify(
      expected: splitCodeExpected,
      recognizedText: '''
姓名 WD-712
手机 +86 18142825560
地区 广东省广州市白云区
地址 均禾街罗岗环岗一路7号
108仓（不要隐藏代码 2A-
712）
邮编 510440
''',
    );

    final phone = result.fields.singleWhere(
      (field) => field.label == 'Телефон склада',
    );
    final address = result.fields.singleWhere(
      (field) => field.label == 'Адрес склада',
    );
    expect(phone.recognizedValue, isNot(startsWith('712')));
    expect(phone.recognizedValue, contains('18142825560'));
    expect(address.matched, isTrue, reason: address.recognizedValue);
    expect(_withoutWhitespace(address.recognizedValue), contains('2A-712'));
  });

  test('восстанавливает хвост кода, возвращённый OCR вне блока адреса', () {
    const splitCodeExpected = WarehouseAddressCheckData(
      clientCode: '2A-712',
      address: '广东省广州市白云区均禾街罗岗环岗一路7号108仓 (不要隐藏代码 2A-712)',
      phone: '18142825560',
    );
    final result = WarehouseAddressVerifier.verify(
      expected: splitCodeExpected,
      recognizedText: '''
姓名 WD-712
712
手机 +86 18142825560
地区 广东省广州市白云区
地址 均禾街罗岗环岗一路7号108仓（不要隐藏代码 2A-
邮编 510440
''',
    );

    final code = result.fields.singleWhere(
      (field) => field.label == 'Код клиента',
    );
    final phone = result.fields.singleWhere(
      (field) => field.label == 'Телефон склада',
    );
    final address = result.fields.singleWhere(
      (field) => field.label == 'Адрес склада',
    );
    expect(code.matched, isTrue, reason: code.recognizedValue);
    expect(phone.recognizedValue, contains('18142825560'));
    expect(address.matched, isTrue, reason: address.recognizedValue);
    expect(_withoutWhitespace(address.recognizedValue), contains('2A-712'));
  });

  test('показывает фактически найденный чужой код клиента', () {
    const selectedClient = WarehouseAddressCheckData(
      clientCode: '2A-01',
      address: '广东省广州市白云区均禾街罗岗环岗一路7号108仓 (不要隐藏代码 2A-01)',
      phone: '18142825560',
    );
    final result = WarehouseAddressVerifier.verify(
      expected: selectedClient,
      recognizedText: '''
姓名 WD-712
手机 +86 18142825560
地区 广东省广州市白云区
地址 均禾街罗岗环岗一路7号108仓（不要隐藏代码 2A-
712
邮编 510440
''',
    );

    final code = result.fields.singleWhere(
      (field) => field.label == 'Код клиента',
    );
    final address = result.fields.singleWhere(
      (field) => field.label == 'Адрес склада',
    );
    expect(code.matched, isFalse);
    expect(code.recognizedValue, '2A-712');
    expect(address.matched, isFalse);
    expect(_withoutWhitespace(address.recognizedValue), contains('2A-712'));
  });
}

String _withoutWhitespace(String? value) =>
    (value ?? '').replaceAll(RegExp(r'\s+'), '');
