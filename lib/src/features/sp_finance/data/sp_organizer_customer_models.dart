Map<String, dynamic> _mapValue(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : const {};

List<Map<String, dynamic>> _mapList(dynamic value) => value is List
    ? value
          .whereType<Map>()
          .map(Map<String, dynamic>.from)
          .toList(growable: false)
    : const [];

String? _stringValue(dynamic value) {
  if (value is! String) return null;
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}

int _intValue(dynamic value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

double _doubleValue(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) {
    return double.tryParse(value.replaceAll(',', '.')) ?? 0;
  }
  return 0;
}

bool _boolValue(dynamic value, [bool fallback = false]) =>
    value is bool ? value : fallback;

DateTime? _dateValue(dynamic value) =>
    value is String ? DateTime.tryParse(value) : null;

class SpOrganizerCustomerLastPurchase {
  final int id;
  final String title;
  final String status;
  final String kind;
  final DateTime? createdAt;

  const SpOrganizerCustomerLastPurchase({
    required this.id,
    required this.title,
    required this.status,
    required this.kind,
    this.createdAt,
  });

  factory SpOrganizerCustomerLastPurchase.fromJson(Map<String, dynamic> json) {
    return SpOrganizerCustomerLastPurchase(
      id: _intValue(json['id']),
      title: _stringValue(json['title']) ?? '',
      status: _stringValue(json['status']) ?? '',
      kind: _stringValue(json['kind']) ?? 'group',
      createdAt: _dateValue(json['createdAt']),
    );
  }
}

class SpOrganizerCustomerMetrics {
  final int purchasesCount;
  final int itemsCount;
  final double turnoverRub;
  final double paidRub;
  final double balanceRub;
  final double debtRub;
  final double profitRub;
  final double totalWeightKg;
  final int shipmentsCount;
  final int sentShipmentsCount;
  final int deliveredShipmentsCount;
  final SpOrganizerCustomerLastPurchase? lastPurchase;

  const SpOrganizerCustomerMetrics({
    this.purchasesCount = 0,
    this.itemsCount = 0,
    this.turnoverRub = 0,
    this.paidRub = 0,
    this.balanceRub = 0,
    this.debtRub = 0,
    this.profitRub = 0,
    this.totalWeightKg = 0,
    this.shipmentsCount = 0,
    this.sentShipmentsCount = 0,
    this.deliveredShipmentsCount = 0,
    this.lastPurchase,
  });

  factory SpOrganizerCustomerMetrics.fromJson(Map<String, dynamic> json) {
    final lastPurchase = _mapValue(json['lastPurchase']);
    return SpOrganizerCustomerMetrics(
      purchasesCount: _intValue(json['purchasesCount']),
      itemsCount: _intValue(json['itemsCount']),
      turnoverRub: _doubleValue(json['turnoverRub']),
      paidRub: _doubleValue(json['paidRub']),
      balanceRub: _doubleValue(json['balanceRub']),
      debtRub: _doubleValue(json['debtRub']),
      profitRub: _doubleValue(json['profitRub']),
      totalWeightKg: _doubleValue(json['totalWeightKg']),
      shipmentsCount: _intValue(json['shipmentsCount']),
      sentShipmentsCount: _intValue(json['sentShipmentsCount']),
      deliveredShipmentsCount: _intValue(json['deliveredShipmentsCount']),
      lastPurchase: lastPurchase.isEmpty
          ? null
          : SpOrganizerCustomerLastPurchase.fromJson(lastPurchase),
    );
  }
}

class SpOrganizerCustomer {
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
  final DateTime? archivedAt;
  final String? archivedReason;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final SpOrganizerCustomerMetrics metrics;

  const SpOrganizerCustomer({
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
    this.archivedAt,
    this.archivedReason,
    this.createdAt,
    this.updatedAt,
    this.metrics = const SpOrganizerCustomerMetrics(),
  });

  bool get isArchived => archivedAt != null;

  List<String> get compactContacts => [
    phone,
    email,
    telegram,
    whatsapp,
    wechat,
  ].whereType<String>().where((value) => value.isNotEmpty).toList();

  factory SpOrganizerCustomer.fromJson(Map<String, dynamic> json) {
    return SpOrganizerCustomer(
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
      archivedAt: _dateValue(json['archivedAt']),
      archivedReason: _stringValue(json['archivedReason']),
      createdAt: _dateValue(json['createdAt']),
      updatedAt: _dateValue(json['updatedAt']),
      metrics: SpOrganizerCustomerMetrics.fromJson(_mapValue(json['metrics'])),
    );
  }
}

class SpOrganizerCustomerPage {
  final List<SpOrganizerCustomer> items;
  final int total;
  final int page;
  final int limit;
  final int totalPages;
  final String scope;
  final String sortBy;
  final String sortDirection;
  final String mode;
  final bool persisted;

  const SpOrganizerCustomerPage({
    this.items = const [],
    this.total = 0,
    this.page = 1,
    this.limit = 30,
    this.totalPages = 0,
    this.scope = 'active',
    this.sortBy = 'fullName',
    this.sortDirection = 'asc',
    this.mode = 'read_only',
    this.persisted = false,
  });

  bool get hasMore => page < totalPages;

  factory SpOrganizerCustomerPage.fromJson(Map<String, dynamic> json) {
    return SpOrganizerCustomerPage(
      items: _mapList(
        json['items'],
      ).map(SpOrganizerCustomer.fromJson).toList(growable: false),
      total: _intValue(json['total']),
      page: _intValue(json['page'], 1),
      limit: _intValue(json['limit'], 30),
      totalPages: _intValue(json['totalPages']),
      scope: _stringValue(json['scope']) ?? 'active',
      sortBy: _stringValue(json['sortBy']) ?? 'fullName',
      sortDirection: _stringValue(json['sortDirection']) ?? 'asc',
      mode: _stringValue(json['mode']) ?? 'read_only',
      persisted: _boolValue(json['persisted']),
    );
  }
}

class SpOrganizerCustomerLedgerItem {
  final int id;
  final String title;
  final String status;
  final int quantity;
  final double amountRub;
  final String? trackingNumber;

  const SpOrganizerCustomerLedgerItem({
    required this.id,
    required this.title,
    required this.status,
    this.quantity = 0,
    this.amountRub = 0,
    this.trackingNumber,
  });

  factory SpOrganizerCustomerLedgerItem.item(Map<String, dynamic> json) {
    return SpOrganizerCustomerLedgerItem(
      id: _intValue(json['id']),
      title: _stringValue(json['title']) ?? 'Товар',
      status: _stringValue(json['status']) ?? '',
      quantity: _intValue(json['quantity'], 1),
      amountRub: _doubleValue(json['totalDueRub']),
    );
  }

  factory SpOrganizerCustomerLedgerItem.payment(Map<String, dynamic> json) {
    return SpOrganizerCustomerLedgerItem(
      id: _intValue(json['id']),
      title: _stringValue(json['type']) ?? 'payment',
      status: _stringValue(json['status']) ?? '',
      amountRub: _doubleValue(json['amountRub']),
    );
  }

  factory SpOrganizerCustomerLedgerItem.shipment(Map<String, dynamic> json) {
    return SpOrganizerCustomerLedgerItem(
      id: _intValue(json['id']),
      title: _stringValue(json['carrierName']) ?? 'Отправка',
      status: _stringValue(json['status']) ?? '',
      amountRub: _doubleValue(json['costRub']),
      trackingNumber: _stringValue(json['trackingNumber']),
    );
  }
}

class SpOrganizerCustomerHistoryPurchase {
  final int id;
  final String title;
  final String status;
  final String kind;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final SpOrganizerCustomerMetrics metrics;
  final List<SpOrganizerCustomerLedgerItem> items;
  final List<SpOrganizerCustomerLedgerItem> payments;
  final List<SpOrganizerCustomerLedgerItem> shipments;

  const SpOrganizerCustomerHistoryPurchase({
    required this.id,
    required this.title,
    required this.status,
    required this.kind,
    this.createdAt,
    this.updatedAt,
    this.metrics = const SpOrganizerCustomerMetrics(),
    this.items = const [],
    this.payments = const [],
    this.shipments = const [],
  });

  factory SpOrganizerCustomerHistoryPurchase.fromJson(
    Map<String, dynamic> json,
  ) {
    return SpOrganizerCustomerHistoryPurchase(
      id: _intValue(json['id']),
      title: _stringValue(json['title']) ?? 'Закупка',
      status: _stringValue(json['status']) ?? '',
      kind: _stringValue(json['kind']) ?? 'group',
      createdAt: _dateValue(json['createdAt']),
      updatedAt: _dateValue(json['updatedAt']),
      metrics: SpOrganizerCustomerMetrics.fromJson(_mapValue(json['metrics'])),
      items: _mapList(
        json['items'],
      ).map(SpOrganizerCustomerLedgerItem.item).toList(growable: false),
      payments: _mapList(
        json['payments'],
      ).map(SpOrganizerCustomerLedgerItem.payment).toList(growable: false),
      shipments: _mapList(
        json['shipments'],
      ).map(SpOrganizerCustomerLedgerItem.shipment).toList(growable: false),
    );
  }
}

class SpOrganizerCustomerHistoryPage {
  final List<SpOrganizerCustomerHistoryPurchase> items;
  final int total;
  final int page;
  final int limit;
  final int totalPages;

  const SpOrganizerCustomerHistoryPage({
    this.items = const [],
    this.total = 0,
    this.page = 1,
    this.limit = 30,
    this.totalPages = 0,
  });

  bool get hasMore => page < totalPages;

  factory SpOrganizerCustomerHistoryPage.fromJson(Map<String, dynamic> json) {
    return SpOrganizerCustomerHistoryPage(
      items: _mapList(json['items'])
          .map(SpOrganizerCustomerHistoryPurchase.fromJson)
          .toList(growable: false),
      total: _intValue(json['total']),
      page: _intValue(json['page'], 1),
      limit: _intValue(json['limit'], 30),
      totalPages: _intValue(json['totalPages']),
    );
  }
}

class SpOrganizerCustomerDetail {
  final SpOrganizerCustomer customer;
  final SpOrganizerCustomerMetrics metrics;
  final SpOrganizerCustomerHistoryPage history;
  final String mode;
  final bool persisted;
  final String financialScope;

  const SpOrganizerCustomerDetail({
    required this.customer,
    required this.metrics,
    required this.history,
    this.mode = 'read_only',
    this.persisted = false,
    this.financialScope = 'organizer_customer_ledger',
  });

  bool get hasMore => history.hasMore;

  factory SpOrganizerCustomerDetail.fromJson(Map<String, dynamic> json) {
    final metrics = SpOrganizerCustomerMetrics.fromJson(
      _mapValue(json['metrics']),
    );
    final customerJson = _mapValue(json['customer']);
    return SpOrganizerCustomerDetail(
      customer: SpOrganizerCustomer.fromJson({
        ...customerJson,
        'metrics': json['metrics'],
      }),
      metrics: metrics,
      history: SpOrganizerCustomerHistoryPage.fromJson(
        _mapValue(json['history']),
      ),
      mode: _stringValue(json['mode']) ?? 'read_only',
      persisted: _boolValue(json['persisted']),
      financialScope:
          _stringValue(json['financialScope']) ?? 'organizer_customer_ledger',
    );
  }

  SpOrganizerCustomerDetail mergePage(SpOrganizerCustomerDetail next) {
    return SpOrganizerCustomerDetail(
      customer: next.customer,
      metrics: next.metrics,
      history: SpOrganizerCustomerHistoryPage(
        items: [...history.items, ...next.history.items],
        total: next.history.total,
        page: next.history.page,
        limit: next.history.limit,
        totalPages: next.history.totalPages,
      ),
      mode: next.mode,
      persisted: next.persisted,
      financialScope: next.financialScope,
    );
  }
}
