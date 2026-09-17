import 'package:twoalogistic_shared/twoalogistic_shared.dart';

/// Optional pagination; old servers still return their complete conversation.
class ChatHistoryPage {
  const ChatHistoryPage(this.conversation, {this.hasMore = false});

  final ChatConversation conversation;
  final bool hasMore;

  factory ChatHistoryPage.fromJson(Map<String, dynamic> json) {
    final conversation = Map<String, dynamic>.from(json['conversation'] as Map);
    conversation['messages'] = json['messages'] as List? ?? const [];
    final pagination = json['pagination'];
    return ChatHistoryPage(
      ChatConversation.fromJson(conversation),
      hasMore: pagination is Map && pagination['hasMore'] == true,
    );
  }
}
