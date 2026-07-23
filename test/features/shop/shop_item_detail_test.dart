import 'package:flutter_test/flutter_test.dart';
import 'package:twoalogisticcabineuser/src/features/shop/domain/shop_item_detail.dart';

void main() {
  test('official 1688 detail parses minimum quantity and trusted SKU data', () {
    final item = ShopItemDetail.fromJson({
      'id': '777',
      'title': 'Thermal bottle',
      'provider': '1688',
      'minOrderQuantity': 2,
      'quantity': 5,
      'price': {'original': 9.9, 'currency': 'CNY'},
      'attributes': [
        {
          'propertyName': 'Color',
          'value': 'Blue',
          'isConfigurator': true,
          'pid': '20',
          'vid': '蓝色',
        },
      ],
      'configuredItems': [
        {
          'id': '991',
          'quantity': 5,
          'price': 8.5,
          'configurators': [
            {'pid': '20', 'vid': '蓝色'},
          ],
        },
      ],
    });

    expect(item.minOrderQuantity, 2);
    expect(item.quantity, 5);
    expect(item.configuratorGroups['Color']?.single.value, 'Blue');
    expect(item.findConfiguredItem({'20': '蓝色'})?.id, '991');
    expect(item.findConfiguredItem({'20': 'missing'}), isNull);
  });
}
