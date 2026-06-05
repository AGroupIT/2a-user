import 'package:flutter/material.dart';

/// Китайские площадки, которые будут подключаться через backend-агрегатор.
///
/// Flutter хранит только нормализованную модель. Ключи площадок, подписи,
/// OAuth/session и Yandex GPT перевод должны оставаться на backend стороне.
enum ChinaMarketplace {
  alibaba1688(
    '1688',
    '1688',
    'Оптовые партии',
    Icons.store_mall_directory_rounded,
  ),
  taobao('taobao', 'Taobao', 'Розница и бренды', Icons.shopping_bag_rounded),
  pinduoduo(
    'pinduoduo',
    'Pinduoduo',
    'Акции и низкие цены',
    Icons.local_offer_rounded,
  );

  const ChinaMarketplace(
    this.apiKey,
    this.displayName,
    this.caption,
    this.icon,
  );

  final String apiKey;
  final String displayName;
  final String caption;
  final IconData icon;
}

enum MarketplaceTranslationStatus { translated, pending, originalOnly }

extension MarketplaceTranslationStatusX on MarketplaceTranslationStatus {
  String get label {
    switch (this) {
      case MarketplaceTranslationStatus.translated:
        return 'Переведено';
      case MarketplaceTranslationStatus.pending:
        return 'Ждёт перевода';
      case MarketplaceTranslationStatus.originalOnly:
        return 'Оригинал';
    }
  }
}

enum MarketplaceCatalogFilter {
  all('all', 'Все', Icons.auto_awesome_rounded),
  topRated('topRated', 'Высокий рейтинг', Icons.star_rounded),
  manyReviews('manyReviews', 'Много отзывов', Icons.reviews_rounded),
  freeChinaDelivery(
    'freeChinaDelivery',
    'Доставка ¥0',
    Icons.local_shipping_rounded,
  ),
  smallMinimum('smallMinimum', 'Малый минимум', Icons.inventory_2_rounded);

  const MarketplaceCatalogFilter(this.key, this.label, this.icon);

  final String key;
  final String label;
  final IconData icon;
}

enum MarketplaceSortOption {
  popular('popular', 'Популярные', Icons.trending_up_rounded),
  priceAsc('priceAsc', 'Дешевле', Icons.south_rounded),
  priceDesc('priceDesc', 'Дороже', Icons.north_rounded),
  rating('rating', 'Рейтинг', Icons.star_rounded);

  const MarketplaceSortOption(this.key, this.label, this.icon);

  final String key;
  final String label;
  final IconData icon;
}

class MarketplaceSkuOption {
  final String id;
  final String nameRu;
  final String originalName;
  final double? priceDeltaCny;

  const MarketplaceSkuOption({
    required this.id,
    required this.nameRu,
    this.originalName = '',
    this.priceDeltaCny,
  });
}

class MarketplaceProductAttribute {
  final String name;
  final String value;
  final String originalName;
  final String originalValue;

  const MarketplaceProductAttribute({
    required this.name,
    required this.value,
    this.originalName = '',
    this.originalValue = '',
  });
}

class MarketplaceProductReview {
  final String author;
  final double rating;
  final String text;
  final String dateLabel;

  const MarketplaceProductReview({
    required this.author,
    required this.rating,
    required this.text,
    required this.dateLabel,
  });
}

class MarketplaceProduct {
  final String id;
  final ChinaMarketplace marketplace;
  final String externalId;
  final String originalTitle;
  final String titleRu;
  final String descriptionRu;
  final String sellerName;
  final String category;
  final String externalUrl;
  final double priceCny;
  final double domesticDeliveryCny;
  final int minOrderQuantity;
  final int monthlySales;
  final double rating;
  final int reviewCount;
  final double sellerRating;
  final int sellerReviewCount;
  final List<String> imageUrls;
  final List<MarketplaceSkuOption> skuOptions;
  final List<MarketplaceProductAttribute> attributes;
  final List<MarketplaceProductReview> reviews;
  final MarketplaceTranslationStatus translationStatus;
  final String imageSeed;

  const MarketplaceProduct({
    required this.id,
    required this.marketplace,
    required this.externalId,
    required this.originalTitle,
    required this.titleRu,
    required this.descriptionRu,
    required this.sellerName,
    required this.category,
    required this.externalUrl,
    required this.priceCny,
    this.domesticDeliveryCny = 0,
    this.minOrderQuantity = 1,
    this.monthlySales = 0,
    this.rating = 0,
    this.reviewCount = 0,
    this.sellerRating = 0,
    this.sellerReviewCount = 0,
    this.imageUrls = const [],
    this.skuOptions = const [],
    this.attributes = const [],
    this.reviews = const [],
    this.translationStatus = MarketplaceTranslationStatus.translated,
    this.imageSeed = '',
  });

  double get minLineCny => priceCny * minOrderQuantity;

  String get mainImageUrl => imageUrls.isNotEmpty ? imageUrls.first : '';
}

class MarketplaceCartItem {
  final MarketplaceProduct product;
  final int quantity;
  final MarketplaceSkuOption? sku;
  final String note;

  const MarketplaceCartItem({
    required this.product,
    this.quantity = 1,
    this.sku,
    this.note = '',
  });

  String get key => '${product.id}:${sku?.id ?? 'base'}';

  double get unitCny => product.priceCny + (sku?.priceDeltaCny ?? 0);

  double get totalCny => unitCny * quantity;

  MarketplaceCartItem copyWith({
    int? quantity,
    MarketplaceSkuOption? sku,
    String? note,
  }) {
    return MarketplaceCartItem(
      product: product,
      quantity: quantity ?? this.quantity,
      sku: sku ?? this.sku,
      note: note ?? this.note,
    );
  }
}
