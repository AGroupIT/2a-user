String? _stringValue(dynamic value) =>
    value is String && value.trim().isNotEmpty ? value.trim() : null;

int _intValue(dynamic value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

double _doubleValue(dynamic value, [double fallback = 0]) {
  if (value == null) {
    return fallback;
  }
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value.replaceAll(',', '.')) ?? fallback;
  }
  return fallback;
}

bool _boolValue(dynamic value, [bool fallback = false]) =>
    value is bool ? value : fallback;

DateTime? _dateValue(dynamic value) {
  if (value is String) {
    return DateTime.tryParse(value);
  }
  return null;
}

List<T> _listValue<T>(dynamic value, T Function(Map<String, dynamic>) mapper) {
  if (value is! List) return const [];
  return value
      .whereType<Map<String, dynamic>>()
      .map(mapper)
      .toList(growable: false);
}

class SpV2PurchaseStatusInfo {
  final String code;
  final String label;

  const SpV2PurchaseStatusInfo(this.code, this.label);

  static const all = <SpV2PurchaseStatusInfo>[
    SpV2PurchaseStatusInfo('draft', 'Черновик'),
    SpV2PurchaseStatusInfo('open', 'Принимает товары'),
    SpV2PurchaseStatusInfo('closed_for_items', 'Приём закрыт'),
    SpV2PurchaseStatusInfo('purchasing', 'Выкуп'),
    SpV2PurchaseStatusInfo('purchased', 'Выкуплено'),
    SpV2PurchaseStatusInfo('in_transit', 'В пути'),
    SpV2PurchaseStatusInfo('arrived_msk', 'Прибыло в МСК'),
    SpV2PurchaseStatusInfo('sorting', 'Разбор'),
    SpV2PurchaseStatusInfo('calculating', 'Расчёт'),
    SpV2PurchaseStatusInfo('collecting_payments', 'Сбор оплат'),
    SpV2PurchaseStatusInfo('shipping_to_customers', 'Отправка'),
    SpV2PurchaseStatusInfo('completed', 'Завершено'),
    SpV2PurchaseStatusInfo('cancelled', 'Отменено'),
  ];

  static String labelFor(String code) {
    return all
        .firstWhere(
          (status) => status.code == code,
          orElse: () => SpV2PurchaseStatusInfo(code, code),
        )
        .label;
  }
}

class SpV2ItemStatusInfo {
  final String code;
  final String label;

  const SpV2ItemStatusInfo(this.code, this.label);

  static const all = <SpV2ItemStatusInfo>[
    SpV2ItemStatusInfo('requested', 'Запрошен'),
    SpV2ItemStatusInfo('need_info', 'Нужны данные'),
    SpV2ItemStatusInfo('approved', 'Подтверждён'),
    SpV2ItemStatusInfo('purchased', 'Выкуплен'),
    SpV2ItemStatusInfo('not_purchased', 'Не выкуплен'),
    SpV2ItemStatusInfo('cancelled', 'Отменён'),
    SpV2ItemStatusInfo('in_transit', 'В пути'),
    SpV2ItemStatusInfo('arrived', 'Прибыл'),
    SpV2ItemStatusInfo('sorted', 'Разобран'),
    SpV2ItemStatusInfo('ready_to_ship', 'Готов к отправке'),
    SpV2ItemStatusInfo('sent_to_customer', 'Отправлен'),
    SpV2ItemStatusInfo('delivered', 'Доставлен'),
  ];

  static String labelFor(String code) {
    return all
        .firstWhere(
          (status) => status.code == code,
          orElse: () => SpV2ItemStatusInfo(code, code),
        )
        .label;
  }
}

class SpV2PurchaseStats {
  final int customersCount;
  final int itemsCount;
  final int purchasedItemsCount;
  final int linkedTracksCount;
  final double totalWeightKg;
  final double goodsDueRub;
  final double goodsPaidRub;
  final double deliveryDueRub;
  final double deliveryPaidRub;
  final double extraDueRub;
  final double extraPaidRub;
  final double totalDueRub;
  final double paidRub;
  final double expensesRub;
  final double totalProfitRub;
  final int shipmentsCount;
  final int sentShipmentsCount;

  const SpV2PurchaseStats({
    this.customersCount = 0,
    this.itemsCount = 0,
    this.purchasedItemsCount = 0,
    this.linkedTracksCount = 0,
    this.totalWeightKg = 0,
    this.goodsDueRub = 0,
    this.goodsPaidRub = 0,
    this.deliveryDueRub = 0,
    this.deliveryPaidRub = 0,
    this.extraDueRub = 0,
    this.extraPaidRub = 0,
    this.totalDueRub = 0,
    this.paidRub = 0,
    this.expensesRub = 0,
    this.totalProfitRub = 0,
    this.shipmentsCount = 0,
    this.sentShipmentsCount = 0,
  });

  factory SpV2PurchaseStats.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const SpV2PurchaseStats();
    return SpV2PurchaseStats(
      customersCount: _intValue(json['customersCount']),
      itemsCount: _intValue(json['itemsCount']),
      purchasedItemsCount: _intValue(json['purchasedItemsCount']),
      linkedTracksCount: _intValue(json['linkedTracksCount']),
      totalWeightKg: _doubleValue(json['totalWeightKg']),
      goodsDueRub: _doubleValue(json['goodsDueRub']),
      goodsPaidRub: _doubleValue(json['goodsPaidRub']),
      deliveryDueRub: _doubleValue(json['deliveryDueRub']),
      deliveryPaidRub: _doubleValue(json['deliveryPaidRub']),
      extraDueRub: _doubleValue(json['extraDueRub']),
      extraPaidRub: _doubleValue(json['extraPaidRub']),
      totalDueRub: _doubleValue(json['totalDueRub']),
      paidRub: _doubleValue(json['paidRub']),
      expensesRub: _doubleValue(json['expensesRub']),
      totalProfitRub: _doubleValue(json['totalProfitRub']),
      shipmentsCount: _intValue(json['shipmentsCount']),
      sentShipmentsCount: _intValue(json['sentShipmentsCount']),
    );
  }
}

