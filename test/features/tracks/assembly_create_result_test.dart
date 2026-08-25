import 'package:twoalogisticcabineuser/src/features/tracks/data/assemblies_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses warehouse arrival cooldown error from backend', () {
    final result = AssemblyCreateResult.fromErrorData({
      'error': 'TRACK_WAREHOUSE_ARRIVAL_COOLDOWN',
      'code': 'TRACK_WAREHOUSE_ARRIVAL_COOLDOWN',
      'message':
          'Этот трек только поступил на склад. Отправить его можно завтра.',
    });

    expect(result.isSuccess, isFalse);
    expect(result.errorCode, trackWarehouseArrivalCooldownCode);
    expect(result.message, contains('можно завтра'));
  });

  test('unknown backend error stays generic', () {
    final result = AssemblyCreateResult.fromErrorData('bad gateway');
    expect(result.isSuccess, isFalse);
    expect(result.errorCode, isNull);
    expect(result.message, isNull);
  });

  test('uses legacy backend error text as a user-facing message', () {
    final result = AssemblyCreateResult.fromErrorData({
      'error': 'Укажите список товаров в сборке',
    });

    expect(result.errorCode, isNull);
    expect(result.message, 'Укажите список товаров в сборке');
  });

  test('prefers structured backend code and message', () {
    final result = AssemblyCreateResult.fromErrorData({
      'error': 'legacy fallback',
      'code': 'ASSEMBLY_PRODUCT_INFO_REQUIRED',
      'message': 'Укажите список товаров в сборке',
    });

    expect(result.errorCode, 'ASSEMBLY_PRODUCT_INFO_REQUIRED');
    expect(result.message, 'Укажите список товаров в сборке');
  });
}
