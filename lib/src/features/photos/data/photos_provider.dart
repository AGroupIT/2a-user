import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/photo_item.dart';

/// Провайдер для получения общего количества фото по коду клиента
final photosTotalCountProvider = FutureProvider.family<int, String>((ref, clientCode) async {
  final apiClient = ref.read(apiClientProvider);
  
  try {
    final response = await apiClient.get(
      '/photos',
      queryParameters: {
        'clientCode': clientCode,
        'source': 'photoRequest', // Только фото из запросов фотоотчётов
        'take': 1,
      },
    );
    
    if (response.statusCode == 200 && response.data != null) {
      final data = response.data as Map<String, dynamic>;
      return data['total'] as int? ?? 0;
    }
    return 0;
  } on DioException catch (e) {
    debugPrint('Error loading photos count: $e');
    return 0;
  }
});

/// Провайдер для получения последних фото по коду клиента (только из фотоотчётов)
final photosRecentProvider = FutureProvider.family<List<PhotoItem>, ({String clientCode, int limit})>((ref, params) async {
  final apiClient = ref.read(apiClientProvider);
  
  try {
    final response = await apiClient.get(
      '/photos',
      queryParameters: {
        'clientCode': params.clientCode,
        'source': 'photoRequest', // Только фото из запросов фотоотчётов
        'take': params.limit,
      },
    );
    
    if (response.statusCode == 200 && response.data != null) {
      final data = response.data as Map<String, dynamic>;
      final photosJson = data['data'] as List<dynamic>? ?? [];
      
      return photosJson.map((json) => PhotoItem.fromJson(json as Map<String, dynamic>)).toList();
    }
    return [];
  } on DioException catch (e) {
    debugPrint('Error loading recent photos: $e');
    return [];
  }
});

/// Провайдер для получения дней с фото
final photosDaysProvider = FutureProvider.family<List<String>, ({String clientCode, int month, int year})>((ref, params) async {
  final apiClient = ref.read(apiClientProvider);
  
  try {
    final response = await apiClient.get(
      '/photos/days',
      queryParameters: {
        'clientCode': params.clientCode,
        'source': 'photoRequest', // Только фото из запросов фотоотчётов
        'month': params.month,
        'year': params.year,
      },
    );
    
    if (response.statusCode == 200 && response.data != null) {
      final data = response.data as Map<String, dynamic>;
      final days = data['days'] as List<dynamic>? ?? [];
      return days.map((d) => d.toString()).toList();
    }
    return [];
  } on DioException catch (e) {
    debugPrint('Error loading photo days: $e');
    return [];
  }
});

/// Провайдер для получения фото по дате
final photosByDateProvider = FutureProvider.family<List<PhotoItem>, ({String clientCode, String date})>((ref, params) async {
  final apiClient = ref.read(apiClientProvider);
  
  try {
    final response = await apiClient.get(
      '/photos',
      queryParameters: {
        'clientCode': params.clientCode,
        'source': 'photoRequest', // Только фото из запросов фотоотчётов
        'date': params.date,
        'take': 100,
      },
    );
    
    if (response.statusCode == 200 && response.data != null) {
      final data = response.data as Map<String, dynamic>;
      final photosJson = data['data'] as List<dynamic>? ?? [];
      
      return photosJson.map((json) => PhotoItem.fromJson(json as Map<String, dynamic>)).toList();
    }
    return [];
  } on DioException catch (e) {
    debugPrint('Error loading photos by date: $e');
    return [];
  }
});

/// Провайдер для поиска фото
final photosSearchProvider = FutureProvider.family<List<PhotoItem>, ({String clientCode, String query})>((ref, params) async {
  final apiClient = ref.read(apiClientProvider);
  
  try {
    final response = await apiClient.get(
      '/photos',
      queryParameters: {
        'clientCode': params.clientCode,
        'source': 'photoRequest', // Только фото из запросов фотоотчётов
        'search': params.query,
        'take': 50,
      },
    );
    
    if (response.statusCode == 200 && response.data != null) {
      final data = response.data as Map<String, dynamic>;
      final photosJson = data['data'] as List<dynamic>? ?? [];
      
      return photosJson.map((json) => PhotoItem.fromJson(json as Map<String, dynamic>)).toList();
    }
    return [];
  } on DioException catch (e) {
    debugPrint('Error searching photos: $e');
    return [];
  }
});
