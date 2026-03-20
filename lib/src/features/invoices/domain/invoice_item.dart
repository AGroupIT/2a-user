class InvoiceItem {
  final String id;
  final String invoiceNumber;
  final DateTime? createdAt;
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

  const InvoiceItem({
    required this.id,
    required this.invoiceNumber,
    this.createdAt,
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
  });

  factory InvoiceItem.fromJson(Map<String, dynamic> json) {
    final status = json['status'] as String? ?? 'unknown';
    final statusName = json['statusName'] as String?;
    final statusColor = json['statusColor'] as String?;

    DateTime? createdAt;
    if (json['createdAt'] != null) {
      createdAt = DateTime.tryParse(json['createdAt'].toString());
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

    int totalTracks = 0;
    int tracksWithPhoto = 0;
    final List<String> photoUrls = [];
    final assembly = json['assembly'] as Map<String, dynamic>?;
    if (assembly != null) {
      final tracks = assembly['tracks'] as List? ?? [];
      totalTracks = tracks.length;
      for (final t in tracks) {
        final tm = t as Map<String, dynamic>;
        final pr = tm['photoRequests'] as List?;
        if (pr != null && pr.isNotEmpty) tracksWithPhoto++;
        final photos = tm['photos'] as List?;
        if (photos != null) {
          for (final photo in photos) {
            final url = (photo as Map<String, dynamic>)['url'] as String?;
            if (url != null && url.isNotEmpty) photoUrls.add(url);
          }
        }
      }
    }

    return InvoiceItem(
      id: json['id'].toString(),
      invoiceNumber:
          json['invoiceNumber'] as String? ??
          json['number'] as String? ??
          'INV-${json['id']}',
      createdAt: createdAt,
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
      transshipmentCost: _parseDouble(json['transshipmentCost']).let((v) => v > 0 ? v : null),
      insuranceCost: _parseDouble(json['insuranceCost']).let((v) => v > 0 ? v : null),
      insurancePercent: json['insurancePercent'] != null ? _parseDouble(json['insurancePercent']).let((v) => v > 0 ? v : null) : null,
      discountAmount: json['discount'] != null ? _parseDouble(json['discount']).let((v) => v > 0 ? v : null) : null,
      shippingCost: json['shippingCost'] != null ? _parseDouble(json['shippingCost']).let((v) => v > 0 ? v : null) : null,
      packagings: packagings,
      packagingCostTotal: _parseDouble(json['packagingCost']).let((v) => v > 0 ? v : null),
      totalCostUsd: _parseDouble(json['totalCostUSD']),
      totalCostCny: _parseDouble(json['totalCostCNY']),
      totalCostRub: _parseDouble(json['totalCostRUB']),
      clientRubRate: json['clientRubRate'] != null ? _parseDouble(json['clientRubRate']).let((v) => v > 0 ? v : null) : null,
      clientYuanRate: json['clientYuanRate'] != null ? _parseDouble(json['clientYuanRate']).let((v) => v > 0 ? v : null) : null,
      photoReportCoefficient: _parseDouble(json['photoReportCoefficient']).let((v) => v > 0 ? v : null),
      totalTracks: totalTracks,
      tracksWithPhoto: tracksWithPhoto,
      scalePhotoUrls: photoUrls,
      clientCode: clientCode,
      bonusKgApplied: _parseDouble(json['bonusKgApplied']),
      clientPricePerKg: json['clientPricePerKg'] != null
          ? _parseDouble(json['clientPricePerKg']).let((v) => v > 0 ? v : null)
          : null,
      clientPricePerKgWithPhoto: json['clientPricePerKgWithPhoto'] != null
          ? _parseDouble(json['clientPricePerKgWithPhoto']).let((v) => v > 0 ? v : null)
          : null,
      insurancePercentClient: json['insurancePercentClient'] != null
          ? _parseDouble(json['insurancePercentClient']).let((v) => v > 0 ? v : null)
          : null,
      insuranceCostClient: json['insuranceCostClient'] != null
          ? _parseDouble(json['insuranceCostClient']).let((v) => v > 0 ? v : null)
          : null,
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
