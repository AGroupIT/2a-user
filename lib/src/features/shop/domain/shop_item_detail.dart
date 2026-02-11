import 'shop_item.dart';

class ItemAttribute {
  final String propertyName;
  final String value;
  final String originalPropertyName;
  final String originalValue;
  final bool isConfigurator;
  final String imageUrl;
  final String pid;
  final String vid;

  const ItemAttribute({
    required this.propertyName,
    required this.value,
    this.originalPropertyName = '',
    this.originalValue = '',
    this.isConfigurator = false,
    this.imageUrl = '',
    this.pid = '',
    this.vid = '',
  });

  factory ItemAttribute.fromJson(Map<String, dynamic> json) {
    return ItemAttribute(
      propertyName: json['propertyName'] as String? ?? '',
      value: json['value'] as String? ?? '',
      originalPropertyName: json['originalPropertyName'] as String? ?? '',
      originalValue: json['originalValue'] as String? ?? '',
      isConfigurator: json['isConfigurator'] as bool? ?? false,
      imageUrl: json['imageUrl'] as String? ?? '',
      pid: json['pid'] as String? ?? '',
      vid: json['vid'] as String? ?? '',
    );
  }
}

class ConfiguratorValue {
  final String pid;
  final String vid;

  const ConfiguratorValue({required this.pid, required this.vid});

  factory ConfiguratorValue.fromJson(Map<String, dynamic> json) {
    return ConfiguratorValue(
      pid: json['pid'] as String? ?? '',
      vid: json['vid'] as String? ?? '',
    );
  }
}

class ConfiguredItem {
  final String id;
  final int quantity;
  final double price;
  final List<ConfiguratorValue> configurators;

  const ConfiguredItem({
    required this.id,
    this.quantity = 0,
    this.price = 0,
    this.configurators = const [],
  });

  factory ConfiguredItem.fromJson(Map<String, dynamic> json) {
    final confsJson = json['configurators'] as List<dynamic>? ?? [];
    return ConfiguredItem(
      id: json['id'] as String? ?? '',
      quantity: json['quantity'] as int? ?? 0,
      price: _parseDouble(json['price']),
      configurators: confsJson
          .map((e) => ConfiguratorValue.fromJson(e as Map<String, dynamic>))
          .toList(),
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

class ShopItemDetail {
  final String id;
  final String title;
  final String originalTitle;
  final String provider;
  final String description;
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
  final List<ItemAttribute> attributes;
  final List<ConfiguredItem> configuredItems;
  final int? totalSales;
  final int? volume;

  const ShopItemDetail({
    required this.id,
    required this.title,
    this.originalTitle = '',
    this.provider = '',
    this.description = '',
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
    this.attributes = const [],
    this.configuredItems = const [],
    this.totalSales,
    this.volume,
  });

  factory ShopItemDetail.fromJson(Map<String, dynamic> json) {
    final priceData = json['price'] as Map<String, dynamic>?;
    final imagesJson = json['images'] as List<dynamic>? ?? [];
    final attrsJson = json['attributes'] as List<dynamic>? ?? [];
    final configsJson = json['configuredItems'] as List<dynamic>? ?? [];
    return ShopItemDetail(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      originalTitle: json['originalTitle'] as String? ?? '',
      provider: json['provider'] as String? ?? '',
      description: json['description'] as String? ?? '',
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
      attributes: attrsJson
          .map((e) => ItemAttribute.fromJson(e as Map<String, dynamic>))
          .toList(),
      configuredItems: configsJson
          .map((e) => ConfiguredItem.fromJson(e as Map<String, dynamic>))
          .toList(),
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

  List<ItemAttribute> get configuratorAttributes =>
      attributes.where((a) => a.isConfigurator).toList();

  List<ItemAttribute> get infoAttributes =>
      attributes.where((a) => !a.isConfigurator).toList();

  /// Group configurator attributes by property name
  Map<String, List<ItemAttribute>> get configuratorGroups {
    final map = <String, List<ItemAttribute>>{};
    for (final attr in configuratorAttributes) {
      (map[attr.propertyName] ??= []).add(attr);
    }
    return map;
  }

  /// Find ConfiguredItem that matches selected vid per pid
  ConfiguredItem? findConfiguredItem(Map<String, String> selectedVids) {
    if (selectedVids.isEmpty || configuredItems.isEmpty) return null;
    for (final ci in configuredItems) {
      final matches = ci.configurators.every(
        (c) => selectedVids[c.pid] == c.vid,
      );
      if (matches && ci.quantity > 0) return ci;
    }
    return null;
  }
}
