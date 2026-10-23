import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:twoalogisticcabineuser/src/core/network/api_client.dart';

class _Adapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? body,
    Future<void>? cancelFuture,
  ) async => ResponseBody(
    Stream.fromIterable([
      Uint8List.fromList([1, 2]),
      Uint8List.fromList([3, 4]),
    ]),
    200,
    headers: {
      Headers.contentLengthHeader: ['4'],
    },
  );

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'GET forwards actual Dio download progress and Content-Length',
    () async {
      final api = ApiClient(
        adapterFactory: _Adapter.new,
        runtimeHeaders: () async => {},
      );
      final progress = <(int, int)>[];
      final response = await api.getWithProgress<List<int>>(
        '/uploads/progress.bin',
        options: Options(responseType: ResponseType.bytes),
        onReceiveProgress: (received, total) => progress.add((received, total)),
      );
      expect(response.data, [1, 2, 3, 4]);
      expect(progress, isNotEmpty);
      expect(progress.last, (4, 4));
    },
  );
}
