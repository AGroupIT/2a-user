import 'package:dio/dio.dart';

class NativeHttpFallback {
  NativeHttpFallback({required this.tokenProvider});

  final Future<String?> Function() tokenProvider;

  bool get isAvailable => false;

  Future<Response<T>?> get<T>({
    required String baseUrl,
    required String path,
    Map<String, dynamic>? queryParameters,
    Options? options,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    return null;
  }

  void close() {}
}
