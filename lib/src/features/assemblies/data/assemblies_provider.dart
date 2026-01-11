import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/assembly_item.dart';

/// Провайдер для получения списка сборок по коду клиента
final assembliesListProvider = FutureProvider.family<List<AssemblyItem>, String>((ref, clientCode) async {
  final apiClient = ref.read(apiClientProvider);
  
  try {
    final response = await apiClient.get(
      '/assemblies',
      queryParameters: {
        'clientCode': clientCode,
        'take': 100,
      },
    );
    
    if (response.statusCode == 200 && response.data != null) {
      final data = response.data as Map<String, dynamic>;
      // API возвращает assemblies, не data
      final assembliesJson = data['assemblies'] as List<dynamic>? ?? [];
      
      return assembliesJson.map((json) => AssemblyItem.fromJson(json as Map<String, dynamic>)).toList();
    }
    return [];
  } on DioException catch (e) {
    debugPrint('Error loading assemblies: $e');
    return [];
  }
});

/// Провайдер для общего количества сборок
final assembliesCountProvider = FutureProvider.family<int, String>((ref, clientCode) async {
  final apiClient = ref.read(apiClientProvider);
  
  try {
    final response = await apiClient.get(
      '/assemblies',
      queryParameters: {
        'clientCode': clientCode,
        'take': 1,
      },
    );
    
    if (response.statusCode == 200 && response.data != null) {
      final data = response.data as Map<String, dynamic>;
      // total находится в pagination
      final pagination = data['pagination'] as Map<String, dynamic>?;
      return pagination?['total'] as int? ?? 0;
    }
    return 0;
  } on DioException catch (e) {
    debugPrint('Error loading assemblies count: $e');
    return 0;
  }
});
