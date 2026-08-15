import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

class CurrentCnyRate {
  final DateTime date;
  final double rubPerCny;

  const CurrentCnyRate({required this.date, required this.rubPerCny});

  factory CurrentCnyRate.fromJson(Map<String, dynamic> json) {
    final date = DateTime.tryParse(json['date']?.toString() ?? '');
    final rawRate = json['clientCnyRubRate'];
    final rate = rawRate is num
        ? rawRate.toDouble()
        : double.tryParse(rawRate?.toString().replaceAll(',', '.') ?? '');

    if (date == null || rate == null || !rate.isFinite || rate <= 0) {
      throw const FormatException('Invalid current CNY rate payload');
    }

    return CurrentCnyRate(date: date, rubPerCny: rate);
  }
}

class CurrentCnyRateRepository {
  final ApiClient _apiClient;

  const CurrentCnyRateRepository(this._apiClient);

  Future<CurrentCnyRate?> fetch() async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/client/currency-rate',
    );
    final payload = response.data?['data'];
    if (payload == null) return null;
    if (payload is! Map) {
      throw const FormatException('Invalid current CNY rate response');
    }

    return CurrentCnyRate.fromJson(Map<String, dynamic>.from(payload));
  }
}

final currentCnyRateRepositoryProvider = Provider<CurrentCnyRateRepository>((
  ref,
) {
  return CurrentCnyRateRepository(ref.watch(apiClientProvider));
});

final currentCnyRateProvider = FutureProvider<CurrentCnyRate?>((ref) {
  return ref.watch(currentCnyRateRepositoryProvider).fetch();
});
