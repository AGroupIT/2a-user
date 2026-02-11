class ShopCategory {
  final String id;
  final String name;
  final String parentId;
  final bool isParent;
  final String provider;

  const ShopCategory({
    required this.id,
    required this.name,
    this.parentId = '',
    this.isParent = false,
    this.provider = '',
  });

  factory ShopCategory.fromJson(Map<String, dynamic> json) {
    return ShopCategory(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      parentId: json['parentId'] as String? ?? '',
      isParent: json['isParent'] as bool? ?? false,
      provider: json['provider'] as String? ?? '',
    );
  }
}
