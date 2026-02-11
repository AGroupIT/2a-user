class ShopImage {
  final String url;
  final String small;
  final String medium;
  final String large;

  const ShopImage({
    required this.url,
    this.small = '',
    this.medium = '',
    this.large = '',
  });

  factory ShopImage.fromJson(Map<String, dynamic> json) {
    return ShopImage(
      url: json['url'] as String? ?? '',
      small: json['small'] as String? ?? '',
      medium: json['medium'] as String? ?? '',
      large: json['large'] as String? ?? '',
    );
  }
}

class ShopItem {
  final String id;
  final String title;
  final String originalTitle;
  final String provider;
  final double price;
  final String currency;
  final String mainImage;
  final List<ShopImage> images;
  final String vendorId;
  final String vendorName;
  final int? vendorScore;
  final int? quantity;
  final String brandName;
  final String categoryId;
  final String externalUrl;
  final int? totalSales;
  final int? volume;

  const ShopItem({
    required this.id,
    required this.title,
    this.originalTitle = '',
    this.provider = '',
    this.price = 0,
    this.currency = 'CNY',
    this.mainImage = '',
    this.images = const [],
    this.vendorId = '',
    this.vendorName = '',
    this.vendorScore,
    this.quantity,
    this.brandName = '',
    this.categoryId = '',
    this.externalUrl = '',
    this.totalSales,
    this.volume,
  });

  factory ShopItem.fromJson(Map<String, dynamic> json) {
    final priceData = json['price'] as Map<String, dynamic>?;
    final imagesJson = json['images'] as List<dynamic>? ?? [];
    return ShopItem(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      originalTitle: json['originalTitle'] as String? ?? '',
      provider: json['provider'] as String? ?? '',
      price: _parseDouble(priceData?['original']),
      currency: priceData?['currency'] as String? ?? 'CNY',
      mainImage: json['mainImage'] as String? ?? '',
      images: imagesJson
          .map((e) => ShopImage.fromJson(e as Map<String, dynamic>))
          .toList(),
      vendorId: json['vendorId'] as String? ?? '',
      vendorName: json['vendorName'] as String? ?? '',
      vendorScore: json['vendorScore'] as int?,
      quantity: json['quantity'] as int?,
      brandName: json['brandName'] as String? ?? '',
      categoryId: json['categoryId'] as String? ?? '',
      externalUrl: json['externalUrl'] as String? ?? '',
      totalSales: json['totalSales'] as int?,
      volume: json['volume'] as int?,
    );
  }

  static double _parseDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  String get priceDisplay => '¥${price.toStringAsFixed(0)}';
}
