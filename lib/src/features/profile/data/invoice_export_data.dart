import 'package:intl/intl.dart';

import '../../invoices/domain/invoice_item.dart';

const invoiceExportHeaders = <String>[
  'Номер счёта',
  'Дата создания',
  'Дата оплаты',
  'Дата прибытия',
  'Количество мест',
  'Вес, кг',
  'Объём, м³',
  'Плотность, кг/м³',
  'Тариф, USD/кг',
  'Перевалка, USD',
  'Страховка, USD',
  'Упаковка, USD',
  'Доставка, USD',
  'Курс юаня, ₽/¥',
  'Курс доллара, ₽/USD',
  'Итоговая стоимость, ₽',
  'Итоговая стоимость, USD',
  'Итоговая стоимость, ¥',
];

List<Object> buildInvoiceExportRow(
  InvoiceItem invoice, {
  DateFormat? dateFormat,
}) {
  final formatter = dateFormat ?? DateFormat('dd.MM.yyyy');
  final density = invoice.density > 0
      ? invoice.density
      : invoice.volume > 0
      ? invoice.weight / invoice.volume
      : 0.0;
  final insurance = invoice.insuranceCostClient ?? invoice.insuranceCost ?? 0.0;
  final yuanRubRate =
      invoice.clientCnyRubRate ??
      ((invoice.clientRubRate != null &&
              invoice.clientYuanRate != null &&
              invoice.clientYuanRate! > 0)
          ? invoice.clientRubRate! / invoice.clientYuanRate!
          : 0.0);

  String formatDate(DateTime? value) =>
      value == null ? '' : formatter.format(value.toLocal());

  return <Object>[
    invoice.invoiceNumber,
    formatDate(invoice.createdAt),
    formatDate(invoice.paidAt),
    formatDate(invoice.arrivalDate),
    invoice.placesCount,
    invoice.weight,
    invoice.volume,
    density,
    invoice.clientPricePerKg ?? 0.0,
    invoice.transshipmentCost ?? 0.0,
    insurance,
    invoice.resolvedPackagingCostTotal ?? 0.0,
    invoice.shippingCost ?? 0.0,
    yuanRubRate,
    invoice.clientRubRate ?? 0.0,
    invoice.totalCostRub,
    invoice.totalCostUsd,
    invoice.totalCostCny,
  ];
}
