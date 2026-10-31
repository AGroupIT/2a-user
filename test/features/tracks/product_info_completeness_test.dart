import 'package:flutter_test/flutter_test.dart';
import 'package:twoalogisticcabineuser/src/features/tracks/data/assemblies_provider.dart';
import 'package:twoalogisticcabineuser/src/features/tracks/domain/product_info_completeness.dart';
import 'package:twoalogisticcabineuser/src/features/tracks/domain/track_item.dart';

void main() {
  const complete = ProductInfo(
    name: ' Товар ',
    quantity: 2,
    imageUrl: ' /uploads/item.jpg ',
  );
  test('complete requirement defaults off, independently of the old flag', () {
    expect(
      Tariff.fromJson({
        'requiresProductInfo': true,
      }).requiresCompleteProductInfo,
      isFalse,
    );
    expect(
      Tariff.fromJson({
        'requiresCompleteProductInfo': true,
      }).requiresCompleteProductInfo,
      isTrue,
    );
    expect(
      const Tariff(id: 1, name: 'A', baseCost: 1).requiresCompleteProductInfo,
      isFalse,
    );
  });
  test('requires every row, not only the first complete product', () {
    expect(
      productInfoCompleteness([complete]),
      ProductInfoCompleteness.complete,
    );
    expect(
      productInfoCompleteness([]),
      ProductInfoCompleteness.missingNameOrQuantity,
    );
    expect(
      productInfoCompleteness([
        complete,
        const ProductInfo(name: ' ', imageUrl: '/photo'),
      ]),
      ProductInfoCompleteness.missingNameOrQuantity,
    );
    for (final quantity in [0, -1]) {
      expect(
        productInfoCompleteness([
          ProductInfo(name: 'Товар', quantity: quantity, imageUrl: '/photo'),
        ]),
        ProductInfoCompleteness.missingNameOrQuantity,
      );
    }
    expect(
      productInfoCompleteness([
        complete,
        const ProductInfo(name: 'Другой', imageUrl: '  '),
      ]),
      ProductInfoCompleteness.missingPhoto,
    );
  });
  test('only stored HTTP or relative image references count as photos', () {
    for (final reference in [
      'file:///draft.jpg',
      'blob:local',
      '   ',
      '//other.test/a',
    ]) {
      expect(
        productInfoCompleteness([
          ProductInfo(name: 'Item', imageUrl: reference),
        ]),
        ProductInfoCompleteness.missingPhoto,
      );
    }
    expect(
      productInfoCompleteness([
        const ProductInfo(name: 'Item', imageUrl: 'https://example.test/a.jpg'),
      ]),
      ProductInfoCompleteness.complete,
    );
  });
  test('TrackItem keeps all API rows and legacy first-row access', () {
    final track = TrackItem.fromJson({
      'trackNumber': 'SYNTHETIC',
      'productInfo': [
        {'id': 1, 'name': 'A', 'quantity': 2, 'imageUrl': '/a.jpg'},
        {'id': 2, 'name': 'B', 'quantity': 1, 'imageUrl': null},
      ],
    });
    expect(track.productInfos.length, 2);
    expect(identical(track.productInfo, track.productInfos.first), isTrue);
    expect(
      productInfoCompleteness(track.allProductInfos),
      ProductInfoCompleteness.missingPhoto,
    );
  });
  test('missing quantity cannot become an apparently complete API row', () {
    expect(
      productInfoCompleteness([
        ProductInfo.fromJson({'name': 'A', 'imageUrl': '/a'}),
      ]),
      ProductInfoCompleteness.missingNameOrQuantity,
    );
  });
  test(
    'legacy single-row constructor remains usable, reports do not substitute product photo',
    () {
      final now = DateTime(2026);
      final track = TrackItem(
        code: 'A',
        status: '',
        date: now,
        createdAt: now,
        updatedAt: now,
        productInfo: const ProductInfo(name: 'A', quantity: 1),
        photoReportUrls: ['/report.jpg'],
      );
      expect(track.allProductInfos.length, 1);
      expect(
        productInfoCompleteness(track.allProductInfos),
        ProductInfoCompleteness.missingPhoto,
      );
    },
  );
}
