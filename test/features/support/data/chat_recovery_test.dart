import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twoalogistic_shared/twoalogistic_shared.dart';
import 'package:twoalogisticcabineuser/src/core/network/api_client.dart';
import 'package:twoalogisticcabineuser/src/core/services/websocket_provider.dart';
import 'package:twoalogisticcabineuser/src/features/support/data/chat_provider.dart';
import 'package:twoalogisticcabineuser/src/features/payment_chat/data/payment_chat_provider.dart';
import '../../../helpers/mock_data.dart';

class _ChatApi extends ApiClient {
  Completer<Map<String, dynamic>>? history;
  final poll = Completer<Map<String, dynamic>>();
  int polls = 0;
  bool legacy = false;
  final queries = <Map<String, dynamic>>[];

  Map<String, dynamic> payload(List<int> ids, {bool hasMore = false}) => {
    'conversation': MockData.createMockConversation(id: 1).toJson(),
    'messages': ids
        .map(
          (id) =>
              MockData.createMockMessage(id: id, conversationId: 1).toJson(),
        )
        .toList(),
    if (!legacy) 'pagination': {'hasMore': hasMore},
  };

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    final query = queryParameters ?? {};
    queries.add(Map.of(query));
    final Map<String, dynamic> data;
    if (query.containsKey('afterMessageId')) {
      polls++;
      data = await poll.future;
    } else if (query.containsKey('beforeMessageId')) {
      data = payload([1, 2, 3]); // boundary duplicate must not duplicate row 3
    } else {
      data = history == null
          ? payload([3, 4], hasMore: true)
          : await history!.future;
    }
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
      data: data as T,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final payment in [false, true]) {
    group(payment ? 'payment chat recovery' : 'support chat recovery', () {
      late _ChatApi api;
      late ProviderContainer container;
      late WebSocketService socket;
      late dynamic controller;
      var disposed = false;
      dynamic currentState() => payment
          ? container.read(paymentChatControllerProvider)
          : container.read(chatControllerProvider);
      setUp(() {
        disposed = false;
        api = _ChatApi();
        socket = WebSocketService(serverUrl: 'http://127.0.0.1:1');
        container = ProviderContainer(
          overrides: [
            apiClientProvider.overrideWithValue(api),
            webSocketServiceProvider.overrideWithValue(socket),
          ],
        );
        controller = payment
            ? container.read(paymentChatControllerProvider.notifier)
            : container.read(chatControllerProvider.notifier);
        controller.setRealtimeActive(true);
      });
      tearDown(() {
        if (!disposed) container.dispose();
        socket.dispose();
      });

      test(
        'poll is single flight and ignores response after tab deactivation',
        () async {
          await controller.loadConversation();
          final first = controller.pollNewMessages() as Future<void>;
          await controller.pollNewMessages();
          expect(api.polls, 1);
          controller.setRealtimeActive(false);
          api.poll.complete(api.payload([5]));
          await first;
          expect((currentState().messages as List).map((m) => m.id), [3, 4]);
        },
      );

      test(
        'older page deduplicates boundary and keeps new-message cursor',
        () async {
          await controller.loadConversation();
          expect(currentState().hasMoreHistory, true);
          await controller.loadOlderMessages();
          expect((currentState().messages as List).map((m) => m.id), [
            1,
            2,
            3,
            4,
          ]);
          expect(currentState().lastMessageId, 4);
          expect(currentState().hasMoreHistory, false);
          expect(api.queries.last, {'limit': 50, 'beforeMessageId': 3});
        },
      );

      test('legacy backend full-history response remains readable', () async {
        api.legacy = true;
        await controller.loadConversation();
        expect((currentState().messages as List).length, 2);
        expect(currentState().hasMoreHistory, false);
      });

      test(
        'late initial failure after disposal does not access dead provider',
        () async {
          api.history = Completer<Map<String, dynamic>>();
          final loading = controller.loadConversation() as Future<void>;
          container.dispose();
          disposed = true;
          api.history!.completeError(Exception('offline'));
          await expectLater(loading, completes);
        },
      );

      test(
        'tab activation does not strand an in-flight initial load',
        () async {
          controller.setRealtimeActive(false);
          api.history = Completer<Map<String, dynamic>>();
          final loading = controller.loadConversation() as Future<void>;
          controller.setRealtimeActive(true);
          api.history!.complete(api.payload([3, 4], hasMore: true));
          await loading;
          expect(currentState().isLoading, false);
          expect((currentState().messages as List).length, 2);
        },
      );
    });
  }
}
