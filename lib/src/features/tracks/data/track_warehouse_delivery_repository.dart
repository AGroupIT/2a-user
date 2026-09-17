import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

final trackWarehouseDeliveryRepositoryProvider =
    Provider<TrackWarehouseDeliveryGateway>((ref) {
      return TrackWarehouseDeliveryRepository(ref.read(apiClientProvider));
    });

final warehouseDeliveryTranslationProvider = FutureProvider.autoDispose
    .family<String, String>((ref, text) async {
      return ref.read(trackWarehouseDeliveryRepositoryProvider).translate(text);
    });

abstract interface class TrackWarehouseDeliveryGateway {
  Future<TrackWarehouseDelivery> get(int trackId);

  Future<TrackWarehouseDelivery> request(
    int trackId, {
    required bool automatic,
  });

  Future<String> translate(String text);
}

class TrackWarehouseDeliveryEvent {
  final String time;
  final String context;
  final String? location;
  final String? areaName;
  final String? status;

  const TrackWarehouseDeliveryEvent({
    required this.time,
    required this.context,
    this.location,
    this.areaName,
    this.status,
  });

  factory TrackWarehouseDeliveryEvent.fromJson(Map<String, dynamic> json) {
    return TrackWarehouseDeliveryEvent(
      time: (json['ftime'] ?? json['time'] ?? '').toString(),
      context: (json['context'] ?? '').toString(),
      location: _nullableString(json['location']),
      areaName: _nullableString(json['areaName']),
      status: _nullableString(json['status']),
    );
  }
}

class TrackWarehouseDelivery {
  final bool configured;
  final String trackNumber;
  final String trackStatus;
  final bool automatic;
  final String subscriptionStatus;
  final String? carrierCode;
  final String? carrierName;
  final String? providerStatus;
  final String? externalState;
  final String? externalCondition;
  final bool isDelivered;
  final List<TrackWarehouseDeliveryEvent> trace;
  final DateTime? subscribedAt;
  final DateTime? lastSyncedAt;
  final DateTime? lastQueryAt;
  final DateTime? queryCooldownUntil;
  final String? lastError;

  const TrackWarehouseDelivery({
    required this.configured,
    required this.trackNumber,
    required this.trackStatus,
    required this.automatic,
    required this.subscriptionStatus,
    this.carrierCode,
    this.carrierName,
    this.providerStatus,
    this.externalState,
    this.externalCondition,
    required this.isDelivered,
    this.trace = const [],
    this.subscribedAt,
    this.lastSyncedAt,
    this.lastQueryAt,
    this.queryCooldownUntil,
    this.lastError,
  });

  bool get hasTracking =>
      subscriptionStatus != 'idle' ||
      carrierCode != null ||
      trace.isNotEmpty ||
      lastError != null;

  bool get isWaiting =>
      subscriptionStatus == 'subscribing' ||
      (subscriptionStatus == 'active' && trace.isEmpty);

  factory TrackWarehouseDelivery.fromJson(Map<String, dynamic> json) {
    final rawTrace = json['trace'];
    final trace = rawTrace is List
        ? rawTrace
              .whereType<Map>()
              .map(
                (item) => TrackWarehouseDeliveryEvent.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList()
        : <TrackWarehouseDeliveryEvent>[];
    return TrackWarehouseDelivery(
      configured: json['configured'] == true,
      trackNumber: (json['trackNumber'] ?? '').toString(),
      trackStatus: (json['trackStatus'] ?? '').toString(),
      automatic: json['automatic'] == true,
      subscriptionStatus: (json['subscriptionStatus'] ?? 'idle').toString(),
      carrierCode: _nullableString(json['carrierCode']),
      carrierName: _nullableString(json['carrierName']),
      providerStatus: _nullableString(json['providerStatus']),
      externalState: _nullableString(json['externalState']),
      externalCondition: _nullableString(json['externalCondition']),
      isDelivered: json['isDelivered'] == true,
      trace: trace,
      subscribedAt: _dateTime(json['subscribedAt']),
      lastSyncedAt: _dateTime(json['lastSyncedAt']),
      lastQueryAt: _dateTime(json['lastQueryAt']),
      queryCooldownUntil: _dateTime(json['queryCooldownUntil']),
      lastError: _nullableString(json['lastError']),
    );
  }
}

class TrackWarehouseDeliveryException implements Exception {
  final String message;
  final String? code;

