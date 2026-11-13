class MessageRequest {
  final String id;
  final String senderId;
  final String senderHandle;
  final String senderName;
  final String senderAvatar;
  final String recipientId;
  final String conversationId;
  final String content;
  final String messageType;
  final DateTime createdAt;
  final String status;

  const MessageRequest({
    required this.id,
    required this.senderId,
    required this.senderHandle,
    required this.senderName,
    required this.senderAvatar,
    required this.recipientId,
    required this.conversationId,
    required this.content,
    required this.messageType,
    required this.createdAt,
    required this.status,
  });

  factory MessageRequest.fromJson(Map<String, dynamic> json) => MessageRequest(
        id: (json['id'] ?? '').toString(),
        senderId: (json['sender_id'] ?? '').toString(),
        senderHandle: (json['sender_handle'] ?? '').toString(),
        senderName: (json['sender_name'] ?? '').toString(),
        senderAvatar: (json['sender_avatar'] ?? '').toString(),
        recipientId: (json['recipient_id'] ?? '').toString(),
        conversationId: (json['conversation_id'] ?? '').toString(),
        content: (json['content'] ?? '').toString(),
        messageType: (json['message_type'] ?? 'text').toString(),
        createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ??
            DateTime.now(),
        status: (json['status'] ?? 'PENDING').toString(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'sender_id': senderId,
        'sender_handle': senderHandle,
        'sender_name': senderName,
        'sender_avatar': senderAvatar,
        'recipient_id': recipientId,
        'conversation_id': conversationId,
        'content': content,
        'message_type': messageType,
        'created_at': createdAt.toIso8601String(),
        'status': status,
      };
}
