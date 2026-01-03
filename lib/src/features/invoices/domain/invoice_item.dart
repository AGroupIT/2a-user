class InvoiceItem {
  final String id;
  final String invoiceNumber;
  final DateTime sendDate;
  final String? deliveryType;
  final String? tariffType;
  final int placesCount;
  final double density;
  final double weight;
  final double volume;
  final double? tariffCost;
  final double? insuranceCost;
  final List<String> packagingTypes;
  final double? packagingCost;
  final double? uvCost;
  final double? totalCostUsd;
  final double? rate;
  final double totalCostRub;
  final List<String> scalePhotoUrls;
  final String status;

  const InvoiceItem({
    required this.id,
    required this.invoiceNumber,
    required this.sendDate,
    required this.status,
    this.deliveryType,
    this.tariffType,
    required this.placesCount,
    required this.density,
    required this.weight,
    required this.volume,
    this.tariffCost,
    this.insuranceCost,
    this.packagingTypes = const [],
    this.packagingCost,
    this.uvCost,
    this.totalCostUsd,
    this.rate,
    required this.totalCostRub,
    this.scalePhotoUrls = const [],
  });
}
