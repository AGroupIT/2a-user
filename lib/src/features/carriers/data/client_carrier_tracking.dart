import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../auth/data/auth_provider.dart';

typedef ClientCarrierTarget = ({int? assemblyId, int? invoiceId});

int _integer(dynamic value) => int.tryParse('$value') ?? 0;
List<Map<String, dynamic>> _maps(dynamic value) => value is List
    ? value.whereType<Map>().map((v) => Map<String, dynamic>.from(v)).toList()
    : const [];

/// Client DTO deliberately has no carrier rates, costs or management fields.
class ClientCarrierEvent {
  ClientCarrierEvent.fromJson(Map<String, dynamic> json)
    : labelRu = '${json['labelRu'] ?? ''}',
      labelZh = '${json['labelZh'] ?? ''}',
      date = json['date']?.toString(),
      dateOnly = json['timePrecision'] == 'date',
      forecast = json['isForecast'] == true;

  final String labelRu, labelZh;
  final String? date;
  final bool dateOnly, forecast;
}

class ClientCarrierShipment {
  ClientCarrierShipment.fromJson(Map<String, dynamic> json)
    : id = _integer(json['id']),
      number = '${json['number'] ?? ''}',
      boxIds = json['boxIds'] is List
          ? (json['boxIds'] as List).map(_integer).where((id) => id > 0).toSet()
          : const {},
      places = _integer(json['placesCount']),
      arrived = _integer(json['arrivedPlaces']),
      tracked = _integer(json['trackedPlaces']),
      labelRu = '${json['labelRu'] ?? ''}',
      labelZh = '${json['labelZh'] ?? ''}',
      updatedAt = json['updatedAt']?.toString(),
      eta = json['eta']?.toString(),
      pending = json['trackingPending'] == true,
      stale = json['stale'] == true,
      events = _maps(json['events']).map(ClientCarrierEvent.fromJson).toList();

  final int id, places, arrived, tracked;
  final String number, labelRu, labelZh;
  final Set<int> boxIds;
  final String? updatedAt, eta;
  final bool pending, stale;
  final List<ClientCarrierEvent> events;
}

class ClientCarrierTracking {
  const ClientCarrierTracking({this.shipments = const []});

  factory ClientCarrierTracking.fromJson(Map<String, dynamic> json) =>
      ClientCarrierTracking(
        shipments: _maps(
          json['shipments'],
        ).map(ClientCarrierShipment.fromJson).toList(),
      );

  final List<ClientCarrierShipment> shipments;
}

/// No cross-account cache: an auth change discards pending and completed data.
/// Auto-dispose reloads the server snapshot whenever the detail sheet reopens.
final clientCarrierTrackingProvider = FutureProvider.autoDispose
    .family<ClientCarrierTracking, ClientCarrierTarget>((ref, target) async {
      final access = ref.watch(
        authProvider.select(
          (a) => (
            a.isLoggedIn,
            a.isLoading,
            a.clientId,
            a.userDomain,
            a.userEmail,
          ),
        ),
      );
      if (!access.$1 || access.$2) return const ClientCarrierTracking();
      final assemblyId = target.assemblyId;
      final invoiceId = target.invoiceId;
      if ((assemblyId == null) == (invoiceId == null) ||
          (assemblyId ?? invoiceId ?? 0) <= 0) {
        throw ArgumentError(
          'Exactly one positive carrier tracking target required',
        );
      }
      final response = await ref
          .watch(apiClientProvider)
          .get<dynamic>(
            '/carriers/shipments',
            queryParameters: {
              if (assemblyId != null) 'assemblyId': assemblyId,
              if (invoiceId != null) 'invoiceId': invoiceId,
            },
          );
      if (response.data is! Map) {
        throw const FormatException('Invalid tracking response');
      }
      return ClientCarrierTracking.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
    }, retry: (_, _) => null);
