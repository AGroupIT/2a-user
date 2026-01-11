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
