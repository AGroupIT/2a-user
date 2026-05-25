import '../../../core/models/status_timeline_entry.dart';

class InvoiceItem {
  final String id;
  final String invoiceNumber;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? sendDate;
  final DateTime? arrivalDate; // arrivedAt в БД
  final DateTime? paidAt; // paidAt в БД
  final String? arrivalMarket;
  final String? arrivalStatus;
  final String? tariffName;
  final double? tariffBaseCost;
  final int placesCount;
  final double density;
  final double weight;
  final double volume;
  final String? calculationMethod;
  final List<PackagingItem> packagings;
  final List<InvoicePackagingUsage> packagingUsage;
  final double? packagingCostTotal;
  final double? transshipmentCost;
  final double? insuranceCost;
  final double? insurancePercent;
  final double? discountAmount;
  final double? shippingCost; // стоимость доставки $
  final double totalCostUsd;
  final double totalCostCny; // к оплате в ¥
  final double totalCostRub; // к оплате в ₽
  final double? clientRubRate; // курс $/₽
  final double? clientYuanRate; // курс $/¥
  final double? photoReportCoefficient;
  final int totalTracks;
  final int tracksWithPhoto;
  final List<String> scalePhotoUrls;
  final String status;
  final String? statusName;
  final String? statusColor;
  final String? clientCode;
  final double bonusKgApplied;
  final double? clientPricePerKg;
  final double? clientPricePerKgWithPhoto;
  final double? insurancePercentClient;
  final double? insuranceCostClient;
  final String? tkWaybillPhotoUrl;
  final List<StatusTimelineEntry> statusHistory;

  const InvoiceItem({
    required this.id,
    required this.invoiceNumber,
    this.createdAt,
    this.updatedAt,
    this.sendDate,
    this.arrivalDate,
    this.paidAt,
    this.arrivalMarket,
    this.arrivalStatus,
    required this.status,
    this.statusName,
    this.statusColor,
    this.tariffName,
    this.tariffBaseCost,
    required this.placesCount,
    required this.density,
    required this.weight,
    required this.volume,
    this.calculationMethod,
    this.transshipmentCost,
    this.insuranceCost,
    this.insurancePercent,
    this.discountAmount,
    this.shippingCost,
    this.packagings = const [],
    this.packagingUsage = const [],
    this.packagingCostTotal,
    this.totalCostUsd = 0,
    this.totalCostCny = 0,
    required this.totalCostRub,
    this.clientRubRate,
    this.clientYuanRate,
    this.photoReportCoefficient,
    this.totalTracks = 0,
    this.tracksWithPhoto = 0,
    this.scalePhotoUrls = const [],
    this.clientCode,
    this.bonusKgApplied = 0,
    this.clientPricePerKg,
    this.clientPricePerKgWithPhoto,
    this.insurancePercentClient,
    this.insuranceCostClient,
    this.tkWaybillPhotoUrl,
    this.statusHistory = const [],
  });

  int get billablePlacesCount => placesCount > 0 ? placesCount : 1;

  double get packagingUnitCost =>
      packagings.fold(0, (sum, packaging) => sum + packaging.cost);

  double? get resolvedPackagingCostTotal {
    final usageTotal = packagingUsageClientTotal;
    if (usageTotal > 0) return usageTotal;

    if (packagingCostTotal != null && packagingCostTotal! > 0) {
      return packagingCostTotal;
    }

    final unitCost = packagingUnitCost;
    if (unitCost <= 0) return null;

    return unitCost * billablePlacesCount;
  }

  double get packagingUsageClientTotal =>
      packagingUsage.fold(0, (sum, row) => sum + row.effectiveClientTotalCost);

  bool get hasDetailedPackagingUsage => packagingUsage.isNotEmpty;

  String get packagingNames => packagings
      .map((packaging) => packaging.name.trim())
      .followedBy(packagingUsage.map((row) => row.name.trim()))
      .where((name) => name.isNotEmpty)
      .toSet()
      .join(', ');

