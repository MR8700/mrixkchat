import 'dart:async';
import 'package:flutter/foundation.dart';
import '../database/local_database.dart';
import '../models/contact.dart';
import '../models/conversation.dart';
import '../models/message.dart';
import '../models/message_request.dart';
import '../models/user_profile.dart';
import '../network/api_client.dart';

class MessageRepository extends ChangeNotifier {
  final LocalDatabase _db;
  StreamSubscription? _sub;

  MessageRepository(this._db) {
    _sub = _db.changes.listen((event) {
      if (event.table == 'messages' ||
          event.table == 'message_requests' ||
          event.table == 'conversations' ||
          event.table == 'contacts') {
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  // --- CRUD: CREATE ---
  Future<void> sendMessage(Message message) async {
    await _db.insert('messages', message.id, message.toJson());
    notifyListeners();

    final convData = _db.get('conversations', message.conversationId);
    final userData = _db.get('users', message.senderId);
    if (convData == null ||
        userData == null ||
        message.type != MessageType.text) return;
    final conversation = Conversation.fromJson(convData);
    if (conversation.isGroup) return;
    var recipientId = conversation.peerUserId ?? '';
    if (recipientId.isEmpty && conversation.id.startsWith('conv_')) {
      recipientId = conversation.id.substring('conv_'.length);
    }
    if (recipientId.isEmpty) {
      for (final contactData in _db.getAll('contacts')) {
        if ((contactData['name'] ?? '').toString().toLowerCase() ==
                conversation.title.toLowerCase() ||
            (contactData['handle'] ?? '').toString().toLowerCase() ==
                conversation.title.toLowerCase()) {
          recipientId = (contactData['id'] ?? '').toString();
          break;
        }
      }
    }
    final profile = UserProfile.fromJson(userData);
    if (recipientId.isEmpty ||
        profile.recoveryCode == null ||
        profile.recoveryCode!.isEmpty) return;
    ApiClient()
        .sendMessageRequest(
          senderId: profile.id,
          recipientId: recipientId,
          messageId: message.id,
          conversationId: conversation.id,
          content: message.content,
          recoveryCode: profile.recoveryCode!,
        )
        .catchError((_) => false);
  }

  Future<void> syncIncomingMessageRequests() async {
    final users = _db.getAll('users');
    if (users.isEmpty) return;
    final rawProfile = users.firstWhere(
      (u) => (u['displayName'] as String? ?? '').trim().isNotEmpty,
      orElse: () => users.first,
    );
    final profile = UserProfile.fromJson(rawProfile);
    final code = profile.recoveryCode ?? '';
    if (profile.id.isEmpty || code.isEmpty) return;
    final requests = await ApiClient()
        .fetchMessageRequests(userId: profile.id, recoveryCode: code);
    for (final request in requests) {
      final local = _db.get('message_requests', request.id);
      if (local == null || local['status'] != request.status) {
        await _db.insert('message_requests', request.id, request.toJson());
      }
      if (request.status == 'ACCEPTED')
        await _materializeAcceptedRequest(request);
    }
  }

  List<MessageRequest> getPendingMessageRequests() {
    final requests = _db
        .getAll('message_requests')
        .map(MessageRequest.fromJson)
        .where((request) => request.status == 'PENDING')
        .toList();
    requests.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return requests;
  }

  Future<void> acceptMessageRequest(MessageRequest request) async {
    final users = _db.getAll('users');
    final rawProfile = users.firstWhere(
      (u) => (u['displayName'] as String? ?? '').trim().isNotEmpty,
      orElse: () => users.first,
    );
    final profile = UserProfile.fromJson(rawProfile);
    await ApiClient().respondToMessageRequest(
      userId: profile.id,
      recoveryCode: profile.recoveryCode ?? '',
      requestId: request.id,
      accept: true,
    );
    final accepted = MessageRequest(
      id: request.id,
      senderId: request.senderId,
      senderHandle: request.senderHandle,
      senderName: request.senderName,
      senderAvatar: request.senderAvatar,
      recipientId: request.recipientId,
      conversationId: request.conversationId,
      content: request.content,
      messageType: request.messageType,
      createdAt: request.createdAt,
      status: 'ACCEPTED',
    );
    await _db.insert('message_requests', request.id, accepted.toJson());
    await _materializeAcceptedRequest(accepted);
  }

  Future<void> ignoreMessageRequest(MessageRequest request) async {
    final users = _db.getAll('users');
    final rawProfile = users.firstWhere(
      (u) => (u['displayName'] as String? ?? '').trim().isNotEmpty,
      orElse: () => users.first,
    );
    final profile = UserProfile.fromJson(rawProfile);
    await ApiClient().respondToMessageRequest(
      userId: profile.id,
      recoveryCode: profile.recoveryCode ?? '',
      requestId: request.id,
      accept: false,
    );
    final ignored = MessageRequest(
      id: request.id,
      senderId: request.senderId,
      senderHandle: request.senderHandle,
      senderName: request.senderName,
      senderAvatar: request.senderAvatar,
      recipientId: request.recipientId,
      conversationId: request.conversationId,
      content: request.content,
      messageType: request.messageType,
      createdAt: request.createdAt,
      status: 'IGNORED',
    );
    await _db.insert('message_requests', request.id, ignored.toJson());
    notifyListeners();
  }

  Future<void> _materializeAcceptedRequest(MessageRequest request) async {
    if (_db.get('messages', request.id) != null) return;
    if (_db.get('contacts', request.senderId) == null) {
      final category = request.senderName.isNotEmpty
          ? request.senderName[0].toUpperCase()
          : 'U';
      await _db.insert(
          'contacts',
          request.senderId,
          Contact(
            id: request.senderId,
            name: request.senderName,
            handle: request.senderHandle,
            avatarUrl: request.senderAvatar,
            statusText: 'Demande de message acceptée',
            isVerified: true,
            category: category,
          ).toJson());
    }
    final conversationId = 'conv_${request.senderId}';
    final oldConversation = _db.get('conversations', conversationId);
    final conversation = oldConversation == null
        ? Conversation(
            id: conversationId,
            peerUserId: request.senderId,
            title: request.senderName,
            peerAvatar: request.senderAvatar,
            isVerified: true,
            lastMessage: request.content,
            lastMessageTime: _formatTime(request.createdAt),
            unreadCount: 1,
            tagText: 'Privé',
          )
        : Conversation.fromJson(oldConversation).copyWith(
            lastMessage: request.content,
            lastMessageTime: _formatTime(request.createdAt),
            unreadCount: Conversation.fromJson(oldConversation).unreadCount + 1,
          );
    await _db.insert('conversations', conversationId, conversation.toJson());
    final message = Message(
      id: request.id,
      conversationId: conversationId,
      senderId: request.senderId,
      senderName: request.senderName,
      senderAvatar: request.senderAvatar,
      type: MessageType.text,
      content: request.content,
      time: _formatTime(request.createdAt),
      isOutgoing: false,
      isRead: false,
    );
    await _db.insert('messages', request.id, message.toJson());
    notifyListeners();
  }

  String _formatTime(DateTime date) =>
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

  /// Inserts a local-only system notice (never relayed to the server).
  /// Idempotent: the same [key] is only inserted once.
  Future<void> addSystemMessage(String conversationId, String text,
      {required String key}) async {
    final id = 'sys_${conversationId}_$key';
    if (_db.get('messages', id) != null) return;
    final now = DateTime.now();
    final time =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final msg = Message(
      id: id,
      conversationId: conversationId,
      senderId: 'system',
      senderName: 'MRixk',
      senderAvatar: '',
      type: MessageType.text,
      content: text,
      time: time,
      isOutgoing: false,
      isRead: true,
    );
    await _db.insert('messages', id, msg.toJson());
    notifyListeners();
  }

  // --- CRUD: READ ---
  List<Message> getMessagesForConversation(String conversationId) {
    final list = _db.query(
      'messages',
      (row) => row['conversationId'] == conversationId,
    );
    final messages = list.map((json) => Message.fromJson(json)).toList();
    // Maintain chronological order
    return messages;
  }

  Message? getMessageById(String id) {
    final data = _db.get('messages', id);
    if (data == null) return null;
    return Message.fromJson(data);
  }

  // --- CRUD: UPDATE ---
  Future<void> updateMessage(Message message) async {
    await _db.update('messages', message.id, message.toJson());
    notifyListeners();
  }

  Future<void> editMessage(String messageId, String newContent) async {
    final msg = getMessageById(messageId);
    if (msg == null) return;
    final updated = msg.copyWith(
      content: newContent,
      isEdited: true,
    );
    await updateMessage(updated);
  }

  Future<void> openViewOnceMessage(String messageId) async {
    final msg = getMessageById(messageId);
    if (msg == null) return;
    final updated = msg.copyWith(
      isViewOnceOpened: true,
      content: 'Vue unique expirée',
      imageUri: null,
    );
    await updateMessage(updated);
  }

  Future<void> toggleReaction(String messageId, String emoji) async {
    final msg = getMessageById(messageId);
    if (msg == null) return;

    final currentReactions = Map<String, int>.from(msg.reactions);
    if (currentReactions.containsKey(emoji)) {
      currentReactions[emoji] = currentReactions[emoji]! + 1;
    } else {
      currentReactions[emoji] = 1;
    }

    final updated = msg.copyWith(reactions: currentReactions);
    await updateMessage(updated);
  }

  Future<void> deleteMessageForEveryone(
    String messageId, {
    required String reason,
    required String deletedByName,
  }) async {
    final msg = getMessageById(messageId);
    if (msg == null) return;
    final updated = msg.copyWith(
      isDeletedForEveryone: true,
      deletionReason: reason,
      deletedByName: deletedByName,
      content: 'Ce message a été supprimé',
      imageUri: null,
      voiceTranscription: null,
      waveform: null,
      fileName: null,
    );
    await updateMessage(updated);
  }

  Future<void> deleteMultipleMessages(
    List<String> messageIds, {
    bool forEveryone = false,
    String? reason,
    String? deletedByName,
  }) async {
    for (final id in messageIds) {
      if (forEveryone) {
        await deleteMessageForEveryone(
          id,
          reason: reason ?? 'Non spécifié',
          deletedByName: deletedByName ?? 'Utilisateur',
        );
      } else {
        await deleteMessage(id);
      }
    }
  }

  Future<void> forwardMessage(
    String messageId,
    String targetConversationId, {
    required String senderId,
    required String senderName,
    required String senderAvatar,
  }) async {
    final original = getMessageById(messageId);
    if (original == null) return;

    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final forwarded = original.copyWith(
      id: 'msg_fwd_${DateTime.now().millisecondsSinceEpoch}',
      conversationId: targetConversationId,
      senderId: senderId,
      senderName: senderName,
      senderAvatar: senderAvatar,
      time: timeStr,
      isOutgoing: true,
      isForwarded: true,
      reactions: {},
    );

    await sendMessage(forwarded);
  }

  // --- CRUD: DELETE ---
  Future<void> deleteMessage(String id) async {
    await _db.delete('messages', id);
    notifyListeners();
  }
}
