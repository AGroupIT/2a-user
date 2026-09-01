import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twoalogisticcabineuser/src/core/services/delta_sync_provider.dart';
import 'package:twoalogisticcabineuser/src/features/garage/application/garage_providers.dart';
import 'package:twoalogisticcabineuser/src/features/garage/domain/garage_models.dart';
import 'package:twoalogisticcabineuser/src/features/invoices/data/invoices_provider.dart';

void main() {
  test(
    'payment notification invalidation refreshes open Invoice and Garage',
    () async {
      var invoiceLoads = 0;
      var garageLoads = 0;
      final container = ProviderContainer(
        overrides: [
          invoiceByIdProvider.overrideWith((ref, id) async {
            invoiceLoads += 1;
            return null;
          }),
          garageOrderProvider.overrideWith((ref, id) async {
            garageLoads += 1;
            return GarageOrder.fromJson({
              'id': id,
              'orderNumber': 'GO-$id',
              'requestId': 11,
              'status': 'awaiting_payment',
              'goodsTotalCny': '8.33',
              'chinaDeliveryTotalCny': '0',
              'serviceFeeTotalCny': '0',
              'totalCny': '8.33',
              'totalRub': '100.00',
              'items': const <Map<String, dynamic>>[],
            });
          }),
        ],
      );
      addTearDown(container.dispose);

      final invoiceSub = container.listen(
        invoiceByIdProvider('17'),
        (_, _) {},
        fireImmediately: true,
      );
      final garageSub = container.listen(
        garageOrderProvider(44),
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(invoiceSub.close);
      addTearDown(garageSub.close);
      await container.pump();

      expect(invoiceLoads, 1);
      expect(garageLoads, 1);

      invalidatePaymentTargetProviders(container);
      await container.pump();

      expect(invoiceLoads, 2);
      expect(garageLoads, 2);
    },
  );
}