  factory InvoiceItem.fromJson(Map<String, dynamic> json) {
    final status = json['status'] as String? ?? 'unknown';
    final statusName = json['statusName'] as String?;
    final statusColor = json['statusColor'] as String?;

    DateTime? createdAt;
    if (json['createdAt'] != null) {
      createdAt = DateTime.tryParse(json['createdAt'].toString());
    }

    DateTime? updatedAt;
    if (json['updatedAt'] != null) {
      updatedAt = DateTime.tryParse(json['updatedAt'].toString());
    }

    DateTime? sendDate;
    if (json['sendDate'] != null) {
      sendDate = DateTime.tryParse(json['sendDate'].toString());
    }

    // arrivedAt — основное поле в Prisma, arrivalDate — fallback
    DateTime? arrivalDate;
    if (json['arrivedAt'] != null) {
      arrivalDate = DateTime.tryParse(json['arrivedAt'].toString());
    } else if (json['arrivalDate'] != null) {
      arrivalDate = DateTime.tryParse(json['arrivalDate'].toString());
    }

    // paidAt — основное поле в Prisma, paymentDate — fallback
    DateTime? paidAt;
    if (json['paidAt'] != null) {
      paidAt = DateTime.tryParse(json['paidAt'].toString());
    } else if (json['paymentDate'] != null) {
      paidAt = DateTime.tryParse(json['paymentDate'].toString());
    }

    final tariff = json['tariff'] as Map<String, dynamic>?;
    final tariffName =
        tariff?['name'] as String? ?? tariff?['nameRu'] as String?;
    final tariffBaseCost = _parseDouble(tariff?['baseCost']);

    final clientCodeData = json['clientCode'] as Map<String, dynamic>?;
    final clientCode = clientCodeData?['code'] as String?;

    final List<PackagingItem> packagings = [];
    final packagingsData = json['packagings'] as List<dynamic>? ?? [];
    for (final p in packagingsData) {
      if (p is Map<String, dynamic>) {
        final pkgType = p['packagingType'] as Map<String, dynamic>?;
        if (pkgType != null) {
          packagings.add(
            PackagingItem(
              name:
                  pkgType['nameRu'] as String? ??
                  pkgType['name'] as String? ??
                  '',
              cost: _parseDouble(pkgType['baseCost']),
            ),
          );
        }
      }
    }

    if (packagings.isEmpty) {
      final packaging = json['packagingType'] as Map<String, dynamic>?;
      if (packaging != null) {
        packagings.add(
          PackagingItem(
            name:
                packaging['nameRu'] as String? ??
                packaging['name'] as String? ??
                '',
            cost: _parseDouble(packaging['baseCost']),
          ),
        );
      }
    }

    final rawPackagingUsage = json['packagingUsage'] ?? json['packagingUsages'];
    final packagingUsage = rawPackagingUsage is List
        ? rawPackagingUsage
              .whereType<Map>()
              .map(
                (row) => InvoicePackagingUsage.fromJson(
                  Map<String, dynamic>.from(row),
                ),
              )
              .where((row) => row.packagingTypeId > 0 && row.quantity > 0)
              .toList()
        : <InvoicePackagingUsage>[];

    int totalTracks = 0;
    int tracksWithPhoto = 0;
    final invoiceBoxIds = <int>{};
    void addInvoiceBoxId(dynamic value) {
      final id = int.tryParse(value?.toString() ?? '');
      if (id != null) invoiceBoxIds.add(id);
    }

    addInvoiceBoxId(json['boxId']);
    final rawBoxIds = json['boxIds'];
    if (rawBoxIds is List) {
      for (final id in rawBoxIds) {
        addInvoiceBoxId(id);
      }
    }

    final List<String> scalePhotoUrls = [];
    final seenScalePhotoUrls = <String>{};

    void addScalePhoto(dynamic rawPhoto) {
      if (rawPhoto is! Map) return;
      final url = rawPhoto['url']?.toString();
      if (url == null || url.isEmpty || !seenScalePhotoUrls.add(url)) return;
      scalePhotoUrls.add(url);
    }

    void addScalePhotos(dynamic rawPhotos) {
      if (rawPhotos is! List) return;
      for (final photo in rawPhotos) {
        addScalePhoto(photo);
      }
    }

    addScalePhotos(json['scalePhotos']);

    final assembly = json['assembly'] as Map<String, dynamic>?;
    if (assembly != null) {
      addScalePhotos(assembly['scalePhotos']);

      final boxes = assembly['boxes'] as List? ?? [];
      for (final rawBox in boxes) {
        if (rawBox is! Map) continue;
        final boxId = int.tryParse(rawBox['id']?.toString() ?? '');
        if (invoiceBoxIds.isNotEmpty &&
            (boxId == null || !invoiceBoxIds.contains(boxId))) {
          continue;
        }
        addScalePhotos(rawBox['scalePhotos']);
      }

      final tracks = assembly['tracks'] as List? ?? [];
      totalTracks = tracks.length;
      for (final t in tracks) {
        final tm = t as Map<String, dynamic>;
        final pr = tm['photoRequests'] as List?;
        if (pr != null && pr.isNotEmpty) tracksWithPhoto++;
      }
    }

    final eventsList = json['events'] as List<dynamic>? ?? [];
    final statusHistory = eventsList
        .whereType<Map<String, dynamic>>()
        .where((event) => event['eventType']?.toString() == 'status_changed')
        .map(StatusTimelineEntry.fromEventJson)
        .toList();

    return InvoiceItem(
      id: json['id'].toString(),
      invoiceNumber:
          json['invoiceNumber'] as String? ??
          json['number'] as String? ??
          'INV-${json['id']}',
      createdAt: createdAt,
      updatedAt: updatedAt,
      sendDate: sendDate,
      arrivalDate: arrivalDate,
      paidAt: paidAt,
      arrivalMarket: json['arrivalMarket'] as String?,
      arrivalStatus: json['arrivalStatus'] as String?,
      status: status,
      statusName: statusName,
      statusColor: statusColor,
      tariffName: tariffName,
      tariffBaseCost: tariffBaseCost,
      placesCount: json['placesCount'] as int? ?? 0,
      density: _parseDouble(json['density']),
      weight: _parseDouble(json['weight']),
      volume: _parseDouble(json['volume']),
      calculationMethod: json['calculationMethod'] as String?,
      transshipmentCost: _parseDouble(
        json['transshipmentCost'],
      ).let((v) => v > 0 ? v : null),
      insuranceCost: _parseDouble(
        json['insuranceCost'],
      ).let((v) => v > 0 ? v : null),
      insurancePercent: json['insurancePercent'] != null
          ? _parseDouble(json['insurancePercent']).let((v) => v > 0 ? v : null)
          : null,
      discountAmount: json['discount'] != null
          ? _parseDouble(json['discount']).let((v) => v > 0 ? v : null)
          : null,
      shippingCost: json['shippingCost'] != null
          ? _parseDouble(json['shippingCost']).let((v) => v > 0 ? v : null)
          : null,
      packagings: packagings,
      packagingUsage: packagingUsage,
      packagingCostTotal: _parseDouble(
        json['packagingCost'],
      ).let((v) => v > 0 ? v : null),
      totalCostUsd: _parseDouble(json['totalCostUSD']),
      totalCostCny: _parseDouble(json['totalCostCNY']),
      totalCostRub: _parseDouble(json['totalCostRUB']),
      clientRubRate: json['clientRubRate'] != null
          ? _parseDouble(json['clientRubRate']).let((v) => v > 0 ? v : null)
          : null,
      clientYuanRate: json['clientYuanRate'] != null
          ? _parseDouble(json['clientYuanRate']).let((v) => v > 0 ? v : null)
          : null,
      photoReportCoefficient: _parseDouble(
        json['photoReportCoefficient'],
      ).let((v) => v > 0 ? v : null),
      totalTracks: totalTracks,
      tracksWithPhoto: tracksWithPhoto,
      scalePhotoUrls: scalePhotoUrls,
      clientCode: clientCode,
      bonusKgApplied: _parseDouble(json['bonusKgApplied']),
      clientPricePerKg: json['clientPricePerKg'] != null
          ? _parseDouble(json['clientPricePerKg']).let((v) => v > 0 ? v : null)
          : null,
      clientPricePerKgWithPhoto: json['clientPricePerKgWithPhoto'] != null
          ? _parseDouble(
              json['clientPricePerKgWithPhoto'],
            ).let((v) => v > 0 ? v : null)
          : null,
      insurancePercentClient: json['insurancePercentClient'] != null
          ? _parseDouble(
              json['insurancePercentClient'],
            ).let((v) => v > 0 ? v : null)
          : null,
      insuranceCostClient: json['insuranceCostClient'] != null
          ? _parseDouble(
              json['insuranceCostClient'],
            ).let((v) => v > 0 ? v : null)
          : null,
      tkWaybillPhotoUrl: json['tkWaybillPhotoUrl'] as String?,
      statusHistory: statusHistory,
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}

extension _DoubleLetExt on double {
  T let<T>(T Function(double) f) => f(this);
}

/// Элемент упаковки с названием и стоимостью
class PackagingItem {
  final String name;
  final double cost;

  const PackagingItem({required this.name, required this.cost});
}

/// Фактический расход упаковочных материалов в счёте.
class InvoicePackagingUsage {
  final String id;
  final int packagingTypeId;
  final String name;
  final String kind;
  final String? source;
  final double quantity;
  final String unitLabel;
  final double clientUnitCost;
  final double clientTotalCost;

  const InvoicePackagingUsage({
    required this.id,
    required this.packagingTypeId,
    required this.name,
    this.kind = 'primary',
    this.source,
    this.quantity = 0,
    this.unitLabel = 'шт.',
    this.clientUnitCost = 0,
    this.clientTotalCost = 0,
  });

  factory InvoicePackagingUsage.fromJson(Map<String, dynamic> json) {
    return InvoicePackagingUsage(
      id: json['id']?.toString() ?? '',
      packagingTypeId: _parseInt(json['packagingTypeId']),
      name:
          json['packagingNameRu'] as String? ??
          json['packagingName'] as String? ??
          'Упаковка',
      kind: json['kind']?.toString() ?? 'primary',
      source: json['source']?.toString(),
      quantity: _parseDouble(json['quantity']),
      unitLabel: json['unitLabel']?.toString() ?? 'шт.',
      clientUnitCost: _parseDouble(json['clientUnitCost']),
      clientTotalCost: _parseDouble(json['clientTotalCost']),
    );
  }

  bool get isPrimary => kind != 'addon';

  double get effectiveClientTotalCost {
    if (clientTotalCost > 0) return clientTotalCost;
    return clientUnitCost * quantity;
  }

  String quantityDisplay() {
    final value = quantity == quantity.roundToDouble()
        ? quantity.toInt().toString()
        : quantity.toStringAsFixed(2);
    return '$value $unitLabel';
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}
