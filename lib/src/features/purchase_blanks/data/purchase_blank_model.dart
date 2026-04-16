import 'package:flutter/material.dart';

// ─── Статус бланка ───────────────────────────────────────

enum PurchaseBlankStatus {
  newBlank('new_blank', 'Новый', '新建'),
  submitted('submitted', 'Отправлен', '已提交'),
  inProgress('in_progress', 'В работе', '进行中'),
  completed('completed', 'Выполнен', '已完成'),
  cancelled('cancelled', 'Отменён', '已取消');

  final String code;
  final String label;
  final String labelZh;
  const PurchaseBlankStatus(this.code, this.label, this.labelZh);

  String localizedLabel(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    return locale == 'zh' ? labelZh : label;
  }

  static PurchaseBlankStatus fromCode(String code) {
    return PurchaseBlankStatus.values.firstWhere(
      (e) => e.code == code,
      orElse: () => PurchaseBlankStatus.newBlank,
    );
  }

  Color get color {
    switch (this) {
      case PurchaseBlankStatus.newBlank:
        return const Color(0xFF2196F3); // синий
      case PurchaseBlankStatus.submitted:
        return const Color(0xFF9C27B0); // фиолетовый
      case PurchaseBlankStatus.inProgress:
        return const Color(0xFFFF9800); // оранжевый
      case PurchaseBlankStatus.completed:
        return const Color(0xFF4CAF50); // зелёный
      case PurchaseBlankStatus.cancelled:
        return const Color(0xFFF44336); // красный
    }
  }

  IconData get icon {
    switch (this) {
      case PurchaseBlankStatus.newBlank:
        return Icons.fiber_new_rounded;
      case PurchaseBlankStatus.submitted:
        return Icons.send_rounded;
      case PurchaseBlankStatus.inProgress:
        return Icons.autorenew_rounded;
      case PurchaseBlankStatus.completed:
        return Icons.check_circle_rounded;
      case PurchaseBlankStatus.cancelled:
        return Icons.cancel_rounded;
    }
  }

  /// Клиент может редактировать бланк только в этом статусе
  bool get isEditableByClient => this == PurchaseBlankStatus.newBlank;

  /// Клиент может отменить бланк
  bool get isCancellableByClient =>
      this == PurchaseBlankStatus.newBlank || this == PurchaseBlankStatus.submitted;

  /// Бланк завершён (финальный статус)
  bool get isFinal =>
      this == PurchaseBlankStatus.completed || this == PurchaseBlankStatus.cancelled;
}

// ─── Товар в бланке ──────────────────────────────────────

class PurchaseBlankItem {
  final int id;
  final int blankId;
  final int orderNumber;

  // Заполняет клиент
  final String productName;
  final String productUrl;
  final String? characteristics;
  final int quantity;
  final double unitPrice;
  final List<String> photoUrls;

  // Рассчитывается автоматически
  final double totalPrice; // quantity × unitPrice

  // Заполняет сотрудник (2a-admin)
  final String? trackNumber;
  final double? commission;
  final double? itemTotal; // totalPrice + commission

  final DateTime createdAt;
  final DateTime updatedAt;