class SpV2ClientCodeRef {
  final int id;
  final String code;

  const SpV2ClientCodeRef({required this.id, required this.code});

  factory SpV2ClientCodeRef.fromJson(Map<String, dynamic> json) {
    return SpV2ClientCodeRef(
      id: _intValue(json['id']),
      code: _stringValue(json['code']) ?? '',
    );
  }
}

class SpV2Customer {
  final int id;
  final String fullName;
  final String? phone;
  final String? email;
  final String? telegram;
  final String? whatsapp;
  final String? wechat;
  final String? vk;
  final String? max;
  final String? city;
  final String? deliveryAddress;
  final String? comment;

  const SpV2Customer({
    required this.id,
    required this.fullName,
    this.phone,
    this.email,
    this.telegram,
    this.whatsapp,
    this.wechat,
    this.vk,
    this.max,
    this.city,
    this.deliveryAddress,
    this.comment,
  });

  factory SpV2Customer.fromJson(Map<String, dynamic> json) {
    return SpV2Customer(
      id: _intValue(json['id']),
      fullName: _stringValue(json['fullName']) ?? 'Клиент',
      phone: _stringValue(json['phone']),
      email: _stringValue(json['email']),
      telegram: _stringValue(json['telegram']),
      whatsapp: _stringValue(json['whatsapp']),
      wechat: _stringValue(json['wechat']),
      vk: _stringValue(json['vk']),
      max: _stringValue(json['max']),
      city: _stringValue(json['city']),
      deliveryAddress: _stringValue(json['deliveryAddress']),
      comment: _stringValue(json['comment']),
    );
  }
}

class SpV2TrackRef {
  final int id;
  final String trackNumber;
  final String status;

  const SpV2TrackRef({
    required this.id,
    required this.trackNumber,
    required this.status,
  });

  factory SpV2TrackRef.fromJson(Map<String, dynamic> json) {
    final trackJson = json['track'] is Map<String, dynamic>
        ? json['track'] as Map<String, dynamic>
        : json;
    return SpV2TrackRef(
      id: _intValue(trackJson['id']),
      trackNumber: _stringValue(trackJson['trackNumber']) ?? '',
      status: _stringValue(trackJson['status']) ?? '',
    );
  }
}

class SpV2Media {
  final int id;
  final String url;
  final String? thumbnailUrl;
  final String? fileName;
  final String? mimeType;
  final String? comment;

  const SpV2Media({
    required this.id,
    required this.url,
    this.thumbnailUrl,
    this.fileName,
    this.mimeType,
    this.comment,
  });

  factory SpV2Media.fromJson(Map<String, dynamic> json) {
    return SpV2Media(
      id: _intValue(json['id']),
      url: _stringValue(json['url']) ?? '',
      thumbnailUrl: _stringValue(json['thumbnailUrl']),
      fileName: _stringValue(json['fileName']),
      mimeType: _stringValue(json['mimeType']),
      comment: _stringValue(json['comment']),
    );
  }
}

class SpV2Payment {
  final int id;
  final int? spCustomerId;
  final int? spItemId;
  final String type;
  final String status;
  final double amountRub;
  final double amountYuan;
  final DateTime? paidAt;

  const SpV2Payment({
    required this.id,
    this.spCustomerId,
    this.spItemId,
    required this.type,
    required this.status,
    this.amountRub = 0,
    this.amountYuan = 0,
    this.paidAt,
  });

  bool get isPaid => status == 'paid';

  factory SpV2Payment.fromJson(Map<String, dynamic> json) {
    return SpV2Payment(
      id: _intValue(json['id']),
      spCustomerId: json['spCustomerId'] == null
          ? null
          : _intValue(json['spCustomerId']),
      spItemId: json['spItemId'] == null ? null : _intValue(json['spItemId']),
      type: _stringValue(json['type']) ?? '',
      status: _stringValue(json['status']) ?? 'planned',
      amountRub: _doubleValue(json['amountRub']),
      amountYuan: _doubleValue(json['amountYuan']),
      paidAt: _dateValue(json['paidAt']),
    );
  }
}

class SpV2Expense {
  final int id;
  final String scope;
  final String title;
  final double amountRub;
  final String allocationMethod;
  final String? comment;
  final DateTime? createdAt;

  const SpV2Expense({
    required this.id,
    required this.scope,
    required this.title,
    required this.amountRub,
    required this.allocationMethod,
    this.comment,
    this.createdAt,
  });

  factory SpV2Expense.fromJson(Map<String, dynamic> json) {
    return SpV2Expense(
      id: _intValue(json['id']),
      scope: _stringValue(json['scope']) ?? 'purchase',
      title: _stringValue(json['title']) ?? 'Расход',
      amountRub: _doubleValue(json['amountRub']),
      allocationMethod: _stringValue(json['allocationMethod']) ?? 'equal',
      comment: _stringValue(json['comment']),
      createdAt: _dateValue(json['createdAt']),
    );
  }
}

class SpV2ExpenseAllocationInfo {
  final String code;
  final String label;
  final String description;

  const SpV2ExpenseAllocationInfo(this.code, this.label, this.description);

