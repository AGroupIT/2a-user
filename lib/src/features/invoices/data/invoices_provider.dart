import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/demo_data.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/demo_mode_provider.dart';
import '../domain/invoice_item.dart';

/// Модель статуса счёта
class InvoiceStatus {
  final String id;
  final String code;
  final String nameRu;
  final String? color;
  final int sortOrder;

  const InvoiceStatus({
    required this.id,
    required this.code,
    required this.nameRu,
    this.color,
    this.sortOrder = 0,
  });

  factory InvoiceStatus.fromJson(Map<String, dynamic> json) {
    return InvoiceStatus(
      id: json['id']?.toString() ?? '',
      code: json['code'] as String? ?? '',
      nameRu: json['nameRu'] as String? ?? json['code'] as String? ?? '',
      color: json['color'] as String?,
      sortOrder: json['sortOrder'] as int? ?? 0,
    );
  }
}

/// Провайдер для статусов счетов из БД
final invoiceStatusesProvider = FutureProvider<List<InvoiceStatus>>((
  ref,
) async {
  if (ref.watch(demoModeProvider)) return [];
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

/// Фиксирует нажатие клиентом кнопки "Оплатить".
///
/// Backend переводит счёт из `unpaid`/`pending` в `processing`, чтобы кнопка
/// оплаты сразу исчезала и бухгалтер видел следующий ожидаемый статус.
Future<void> requestInvoicePayment(
  ApiClient apiClient,
  String invoiceId,
) async {
  await apiClient.post('/client/invoices/$invoiceId/request-payment');
}

/// Провайдер для получения списка счетов
final invoicesListProvider = FutureProvider.family<List<InvoiceItem>, String>((
  ref,
  clientCode,
) async {
  if (ref.watch(demoModeProvider)) return DemoData.invoices;
  final apiClient = ref.read(apiClientProvider);

  try {
    final response = await apiClient.get(
      '/invoices',
      queryParameters: {'clientCode': clientCode, 'take': 100},
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
final invoicesDigestProvider = FutureProvider.family<List<InvoiceItem>, String>(
  (ref, clientCode) async {
    if (ref.watch(demoModeProvider)) return DemoData.invoices;
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
  },
);

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
      debugPrint(
        'fetchAllInvoicesForExport: hit safetyLimit=$safetyLimit, stop',
      );
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

/// Провайдер количества счетов для карточки на главном экране.
/// Считаются только неоплаченные счета (status=unpaid).
final invoicesCountProvider = FutureProvider.family<int, String>((
  ref,
  clientCode,
) async {
  if (ref.watch(demoModeProvider)) return DemoData.invoicesCount;
  final apiClient = ref.read(apiClientProvider);

  try {
    final response = await apiClient.get(
      '/invoices',
      queryParameters: {
        'clientCode': clientCode,
        'take': 1,
        'status': 'unpaid',
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

/// Количество счетов, созданных за последние 7 дней.
final invoicesWeeklyCountProvider = FutureProvider.family<int, String>((
  ref,
  clientCode,
) async {
  final weekStart = DateTime.now().subtract(const Duration(days: 7));
  if (ref.watch(demoModeProvider)) {
    return DemoData.invoices
        .where(
          (invoice) =>
              invoice.createdAt != null &&
              !invoice.createdAt!.isBefore(weekStart),
        )
        .length;
  }
  final apiClient = ref.read(apiClientProvider);

  try {
    final response = await apiClient.get(
      '/invoices',
      queryParameters: {
        'clientCode': clientCode,
        'take': 1,
        'dateFrom': weekStart.toUtc().toIso8601String(),
        'sortBy': 'createdAt',
      },
    );

    if (response.statusCode == 200 && response.data != null) {
      final data = response.data as Map<String, dynamic>;
      return data['total'] as int? ?? 0;
    }
    return 0;
  } on DioException catch (e) {
    debugPrint('Error loading weekly invoices count: $e');
    return 0;
  }
});

/// Провайдер для получения одного счёта по ID (для актуальных данных в чате)
final invoiceByIdProvider = FutureProvider.family<InvoiceItem?, String>((
  ref,
  id,
) async {
  if (ref.watch(demoModeProvider)) {
    return DemoData.invoices.where((i) => i.id == id).firstOrNull;
  }
  final apiClient = ref.read(apiClientProvider);

  try {
    final response = await apiClient.get('/invoices/$id');

    if (response.statusCode == 200 && response.data != null) {
      final data = response.data as Map<String, dynamic>;
      final invoiceJson = data['data'] as Map<String, dynamic>?;
      if (invoiceJson == null) return null;
      return InvoiceItem.fromJson(invoiceJson);
    }
    return null;
  } on DioException catch (e) {
    debugPrint('Error loading invoice by id: $e');
    return null;
  }
});

/// Payment TG username — cached after first load
String? _paymentTgUsername;

/// Provider that loads and caches payment TG config
final paymentTgUsernameProvider = FutureProvider<String?>((ref) async {
  if (_paymentTgUsername != null) return _paymentTgUsername;
  try {
    final api = ref.read(apiClientProvider);
    final res = await api.get('/client/payment-tg-config');
    final data = res.data['data'] as Map<String, dynamic>?;
    if (data != null && data['enabled'] == true) {
      _paymentTgUsername = data['businessUsername'] as String?;
    }
  } catch (_) {}
  return _paymentTgUsername;
});
