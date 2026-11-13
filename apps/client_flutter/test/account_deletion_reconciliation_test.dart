import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mrixk_client/core/database/local_database.dart';
import 'package:mrixk_client/core/models/contact.dart';
import 'package:mrixk_client/core/models/conversation.dart';
import 'package:mrixk_client/core/repositories/contact_repository.dart';
import 'package:mrixk_client/core/repositories/conversation_repository.dart';
import 'package:mrixk_client/core/repositories/message_repository.dart';
import 'package:mrixk_client/core/repositories/profile_repository.dart';
import 'package:mrixk_client/core/services/account_reconciliation_service.dart';

void main() {
  late LocalDatabase db;
  late ContactRepository contacts;
  late ConversationRepository convs;
  late MessageRepository messages;
  late ProfileRepository profile;

  setUp(() async {
    db = LocalDatabase();
    await db.initialize();
    contacts = ContactRepository(db);
    convs = ConversationRepository(db);
    messages = MessageRepository(db);
    profile = ProfileRepository(db);

    await contacts.createContact(Contact(
        id: 'usr-1', name: 'Bob', handle: '@bob', avatarUrl: '', statusText: 'x', category: 'B'));
    await contacts.createContact(Contact(
        id: 'usr-2', name: 'Carl', handle: '@carl', avatarUrl: '', statusText: 'x', category: 'C'));
    await convs.createConversation(Conversation(
        id: 'conv_usr-1', title: 'Bob', peerAvatar: '', lastMessage: 'salut', lastMessageTime: '10:00'));
    await convs.createConversation(Conversation(
      id: 'grp-1',
      title: 'Équipe',
      peerAvatar: '',
      isGroup: true,
      groupMembersCount: 2,
      lastMessage: '',
      lastMessageTime: '10:00',
      groupMembers: const [
        GroupMember(id: 'usr-1', name: 'Bob', handle: '@bob', role: 'creator'),
        GroupMember(id: 'usr-2', name: 'Carl', handle: '@carl', role: 'member'),
      ],
    ));
  });

  Future<ReconcileResult> runWith(http.Client client) => http.runWithClient(
        () => AccountReconciliationService.run(
          contacts: contacts,
          conversations: convs,
          messages: messages,
          profile: profile,
        ),
        () => client,
      );

  test('deleted account: contact removed, private chat closed, group updated', () async {
    final client = MockClient((req) async {
      expect(req.url.path, endsWith('/users/status'));
      return http.Response(
        jsonEncode({
          'active': [
            {'id': 'usr-2', 'handle': '@carl', 'display_name': 'Carl', 'status_message': 'x'}
          ],
          'deleted': [
            {'user_id': 'usr-1', 'handle': '@bob', 'display_name': 'Bob'}
          ],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final result = await runWith(client);
    expect(result.handled, 1);

    // contact auto-removed
    expect(contacts.getAllContacts().map((c) => c.id), ['usr-2']);

    // private discussion read-only with system notice
    final direct = convs.getConversationById('conv_usr-1')!;
    expect(direct.isBlocked, isTrue);
    expect(direct.blockedMessage, contains('supprimé son compte'));
    final directMsgs = messages.getMessagesForConversation('conv_usr-1');
    expect(directMsgs.any((m) => m.senderId == 'system' && m.content.contains('supprimé son compte')), isTrue);

    // group: member removed, new creator promoted, notice added
    final group = convs.getConversationById('grp-1')!;
    expect(group.groupMembers.map((m) => m.id), ['usr-2']);
    expect(group.groupMembers.first.isCreator, isTrue);
    expect(group.groupMembersCount, 1);
    expect(messages.getMessagesForConversation('grp-1').any((m) => m.content.contains('retiré du groupe')), isTrue);

    // idempotent: second run does not duplicate notices
    await runWith(client);
    expect(messages.getMessagesForConversation('grp-1').where((m) => m.senderId == 'system').length, 1);
  });

  test('server unreachable: local state is never altered', () async {
    final client = MockClient((_) async => throw Exception('offline'));
    final result = await runWith(client);
    expect(result.handled, 0);
    expect(contacts.getAllContacts().length, 2);
    expect(convs.getConversationById('conv_usr-1')!.isBlocked, isFalse);
    expect(convs.getConversationById('grp-1')!.groupMembers.length, 2);
  });
}