  static const all = <SpV2ExpenseAllocationInfo>[
    SpV2ExpenseAllocationInfo(
      'equal',
      'Поровну',
      'Разделить сумму одинаково между клиентами СП.',
    ),
    SpV2ExpenseAllocationInfo(
      'by_weight',
      'По весу',
      'Распределить пропорционально фактическому весу товаров клиента.',
    ),
    SpV2ExpenseAllocationInfo(
      'by_item_count',
      'По количеству товаров',
      'Распределить пропорционально количеству позиций клиента.',
    ),
    SpV2ExpenseAllocationInfo(
      'by_purchase_amount',
      'По сумме товаров',
      'Распределить пропорционально стоимости товаров клиента.',
    ),
  ];

  static String labelFor(String code) {
    // Legacy fallback: раньше в UI был пункт manual, но без ввода долей он
    // фактически считался как equal. Новые расходы больше не дают выбрать
    // недоделанное ручное распределение.
    if (code == 'manual') return 'Поровну между клиентами';
    return all
        .firstWhere(
          (method) => method.code == code,
          orElse: () => SpV2ExpenseAllocationInfo(code, code, ''),
        )
        .label;
  }
}

class SpV2Item {
  final int id;
  final int? spProductId;
  final String title;
  final String status;
  final String statusLabel;
  final int quantity;
  final String? sourceUrl;
  final String? sellerInfo;
  final String? description;
  final String? comment;
  final double supplierPriceYuan;
  final double purchasePriceYuan;
  final double clientPriceYuan;
  final double costPriceRub;
  final double clientPriceRub;
  final double shippingCostRub;
  final double shippingCostActualRub;
  final double additionalExpensesRub;
  final double actualWeightKg;
  final double totalDueRub;
  final DateTime? updatedAt;
  final SpV2Customer? customer;
  final List<SpV2TrackRef> tracks;
  final List<SpV2Media> media;
  final List<SpV2Payment> payments;

  const SpV2Item({
    required this.id,
    this.spProductId,
    required this.title,
    required this.status,
    required this.statusLabel,
    required this.quantity,
    this.sourceUrl,
    this.sellerInfo,
    this.description,
    this.comment,
    this.supplierPriceYuan = 0,
    this.purchasePriceYuan = 0,
    this.clientPriceYuan = 0,
    this.costPriceRub = 0,
    this.clientPriceRub = 0,
    this.shippingCostRub = 0,
    this.shippingCostActualRub = 0,
    this.additionalExpensesRub = 0,
    this.actualWeightKg = 0,
    this.totalDueRub = 0,
    this.updatedAt,
    this.customer,
    this.tracks = const [],
    this.media = const [],
    this.payments = const [],
  });

  factory SpV2Item.fromJson(Map<String, dynamic> json) {
    final status = _stringValue(json['status']) ?? 'requested';
    return SpV2Item(
      id: _intValue(json['id']),
      spProductId: json['spProductId'] == null
          ? null
          : _intValue(json['spProductId']),
      title: _stringValue(json['title']) ?? 'Товар',
      status: status,
      statusLabel:
          _stringValue(json['statusLabel']) ??
          SpV2ItemStatusInfo.labelFor(status),
      quantity: _intValue(json['quantity'], 1),
      sourceUrl: _stringValue(json['sourceUrl']),
      sellerInfo: _stringValue(json['sellerInfo']),
      description: _stringValue(json['description']),
      comment: _stringValue(json['comment']),
      supplierPriceYuan: _doubleValue(json['supplierPriceYuan']),
      purchasePriceYuan: _doubleValue(json['purchasePriceYuan']),
      clientPriceYuan: _doubleValue(json['clientPriceYuan']),
      costPriceRub: _doubleValue(json['costPriceRub']),
      clientPriceRub: _doubleValue(json['clientPriceRub']),
      shippingCostRub: _doubleValue(json['shippingCostRub']),
      shippingCostActualRub: _doubleValue(json['shippingCostActualRub']),
      additionalExpensesRub: _doubleValue(json['additionalExpensesRub']),
      actualWeightKg: _doubleValue(json['actualWeightKg']),
      totalDueRub: _doubleValue(json['totalDueRub']),
      updatedAt: _dateValue(json['updatedAt']),
      customer: json['customer'] is Map<String, dynamic>
          ? SpV2Customer.fromJson(json['customer'] as Map<String, dynamic>)
          : null,
      tracks: _listValue(json['tracks'], SpV2TrackRef.fromJson),
      media: _listValue(json['media'], SpV2Media.fromJson),
      payments: _listValue(json['payments'], SpV2Payment.fromJson),
    );
  }

  double purchasePriceForCurrency(String currency) =>
      currency == 'RUB' ? costPriceRub : purchasePriceYuan;

  double clientPriceForCurrency(String currency) =>
      currency == 'RUB' ? clientPriceRub : clientPriceYuan;

  bool get isPurchased => status == 'purchased';

  bool get isGoodsPaid => payments.any(
    (payment) => payment.type == 'goods_payment' && payment.isPaid,
  );

  bool get isDeliveryPaid => payments.any(
    (payment) => payment.type == 'delivery_payment' && payment.isPaid,
  );
}

class SpV2BulkItemUpdate {
  final int id;
  final DateTime expectedUpdatedAt;
  final double? clientPriceYuan;
  final double? clientPriceRub;
  final double? shippingCostRub;
  final double? shippingCostActualRub;
  final double? totalDueRub;

