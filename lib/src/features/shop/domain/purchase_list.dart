class PurchaseList {
  final int id;
  final String status;
  final String? note;
  final String? managerNote;
  final int totalItems;
  final DateTime? submittedAt;
  final DateTime createdAt;
  final List<PurchaseItem> items;
  final MarketplaceOrderSummary? marketplaceOrder;

  const PurchaseList({
    required this.id,
    required this.status,
    this.note,
    this.managerNote,
    this.totalItems = 0,
    this.submittedAt,
    required this.createdAt,
    this.items = const [],
    this.marketplaceOrder,
  });

  factory PurchaseList.fromJson(Map<String, dynamic> json) {
    final itemsJson = json['items'] as List<dynamic>? ?? [];
    return PurchaseList(
      id: json['id'] as int,
      status: json['status'] as String? ?? 'draft',
      note: json['note'] as String?,
      managerNote: json['managerNote'] as String?,
      totalItems: json['totalItems'] as int? ?? 0,
      submittedAt: json['submittedAt'] != null
          ? DateTime.parse(json['submittedAt'] as String)
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
      items: itemsJson
          .map((e) => PurchaseItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      marketplaceOrder: json['marketplaceOrder'] is Map
          ? MarketplaceOrderSummary.fromJson(
              Map<String, dynamic>.from(json['marketplaceOrder'] as Map),
            )
          : null,
    );
  }

  bool get isDraft => status == 'draft';
  bool get isSubmitted => status == 'submitted';

  String get statusDisplay {
    switch (status) {
      case 'draft':
        return 'Черновик';
      case 'submitted':
        return 'Отправлена';
      case 'processing':
        return 'В работе';
      case 'completed':
        return 'Выполнена';
      case 'cancelled':
        return 'Отменена';
      default:
        return status;
    }
  }
}

class MarketplaceOrderSummary {
  const MarketplaceOrderSummary({
    required this.id,
    required this.platform,
    required this.status,
    required this.payableCny,
    required this.freightCny,
    required this.currency,
    required this.groups,
    this.lastSyncedAt,
  });

  final int id;
  final String platform;
  final String status;
  final double payableCny;
  final double freightCny;
  final String currency;
  final List<MarketplaceOrderGroupSummary> groups;
  final DateTime? lastSyncedAt;

  factory MarketplaceOrderSummary.fromJson(Map<String, dynamic> json) {
    final totals = json['totals'] is Map
        ? Map<String, dynamic>.from(json['totals'] as Map)
        : const <String, dynamic>{};
    final groups = json['groups'] as List<dynamic>? ?? const [];
    return MarketplaceOrderSummary(
      id: (json['id'] as num?)?.toInt() ?? 0,
      platform: json['platform']?.toString() ?? '1688',
      status: json['status']?.toString() ?? 'unknown',
      payableCny: PurchaseItem._parseDouble(totals['payable']),
      freightCny: PurchaseItem._parseDouble(totals['freight']),
      currency: totals['currency']?.toString() ?? 'CNY',
      groups: groups
          .whereType<Map>()
          .map(
            (group) => MarketplaceOrderGroupSummary.fromJson(
              Map<String, dynamic>.from(group),
            ),
          )
          .toList(growable: false),
      lastSyncedAt: DateTime.tryParse(json['lastSyncedAt']?.toString() ?? ''),
    );
  }

  String get statusDisplay {
    return switch (status) {
      'previewed' => 'Рассчитан',
      'creating' => 'Создаётся',
      'awaiting_payment' => 'Ожидает оплаты',
      'paid' => 'Оплачен',
      'partially_shipped' => 'Частично отправлен',
      'shipped' => 'Отправлен',
      'completed' => 'Завершён',
      'cancelled' => 'Отменён',
      'failed' => 'Ошибка создания',
      'sync_required' => 'Требуется проверка',
      _ => status,
    };
  }
}

class MarketplaceOrderGroupSummary {
  const MarketplaceOrderGroupSummary({
    required this.supplierName,
    required this.status,
    required this.externalOrders,
  });

  final String? supplierName;
  final String status;
  final List<MarketplaceExternalOrderSummary> externalOrders;

  factory MarketplaceOrderGroupSummary.fromJson(Map<String, dynamic> json) {
    final orders = json['externalOrders'] as List<dynamic>? ?? const [];
    return MarketplaceOrderGroupSummary(
      supplierName: json['supplierName']?.toString(),
      status: json['status']?.toString() ?? 'unknown',
      externalOrders: orders
          .whereType<Map>()
          .map(
            (order) => MarketplaceExternalOrderSummary.fromJson(
              Map<String, dynamic>.from(order),
            ),
          )
          .toList(growable: false),
    );
  }
}

class MarketplaceExternalOrderSummary {
  const MarketplaceExternalOrderSummary({
    required this.externalOrderId,
    required this.status,
    required this.shipments,
  });

  final String externalOrderId;
  final String status;
  final List<MarketplaceShipmentSummary> shipments;

  factory MarketplaceExternalOrderSummary.fromJson(Map<String, dynamic> json) {
    final logistics = json['logistics'] is Map
        ? Map<String, dynamic>.from(json['logistics'] as Map)
        : const <String, dynamic>{};
    final shipments = logistics['shipments'] as List<dynamic>? ?? const [];
    return MarketplaceExternalOrderSummary(
      externalOrderId: json['externalOrderId']?.toString() ?? '',
      status: json['status']?.toString() ?? 'unknown',
      shipments: shipments
          .whereType<Map>()
          .map(
            (shipment) => MarketplaceShipmentSummary.fromJson(
              Map<String, dynamic>.from(shipment),
            ),
          )
          .toList(growable: false),
    );
  }
}

class MarketplaceShipmentSummary {
  const MarketplaceShipmentSummary({
    required this.companyName,
    required this.trackingNumber,
    required this.status,
  });

  final String companyName;
  final String trackingNumber;
  final String status;

  factory MarketplaceShipmentSummary.fromJson(Map<String, dynamic> json) {
    return MarketplaceShipmentSummary(
      companyName: json['companyName']?.toString() ?? '',
      trackingNumber: json['trackingNumber']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
    );
  }
}

class PurchaseItem {
  final int id;
  final String externalItemId;
  final String provider;
  final String title;
  final String? imageUrl;
  final double price;
  final String currency;
  final int quantity;
  final String? skuId;
  final List<SkuProperty> skuProperties;
  final String? externalUrl;
  final String? note;

  const PurchaseItem({
    required this.id,
    required this.externalItemId,
    required this.provider,
    required this.title,
    this.imageUrl,
    this.price = 0,
    this.currency = 'CNY',
    this.quantity = 1,
    this.skuId,
    this.skuProperties = const [],
    this.externalUrl,
    this.note,
  });

  factory PurchaseItem.fromJson(Map<String, dynamic> json) {
    final propsJson = json['skuProperties'] as List<dynamic>? ?? [];
    return PurchaseItem(
      id: json['id'] as int,
      externalItemId: json['externalItemId'] as String? ?? '',
      provider: json['provider'] as String? ?? '',
      title: json['title'] as String? ?? '',
      imageUrl: json['imageUrl'] as String?,
      price: _parseDouble(json['price']),
      currency: json['currency'] as String? ?? 'CNY',
      quantity: json['quantity'] as int? ?? 1,
      skuId: json['skuId'] as String?,
      skuProperties: propsJson
          .map((e) => SkuProperty.fromJson(e as Map<String, dynamic>))
          .toList(),
      externalUrl: json['externalUrl'] as String?,
      note: json['note'] as String?,
    );
  }

  static double _parseDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  String get priceDisplay => '¥${price.toStringAsFixed(0)}';

  String get skuPropertiesDisplay {
    if (skuProperties.isEmpty) return '';
    return skuProperties.map((p) => '${p.name}: ${p.value}').join(', ');
  }
}

class SkuProperty {
  final String name;
  final String value;

  const SkuProperty({required this.name, required this.value});

  factory SkuProperty.fromJson(Map<String, dynamic> json) {
    return SkuProperty(
      name: json['name'] as String? ?? '',
      value: json['value'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'name': name, 'value': value};
}
