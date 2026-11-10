import 'package:flutter/foundation.dart';
import '../database/local_database.dart';
import '../models/conversation.dart';

class ConversationRepository extends ChangeNotifier {
  final LocalDatabase _db;

  ConversationRepository(this._db) {
    _db.changes.listen((event) {
      if (event.table == 'conversations') {
        notifyListeners();
      }
    });
  }

  // --- CRUD: CREATE ---
  Future<void> createConversation(Conversation conversation) async {
    await _db.insert('conversations', conversation.id, conversation.toJson());
    notifyListeners();
  }

  // --- CRUD: READ ---
  List<Conversation> getAllConversations() {
    final list = _db.getAll('conversations');
    final convs = list.map((json) => Conversation.fromJson(json)).toList();
    return convs;
  }

  List<Conversation> getFilteredConversations({
    String filter = 'Tous',
    String searchQuery = '',
  }) {
    var list = getAllConversations();

    // Search query filter
    if (searchQuery.trim().isNotEmpty) {
      final query = searchQuery.toLowerCase();
      list = list.where((c) {
        return c.title.toLowerCase().contains(query) ||
            c.lastMessage.toLowerCase().contains(query);
      }).toList();
    }

    // Tab pill filter
    if (filter == 'Archivés') {
      return list.where((c) => c.isArchived).toList();
    }

    // Standard views only show non-archived conversations
    final nonArchived = list.where((c) => !c.isArchived).toList();

    switch (filter) {
      case 'Non lus':
        return nonArchived.where((c) => c.unreadCount > 0).toList();
      case 'Groupes':
        return nonArchived.where((c) => c.isGroup).toList();
      case 'Favoris':
        return nonArchived.where((c) => c.isFavorite).toList();
      case 'Tous':
      default:
        return nonArchived;
    }
  }

  Conversation? getConversationById(String id) {
    final data = _db.get('conversations', id);
    if (data == null) return null;
    return Conversation.fromJson(data);
  }

  // --- CRUD: UPDATE ---
  Future<void> updateConversation(Conversation conversation) async {
    await _db.update('conversations', conversation.id, conversation.toJson());
    notifyListeners();
  }

  Future<void> toggleArchive(String id) async {
    final conv = getConversationById(id);
    if (conv != null) {
      final updated = conv.copyWith(isArchived: !conv.isArchived);
      await updateConversation(updated);
    }
  }

  Future<void> markAsRead(String id) async {
    final conv = getConversationById(id);
    if (conv != null && conv.unreadCount > 0) {
      final updated = conv.copyWith(unreadCount: 0);
      await updateConversation(updated);
    }
  }

  Future<void> updateLastMessage({
    required String conversationId,
    required String message,
    required String time,
  }) async {
    final conv = getConversationById(conversationId);
    if (conv != null) {
      final updated = conv.copyWith(
        lastMessage: message,
        lastMessageTime: time,
      );
      await updateConversation(updated);
    }
  }

  // --- CRUD: DELETE ---
  Future<void> deleteConversation(String id) async {
    await _db.delete('conversations', id);
    notifyListeners();
  }
}