  const SpV2BulkItemUpdate({
    required this.id,
    required this.expectedUpdatedAt,
    this.clientPriceYuan,
    this.clientPriceRub,
    this.shippingCostRub,
    this.shippingCostActualRub,
    this.totalDueRub,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'expectedUpdatedAt': expectedUpdatedAt.toUtc().toIso8601String(),
      if (clientPriceYuan != null) 'clientPriceYuan': clientPriceYuan,
      if (clientPriceRub != null) 'clientPriceRub': clientPriceRub,
      if (shippingCostRub != null) 'shippingCostRub': shippingCostRub,
      if (shippingCostActualRub != null)
        'shippingCostActualRub': shippingCostActualRub,
      if (totalDueRub != null) 'totalDueRub': totalDueRub,
    };
  }
}

class SpV2BulkStatusOption {
  final String code;
  final String nameRu;
  final String? nameZh;
  final String? color;
  final String? icon;
  final int sortOrder;

  const SpV2BulkStatusOption({
    required this.code,
    required this.nameRu,
    this.nameZh,
    this.color,
    this.icon,
    required this.sortOrder,
  });

  factory SpV2BulkStatusOption.fromJson(Map<String, dynamic> json) {
    return SpV2BulkStatusOption(
      code: _stringValue(json['code']) ?? '',
      nameRu: _stringValue(json['nameRu']) ?? '',
      nameZh: _stringValue(json['nameZh']),
      color: _stringValue(json['color']),
      icon: _stringValue(json['icon']),
      sortOrder: _intValue(json['sortOrder']),
    );
  }
}

class SpV2BulkCustomerOption {
  final int id;
  final String name;
  final bool isOrganizerSelf;

  const SpV2BulkCustomerOption({
    required this.id,
    required this.name,
    required this.isOrganizerSelf,
  });

  factory SpV2BulkCustomerOption.fromJson(Map<String, dynamic> json) {
    return SpV2BulkCustomerOption(
      id: _intValue(json['id']),
      name: _stringValue(json['name']) ?? '',
      isOrganizerSelf: json['isOrganizerSelf'] == true,
    );
  }
}

class SpV2BulkPurchaseOption {
  final int id;
  final String title;
  final String status;

  const SpV2BulkPurchaseOption({
    required this.id,
    required this.title,
    required this.status,
  });

  factory SpV2BulkPurchaseOption.fromJson(Map<String, dynamic> json) {
    return SpV2BulkPurchaseOption(
      id: _intValue(json['id']),
      title: _stringValue(json['title']) ?? '',
      status: _stringValue(json['status']) ?? '',
    );
  }
}

class SpV2BulkOptions {
  final int purchaseId;
  final int maxItems;
  final List<SpV2BulkStatusOption> statuses;
  final List<SpV2BulkCustomerOption> customers;
  final List<SpV2BulkPurchaseOption> purchases;

  const SpV2BulkOptions({
    required this.purchaseId,
    required this.maxItems,
    this.statuses = const [],
    this.customers = const [],
    this.purchases = const [],
  });

  factory SpV2BulkOptions.fromJson(Map<String, dynamic> json) {
    final statuses = [
      ..._listValue(json['statuses'], SpV2BulkStatusOption.fromJson),
    ]..sort((left, right) => left.sortOrder.compareTo(right.sortOrder));
    return SpV2BulkOptions(
      purchaseId: _intValue(json['purchaseId']),
      maxItems: _intValue(json['maxItems'], 500),
      statuses: statuses,
      customers: _listValue(json['customers'], SpV2BulkCustomerOption.fromJson),
      purchases: _listValue(json['purchases'], SpV2BulkPurchaseOption.fromJson),
    );
  }
}

class SpV2BulkApplyResult {
  final String operation;
  final int purchaseId;
  final int requestedCount;
  final int updatedCount;
  final bool applied;
  final List<int> itemIds;

  const SpV2BulkApplyResult({
    required this.operation,
    required this.purchaseId,
    required this.requestedCount,
    required this.updatedCount,
    required this.applied,
    this.itemIds = const [],
  });

  factory SpV2BulkApplyResult.fromJson(Map<String, dynamic> json) {
    return SpV2BulkApplyResult(
      operation: _stringValue(json['operation']) ?? '',
      purchaseId: _intValue(json['purchaseId']),
      requestedCount: _intValue(json['requestedCount']),
      updatedCount: _intValue(json['updatedCount']),
      applied: json['applied'] == true,
      itemIds: json['itemIds'] is List
          ? (json['itemIds'] as List)
                .map(_intValue)
                .where((id) => id > 0)
                .toList(growable: false)
          : const [],
    );
  }
}

class SpV2CustomerShipment {
  final int id;
  final int spCustomerId;
  final String status;
  final String? carrierName;
  final String? trackingNumber;
  final double costRub;
  final DateTime? sentAt;
  final DateTime? deliveredAt;
  final String? comment;
  final SpV2Customer? customer;

  const SpV2CustomerShipment({
    required this.id,
    required this.spCustomerId,
    required this.status,
    this.carrierName,
    this.trackingNumber,
    this.costRub = 0,
    this.sentAt,
    this.deliveredAt,
    this.comment,
    this.customer,
  });

  factory SpV2CustomerShipment.fromJson(Map<String, dynamic> json) {
    return SpV2CustomerShipment(
      id: _intValue(json['id']),
      spCustomerId: _intValue(json['spCustomerId']),
      status: _stringValue(json['status']) ?? 'draft',
      carrierName: _stringValue(json['carrierName']),
      trackingNumber: _stringValue(json['trackingNumber']),
      costRub: _doubleValue(json['costRub']),
      sentAt: _dateValue(json['sentAt']),
      deliveredAt: _dateValue(json['deliveredAt']),
      comment: _stringValue(json['comment']),
      customer: json['customer'] is Map<String, dynamic>
          ? SpV2Customer.fromJson(json['customer'] as Map<String, dynamic>)
          : null,
    );
  }
}

