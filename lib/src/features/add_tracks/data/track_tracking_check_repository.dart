import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/error_utils.dart';

enum TrackTrackingStatus { trackable, unconfirmed, existing }

enum TrackTrackingReason {
  noTrackingData,
  carrierNotRecognized,
  checkUnavailable,
  alreadyExists,
}

class TrackTrackingCheckItem {
  final String code;
  final TrackTrackingStatus status;
  final TrackTrackingReason? reason;
  final String? carrierCode;
  final String? carrierName;

  const TrackTrackingCheckItem({
    required this.code,
    required this.status,
    this.reason,
    this.carrierCode,
    this.carrierName,
  });

  factory TrackTrackingCheckItem.fromJson(Map<String, dynamic> json) {
    return TrackTrackingCheckItem(
      code: json['code']?.toString() ?? '',
      status: switch (json['status']) {
        'trackable' => TrackTrackingStatus.trackable,
        'existing' => TrackTrackingStatus.existing,
        _ => TrackTrackingStatus.unconfirmed,
      },
      reason: switch (json['reason']) {
        'no_tracking_data' => TrackTrackingReason.noTrackingData,
        'carrier_not_recognized' => TrackTrackingReason.carrierNotRecognized,
        'check_unavailable' => TrackTrackingReason.checkUnavailable,
        'already_exists' => TrackTrackingReason.alreadyExists,
        _ => null,
      },
      carrierCode: json['carrierCode']?.toString(),
      carrierName: json['carrierName']?.toString(),
    );
  }
}

class TrackTrackingCheckResult {
  final bool configured;
  final bool checkAvailable;
  final int? retryAfterSeconds;
  final List<TrackTrackingCheckItem> items;

  const TrackTrackingCheckResult({
    required this.configured,
    required this.checkAvailable,
    required this.items,
    this.retryAfterSeconds,
  });

  factory TrackTrackingCheckResult.fromJson(Map<String, dynamic> json) {
    final rawResults = json['results'];
    return TrackTrackingCheckResult(
      configured: json['configured'] == true,
      checkAvailable: json['checkAvailable'] == true,
      retryAfterSeconds: (json['retryAfterSeconds'] as num?)?.toInt(),
      items: rawResults is List
          ? rawResults
                .whereType<Map>()
                .map(
                  (item) => TrackTrackingCheckItem.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .where((item) => item.code.isNotEmpty)
                .toList()
          : const [],
    );
  }
}

abstract class TrackTrackingCheckRepository {
  Future<TrackTrackingCheckResult> check({
    required String clientCode,
    required List<String> trackCodes,
  });
}

final trackTrackingCheckRepositoryProvider =
    Provider<TrackTrackingCheckRepository>((ref) {
      return RealTrackTrackingCheckRepository(ref);
    });

class RealTrackTrackingCheckRepository implements TrackTrackingCheckRepository {
  final Ref _ref;

  RealTrackTrackingCheckRepository(this._ref);

  ApiClient get _api => _ref.read(apiClientProvider);

  @override
  Future<TrackTrackingCheckResult> check({
    required String clientCode,
    required List<String> trackCodes,
  }) async {
    try {
      final response = await _api.post(
        '/client/tracks/tracking-check',
        data: {'clientCode': clientCode, 'trackNumbers': trackCodes},
      );
      final data = response.data;
      if (response.statusCode == 200 && data is Map) {
        return TrackTrackingCheckResult.fromJson(
          Map<String, dynamic>.from(data),
        );
      }
      throw Exception('Не удалось проверить трек-номера');
    } on DioException catch (error) {
      debugPrint('Error checking track numbers: $error');
      final responseData = error.response?.data;
      if (responseData is Map && responseData['error'] is String) {
        throw Exception(responseData['error'] as String);
      }
      throw Exception(ErrorUtils.getErrorInfo(error).message);
    } catch (error) {
      if (error is Exception) rethrow;
      throw Exception('Не удалось проверить трек-номера. Попробуйте ещё раз');
    }
  }
}
