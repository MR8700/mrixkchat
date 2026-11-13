import 'dart:async';
import 'package:flutter/foundation.dart';
import '../database/local_database.dart';
import '../models/message.dart';
import '../network/api_client.dart';

class MessageRepository extends ChangeNotifier {
  final LocalDatabase _db;
  StreamSubscription? _sub;

  MessageRepository(this._db) {
    _sub = _db.changes.listen((event) {
      if (event.table == 'messages') {
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

    // Asynchronous network sync with server relay
    ApiClient().sendEncryptedMessage(
      conversationId: message.conversationId,
      ciphertext: message.content,
      idempotencyKey: message.id,
    ).catchError((_) => false);
  }

  /// Inserts a local-only system notice (never relayed to the server).
  /// Idempotent: the same [key] is only inserted once.
  Future<void> addSystemMessage(String conversationId, String text, {required String key}) async {
    final id = 'sys_${conversationId}_$key';
    if (_db.get('messages', id) != null) return;
    final now = DateTime.now();
    final time = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
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