class SpV2ShipmentStatusInfo {
  final String code;
  final String label;

  const SpV2ShipmentStatusInfo(this.code, this.label);

  static const all = <SpV2ShipmentStatusInfo>[
    SpV2ShipmentStatusInfo('draft', 'Черновик'),
    SpV2ShipmentStatusInfo('ready', 'Готово к отправке'),
    SpV2ShipmentStatusInfo('sent', 'Отправлено'),
    SpV2ShipmentStatusInfo('delivered', 'Доставлено'),
    SpV2ShipmentStatusInfo('cancelled', 'Отменено'),
  ];

  static String labelFor(String code) {
    return all
        .firstWhere(
          (status) => status.code == code,
          orElse: () => SpV2ShipmentStatusInfo(code, code),
        )
        .label;
  }
}

class SpV2Purchase {
  final int id;
  final String kind;
  final String title;
  final String? description;
  final String status;
  final String statusLabel;
  final bool isAcceptingItems;
  final String currency;
  final double purchaseRate;
  final String commissionMode;
  final SpV2ClientCardSections clientCardSections;
  final DateTime? startedAt;
  final DateTime? dispatchedFromChinaAt;
  final DateTime? completedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final SpV2ClientCodeRef? clientCode;
  final SpV2PurchaseStats stats;
  final SpV2PurchaseDirectoryCard directory;
  final List<SpV2Item> items;
  final List<SpV2Expense> expenses;
  final List<SpV2Payment> payments;
  final List<SpV2CustomerShipment> shipments;

  const SpV2Purchase({
    required this.id,
    this.kind = 'group',
    required this.title,
    this.description,
    required this.status,
    required this.statusLabel,
    required this.isAcceptingItems,
    this.currency = 'CNY',
    this.purchaseRate = 0,
    this.commissionMode = 'hidden_margin',
    this.clientCardSections = const SpV2ClientCardSections(),
    this.startedAt,
    this.dispatchedFromChinaAt,
    this.completedAt,
    this.createdAt,
    this.updatedAt,
    this.clientCode,
    this.stats = const SpV2PurchaseStats(),
    this.directory = const SpV2PurchaseDirectoryCard(),
    this.items = const [],
    this.expenses = const [],
    this.payments = const [],
    this.shipments = const [],
  });

  factory SpV2Purchase.fromJson(Map<String, dynamic> json) {
    final status = _stringValue(json['status']) ?? 'open';
    return SpV2Purchase(
      id: _intValue(json['id']),
      kind: _stringValue(json['kind']) ?? 'group',
      title: _stringValue(json['title']) ?? 'Совместная покупка',
      description: _stringValue(json['description']),
      status: status,
      statusLabel:
          _stringValue(json['statusLabel']) ??
          SpV2PurchaseStatusInfo.labelFor(status),
      isAcceptingItems: _boolValue(json['isAcceptingItems'], status == 'open'),
      currency: (_stringValue(json['currency']) ?? 'CNY').toUpperCase(),
      purchaseRate: _doubleValue(json['purchaseRate']),
      commissionMode: _stringValue(json['commissionMode']) ?? 'hidden_margin',
      clientCardSections: SpV2ClientCardSections.fromJson(json),
      startedAt: _dateValue(json['startedAt']),
      dispatchedFromChinaAt: _dateValue(json['dispatchedFromChinaAt']),
      completedAt: _dateValue(json['completedAt']),
      createdAt: _dateValue(json['createdAt']),
      updatedAt: _dateValue(json['updatedAt']),
      clientCode: json['clientCode'] is Map<String, dynamic>
          ? SpV2ClientCodeRef.fromJson(
              json['clientCode'] as Map<String, dynamic>,
            )
          : null,
      stats: SpV2PurchaseStats.fromJson(json['stats'] as Map<String, dynamic>?),
      directory: SpV2PurchaseDirectoryCard.fromJson(
        json['directory'] as Map<String, dynamic>?,
      ),
      items: _listValue(json['items'], SpV2Item.fromJson),
      expenses: _listValue(json['expenses'], SpV2Expense.fromJson),
      payments: _listValue(json['payments'], SpV2Payment.fromJson),
      shipments: _listValue(json['shipments'], SpV2CustomerShipment.fromJson),
    );
  }
}

class SpV2ClientCardSections {
  final bool showTariff;
  final bool showCustomPrice;
  final bool showFinance;
  final bool showDelivery;

  const SpV2ClientCardSections({
    this.showTariff = true,
    this.showCustomPrice = true,
    this.showFinance = true,
    this.showDelivery = true,
  });

  factory SpV2ClientCardSections.fromJson(Map<String, dynamic> json) {
    return SpV2ClientCardSections(
      showTariff: _boolValue(json['showClientTariff'], true),
      showCustomPrice: _boolValue(json['showClientCustomPrice'], true),
      showFinance: _boolValue(json['showClientFinance'], true),
      showDelivery: _boolValue(json['showClientDelivery'], true),
    );
  }

  SpV2ClientCardSections copyWith({
    bool? showTariff,
    bool? showCustomPrice,
    bool? showFinance,
    bool? showDelivery,
  }) {
    return SpV2ClientCardSections(
      showTariff: showTariff ?? this.showTariff,
      showCustomPrice: showCustomPrice ?? this.showCustomPrice,
      showFinance: showFinance ?? this.showFinance,
      showDelivery: showDelivery ?? this.showDelivery,
    );
  }

  Map<String, dynamic> toJson() => {
    'showClientTariff': showTariff,
    'showClientCustomPrice': showCustomPrice,
    'showClientFinance': showFinance,
    'showClientDelivery': showDelivery,
  };
}

