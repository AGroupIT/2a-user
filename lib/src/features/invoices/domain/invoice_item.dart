class InvoiceItem {
  final String id;
  final String invoiceNumber;
  final DateTime sendDate;
  final String? tariffName; // Название тарифа
  final double? tariffBaseCost; // Базовая стоимость тарифа за кг/$
  final int placesCount;
  final double density;
  final double weight;
  final double volume;
  final String? calculationMethod; // По весу / по объёму
  final double? transshipmentCost; // Перевалка USD
  final double? insuranceCost; // Страховка USD
  final double? discount; // Скидка USD
  final List<PackagingItem> packagings; // Список упаковок с ценами
  final double? packagingCostTotal; // Общая стоимость упаковки
  final double deliveryCostUsd; // Итого доставка USD
  final double totalCostUsd; // Итого USD
  final double? rate; // Курс
  final double totalCostRub; // К оплате RUB
  final List<String> scalePhotoUrls;
  final String status;
  final String? statusName; // Локализованное название статуса
  final String? statusColor; // Цвет статуса
  final String? clientCode;

  const InvoiceItem({
    required this.id,
    required this.invoiceNumber,
    required this.sendDate,
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
    this.discount,
    this.packagings = const [],
    this.packagingCostTotal,
    this.deliveryCostUsd = 0,
    this.totalCostUsd = 0,
    this.rate,
    required this.totalCostRub,
    this.scalePhotoUrls = const [],
    this.clientCode,
  });

  factory InvoiceItem.fromJson(Map<String, dynamic> json) {
    // Получаем статус и его локализованное название
    final status = json['status'] as String? ?? 'unknown';
    final statusName = json['statusName'] as String?;
    final statusColor = json['statusColor'] as String?;

    // Получаем дату - используем updatedAt для сортировки по последним изменениям
    DateTime sendDate;
    if (json['updatedAt'] != null) {
      sendDate =
          DateTime.tryParse(json['updatedAt'].toString()) ?? DateTime.now();
    } else if (json['createdAt'] != null) {
      sendDate =
          DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now();
    } else {
      sendDate = DateTime.now();
    }

    // Тариф
    final tariff = json['tariff'] as Map<String, dynamic>?;
    final tariffName =
        tariff?['name'] as String? ?? tariff?['nameRu'] as String?;
    final tariffBaseCost = _parseDouble(tariff?['baseCost']);

    // Код клиента
    final clientCodeData = json['clientCode'] as Map<String, dynamic>?;
    final clientCode = clientCodeData?['code'] as String?;

    // Парсим упаковки (множественное значение)
    final List<PackagingItem> packagings = [];

    // Из packagings (связь многие-ко-многим)
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

    return InvoiceItem(
      id: json['id'].toString(),
      invoiceNumber:
          json['invoiceNumber'] as String? ??
          json['number'] as String? ??
          'INV-${json['id']}',
      sendDate: sendDate,
      status: status,
      statusName: statusName,
      statusColor: statusColor,
      tariffName: tariffName,
      tariffBaseCost: tariffBaseCost,
      placesCount: json['placesCount'] as int? ?? 1,
      density: _parseDouble(json['density']),
      weight: _parseDouble(json['weight']),
      volume: _parseDouble(json['volume']),
      calculationMethod: json['calculationMethod'] as String?,
      transshipmentCost: _parseDouble(json['transshipmentCost']),
      insuranceCost: _parseDouble(json['insuranceCost']),
      discount: _parseDouble(json['discount']),
      packagings: packagings,
      packagingCostTotal: _parseDouble(json['packagingCost']),
      deliveryCostUsd: _parseDouble(json['deliveryCost']),
      totalCostUsd: _parseDouble(json['totalCostUSD']),
      rate: _parseDouble(json['exchangeRate']),
      totalCostRub: _parseDouble(json['totalCostRUB']),
      clientCode: clientCode,
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
