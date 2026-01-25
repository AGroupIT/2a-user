/// Участник совместной покупки с агрегированными данными
class SpParticipant {
  final String name;
  final int trackCount;
  final double weight;
  final double totalAmount;
  final bool isPaid;

  const SpParticipant({
    required this.name,
    required this.trackCount,
    required this.weight,
    required this.totalAmount,
    this.isPaid = false,
  });

  factory SpParticipant.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is String) return double.tryParse(value) ?? 0.0;
      return (value as num).toDouble();
    }

    return SpParticipant(
      name: json['name'] as String,
      trackCount: json['trackCount'] as int,
      weight: parseDouble(json['weight']),
      totalAmount: parseDouble(json['totalAmount']),
      isPaid: json['isPaid'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'trackCount': trackCount,
      'weight': weight,
      'totalAmount': totalAmount,
      'isPaid': isPaid,
    };
  }

  SpParticipant copyWith({
    String? name,
    int? trackCount,
    double? weight,
    double? totalAmount,
    bool? isPaid,
  }) {
    return SpParticipant(
      name: name ?? this.name,
      trackCount: trackCount ?? this.trackCount,
      weight: weight ?? this.weight,
      totalAmount: totalAmount ?? this.totalAmount,
      isPaid: isPaid ?? this.isPaid,
    );
  }
}

/// Статистика по совместной покупке для сборки
class SpStats {
  final int tracksTotal;
  final int tracksWithSP;
  final double? grossWeightKg;
  final double totalNetWeightKg;
  final double totalCostRub;
  final double totalRevenueRub;
  final double totalShippingRub;
  final double totalProfitRub;
  final List<SpParticipant> participants;

  const SpStats({
    required this.tracksTotal,
    required this.tracksWithSP,
    this.grossWeightKg,
    required this.totalNetWeightKg,
    required this.totalCostRub,
    required this.totalRevenueRub,
    required this.totalShippingRub,
    required this.totalProfitRub,
    required this.participants,
  });