class SpV2PurchaseDirectoryIntegrations {
  final int selfBuyoutRequestsCount;
  final int garageOrderItemsCount;
  final int tracksCount;
  final int photosCount;
  final int photoRequestsCount;
  final int assembliesCount;
  final int invoicesCount;
  final int connectedServicesCount;

  const SpV2PurchaseDirectoryIntegrations({
    this.selfBuyoutRequestsCount = 0,
    this.garageOrderItemsCount = 0,
    this.tracksCount = 0,
    this.photosCount = 0,
    this.photoRequestsCount = 0,
    this.assembliesCount = 0,
    this.invoicesCount = 0,
    this.connectedServicesCount = 0,
  });

  bool get hasAny => connectedServicesCount > 0;

  factory SpV2PurchaseDirectoryIntegrations.fromJson(
    Map<String, dynamic>? json,
  ) {
    if (json == null) {
      return const SpV2PurchaseDirectoryIntegrations();
    }
    return SpV2PurchaseDirectoryIntegrations(
      selfBuyoutRequestsCount: _intValue(json['selfBuyoutRequestsCount']),
      garageOrderItemsCount: _intValue(json['garageOrderItemsCount']),
      tracksCount: _intValue(json['tracksCount']),
      photosCount: _intValue(json['photosCount']),
      photoRequestsCount: _intValue(json['photoRequestsCount']),
      assembliesCount: _intValue(json['assembliesCount']),
      invoicesCount: _intValue(json['invoicesCount']),
      connectedServicesCount: _intValue(json['connectedServicesCount']),
    );
  }
}

class SpV2PurchaseDirectoryCard {
  final bool available;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? stageAt;
  final double weightKg;
  final String weightSource;
  final double costRub;
  final double outstandingRub;
  final double profitRub;
  final SpV2PurchaseDirectoryIntegrations integrations;

  const SpV2PurchaseDirectoryCard({
    this.available = false,
    this.createdAt,
    this.updatedAt,
    this.stageAt,
    this.weightKg = 0,
    this.weightSource = 'none',
    this.costRub = 0,
    this.outstandingRub = 0,
    this.profitRub = 0,
    this.integrations = const SpV2PurchaseDirectoryIntegrations(),
  });

  factory SpV2PurchaseDirectoryCard.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const SpV2PurchaseDirectoryCard();
    return SpV2PurchaseDirectoryCard(
      available: true,
      createdAt: _dateValue(json['createdAt']),
      updatedAt: _dateValue(json['updatedAt']),
      stageAt: _dateValue(json['stageAt']),
      weightKg: _doubleValue(json['weightKg']),
      weightSource: _stringValue(json['weightSource']) ?? 'none',
      costRub: _doubleValue(json['costRub']),
      outstandingRub: _doubleValue(json['outstandingRub']),
      profitRub: _doubleValue(json['profitRub']),
      integrations: SpV2PurchaseDirectoryIntegrations.fromJson(
        json['integrations'] as Map<String, dynamic>?,
      ),
    );
  }
}

const _spDirectoryUnset = Object();

class SpV2PurchaseDirectoryQuery {
  final String query;
  final String? status;
  final String? kind;
  final String scope;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String sortBy;
  final String sortDirection;
  final int page;
  final int limit;

  const SpV2PurchaseDirectoryQuery({
    this.query = '',
    this.status,
    this.kind,
    this.scope = 'active',
    this.dateFrom,
    this.dateTo,
    this.sortBy = 'createdAt',
    this.sortDirection = 'desc',
    this.page = 1,
    this.limit = 20,
  });

  bool get hasCustomFilters =>
      status != null ||
      kind != null ||
      scope != 'active' ||
      dateFrom != null ||
      dateTo != null ||
      sortBy != 'createdAt' ||
      sortDirection != 'desc';

  int get activeFilterCount {
    var count = 0;
    if (status != null) count += 1;
    if (kind != null) count += 1;
    if (scope != 'active') count += 1;
    if (dateFrom != null || dateTo != null) count += 1;
    if (sortBy != 'createdAt' || sortDirection != 'desc') count += 1;
    return count;
  }

  Map<String, dynamic> toQueryParameters() => {
    'page': page,
    'limit': limit,
    'scope': scope,
    'sortBy': sortBy,
    'sortDirection': sortDirection,
    if (query.trim().isNotEmpty) 'q': query.trim(),
    if (status != null) 'status': status,
    if (kind != null) 'kind': kind,
    if (dateFrom != null) 'dateFrom': _spDirectoryDate(dateFrom!),
    if (dateTo != null) 'dateTo': _spDirectoryDate(dateTo!),
  };

  SpV2PurchaseDirectoryQuery copyWith({
    String? query,
    Object? status = _spDirectoryUnset,
    Object? kind = _spDirectoryUnset,
    String? scope,
    Object? dateFrom = _spDirectoryUnset,
    Object? dateTo = _spDirectoryUnset,
    String? sortBy,
    String? sortDirection,
    int? page,
    int? limit,
  }) {
    return SpV2PurchaseDirectoryQuery(
      query: query ?? this.query,
      status: identical(status, _spDirectoryUnset)
          ? this.status
          : status as String?,
      kind: identical(kind, _spDirectoryUnset) ? this.kind : kind as String?,
      scope: scope ?? this.scope,
      dateFrom: identical(dateFrom, _spDirectoryUnset)
          ? this.dateFrom
          : dateFrom as DateTime?,
      dateTo: identical(dateTo, _spDirectoryUnset)
          ? this.dateTo
          : dateTo as DateTime?,
      sortBy: sortBy ?? this.sortBy,
      sortDirection: sortDirection ?? this.sortDirection,
      page: page ?? this.page,
      limit: limit ?? this.limit,
    );
  }
}

