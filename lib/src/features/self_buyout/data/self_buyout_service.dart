import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_parser/http_parser.dart';

import '../../../core/network/api_client.dart';
import 'self_buyout_models.dart';

class SelfBuyoutService {
  final ApiClient _apiClient;
  SelfBuyoutService(this._apiClient);

  Future<SelfBuyoutAvailability> getAvailability() async {
    try {
      final res = await _apiClient.get('/client/self-buyout/availability');
      if (res.statusCode == 200 && res.data is Map) {
        return SelfBuyoutAvailability.fromJson(
          res.data as Map<String, dynamic>,
        );
      }
      return SelfBuyoutAvailability.unavailable;
    } on DioException catch (e) {
      debugPrint('getAvailability error: $e');
      return SelfBuyoutAvailability.unavailable;
    }
  }

  Future<List<SelfBuyoutRequest>> getRequests() async {
    final res = await _apiClient.get('/client/self-buyout/requests');
    final list = (res.data?['requests'] as List?) ?? const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(SelfBuyoutRequest.fromJson)
        .toList();
  }

  Future<SelfBuyoutDetail> getDetail(int requestId) async {
    final res = await _apiClient.get('/client/self-buyout/requests/$requestId');
    return SelfBuyoutDetail.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Uint8List> getTransferProofBytes(String gatedUrl) async {
    final res = await _apiClient.get<List<int>>(
      _apiPath(gatedUrl),
      options: Options(responseType: ResponseType.bytes),
    );
    final bytes = res.data;
    if (bytes == null || bytes.isEmpty) {
      throw StateError('Transfer proof response is empty');
    }
    return bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
  }

  String _apiPath(String url) {
    final uri = Uri.tryParse(url);
    final path = uri?.path ?? url;
    if (path.startsWith('/api/')) return path.substring(4);
    if (path.startsWith('api/')) return '/${path.substring(4)}';
    return path.startsWith('/') ? path : '/$path';
  }

  /// Создать заявку. transferQr — опциональное изображение реквизитов.
  Future<SelfBuyoutRequest> createRequest({
    required int clientCodeId,
    required String amountEnteredIn, // cny | rub
    required double amount,
    String? transferRequisitesText,
    required bool warningAccepted,
    Uint8List? fileBytes,
    String? fileName,
    String? fileMime,
  }) async {
    final map = <String, dynamic>{
      'clientCodeId': clientCodeId.toString(),
      'amountEnteredIn': amountEnteredIn,
      'amount': amount.toString(),
      'warningAccepted': warningAccepted.toString(),
      if (transferRequisitesText != null && transferRequisitesText.isNotEmpty)
        'transferRequisitesText': transferRequisitesText,
    };
    if (fileBytes != null) {
      final parts = (fileMime ?? 'image/jpeg').split('/');
      map['transferQr'] = MultipartFile.fromBytes(
        fileBytes,
        filename: fileName ?? 'transfer-qr',
        contentType: MediaType(
          parts.isNotEmpty ? parts[0] : 'image',
          parts.length > 1 ? parts[1] : 'jpeg',
        ),
      );
    }
    final formData = FormData.fromMap(map);
    final res = await _apiClient.post(
      '/client/self-buyout/requests',
      data: formData,
      options: Options(headers: {'Content-Type': 'multipart/form-data'}),
    );
    return SelfBuyoutRequest.fromJson(
      res.data['request'] as Map<String, dynamic>,
    );
  }

  Future<SelfBuyoutRequest> correctTransferRequisites({
    required int requestId,
    String? transferRequisitesText,
    Uint8List? fileBytes,
    String? fileName,
    String? fileMime,
  }) async {
    final map = <String, dynamic>{
      if (transferRequisitesText != null && transferRequisitesText.isNotEmpty)
        'transferRequisitesText': transferRequisitesText,
    };
    if (fileBytes != null) {
      final parts = (fileMime ?? 'image/jpeg').split('/');
      map['transferQr'] = MultipartFile.fromBytes(
        fileBytes,
        filename: fileName ?? 'transfer-qr',
        contentType: MediaType(
          parts.isNotEmpty ? parts[0] : 'image',
          parts.length > 1 ? parts[1] : 'jpeg',
        ),
      );
    }
    final res = await _apiClient.patch(
      '/client/self-buyout/requests/$requestId/transfer-requisites',
      data: FormData.fromMap(map),
      options: Options(headers: {'Content-Type': 'multipart/form-data'}),
    );
    return SelfBuyoutRequest.fromJson(
      res.data['request'] as Map<String, dynamic>,
    );
  }

  /// Старт QR-оплаты по заявке. Идемпотентно на бэке.
  Future<SelfBuyoutPaymentInfo?> startBankQr(int requestId) async {
    final res = await _apiClient.post(
      '/client/self-buyout/requests/$requestId/bank-qr/start',
      data: const <String, dynamic>{},
    );
    if (res.statusCode == 200 && res.data is Map) {
      return SelfBuyoutPaymentInfo.fromStartJson(
        res.data as Map<String, dynamic>,
      );
    }
    return null;
  }

  Future<bool> uploadReceipt({
    required int paymentId,
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  }) async {
    final parts = mimeType.split('/');
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        bytes,
        filename: fileName,
        contentType: MediaType(
          parts.isNotEmpty ? parts[0] : 'application',
          parts.length > 1 ? parts[1] : 'octet-stream',
        ),
      ),
    });
    final res = await _apiClient.post(
      '/client/self-buyout/payments/$paymentId/receipt',
      data: formData,
      options: Options(headers: {'Content-Type': 'multipart/form-data'}),
    );
    return res.statusCode == 200;
  }

  Future<bool> cancel(int requestId) async {
    final res = await _apiClient.post(
      '/client/self-buyout/requests/$requestId/cancel',
      data: const <String, dynamic>{},
    );
    return res.statusCode == 200;
  }
}

final selfBuyoutServiceProvider = Provider<SelfBuyoutService>((ref) {
  return SelfBuyoutService(ref.read(apiClientProvider));
});

/// Доступность самовыкупа (для меню и экрана).
final selfBuyoutAvailabilityProvider = FutureProvider<SelfBuyoutAvailability>((
  ref,
) async {
  return ref.read(selfBuyoutServiceProvider).getAvailability();
});

/// Список заявок клиента.
final selfBuyoutRequestsProvider =
    FutureProvider.autoDispose<List<SelfBuyoutRequest>>((ref) async {
      return ref.read(selfBuyoutServiceProvider).getRequests();
    });
