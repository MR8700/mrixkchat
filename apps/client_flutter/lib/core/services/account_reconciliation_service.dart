import '../models/conversation.dart';
import '../network/api_client.dart';
import '../repositories/contact_repository.dart';
import '../repositories/conversation_repository.dart';
import '../repositories/message_repository.dart';
import '../repositories/profile_repository.dart';
import 'identity_directory_service.dart';

/// Keeps the whole app coherent with the server's source of truth:
///  - accounts deleted online are removed from contacts and groups,
///  - private discussions with a deleted account are closed with a system notice,
///  - groups get a notice and a new creator if needed,
///  - profile data of remaining contacts is refreshed (name/avatar/status).
class ReconcileResult {
  final int handled;
  final bool selfDeleted;
  final bool selfMissing;
  const ReconcileResult({this.handled = 0, this.selfDeleted = false, this.selfMissing = false});
}

class AccountReconciliationService {
  AccountReconciliationService._();

  static bool _running = false;

  /// Returns what was handled (nothing if the server is unreachable).
  static Future<ReconcileResult> run({
    required ContactRepository contacts,
    required ConversationRepository conversations,
    required MessageRepository messages,
    required ProfileRepository profile,
  }) async {
    if (_running) return const ReconcileResult();
    _running = true;
    try {
      final myId = profile.getProfile().id;
      final contactList = contacts.getAllContacts();
      final convList = conversations.getAllConversations();

      final ids = <String>{};
      for (final c in contactList) {
        if (c.id.isNotEmpty && c.id != myId) ids.add(c.id);
      }
      for (final conv in convList) {
        for (final m in conv.groupMembers) {
          if (m.id.isNotEmpty && m.id != myId) ids.add(m.id);
        }
      }
      if (myId.isNotEmpty) ids.add(myId);
      if (ids.isEmpty) return const ReconcileResult();

      // Never change local state if the server cannot be reached.
      final status = await ApiClient().usersStatus(ids.toList());
      if (status == null) return const ReconcileResult();

      // My own account was deleted from another device: this device must follow.
      if (myId.isNotEmpty && status.deleted.containsKey(myId)) {
        return const ReconcileResult(selfDeleted: true);
      }
      if (myId.isNotEmpty && status.missing.contains(myId)) {
        return const ReconcileResult(selfMissing: true);
      }

      // Refresh live profile data of remaining contacts
      for (final c in contactList) {
        final live = status.active[c.id];
        if (live == null) continue;
        final name = (live['display_name'] ?? c.name).toString();
        final avatar = (live['avatar_ref'] ?? live['avatar_url'] ?? c.avatarUrl).toString();
        final st = (live['status_message'] ?? c.statusText).toString();
        if (name != c.name || avatar != c.avatarUrl || st != c.statusText) {
          await contacts.updateContact(c.copyWith(
            name: name.isNotEmpty ? name : c.name,
            avatarUrl: avatar,
            statusText: st.isNotEmpty ? st : c.statusText,
          ));
        }
      }

      var handled = 0;
      for (final entry in status.deleted.entries) {
        final deletedId = entry.key;
        if (deletedId.isEmpty || deletedId == myId) continue;
        final label = _label(entry.value);
        handled++;

        // 1. Remove from contacts (automatic removal)
        final matching = contactList.where((c) => c.id == deletedId).toList();
        final contactNames = matching.map((c) => c.name.toLowerCase()).toSet();
        for (final c in matching) {
          await contacts.deleteContact(c.id);
        }

        // 2. Private discussions: close with notice. Groups: remove the member.
        for (final conv in conversations.getAllConversations()) {
          if (conv.isGroup) {
            await _removeFromGroup(conv, deletedId, label, conversations, messages);
          } else if (_isDirectWith(conv, deletedId, contactNames)) {
            await messages.addSystemMessage(
              conv.id,
              '🚫 $label a supprimé son compte. Cette discussion est désormais en lecture seule.',
              key: 'deleted_$deletedId',
            );
            await conversations.updateConversation(conv.copyWith(
              isBlocked: true,
              blockedMessage: '$label a supprimé son compte. Vous ne pouvez plus lui écrire.',
              isOnline: false,
              lastMessage: 'Compte supprimé',
            ));
          }
        }

        IdentityDirectoryService.registeredUsers.removeWhere((u) => u.id == deletedId);
      }
      return ReconcileResult(handled: handled);
    } finally {
      _running = false;
    }
  }

  static String _label(Map<String, dynamic> tombstone) {
    final handle = (tombstone['handle'] ?? '').toString();
    final name = (tombstone['display_name'] ?? '').toString();
    if (name.isNotEmpty && handle.isNotEmpty) return '$name ($handle)';
    return name.isNotEmpty ? name : (handle.isNotEmpty ? handle : 'Un utilisateur');
  }

  static bool _isDirectWith(Conversation conv, String userId, Set<String> contactNames) {
    if (conv.id == 'conv_$userId') return true;
    return contactNames.contains(conv.title.toLowerCase());
  }

  static Future<void> _removeFromGroup(
    Conversation conv,
    String userId,
    String label,
    ConversationRepository conversations,
    MessageRepository messages,
  ) async {
    if (!conv.groupMembers.any((m) => m.id == userId)) return;
    final removed = conv.groupMembers.firstWhere((m) => m.id == userId);
    var remaining = conv.groupMembers.where((m) => m.id != userId).toList();

    // Keep the group governable: promote someone if the creator left.
    if (removed.isCreator && remaining.isNotEmpty && !remaining.any((m) => m.isCreator)) {
      final successorIdx = remaining.indexWhere((m) => m.isAdmin);
      final idx = successorIdx >= 0 ? successorIdx : 0;
      remaining = [
        for (var i = 0; i < remaining.length; i++)
          i == idx ? remaining[i].copyWith(role: 'creator') : remaining[i],
      ];
    }

    await conversations.updateConversation(conv.copyWith(
      groupMembers: remaining,
      groupMembersCount: remaining.isEmpty ? 1 : remaining.length,
    ));
    await messages.addSystemMessage(
      conv.id,
      '👋 $label a été retiré du groupe (compte supprimé).',
      key: 'deleted_$userId',
    );
  }
}