String _spDirectoryDate(DateTime value) {
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${value.year}-${twoDigits(value.month)}-${twoDigits(value.day)}';
}

class SpV2PurchaseDirectoryStatus {
  final String code;
  final String label;

  const SpV2PurchaseDirectoryStatus({required this.code, required this.label});

  factory SpV2PurchaseDirectoryStatus.fromJson(Map<String, dynamic> json) {
    final code = _stringValue(json['code']) ?? '';
    return SpV2PurchaseDirectoryStatus(
      code: code,
      label:
          _stringValue(json['label']) ?? SpV2PurchaseStatusInfo.labelFor(code),
    );
  }
}

class SpV2PurchaseDirectoryPagination {
  final int page;
  final int limit;
  final int total;
  final int totalPages;
  final bool hasNextPage;
  final bool hasPreviousPage;

  const SpV2PurchaseDirectoryPagination({
    this.page = 1,
    this.limit = 20,
    this.total = 0,
    this.totalPages = 1,
    this.hasNextPage = false,
    this.hasPreviousPage = false,
  });

  factory SpV2PurchaseDirectoryPagination.fromJson(
    Map<String, dynamic>? json, {
    int fallbackTotal = 0,
  }) {
    if (json == null) {
      return SpV2PurchaseDirectoryPagination(
        total: fallbackTotal,
        limit: fallbackTotal > 0 ? fallbackTotal : 20,
      );
    }
    return SpV2PurchaseDirectoryPagination(
      page: _intValue(json['page'], 1),
      limit: _intValue(json['limit'], 20),
      total: _intValue(json['total'], fallbackTotal),
      totalPages: _intValue(json['totalPages'], 1),
      hasNextPage: _boolValue(json['hasNextPage']),
      hasPreviousPage: _boolValue(json['hasPreviousPage']),
    );
  }
}

class SpV2PurchaseDirectorySummary {
  final int purchasesCount;
  final int activePurchasesCount;
  final int itemsCount;
  final double totalDueRub;
  final double totalProfitRub;

  const SpV2PurchaseDirectorySummary({
    this.purchasesCount = 0,
    this.activePurchasesCount = 0,
    this.itemsCount = 0,
    this.totalDueRub = 0,
    this.totalProfitRub = 0,
  });

  factory SpV2PurchaseDirectorySummary.fromJson(
    Map<String, dynamic>? json,
    List<SpV2Purchase> purchases,
  ) {
    if (json == null) {
      return SpV2PurchaseDirectorySummary.fromPurchases(purchases);
    }
    return SpV2PurchaseDirectorySummary(
      purchasesCount: _intValue(json['purchasesCount']),
      activePurchasesCount: _intValue(json['activePurchasesCount']),
      itemsCount: _intValue(json['itemsCount']),
      totalDueRub: _doubleValue(json['totalDueRub']),
      totalProfitRub: _doubleValue(json['totalProfitRub']),
    );
  }

  factory SpV2PurchaseDirectorySummary.fromPurchases(
    List<SpV2Purchase> purchases,
  ) {
    return SpV2PurchaseDirectorySummary(
      purchasesCount: purchases.length,
      activePurchasesCount: purchases
          .where(
            (purchase) =>
                purchase.status != 'completed' &&
                purchase.status != 'cancelled',
          )
          .length,
      itemsCount: purchases.fold(
        0,
        (sum, purchase) => sum + purchase.stats.itemsCount,
      ),
      totalDueRub: purchases.fold(
        0,
        (sum, purchase) => sum + purchase.stats.totalDueRub,
      ),
      totalProfitRub: purchases.fold(
        0,
        (sum, purchase) => sum + purchase.stats.totalProfitRub,
      ),
    );
  }
}

class SpV2PurchaseDirectoryPage {
  final List<SpV2Purchase> purchases;
  final SpV2PurchaseDirectoryPagination pagination;
  final SpV2PurchaseDirectorySummary summary;
  final List<SpV2PurchaseDirectoryStatus> statusOptions;
  final bool usedLegacyResponse;

  const SpV2PurchaseDirectoryPage({
    this.purchases = const [],
    this.pagination = const SpV2PurchaseDirectoryPagination(),
    this.summary = const SpV2PurchaseDirectorySummary(),
    this.statusOptions = const [],
    this.usedLegacyResponse = false,
  });

  factory SpV2PurchaseDirectoryPage.fromResponse(dynamic response) {
    if (response is List) {
      final purchases = response
          .whereType<Map<String, dynamic>>()
          .map(SpV2Purchase.fromJson)
          .toList(growable: false);
      return SpV2PurchaseDirectoryPage(
        purchases: purchases,
        pagination: SpV2PurchaseDirectoryPagination(
          limit: purchases.isEmpty ? 20 : purchases.length,
          total: purchases.length,
        ),
        summary: SpV2PurchaseDirectorySummary.fromPurchases(purchases),
        statusOptions: SpV2PurchaseStatusInfo.all
            .map(
              (status) => SpV2PurchaseDirectoryStatus(
                code: status.code,
                label: status.label,
              ),
            )
            .toList(growable: false),
        usedLegacyResponse: true,
      );
    }

    if (response is! Map<String, dynamic>) {
      return const SpV2PurchaseDirectoryPage();
    }

    final purchases = _listValue(response['data'], SpV2Purchase.fromJson);
    final filterOptions = response['filterOptions'] is Map<String, dynamic>
        ? response['filterOptions'] as Map<String, dynamic>
        : null;
    final statuses = _listValue(
      filterOptions?['statuses'],
      SpV2PurchaseDirectoryStatus.fromJson,
    );
    return SpV2PurchaseDirectoryPage(
      purchases: purchases,
      pagination: SpV2PurchaseDirectoryPagination.fromJson(
        response['pagination'] as Map<String, dynamic>?,
        fallbackTotal: purchases.length,
      ),
      summary: SpV2PurchaseDirectorySummary.fromJson(
        response['summary'] as Map<String, dynamic>?,
        purchases,
      ),
      statusOptions: statuses.isEmpty
          ? SpV2PurchaseStatusInfo.all
                .map(
                  (status) => SpV2PurchaseDirectoryStatus(
                    code: status.code,
                    label: status.label,
                  ),
                )
                .toList(growable: false)
          : statuses,
    );
  }
}

