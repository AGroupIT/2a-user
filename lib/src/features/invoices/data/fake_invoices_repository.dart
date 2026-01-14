import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/invoice_item.dart';

Future<void> _latency() => Future<void>.microtask(() {});

abstract class InvoicesRepository {
  Future<List<InvoiceItem>> fetchInvoices({required String clientCode});
}

final invoicesRepositoryProvider = Provider<InvoicesRepository>((ref) {
  return FakeInvoicesRepository();
});

final invoicesListProvider = FutureProvider.family<List<InvoiceItem>, String>((ref, clientCode) async {
  final repo = ref.watch(invoicesRepositoryProvider);
  return repo.fetchInvoices(clientCode: clientCode);
});

class FakeInvoicesRepository implements InvoicesRepository {
  @override
  Future<List<InvoiceItem>> fetchInvoices({required String clientCode}) async {
    await _latency();
    final rng = Random(clientCode.hashCode ^ 0xC0FFEE);
    final now = DateTime.now();

    const statuses = <String>[
      'Новый',
      'Требует оплаты',
      'Оплачен',
    ];

    const deliveryTypes = <String>[
      'Авто',
      'Авиа',
      'Ж/Д',
    ];
    const tariffTypes = <String>[
      'Сборный груз',
      'Спец. тариф',
      'Крупный ОПТ',
    ];
    const packagingOptions = <String>[
      'Коробка',
      'Картонные уголки',
      'Пузырчатая пленка',
      'Деревянная обрешетка',
      'Паллет',
    ];

    return List.generate(10, (i) {
      final number = 'INV-${clientCode.replaceAll(' ', '')}-${2400 + i}';
      final date = now.subtract(Duration(days: i * 3 + rng.nextInt(3)));
      final placesCount = 1 + rng.nextInt(6);
      final weight = (5 + rng.nextInt(120)) + rng.nextDouble();
      final volume = (0.1 + rng.nextDouble() * 1.8);
      final density = weight / volume;

      final _ = deliveryTypes[rng.nextInt(deliveryTypes.length)];
      final tariffType = tariffTypes[rng.nextInt(tariffTypes.length)];

      final tariffCost = (weight * (6 + rng.nextDouble() * 4));
      final insuranceEnabled = rng.nextInt(4) == 0;
      final insuranceCost = insuranceEnabled ? (tariffCost * (0.02 + rng.nextDouble() * 0.03)) : 0.0;

      final packagingTypes = packagingOptions.where((_) => rng.nextBool()).toList(growable: false);
      final packagingCost = packagingTypes.isEmpty ? 0.0 : (2 + packagingTypes.length * (1.5 + rng.nextDouble() * 2));

      final uvCost = rng.nextInt(5) == 0 ? (3 + rng.nextDouble() * 6) : 0.0;
      final totalUsd = tariffCost + insuranceCost + packagingCost + uvCost;
      final rate = 93 + rng.nextDouble() * 10;
      final totalRub = totalUsd * rate;

      final photoCount = rng.nextInt(3);
      final photoUrls = List.generate(photoCount, (j) {
        final seed = (clientCode.hashCode + i * 100 + j) & 0x7fffffff;
        return 'https://picsum.photos/seed/inv_$seed/900/700';
      });
      
      final status = statuses[rng.nextInt(statuses.length)];
      
      // Генерируем упаковки с ценами
      final packagingItems = packagingTypes.map((name) => 
        PackagingItem(name: name, cost: 1.5 + rng.nextDouble() * 3)
      ).toList();
      
      return InvoiceItem(
        id: 'i_${clientCode}_$i',
        invoiceNumber: number,
        sendDate: date,
        status: status,
        tariffName: tariffType,
        tariffBaseCost: 6 + rng.nextDouble() * 4,
        placesCount: placesCount,
        density: density,
        weight: weight,
        volume: volume,
        calculationMethod: rng.nextBool() ? 'weight' : 'volume',
        transshipmentCost: rng.nextInt(3) == 0 ? 10 + rng.nextDouble() * 20 : null,
        insuranceCost: insuranceEnabled ? insuranceCost : null,
        discount: rng.nextInt(5) == 0 ? 5 + rng.nextDouble() * 15 : null,
        packagings: packagingItems,
        packagingCostTotal: packagingTypes.isEmpty ? null : packagingCost,
        deliveryCostUsd: totalUsd,
        totalCostUsd: totalUsd,
        rate: rate,
        totalCostRub: totalRub,
        scalePhotoUrls: photoUrls,
      );
    }).toList()
      ..sort((a, b) => b.sendDate.compareTo(a.sendDate));
  }
}
