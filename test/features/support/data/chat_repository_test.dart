import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:twoalogisticcabineuser/src/core/network/api_client.dart';
import 'package:twoalogisticcabineuser/src/features/support/data/chat_provider.dart';
import '../../../helpers/mock_data.dart';

class MockApiClient extends Mock implements ApiClient {}

void main() {
  group('ChatRepository', () {
    late MockApiClient mockApiClient;
    late ChatRepository repository;

    setUp(() {
      mockApiClient = MockApiClient();
      repository = ChatRepository(mockApiClient);
    });

    group('getConversation', () {
      test('should return conversation with messages on success', () async {
        // Arrange
        final mockConversation = MockData.createMockConversation(id: 1);
        final mockMessages = [
          MockData.createMockMessage(id: 1, conversationId: 1),
          MockData.createMockMessage(id: 2, conversationId: 1),
        ];

        when(() => mockApiClient.get('/client/chat')).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/client/chat'),
            statusCode: 200,
            data: {
              'conversation': mockConversation.toJson()
                ..remove('messages'), // API returns messages separately
              'messages': mockMessages.map((m) => m.toJson()).toList(),
            },
          ),
        );

        // Act
        final result = await repository.getConversation();

        // Assert
        expect(result.id, 1);
        expect(result.messages.length, 2);
        verify(() => mockApiClient.get('/client/chat')).called(1);
      });

      test('should throw exception when status code is not 200', () async {
        // Arrange
        when(() => mockApiClient.get('/client/chat')).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/client/chat'),
            statusCode: 500,
            data: null,
          ),
        );

        // Act & Assert
        expect(
          () => repository.getConversation(),
          throwsA(isA<Exception>()),
        );
      });

      test('should throw exception when data is null', () async {
        // Arrange
        when(() => mockApiClient.get('/client/chat')).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/client/chat'),
            statusCode: 200,
            data: null,
          ),
        );

        // Act & Assert
        expect(
          () => repository.getConversation(),
          throwsA(isA<Exception>()),
        );
      });

      test('should handle DioException and rethrow', () async {
        // Arrange
        when(() => mockApiClient.get('/client/chat')).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: '/client/chat'),
            type: DioExceptionType.connectionTimeout,
          ),
        );

        // Act & Assert
        expect(
          () => repository.getConversation(),
          throwsA(isA<DioException>()),
        );
      });

      test('should handle empty messages array', () async {
        // Arrange
        final mockConversation = MockData.createMockConversation(id: 1);

        when(() => mockApiClient.get('/client/chat')).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/client/chat'),
            statusCode: 200,
            data: {
              'conversation': mockConversation.toJson()..remove('messages'),
              'messages': [],
            },
          ),
        );

        // Act
        final result = await repository.getConversation();

        // Assert
        expect(result.messages, isEmpty);
      });
    });

    group('sendMessage', () {
      test('should send text message successfully', () async {
        // Arrange
        final mockMessage = MockData.createMockMessage(
          id: 1,
          content: 'Test message',
        );

        when(() => mockApiClient.post(
              '/client/chat',
              data: any(named: 'data'),
            )).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/client/chat'),
            statusCode: 201,
            data: {
              'message': mockMessage.toJson(),
            },
          ),
        );

        // Act
        final result = await repository.sendMessage('Test message');

        // Assert
        expect(result.content, 'Test message');
        verify(() => mockApiClient.post(
              '/client/chat',
              data: {
                'content': 'Test message',
                'contentType': 'text',
              },
            )).called(1);
      });

      test('should send message with attachments', () async {
        // Arrange
        final mockMessage = MockData.createMockMessage(id: 1);

        when(() => mockApiClient.post(
              '/client/chat',
              data: any(named: 'data'),
            )).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/client/chat'),
            statusCode: 201,
            data: {
              'message': mockMessage.toJson(),
            },
          ),
        );

        // Act
        await repository.sendMessage(
          'Test',
          attachmentIds: [1, 2],
        );

        // Assert
        verify(() => mockApiClient.post(
              '/client/chat',
              data: {
                'content': 'Test',
                'contentType': 'text',
                'attachmentIds': [1, 2],
              },
            )).called(1);
      });

      test('should throw exception when status code is not 201', () async {
        // Arrange
        when(() => mockApiClient.post(
              '/client/chat',
              data: any(named: 'data'),
            )).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/client/chat'),
            statusCode: 500,
            data: null,
          ),
        );

        // Act & Assert
        expect(
          () => repository.sendMessage('Test'),
          throwsA(isA<Exception>()),
        );
      });

      test('should handle DioException', () async {
        // Arrange
        when(() => mockApiClient.post(
              '/client/chat',
              data: any(named: 'data'),
            )).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: '/client/chat'),
            type: DioExceptionType.badResponse,
          ),
        );

        // Act & Assert
        expect(
          () => repository.sendMessage('Test'),
          throwsA(isA<DioException>()),
        );
      });

      test('should send message with custom content type', () async {
        // Arrange
        final mockMessage = MockData.createMockMessage(id: 1);

        when(() => mockApiClient.post(
              '/client/chat',
              data: any(named: 'data'),
            )).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/client/chat'),
            statusCode: 201,
            data: {
              'message': mockMessage.toJson(),
            },
          ),
        );

        // Act
        await repository.sendMessage(
          'Test',
          contentType: 'image',
        );

        // Assert
        verify(() => mockApiClient.post(
              '/client/chat',
              data: {
                'content': 'Test',
                'contentType': 'image',
              },
            )).called(1);
      });
    });

    group('getNewMessages', () {
      test('should return new messages after specified ID', () async {
        // Arrange
        final mockMessages = [
          MockData.createMockMessage(id: 3, conversationId: 1),
          MockData.createMockMessage(id: 4, conversationId: 1),
        ];

        when(() => mockApiClient.get(
              '/client/chat',
              queryParameters: any(named: 'queryParameters'),
            )).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/client/chat'),
            statusCode: 200,
            data: {
              'conversation': {},
              'messages': mockMessages.map((m) => m.toJson()).toList(),
            },
          ),
        );

        // Act
        final result = await repository.getNewMessages(1, 2);

        // Assert
        expect(result.length, 2);
        expect(result.every((m) => m.id > 2), true);
        verify(() => mockApiClient.get(
              '/client/chat',
              queryParameters: {'afterMessageId': '2'},
            )).called(1);
      });

      test('should filter messages with ID <= afterMessageId', () async {
        // Arrange
        final mockMessages = [
          MockData.createMockMessage(id: 2, conversationId: 1),
          MockData.createMockMessage(id: 3, conversationId: 1),
          MockData.createMockMessage(id: 4, conversationId: 1),
        ];

        when(() => mockApiClient.get(
              '/client/chat',
              queryParameters: any(named: 'queryParameters'),
            )).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/client/chat'),
            statusCode: 200,
            data: {
              'conversation': {},
              'messages': mockMessages.map((m) => m.toJson()).toList(),
            },
          ),
        );

        // Act
        final result = await repository.getNewMessages(1, 2);

        // Assert
        expect(result.length, 2);
        expect(result.first.id, 3);
        expect(result.last.id, 4);
      });

      test('should return empty list on error', () async {
        // Arrange
        when(() => mockApiClient.get(
              '/client/chat',
              queryParameters: any(named: 'queryParameters'),
            )).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: '/client/chat'),
            type: DioExceptionType.connectionTimeout,
          ),
        );

        // Act
        final result = await repository.getNewMessages(1, 2);

        // Assert
        expect(result, isEmpty);
      });

      test('should handle null messages array', () async {
        // Arrange
        when(() => mockApiClient.get(
              '/client/chat',
              queryParameters: any(named: 'queryParameters'),
            )).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/client/chat'),
            statusCode: 200,
            data: {
              'conversation': {},
              'messages': null,
            },
          ),
        );

        // Act
        final result = await repository.getNewMessages(1, 2);

        // Assert
        expect(result, isEmpty);
      });

      test('should handle empty messages array', () async {
        // Arrange
        when(() => mockApiClient.get(
              '/client/chat',
              queryParameters: any(named: 'queryParameters'),
            )).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/client/chat'),
            statusCode: 200,
            data: {
              'conversation': {},
              'messages': [],
            },
          ),
        );

        // Act
        final result = await repository.getNewMessages(1, 2);

        // Assert
        expect(result, isEmpty);
      });
    });

  });
}
