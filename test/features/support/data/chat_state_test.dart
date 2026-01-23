import 'package:flutter_test/flutter_test.dart';
import 'package:twoalogisticcabineuser/src/features/support/data/chat_provider.dart';
import '../../../helpers/mock_data.dart';

void main() {
  group('ChatState', () {
    test('should create state with default values', () {
      const state = ChatState();

      expect(state.conversation, null);
      expect(state.messages, isEmpty);
      expect(state.isLoading, false);
      expect(state.isSending, false);
      expect(state.isUploading, false);
      expect(state.error, null);
      expect(state.lastMessageId, null);
      expect(state.pendingAttachments, isEmpty);
    });

    test('should copy state with new values', () {
      const original = ChatState();
      final mockConversation = MockData.createMockConversation(id: 1);
      final mockMessages = [MockData.createMockMessage(id: 1)];
      final mockAttachments = [MockData.createMockAttachment(id: 1)];

      final updated = original.copyWith(
        conversation: mockConversation,
        messages: mockMessages,
        isLoading: true,
        isSending: true,
        isUploading: true,
        error: 'Test error',
        lastMessageId: 5,
        pendingAttachments: mockAttachments,
      );

      expect(updated.conversation, mockConversation);
      expect(updated.messages, mockMessages);
      expect(updated.isLoading, true);
      expect(updated.isSending, true);
      expect(updated.isUploading, true);
      expect(updated.error, 'Test error');
      expect(updated.lastMessageId, 5);
      expect(updated.pendingAttachments, mockAttachments);
    });

    test('should keep original values when copyWith without parameters', () {
      final mockConversation = MockData.createMockConversation(id: 1);
      final mockMessages = [MockData.createMockMessage(id: 1)];

      final original = ChatState(
        conversation: mockConversation,
        messages: mockMessages,
        isLoading: true,
        error: 'Test error',
        lastMessageId: 5,
      );

      final updated = original.copyWith();

      expect(updated.conversation, mockConversation);
      expect(updated.messages, mockMessages);
      expect(updated.isLoading, true);
      expect(updated.error, 'Test error');
      expect(updated.lastMessageId, 5);
    });

    test('should clear error when clearError is true', () {
      const original = ChatState(error: 'Test error');

      final updated = original.copyWith(clearError: true);

      expect(updated.error, null);
    });

    test('should keep error when clearError is false', () {
      const original = ChatState(error: 'Test error');

      final updated = original.copyWith(clearError: false);

      expect(updated.error, 'Test error');
    });

    test('should preserve error when copyWith with new error', () {
      const original = ChatState(error: 'Old error');

      final updated = original.copyWith(error: 'New error');

      expect(updated.error, 'New error');
    });

    test('should update only specified fields', () {
      const original = ChatState(
        isLoading: false,
        isSending: false,
        error: 'Test error',
      );

      final updated = original.copyWith(isLoading: true);

      expect(updated.isLoading, true);
      expect(updated.isSending, false);
      expect(updated.error, 'Test error');
    });

    test('should handle multiple copyWith calls', () {
      const original = ChatState();

      final step1 = original.copyWith(isLoading: true);
      final step2 = step1.copyWith(error: 'Error');
      final step3 = step2.copyWith(isLoading: false);

      expect(step3.isLoading, false);
      expect(step3.error, 'Error');
    });

    test('should handle empty messages list', () {
      const state = ChatState(messages: []);

      expect(state.messages, isEmpty);
    });

    test('should handle multiple messages', () {
      final messages = List.generate(
        10,
        (i) => MockData.createMockMessage(id: i),
      );

      final state = ChatState(messages: messages);

      expect(state.messages.length, 10);
    });

    test('should handle multiple pending attachments', () {
      final attachments = List.generate(
        5,
        (i) => MockData.createMockAttachment(id: i),
      );

      final state = ChatState(pendingAttachments: attachments);

      expect(state.pendingAttachments.length, 5);
    });

    test('should handle all flags set to true', () {
      const state = ChatState(
        isLoading: true,
        isSending: true,
        isUploading: true,
      );

      expect(state.isLoading, true);
      expect(state.isSending, true);
      expect(state.isUploading, true);
    });

    test('should handle lastMessageId updates', () {
      const original = ChatState(lastMessageId: 1);

      final updated = original.copyWith(lastMessageId: 10);

      expect(updated.lastMessageId, 10);
    });

    test('should handle conversation updates', () {
      final conversation1 = MockData.createMockConversation(id: 1);
      final conversation2 = MockData.createMockConversation(id: 2);

      final original = ChatState(conversation: conversation1);
      final updated = original.copyWith(conversation: conversation2);

      expect(updated.conversation!.id, 2);
    });
  });
}