  factory SpStats.fromJson(Map<String, dynamic> json) {
    // Helper to convert string or number to double
    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is String) return double.tryParse(value) ?? 0.0;
      return (value as num).toDouble();
    }

    double? parseDoubleNullable(dynamic value) {
      if (value == null) return null;
      if (value is String) return double.tryParse(value);
      return (value as num).toDouble();
    }

    return SpStats(
      tracksTotal: json['tracksTotal'] as int,
      tracksWithSP: json['tracksWithSP'] as int,
      grossWeightKg: parseDoubleNullable(json['grossWeightKg']),
      totalNetWeightKg: parseDouble(json['totalNetWeightKg']),
      totalCostRub: parseDouble(json['totalCostRub']),
      totalRevenueRub: parseDouble(json['totalRevenueRub']),
      totalShippingRub: parseDouble(json['totalShippingRub']),
      totalProfitRub: parseDouble(json['totalProfitRub']),
      participants: (json['participants'] as List<dynamic>?)
              ?.map((e) => SpParticipant.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  SpStats copyWith({
    int? tracksTotal,
    int? tracksWithSP,
    double? grossWeightKg,
    double? totalNetWeightKg,
    double? totalCostRub,
    double? totalRevenueRub,
    double? totalShippingRub,
    double? totalProfitRub,
    List<SpParticipant>? participants,
  }) {
    return SpStats(
      tracksTotal: tracksTotal ?? this.tracksTotal,
      tracksWithSP: tracksWithSP ?? this.tracksWithSP,
      grossWeightKg: grossWeightKg ?? this.grossWeightKg,
      totalNetWeightKg: totalNetWeightKg ?? this.totalNetWeightKg,
      totalCostRub: totalCostRub ?? this.totalCostRub,
      totalRevenueRub: totalRevenueRub ?? this.totalRevenueRub,
      totalShippingRub: totalShippingRub ?? this.totalShippingRub,
      totalProfitRub: totalProfitRub ?? this.totalProfitRub,
      participants: participants ?? this.participants,
    );
  }
}

/// Информация о фото трека
class SpPhoto {
  final int id;
  final String url;
  final String? thumbnailUrl;
  final DateTime createdAt;

  const SpPhoto({
    required this.id,
    required this.url,
    this.thumbnailUrl,
    required this.createdAt,
  });

  factory SpPhoto.fromJson(Map<String, dynamic> json) {
    return SpPhoto(
      id: json['id'] as int,
      url: json['url'] as String,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

/// Информация о товаре
class SpProductInfo {
  final int id;
  final String? title;
  final String? description;
  final String? category;
  final String? brand;
  final int quantity;
  final String? imageUrl;

  const SpProductInfo({
    required this.id,
    this.title,
    this.description,
    this.category,
    this.brand,
    this.quantity = 1,
    this.imageUrl,
  });

  factory SpProductInfo.fromJson(Map<String, dynamic> json) {
    return SpProductInfo(
      id: json['id'] as int,
      title: json['title'] as String? ?? json['name'] as String? ?? json['productName'] as String?,
      description: json['description'] as String?,
      category: json['category'] as String?,
      brand: json['brand'] as String?,
      quantity: json['quantity'] as int? ?? 1,
      imageUrl: json['imageUrl'] as String?,
    );
  }
}

/// Расширенная информация о треке с СП данными
class SpTrack {
  final int id;
  final String trackNumber;
  final String? spParticipantName;
  final String? note;               // Комментарий/заметка к треку
  final double? supplierPriceYuan;  // Цена поставщика в ¥
  final double? purchasePriceYuan;  // Цена выкупа в ¥ (со скидкой)
  final double? clientPriceYuan;    // Цена для участника в ¥
  final double? purchaseRate;       // Курс ¥→₽
  final double? costPriceRub;       // Себестоимость = purchasePriceYuan × rate
  final double? clientPriceRub;     // Цена участника = clientPriceYuan × rate
  final double? organizerMarginRub; // Прибыль = clientPriceRub - costPriceRub
  final double? netWeightKg;        // Чистый вес
  final double? shippingCostRub;    // Доля доставки = netWeight × ставка за кг
  final double? additionalExpensesRub; // Дополнительные расходы в ₽
  final double? totalCostRub;       // Итого = clientPriceRub + shippingCostRub + additionalExpensesRub
  final String? status;
  final String? productTitle;
  final List<SpPhoto>? photos;
  final SpProductInfo? productInfo;

  const SpTrack({
    required this.id,
    required this.trackNumber,
    this.spParticipantName,
    this.note,
    this.supplierPriceYuan,
    this.purchasePriceYuan,
    this.clientPriceYuan,
    this.purchaseRate,
    this.costPriceRub,
    this.clientPriceRub,
    this.organizerMarginRub,
    this.netWeightKg,
    this.shippingCostRub,
    this.additionalExpensesRub,
    this.totalCostRub,
    this.status,
    this.productTitle,
    this.photos,
    this.productInfo,
  });

  factory SpTrack.fromJson(Map<String, dynamic> json) {
    // Helper to convert string or number to double (Prisma Decimal comes as String)
    double? parseDouble(dynamic value) {
      if (value == null) return null;
      if (value is String) return double.tryParse(value);
      return (value as num).toDouble();
    }

    return SpTrack(
      id: json['id'] as int,
      trackNumber: json['trackNumber'] as String,
      spParticipantName: json['spParticipantName'] as String?,
      note: json['note'] as String?,
      supplierPriceYuan: parseDouble(json['supplierPriceYuan']),
      purchasePriceYuan: parseDouble(json['purchasePriceYuan']),
      clientPriceYuan: parseDouble(json['clientPriceYuan']),
      purchaseRate: parseDouble(json['purchaseRate']),
      costPriceRub: parseDouble(json['costPriceRub']),
      clientPriceRub: parseDouble(json['clientPriceRub']),
      organizerMarginRub: parseDouble(json['organizerMarginRub']),
      netWeightKg: parseDouble(json['netWeightKg']),
      shippingCostRub: parseDouble(json['shippingCostRub']),
      additionalExpensesRub: parseDouble(json['additionalExpensesRub']),
      totalCostRub: parseDouble(json['totalCostRub']),
      status: json['status'] as String?,
      productTitle: json['productTitle'] as String?,
      photos: (json['photos'] as List<dynamic>?)
              ?.map((e) => SpPhoto.fromJson(e as Map<String, dynamic>))
              .toList(),
      productInfo: _parseProductInfo(json['productInfo']),
    );
  }

  /// Парсит productInfo - может быть массивом или объектом
  static SpProductInfo? _parseProductInfo(dynamic productInfoData) {
    if (productInfoData == null) return null;

    // Если это массив - берём первый элемент (как в track_item.dart)
    if (productInfoData is List) {
      if (productInfoData.isEmpty) return null;
      return SpProductInfo.fromJson(productInfoData.first as Map<String, dynamic>);
    }

    // Если это объект - парсим напрямую
    if (productInfoData is Map<String, dynamic>) {
      return SpProductInfo.fromJson(productInfoData);
    }

    return null;
  }

  SpTrack copyWith({
    String? spParticipantName,
    String? note,
    double? supplierPriceYuan,
    double? purchasePriceYuan,
    double? clientPriceYuan,
    double? purchaseRate,
    double? netWeightKg,
    double? additionalExpensesRub,
  }) {
    return SpTrack(
      id: id,
      trackNumber: trackNumber,
      spParticipantName: spParticipantName ?? this.spParticipantName,
      note: note ?? this.note,
      supplierPriceYuan: supplierPriceYuan ?? this.supplierPriceYuan,
      purchasePriceYuan: purchasePriceYuan ?? this.purchasePriceYuan,
      clientPriceYuan: clientPriceYuan ?? this.clientPriceYuan,
      purchaseRate: purchaseRate ?? this.purchaseRate,
      netWeightKg: netWeightKg ?? this.netWeightKg,
      costPriceRub: costPriceRub,
      clientPriceRub: clientPriceRub,
      organizerMarginRub: organizerMarginRub,
      shippingCostRub: shippingCostRub,
      additionalExpensesRub: additionalExpensesRub ?? this.additionalExpensesRub,
      totalCostRub: totalCostRub,
      status: status,
      productTitle: productTitle,
      photos: photos,
      productInfo: productInfo,
    );
  }
}

/// Информация о счете для расчета доставки
class SpInvoice {
  final int id;
  final String? invoiceNumber;
  final double weight;
  final double volume;
  final int placesCount;
  final String? calculationMethod;
  final double transshipmentCost;
  final double insuranceCost;
  final double discount;
  final double? exchangeRate;
  final double? totalCostRUB;
  final double? tariffBaseCost;
  final List<double> packagingCosts;

  const SpInvoice({
    required this.id,
    this.invoiceNumber,
    this.weight = 0,
    this.volume = 0,
    this.placesCount = 1,
    this.calculationMethod,
    this.transshipmentCost = 0,
    this.insuranceCost = 0,
    this.discount = 0,
    this.exchangeRate,
    this.totalCostRUB,
    this.tariffBaseCost,
    this.packagingCosts = const [],
  });

  /// Расчёт стоимости тарифа = вес × baseCost (или объём × 250)
  double get tariffCost {
    final baseCost = tariffBaseCost ?? 0;
    final isByWeight = calculationMethod?.toLowerCase() == 'byweight';
    if (isByWeight) {
      return weight * baseCost;
    } else {
      return volume * 250;
    }
  }

  /// Расчёт общей стоимости упаковки = сумма упаковок × кол-во мест
  double get packagingCost {
    double sum = 0;
    for (final cost in packagingCosts) {
      sum += cost;
    }
    return sum * placesCount;
  }

  /// Доставка USD = тариф + упаковка + перевалка + страховка - скидка
  double get deliveryCostUsd {
    return tariffCost + packagingCost + transshipmentCost + insuranceCost - discount;
  }

  /// Доставка RUB = Доставка USD × Курс
  double get deliveryCostRub {
    final rate = exchangeRate ?? 0;
    return deliveryCostUsd * rate;
  }

  factory SpInvoice.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is String) return double.tryParse(value) ?? 0.0;
      return (value as num).toDouble();
    }

    double? parseDoubleNullable(dynamic value) {
      if (value == null) return null;
      if (value is String) return double.tryParse(value);
      return (value as num).toDouble();
    }

    // Парсим tariff.baseCost
    final tariff = json['tariff'] as Map<String, dynamic>?;
    final tariffBaseCost = parseDoubleNullable(tariff?['baseCost']);

    // Парсим packagings[].packagingType.baseCost
    final packagingsData = json['packagings'] as List<dynamic>? ?? [];
    final packagingCosts = <double>[];
    for (final p in packagingsData) {
      if (p is Map<String, dynamic>) {
        final pkgType = p['packagingType'] as Map<String, dynamic>?;
        if (pkgType != null) {
          packagingCosts.add(parseDouble(pkgType['baseCost']));
        }
      }
    }

    return SpInvoice(
      id: json['id'] as int,
      invoiceNumber: json['invoiceNumber'] as String?,
      weight: parseDouble(json['weight']),
      volume: parseDouble(json['volume']),
      placesCount: json['placesCount'] as int? ?? 1,
      calculationMethod: json['calculationMethod'] as String?,
      transshipmentCost: parseDouble(json['transshipmentCost']),
      insuranceCost: parseDouble(json['insuranceCost']),
      discount: parseDouble(json['discount']),
      exchangeRate: parseDoubleNullable(json['exchangeRate']),
      totalCostRUB: parseDoubleNullable(json['totalCostRUB']),
      tariffBaseCost: tariffBaseCost,
      packagingCosts: packagingCosts,
    );
  }
}

/// Сборка с СП данными и статистикой
class SpAssembly {
  final int id;
  final String? assemblyNumber;
  final String? name; // Название сборки
  final String status;
  final double? totalShippingCostRub;
  final double? defaultPurchaseRate;
  final List<SpTrack> tracks;
  final List<SpInvoice> invoices;
  final SpStats stats;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const SpAssembly({
    required this.id,
    this.assemblyNumber,
    this.name,
    required this.status,
    this.totalShippingCostRub,
    this.defaultPurchaseRate,
    required this.tracks,
    required this.invoices,
    required this.stats,
    required this.createdAt,
    this.updatedAt,
  });

  /// Отображаемое название сборки
  String get displayName {
    if (name != null && name!.isNotEmpty) return name!;
    if (assemblyNumber != null && assemblyNumber!.isNotEmpty) return assemblyNumber!;
    return 'Сборка #$id';
  }

  factory SpAssembly.fromJson(Map<String, dynamic> json) {
    // Helper to convert string or number to double
    double? parseDoubleNullable(dynamic value) {
      if (value == null) return null;
      if (value is String) return double.tryParse(value);
      return (value as num).toDouble();
    }

    return SpAssembly(
      id: json['id'] as int,
      assemblyNumber: json['assemblyNumber'] as String? ?? json['number'] as String?,
      name: json['name'] as String?,
      status: json['status'] as String,
      totalShippingCostRub: parseDoubleNullable(json['totalShippingCostRub']),
      defaultPurchaseRate: parseDoubleNullable(json['defaultPurchaseRate']),
      tracks: (json['tracks'] as List<dynamic>?)
              ?.map((e) => SpTrack.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      invoices: (json['invoices'] as List<dynamic>?)
              ?.map((e) => SpInvoice.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      stats: SpStats.fromJson(json['stats'] as Map<String, dynamic>),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt'] as String) : null,
    );
  }

  SpAssembly copyWith({
    double? totalShippingCostRub,
    double? defaultPurchaseRate,
    List<SpTrack>? tracks,
    SpStats? stats,
  }) {
    return SpAssembly(
      id: id,
      assemblyNumber: assemblyNumber,
      name: name,
      status: status,
      totalShippingCostRub: totalShippingCostRub ?? this.totalShippingCostRub,
      defaultPurchaseRate: defaultPurchaseRate ?? this.defaultPurchaseRate,
      tracks: tracks ?? this.tracks,
      invoices: invoices,
      stats: stats ?? this.stats,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

/// Данные для обновления трека СП
class SpTrackUpdate {
  final String? spParticipantName;
  final double? supplierPriceYuan;
  final double? purchasePriceYuan;
  final double? clientPriceYuan; // Цена для участника в юанях
  final double? purchaseRate;
  final double? netWeightKg;
  final double? additionalExpensesRub; // Дополнительные расходы в рублях
  final String? note; // Комментарий к треку

  const SpTrackUpdate({
    this.spParticipantName,
    this.supplierPriceYuan,
    this.purchasePriceYuan,
    this.clientPriceYuan,
    this.purchaseRate,
    this.netWeightKg,
    this.additionalExpensesRub,
    this.note,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = {};

    if (spParticipantName != null) json['spParticipantName'] = spParticipantName;
    if (supplierPriceYuan != null) json['supplierPriceYuan'] = supplierPriceYuan;
    if (purchasePriceYuan != null) json['purchasePriceYuan'] = purchasePriceYuan;
    if (clientPriceYuan != null) json['clientPriceYuan'] = clientPriceYuan;
    if (purchaseRate != null) json['purchaseRate'] = purchaseRate;
    if (netWeightKg != null) json['netWeightKg'] = netWeightKg;
    if (additionalExpensesRub != null) json['additionalExpensesRub'] = additionalExpensesRub;
    if (note != null) json['note'] = note;

    return json;
  }
}

/// Данные для обновления сборки СП
class SpAssemblyUpdate {
  final double? defaultPurchaseRate;

  const SpAssemblyUpdate({
    this.defaultPurchaseRate,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = {};

    if (defaultPurchaseRate != null) json['defaultPurchaseRate'] = defaultPurchaseRate;

    return json;
  }
}
