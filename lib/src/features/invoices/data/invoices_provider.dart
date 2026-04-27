import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/invoice_item.dart';

/// Модель статуса счёта
class InvoiceStatus {
  final String id;
  final String code;
  final String nameRu;
  final String? color;

  const InvoiceStatus({
    required this.id,
    required this.code,
    required this.nameRu,
    this.color,
  });

  factory InvoiceStatus.fromJson(Map<String, dynamic> json) {
    return InvoiceStatus(
      id: json['id']?.toString() ?? '',
      code: json['code'] as String? ?? '',
      nameRu: json['nameRu'] as String? ?? json['code'] as String? ?? '',
      color: json['color'] as String?,
    );
  }
}

/// Провайдер для статусов счетов из БД
final invoiceStatusesProvider = FutureProvider<List<InvoiceStatus>>((ref) async {
  final apiClient = ref.read(apiClientProvider);

  try {
    final response = await apiClient.get(
      '/statuses',
      queryParameters: {'type': 'invoice'},
    );

    debugPrint('Invoice statuses response: ${response.data}');

    if (response.statusCode == 200 && response.data != null) {
      final data = response.data as Map<String, dynamic>;
      // API возвращает 'data', а не 'statuses'
      final statusesJson = data['data'] as List<dynamic>? ?? [];

      final statuses = statusesJson
          .map((json) => InvoiceStatus.fromJson(json as Map<String, dynamic>))
          .toList();

      debugPrint('Parsed invoice statuses: ${statuses.length}');
      return statuses;
    }
    return [];
  } on DioException catch (e) {
    debugPrint('Error loading invoice statuses: $e');
    return [];
  }
});

/// Провайдер для получения списка счетов
final invoicesListProvider = FutureProvider.family<List<InvoiceItem>, String>((ref, clientCode) async {
  final apiClient = ref.read(apiClientProvider);

  try {
    final response = await apiClient.get(
      '/invoices',
      queryParameters: {
        'clientCode': clientCode,
        'take': 100,
      },
    );

    if (response.statusCode == 200 && response.data != null) {
      final data = response.data as Map<String, dynamic>;
      final invoicesJson = data['data'] as List<dynamic>? ?? [];

      return invoicesJson
          .map((json) => InvoiceItem.fromJson(json as Map<String, dynamic>))
          .toList();
    }
    return [];
  } on DioException catch (e) {
    debugPrint('Error loading invoices: $e');
    return [];
  }
});

/// Провайдер для дайджеста счетов (последние 10, сортировка по updatedAt)
final invoicesDigestProvider = FutureProvider.family<List<InvoiceItem>, String>((ref, clientCode) async {
  final apiClient = ref.read(apiClientProvider);

  try {
    final response = await apiClient.get(
      '/invoices',
      queryParameters: {
        'clientCode': clientCode,
        'take': 10,
        'sortBy': 'updatedAt',
      },
    );

    if (response.statusCode == 200 && response.data != null) {
      final data = response.data as Map<String, dynamic>;
      final invoicesJson = data['data'] as List<dynamic>? ?? [];

      return invoicesJson
          .map((json) => InvoiceItem.fromJson(json as Map<String, dynamic>))
          .toList();
    }
    return [];
  } on DioException catch (e) {
    debugPrint('Error loading invoices digest: $e');
    return [];
  }
});

/// PU-H9: вытащить ВСЕ счета клиента батчами для экспорта.
///
/// `invoicesListProvider` берёт только первые 100, поэтому при
/// >100 счетах Excel-экспорт был неполным. Здесь делаем batch fetch по
/// `skip`/`take` до `hasMore == false`. Не Provider — обычная функция,
/// чтобы не дребезжать кешем (вызывается одноразово при кнопке).
///
/// Принимает `ApiClient` напрямую (а не `Ref`), чтобы вызывать одинаково
/// и из ConsumerWidget (`ref.read(apiClientProvider)`), и из обычного
/// контроллера, и из теста с моком.
Future<List<InvoiceItem>> fetchAllInvoicesForExport(
  ApiClient apiClient,
  String clientCode, {
  int batchSize = 200,
  int safetyLimit = 50000, // ~250 батчей × 200 — крайний предохранитель
}) async {
  final all = <InvoiceItem>[];
  var skip = 0;

  while (true) {
    if (all.length >= safetyLimit) {
      debugPrint('fetchAllInvoicesForExport: hit safetyLimit=$safetyLimit, stop');
      break;
    }
    try {
      final response = await apiClient.get(
        '/invoices',
        queryParameters: {
          'clientCode': clientCode,
          'skip': skip,
          'take': batchSize,
        },
      );
      if (response.statusCode != 200 || response.data == null) break;

      final data = response.data as Map<String, dynamic>;
      final invoicesJson = data['data'] as List<dynamic>? ?? const [];
      final batch = invoicesJson
          .map((json) => InvoiceItem.fromJson(json as Map<String, dynamic>))
          .toList();
      all.addAll(batch);

      final hasMore = data['hasMore'] as bool? ?? (batch.length == batchSize);
      if (!hasMore || batch.isEmpty) break;
      skip += batchSize;
    } on DioException catch (e) {
      debugPrint('fetchAllInvoicesForExport error: $e');
      // Возвращаем что собрали, даже если последний батч упал.
      break;
    }
  }
  return all;
}

/// Провайдер для общего количества счетов
final invoicesCountProvider = FutureProvider.family<int, String>((ref, clientCode) async {
  final apiClient = ref.read(apiClientProvider);

  try {
    final response = await apiClient.get(
      '/invoices',
      queryParameters: {
        'clientCode': clientCode,
        'take': 1,
      },
    );

    if (response.statusCode == 200 && response.data != null) {
      final data = response.data as Map<String, dynamic>;
      return data['total'] as int? ?? 0;
    }
    return 0;
  } on DioException catch (e) {
    debugPrint('Error loading invoices count: $e');
    return 0;
  }
});