class CreateSpV2PurchaseInput {
  final String title;
  final String? kind;
  final String? description;
  final int? clientCodeId;
  final String? status;
  final String currency;
  final double? purchaseRate;
  final DateTime? startedAt;
  final DateTime? dispatchedFromChinaAt;
  final DateTime? completedAt;
  final SpV2ClientCardSections clientCardSections;

  const CreateSpV2PurchaseInput({
    required this.title,
    this.kind,
    this.description,
    this.clientCodeId,
    this.status,
    this.currency = 'CNY',
    this.purchaseRate,
    this.startedAt,
    this.dispatchedFromChinaAt,
    this.completedAt,
    this.clientCardSections = const SpV2ClientCardSections(),
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    if (kind != null) 'kind': kind,
    if (description != null && description!.trim().isNotEmpty)
      'description': description,
    if (clientCodeId != null) 'clientCodeId': clientCodeId,
    if (status != null) 'status': status,
    'currency': currency,
    if (purchaseRate != null) 'purchaseRate': purchaseRate,
    if (startedAt != null) 'startedAt': spDateOnly(startedAt!),
    if (dispatchedFromChinaAt != null)
      'dispatchedFromChinaAt': spDateOnly(dispatchedFromChinaAt!),
    if (completedAt != null) 'completedAt': spDateOnly(completedAt!),
    ...clientCardSections.toJson(),
  };
}

String spDateOnly(DateTime value) {
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${value.year.toString().padLeft(4, '0')}-'
      '${twoDigits(value.month)}-${twoDigits(value.day)}';
}

class CreateSpV2ItemInput {
  final int? spCustomerId;
  final int? spProductId;
  final String? customerName;
  final String? customerPhone;
  final String? customerTelegram;
  final String? customerWhatsapp;
  final String? customerWechat;
  final String title;
  final String? sourceUrl;
  final String? sellerInfo;
  final String? description;
  final int quantity;
  final String currency;
  final double? purchasePrice;
  final double? clientPriceYuan;
  final double? clientPriceRub;
  final double? shippingCostRub;
  final double? shippingCostActualRub;
  final List<String> mediaUrls;

  const CreateSpV2ItemInput({
    this.spCustomerId,
    this.spProductId,
    this.customerName,
    this.customerPhone,
    this.customerTelegram,
    this.customerWhatsapp,
    this.customerWechat,
    required this.title,
    this.sourceUrl,
    this.sellerInfo,
    this.description,
    this.quantity = 1,
    this.currency = 'CNY',
    this.purchasePrice,
    this.clientPriceYuan,
    this.clientPriceRub,
    this.shippingCostRub,
    this.shippingCostActualRub,
    this.mediaUrls = const [],
  });

  Map<String, dynamic> toJson() => {
    if (spCustomerId != null) 'spCustomerId': spCustomerId,
    if (spProductId != null) 'spProductId': spProductId,
    if (spCustomerId == null)
      'customer': {
        'fullName': customerName,
        if (customerPhone != null && customerPhone!.trim().isNotEmpty)
          'phone': customerPhone,
        if (customerTelegram != null && customerTelegram!.trim().isNotEmpty)
          'telegram': customerTelegram,
        if (customerWhatsapp != null && customerWhatsapp!.trim().isNotEmpty)
          'whatsapp': customerWhatsapp,
        if (customerWechat != null && customerWechat!.trim().isNotEmpty)
          'wechat': customerWechat,
      },
    'title': title,
    if (sourceUrl != null && sourceUrl!.trim().isNotEmpty)
      'sourceUrl': sourceUrl,
    if (sellerInfo != null && sellerInfo!.trim().isNotEmpty)
      'sellerInfo': sellerInfo,
    if (description != null && description!.trim().isNotEmpty)
      'description': description,
    'quantity': quantity,
    if (currency == 'RUB') ...{
      if (purchasePrice != null) 'purchasePriceRub': purchasePrice,
      if (clientPriceRub != null) 'clientPriceRub': clientPriceRub,
    } else ...{
      if (purchasePrice != null) 'purchasePriceYuan': purchasePrice,
      if (clientPriceYuan != null) 'clientPriceYuan': clientPriceYuan,
    },
    if (shippingCostRub != null) 'shippingCostRub': shippingCostRub,
    if (shippingCostActualRub != null)
      'shippingCostActualRub': shippingCostActualRub,
    if (mediaUrls.isNotEmpty) 'mediaUrls': mediaUrls,
  };
}

class CreateSpV2ExpenseInput {
  final String title;
  final double amountRub;
  final String allocationMethod;
  final String? comment;

  const CreateSpV2ExpenseInput({
    required this.title,
    required this.amountRub,
    this.allocationMethod = 'equal',
    this.comment,
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'amountRub': amountRub,
    'allocationMethod': allocationMethod,
    if (comment != null && comment!.trim().isNotEmpty) 'comment': comment,
  };
}
