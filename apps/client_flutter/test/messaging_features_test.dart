import 'package:flutter_test/flutter_test.dart';
import 'package:mrixk_client/core/database/database_seed.dart';
import 'package:mrixk_client/core/database/local_database.dart';
import 'package:mrixk_client/core/models/message.dart';
import 'package:mrixk_client/core/repositories/conversation_repository.dart';
import 'package:mrixk_client/core/repositories/message_repository.dart';

void main() {
  group('MRixk Messaging Core Features & Innovations Tests', () {
    late LocalDatabase db;
    late ConversationRepository convRepo;
    late MessageRepository msgRepo;

    setUp(() async {
      db = LocalDatabase();
      await db.initialize(onSeed: (database) async {
        await seedTestDataForUnitTestsOnly(database);
      });
      convRepo = ConversationRepository(db);
      msgRepo = MessageRepository(db);
    });

    test('Swipe to Archive and Unarchive conversations', () async {
      final initialArchived = convRepo.getFilteredConversations(filter: 'Archivés');
      expect(initialArchived.length, equals(0));

      final allConvs = convRepo.getFilteredConversations(filter: 'Tous');
      final firstConv = allConvs.first;

      // 1. Swipe right to archive
      await convRepo.toggleArchive(firstConv.id);

      final afterArchive = convRepo.getFilteredConversations(filter: 'Archivés');
      expect(afterArchive.length, equals(1));
      expect(afterArchive.first.id, equals(firstConv.id));

      final activeConvs = convRepo.getFilteredConversations(filter: 'Tous');
      expect(activeConvs.any((c) => c.id == firstConv.id), isFalse);

      // 2. Swipe right again to unarchive
      await convRepo.toggleArchive(firstConv.id);
      expect(convRepo.getFilteredConversations(filter: 'Archivés').length, equals(0));
      expect(convRepo.getFilteredConversations(filter: 'Tous').any((c) => c.id == firstConv.id), isTrue);
    });

    test('Swipe to Delete a conversation', () async {
      final initialCount = convRepo.getAllConversations().length;
      await convRepo.deleteConversation('conv_idriss');

      expect(convRepo.getAllConversations().length, equals(initialCount - 1));
      expect(convRepo.getConversationById('conv_idriss'), isNull);
    });

    test('Message Editing (isEdited flag & content update)', () async {
      final msg = Message(
        id: 'msg_edit_test',
        conversationId: 'conv_sophie',
        senderId: 'user_richard',
        senderName: 'Richard MARE',
        senderAvatar: '',
        type: MessageType.text,
        content: 'Texte avant modification',
        time: '14:00',
        isOutgoing: true,
      );
      await msgRepo.sendMessage(msg);

      // Edit message
      await msgRepo.editMessage('msg_edit_test', 'Texte corrigé et vérifié');

      final updated = msgRepo.getMessageById('msg_edit_test');
      expect(updated, isNotNull);
      expect(updated!.content, equals('Texte corrigé et vérifié'));
      expect(updated.isEdited, isTrue);
    });

    test('View-Once Message (isViewOnce flag & auto-destruction upon opening)', () async {
      final viewOnceMsg = Message(
        id: 'msg_view_once_test',
        conversationId: 'conv_sophie',
        senderId: 'user_richard',
        senderName: 'Richard MARE',
        senderAvatar: '',
        type: MessageType.text,
        content: 'Secret confidentiel éphémère 🔒',
        time: '14:05',
        isOutgoing: true,
        isViewOnce: true,
      );
      await msgRepo.sendMessage(viewOnceMsg);

      final stored = msgRepo.getMessageById('msg_view_once_test');
      expect(stored!.isViewOnce, isTrue);
      expect(stored.isViewOnceOpened, isFalse);
      expect(stored.content, equals('Secret confidentiel éphémère 🔒'));

      // Destinataire ou utilisateur ouvre la vue unique -> Auto-destruction
      await msgRepo.openViewOnceMessage('msg_view_once_test');

      final destroyed = msgRepo.getMessageById('msg_view_once_test');
      expect(destroyed!.isViewOnceOpened, isTrue);
      expect(destroyed.content, equals('Vue unique expirée'));
      expect(destroyed.imageUri, isNull);
    });

    test('Multi-selection delete for everyone WITH mandatory reason', () async {
      final msg1 = Message(
        id: 'msg_del_1',
        conversationId: 'conv_sophie',
        senderId: 'user_richard',
        senderName: 'Richard MARE',
        senderAvatar: '',
        type: MessageType.text,
        content: 'Message confidentiel à supprimer 1',
        time: '14:10',
        isOutgoing: true,
      );
      final msg2 = Message(
        id: 'msg_del_2',
        conversationId: 'conv_sophie',
        senderId: 'user_richard',
        senderName: 'Richard MARE',
        senderAvatar: '',
        type: MessageType.text,
        content: 'Message confidentiel à supprimer 2',
        time: '14:11',
        isOutgoing: true,
      );
      await msgRepo.sendMessage(msg1);
      await msgRepo.sendMessage(msg2);

      // Delete multiple messages for everyone with mandatory motif
      await msgRepo.deleteMultipleMessages(
        ['msg_del_1', 'msg_del_2'],
        forEveryone: true,
        reason: 'Information confidentielle ou sensible',
        deletedByName: 'Richard MARE',
      );

      final res1 = msgRepo.getMessageById('msg_del_1');
      final res2 = msgRepo.getMessageById('msg_del_2');

      expect(res1!.isDeletedForEveryone, isTrue);
      expect(res1.deletionReason, equals('Information confidentielle ou sensible'));
      expect(res1.deletedByName, equals('Richard MARE'));

      expect(res2!.isDeletedForEveryone, isTrue);
      expect(res2.deletionReason, equals('Information confidentielle ou sensible'));
    });

    test('Multi-selection delete for ME (local removal)', () async {
      final msg = Message(
        id: 'msg_del_forme',
        conversationId: 'conv_sophie',
        senderId: 'user_richard',
        senderName: 'Richard MARE',
        senderAvatar: '',
        type: MessageType.text,
        content: 'Message à effacer localement',
        time: '14:15',
        isOutgoing: true,
      );
      await msgRepo.sendMessage(msg);

      await msgRepo.deleteMultipleMessages(['msg_del_forme'], forEveryone: false);
      expect(msgRepo.getMessageById('msg_del_forme'), isNull);
    });

    test('Message forwarding between conversations', () async {
      final original = Message(
        id: 'msg_orig_fwd',
        conversationId: 'conv_sophie',
        senderId: 'user_sophie',
        senderName: 'Sophie Valade',
        senderAvatar: '',
        type: MessageType.text,
        content: 'Information stratégique à partager',
        time: '14:20',
      );
      await msgRepo.sendMessage(original);

      // Forward to Idriss
      await msgRepo.forwardMessage(
        'msg_orig_fwd',
        'conv_idriss',
        senderId: 'user_richard',
        senderName: 'Richard MARE',
        senderAvatar: '',
      );

      final idrissMessages = msgRepo.getMessagesForConversation('conv_idriss');
      final forwarded = idrissMessages.firstWhere((m) => m.content == 'Information stratégique à partager');

      expect(forwarded.isForwarded, isTrue);
      expect(forwarded.conversationId, equals('conv_idriss'));
      expect(forwarded.senderName, equals('Richard MARE'));
    });

    test('High quality emoji reactions toggle and count', () async {
      final msg = Message(
        id: 'msg_emoji_test',
        conversationId: 'conv_sophie',
        senderId: 'user_richard',
        senderName: 'Richard MARE',
        senderAvatar: '',
        type: MessageType.text,
        content: 'Innovation E2EE locale 🚀',
        time: '14:25',
        isOutgoing: true,
      );
      await msgRepo.sendMessage(msg);

      // Add reaction
      await msgRepo.toggleReaction('msg_emoji_test', '🔥');
      expect(msgRepo.getMessageById('msg_emoji_test')!.reactions['🔥'], equals(1));

      // Add another reaction
      await msgRepo.toggleReaction('msg_emoji_test', '🔥');
      expect(msgRepo.getMessageById('msg_emoji_test')!.reactions['🔥'], equals(2));

      await msgRepo.toggleReaction('msg_emoji_test', '✨');
      expect(msgRepo.getMessageById('msg_emoji_test')!.reactions['✨'], equals(1));
    });

    test('Live camera photo capture & HD attributes', () async {
      final photoMsg = Message(
        id: 'msg_cam_test',
        conversationId: 'conv_sophie',
        senderId: 'user_richard',
        senderName: 'Richard MARE',
        senderAvatar: '',
        type: MessageType.image,
        content: 'Photo capturée en direct 📷 (Haute Définition)',
        time: '14:30',
        isOutgoing: true,
        imageUri: 'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=600',
      );
      await msgRepo.sendMessage(photoMsg);

      final stored = msgRepo.getMessageById('msg_cam_test');
      expect(stored!.type, equals(MessageType.image));
      expect(stored.imageUri, contains('unsplash.com'));
      expect(stored.content, contains('Photo capturée en direct'));
    });
  });
}