  const TrackWarehouseDeliveryException(this.message, {this.code});

  @override
  String toString() => message;
}

class TrackWarehouseDeliveryRepository
    implements TrackWarehouseDeliveryGateway {
  final ApiClient _api;

  final _translations = <String, String>{};
  final _pendingTranslations = <String, Future<String>>{};
  Future<void> _translationTail = Future<void>.value();
  DateTime? _translationRetryAt;

  TrackWarehouseDeliveryRepository(this._api);

  @override
  Future<TrackWarehouseDelivery> get(int trackId) async {
    try {
      final response = await _api.get<Map<String, dynamic>>(
        '/tracks/$trackId/warehouse-delivery',
      );
      return _parse(response.data);
    } on DioException catch (error) {
      throw _fromDio(error);
    }
  }

  @override
  Future<TrackWarehouseDelivery> request(
    int trackId, {
    required bool automatic,
  }) async {
    try {
      final response = await _api.post<Map<String, dynamic>>(
        '/tracks/$trackId/warehouse-delivery',
        data: {'mode': automatic ? 'auto' : 'manual'},
      );
      return _parse(response.data);
    } on DioException catch (error) {
      throw _fromDio(error);
    }
  }

  @override
  Future<String> translate(String text) {
    if (text.trim().isEmpty) return Future.value(text);
    final cached = _translations[text];
    if (cached != null) return Future.value(cached);
    final pending = _pendingTranslations[text];
    if (pending != null) return pending;
    if (_pendingTranslations.length >= 64 || _translationCoolingDown) {
      return Future.value(text);
    }

    // History rows mount together. Serialize their requests instead of
    // sending one simultaneous LLM request for every event and location.
    final result = _translationTail.then((_) => _translateQueued(text));
    _pendingTranslations[text] = result;
    _translationTail = result.then<void>(
      (_) => _pendingTranslations.remove(text),
      onError: (Object error, StackTrace stackTrace) {
        _pendingTranslations.remove(text);
      },
    );
    return result;
  }

  bool get _translationCoolingDown {
    final retryAt = _translationRetryAt;
    return retryAt != null && DateTime.now().isBefore(retryAt);
  }

  Future<String> _translateQueued(String text) async {
    // A preceding request may have opened the cooldown while this waited.
    if (_translationCoolingDown) return text;
    try {
      final response = await _api.post<Map<String, dynamic>>(
        '/translate',
        data: {'text': text, 'direction': 'zh-ru'},
      );
      final translated = _nullableString(response.data?['translation']);
      if (translated == null) return text;
      if (_translations.length >= 128) {
        _translations.remove(_translations.keys.first);
      }
      _translations[text] = translated;
      return translated;
    } on DioException catch (error) {
      final raw = error.response?.data;
      final retryAfterMs = raw is Map ? raw['retryAfterMs'] : null;
      final delayMs = retryAfterMs is num && retryAfterMs.isFinite
          ? retryAfterMs.toInt().clamp(30000, 300000)
          : 30000;
      _translationRetryAt = DateTime.now().add(Duration(milliseconds: delayMs));
      // Do not cache a failed translation as a successful one.
      return text;
    }
  }

  TrackWarehouseDelivery _parse(Map<String, dynamic>? response) {
    final raw = response?['data'];
    if (raw is! Map) {
      throw const TrackWarehouseDeliveryException('Invalid server response');
    }
    return TrackWarehouseDelivery.fromJson(Map<String, dynamic>.from(raw));
  }

  TrackWarehouseDeliveryException _fromDio(DioException error) {
    final raw = error.response?.data;
    if (raw is Map) {
      return TrackWarehouseDeliveryException(
        (raw['error'] ?? error.message ?? 'Request failed').toString(),
        code: _nullableString(raw['code']),
      );
    }
    return TrackWarehouseDeliveryException(error.message ?? 'Request failed');
  }
}

String? _nullableString(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

DateTime? _dateTime(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}