  const PurchaseBlankItem({
    required this.id,
    required this.blankId,
    required this.orderNumber,
    required this.productName,
    required this.productUrl,
    this.characteristics,
    this.quantity = 1,
    required this.unitPrice,
    this.photoUrls = const [],
    this.totalPrice = 0,
    this.trackNumber,
    this.commission,
    this.itemTotal,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Есть ли данные сотрудника
  bool get hasEmployeeData => trackNumber != null || commission != null;

  factory PurchaseBlankItem.fromJson(Map<String, dynamic> json) {
    final photoUrlsRaw = json['photoUrls'];
    List<String> photoUrls = [];
    if (photoUrlsRaw is List) {
      photoUrls = photoUrlsRaw.map((e) => e.toString()).toList();
    } else if (photoUrlsRaw is String) {
      try {
        // Может быть JSON-строкой
        photoUrls = [];
      } catch (_) {}
    }

    return PurchaseBlankItem(
      id: json['id'] as int? ?? 0,
      blankId: json['blankId'] as int? ?? 0,
      orderNumber: json['orderNumber'] as int? ?? 0,
      productName: json['productName'] as String? ?? '',
      productUrl: json['productUrl'] as String? ?? '',
      characteristics: json['characteristics'] as String?,
      quantity: json['quantity'] as int? ?? 1,
      unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0.0,
      photoUrls: photoUrls,
      totalPrice: (json['totalPrice'] as num?)?.toDouble() ?? 0.0,
      trackNumber: json['trackNumber'] as String?,
      commission: (json['commission'] as num?)?.toDouble(),
      itemTotal: (json['itemTotal'] as num?)?.toDouble(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'productName': productName,
        'productUrl': productUrl,
        if (characteristics != null) 'characteristics': characteristics,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'photoUrls': photoUrls,
      };

  PurchaseBlankItem copyWith({
    int? id,
    int? blankId,
    int? orderNumber,
    String? productName,
    String? productUrl,
    String? characteristics,
    int? quantity,
    double? unitPrice,
    List<String>? photoUrls,
    double? totalPrice,
    String? trackNumber,
    double? commission,
    double? itemTotal,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PurchaseBlankItem(
      id: id ?? this.id,
      blankId: blankId ?? this.blankId,
      orderNumber: orderNumber ?? this.orderNumber,
      productName: productName ?? this.productName,
      productUrl: productUrl ?? this.productUrl,
      characteristics: characteristics ?? this.characteristics,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      photoUrls: photoUrls ?? this.photoUrls,
      totalPrice: totalPrice ?? this.totalPrice,
      trackNumber: trackNumber ?? this.trackNumber,
      commission: commission ?? this.commission,
      itemTotal: itemTotal ?? this.itemTotal,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// ─── Бланк на выкуп ─────────────────────────────────────

class PurchaseBlank {
  final int id;
  final int clientId;
  final int agentId;
  final int? conversationId;
  final PurchaseBlankStatus status;

  // Финансовые поля (заполняет сотрудник)
  final double? commissionPercent;
  final double? usdToCny;
  final double? usdToRub;
  final double? totalAmountCny;
  final double? totalAmountRub;

  final String? employeeComment;

  final DateTime createdAt;
  final DateTime updatedAt;

  // Товары
  final List<PurchaseBlankItem> items;

  const PurchaseBlank({
    required this.id,
    required this.clientId,
    required this.agentId,
    this.conversationId,
    this.status = PurchaseBlankStatus.newBlank,
    this.commissionPercent,
    this.usdToCny,
    this.usdToRub,
    this.totalAmountCny,
    this.totalAmountRub,
    this.employeeComment,
    required this.createdAt,
    required this.updatedAt,
    this.items = const [],
  });

  /// Кол-во товаров
  int get itemsCount => items.length;

  /// Общая стоимость товаров (клиентская, без комиссий)
  double get clientTotalCny =>
      items.fold(0.0, (sum, item) => sum + item.totalPrice);

  /// Есть ли данные сотрудника
  bool get hasEmployeeData =>
      commissionPercent != null || usdToCny != null || usdToRub != null;

  factory PurchaseBlank.fromJson(Map<String, dynamic> json) {
    final itemsJson = json['items'] as List<dynamic>? ?? [];

    return PurchaseBlank(
      id: json['id'] as int? ?? 0,
      clientId: json['clientId'] as int? ?? 0,
      agentId: json['agentId'] as int? ?? 0,
      conversationId: json['conversationId'] as int?,
      status: PurchaseBlankStatus.fromCode(
          json['status'] as String? ?? 'new_blank'),
      commissionPercent: (json['commissionPercent'] as num?)?.toDouble(),
      usdToCny: (json['usdToCny'] as num?)?.toDouble(),
      usdToRub: (json['usdToRub'] as num?)?.toDouble(),
      totalAmountCny: (json['totalAmountCny'] as num?)?.toDouble(),
      totalAmountRub: (json['totalAmountRub'] as num?)?.toDouble(),
      employeeComment: json['employeeComment'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      items: itemsJson
          .map((e) =>
              PurchaseBlankItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
