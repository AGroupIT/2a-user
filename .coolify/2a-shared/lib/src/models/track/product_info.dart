/// Информация о товаре
class ProductInfo {
  final int? id;
  final String? name;
  final int quantity;
  final String? imageUrl;
  final DateTime? createdAt;

  const ProductInfo({
    this.id,
    this.name,
    this.quantity = 1,
    this.imageUrl,
    this.createdAt,
  });

  factory ProductInfo.fromJson(Map<String, dynamic> json) {
    return ProductInfo(
      id: json['id'] as int?,
      name: json['name'] as String? ?? json['productName'] as String?,
      quantity: json['quantity'] as int? ?? 1,
      imageUrl: json['imageUrl'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'quantity': quantity,
      'imageUrl': imageUrl,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  ProductInfo copyWith({
    int? id,
    String? name,
    int? quantity,
    String? imageUrl,
    DateTime? createdAt,
  }) {
    return ProductInfo(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;
}
