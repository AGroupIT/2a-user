import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';

abstract interface class GarageRemoteClient {
  Future<Object?> get(String path, {Map<String, dynamic>? queryParameters});

  Future<Object?> post(
    String path, {
    Object? data,
    Map<String, String>? headers,
  });

  Future<Object?> patch(String path, {Object? data});

  Future<Object?> delete(String path);
}

class ApiClientGarageRemoteClient implements GarageRemoteClient {
  final ApiClient _apiClient;

  const ApiClientGarageRemoteClient(this._apiClient);

  @override
  Future<Object?> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final response = await _apiClient.get<Object?>(
      path,
      queryParameters: queryParameters,
    );
    return response.data;
  }

  @override
  Future<Object?> post(
    String path, {
    Object? data,
    Map<String, String>? headers,
  }) async {
    final response = await _apiClient.post<Object?>(
      path,
      data: data,
      options: headers == null ? null : Options(headers: headers),
    );
    return response.data;
  }

  @override
  Future<Object?> patch(String path, {Object? data}) async {
    final response = await _apiClient.patch<Object?>(path, data: data);
    return response.data;
  }

  @override
  Future<Object?> delete(String path) async {
    final response = await _apiClient.delete<Object?>(path);
    return response.data;
  }
}
