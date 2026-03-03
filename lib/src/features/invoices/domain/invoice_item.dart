class InvoiceItem {
  final String id;
  final String invoiceNumber;
  final DateTime? sendDate; // Дата отправки
  final DateTime? arrivalDate; // Дата прибытия
  final DateTime? paymentDate; // Дата оплаты
  final String? arrivalMarket; // Рынок разгрузки
  final String? tariffName;
  final double? tariffBaseCost; // Базовая стоимость тарифа
  final int placesCount;
  final double density;
  final double weight;
  final double volume;
  final String? calculationMethod;
  final List<PackagingItem> packagings;
  final double? packagingCostTotal;
  final double? transshipmentCost; // Приём груза (разгрузка) для клиента $
  final double? insuranceCost; // Страховка для клиента $
  final double? discountAmount; // Скидка $
  final double totalCostUsd; // Итого к оплате $
  final double? clientRubRate; // Курс доллара клиента
  final double totalCostRub; // К оплате RUB
  final double? photoReportCoefficient; // Коэффициент фотоотчёта
  final int totalTracks; // Всего треков в сборке
  final int tracksWithPhoto; // Треков с фотоотчётом
  final List<String> scalePhotoUrls;
  final String status;
  final String? statusName;
  final String? statusColor;
  final String? clientCode;
  final double bonusKgApplied;
  final double? clientPricePerKg;

  const InvoiceItem({
    required this.id,
    required this.invoiceNumber,
    this.sendDate,
    this.arrivalDate,
    this.paymentDate,
    this.arrivalMarket,
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
    this.discountAmount,
    this.packagings = const [],
    this.packagingCostTotal,
    this.totalCostUsd = 0,
    this.clientRubRate,
    required this.totalCostRub,
    this.photoReportCoefficient,
    this.totalTracks = 0,
    this.tracksWithPhoto = 0,
    this.scalePhotoUrls = const [],
    this.clientCode,
    this.bonusKgApplied = 0,
    this.clientPricePerKg,
  });

  factory InvoiceItem.fromJson(Map<String, dynamic> json) {
    final status = json['status'] as String? ?? 'unknown';
    final statusName = json['statusName'] as String?;
    final statusColor = json['statusColor'] as String?;

    // Дата отправки
    DateTime? sendDate;
    if (json['sendDate'] != null) {
      sendDate = DateTime.tryParse(json['sendDate'].toString());
    }

    // Дата прибытия
    DateTime? arrivalDate;
    if (json['arrivalDate'] != null) {
      arrivalDate = DateTime.tryParse(json['arrivalDate'].toString());
    }

    // Дата оплаты
    DateTime? paymentDate;
    if (json['paymentDate'] != null) {
      paymentDate = DateTime.tryParse(json['paymentDate'].toString());
    }

    // Тариф
    final tariff = json['tariff'] as Map<String, dynamic>?;
    final tariffName =
        tariff?['name'] as String? ?? tariff?['nameRu'] as String?;
    final tariffBaseCost = _parseDouble(tariff?['baseCost']);

    // Код клиента
    final clientCodeData = json['clientCode'] as Map<String, dynamic>?;
    final clientCode = clientCodeData?['code'] as String?;

    // Упаковки (множественное значение)
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

    // Fallback: packagingType (одиночное значение)
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

    // Фотоотчёт и фото: считаем треки с фото из assembly.tracks
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
        // Собираем URL фотографий из треков
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
      sendDate: sendDate,
      arrivalDate: arrivalDate,
      paymentDate: paymentDate,
      arrivalMarket: json['arrivalMarket'] as String?,
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
      transshipmentCost: _parseDouble(json['transshipmentCost']),
      insuranceCost: _parseDouble(json['insuranceCost']),
      discountAmount: json['discount'] != null ? _parseDouble(json['discount']) : null,
      packagings: packagings,
      packagingCostTotal: _parseDouble(json['packagingCost']),
      totalCostUsd: _parseDouble(json['totalCostUSD']),
      clientRubRate: _parseDouble(json['clientRubRate']),
      totalCostRub: _parseDouble(json['totalCostRUB']),
      photoReportCoefficient: _parseDouble(json['photoReportCoefficient']),
      totalTracks: totalTracks,
      tracksWithPhoto: tracksWithPhoto,
      scalePhotoUrls: photoUrls,
      clientCode: clientCode,
      bonusKgApplied: _parseDouble(json['bonusKgApplied']),
      clientPricePerKg: json['clientPricePerKg'] != null
          ? _parseDouble(json['clientPricePerKg'])
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

/// Элемент упаковки с названием и стоимостью
class PackagingItem {
  final String name;
  final double cost;

  const PackagingItem({required this.name, required this.cost});
}
