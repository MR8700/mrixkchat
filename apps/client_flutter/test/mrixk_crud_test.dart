import 'package:flutter_test/flutter_test.dart';
import 'package:mrixk_client/core/database/database_seed.dart';
import 'package:mrixk_client/core/database/local_database.dart';
import 'package:mrixk_client/core/models/contact.dart';
import 'package:mrixk_client/core/models/device.dart';
import 'package:mrixk_client/core/models/memory_item.dart';
import 'package:mrixk_client/core/models/message.dart';
import 'package:mrixk_client/core/repositories/assistant_repository.dart';
import 'package:mrixk_client/core/repositories/contact_repository.dart';
import 'package:mrixk_client/core/repositories/conversation_repository.dart';
import 'package:mrixk_client/core/repositories/device_repository.dart';
import 'package:mrixk_client/core/repositories/message_repository.dart';
import 'package:mrixk_client/core/repositories/moment_repository.dart';
import 'package:mrixk_client/core/repositories/profile_repository.dart';

void main() {
  group('MRixk Local Database & CRUD Engine Tests', () {
    late LocalDatabase db;

    setUp(() async {
      db = LocalDatabase();
      await db.initialize(onSeed: (database) async {
        await seedTestDataForUnitTestsOnly(database);
      });
    });

    test('Initial Seed populates genuine test data via CRUD', () {
      expect(db.count('users'), greaterThanOrEqualTo(1));
      expect(db.count('devices'), equals(3));
      expect(db.count('contacts'), greaterThanOrEqualTo(5));
      expect(db.count('conversations'), greaterThanOrEqualTo(5));
      expect(db.count('messages'), greaterThanOrEqualTo(4));
      expect(db.count('moments'), greaterThanOrEqualTo(3));
      expect(db.count('memories'), greaterThanOrEqualTo(4));
    });

    test('DeviceRepository enforces strict 3-device limit', () async {
      final devRepo = DeviceRepository(db);
      expect(devRepo.getActiveDevices().length, equals(3));

      // Attempt to authorize 4th device -> MUST BE REJECTED
      final dev4 = Device(
        id: 'dev_4_unauthorized',
        name: 'Tentative 4ème appareil',
        platform: 'Linux',
        status: 'ACTIVE',
        lastSeenText: 'Tentative',
      );
      final allowed = await devRepo.authorizeDevice(dev4);
      expect(allowed, isFalse);
      expect(devRepo.getActiveDevices().length, equals(3));

      // Revoke one device
      await devRepo.revokeDevice('dev_2');
      expect(devRepo.getActiveDevices().length, equals(2));

      // Now 4th device can be authorized within quota
      final allowedNow = await devRepo.authorizeDevice(dev4);
      expect(allowedNow, isTrue);
      expect(devRepo.getActiveDevices().length, equals(3));
    });

    test('ContactRepository CRUD operations', () async {
      final contactRepo = ContactRepository(db);
      final initialCount = contactRepo.getAllContacts().length;

      // Create contact
      final newContact = Contact(
        id: 'contact_test_crud',
        name: 'Élodie Laurent',
        handle: '@elodie.l',
        avatarUrl: '',
        statusText: 'Développement mobile 🚀',
        category: 'E',
      );
      await contactRepo.createContact(newContact);
      expect(contactRepo.getAllContacts().length, equals(initialCount + 1));

      // Search contact
      final searchResults = contactRepo.searchContacts('Élodie');
      expect(searchResults.length, equals(1));
      expect(searchResults.first.name, equals('Élodie Laurent'));

      // Toggle favorite
      expect(searchResults.first.isFavorite, isFalse);
      await contactRepo.toggleFavorite('contact_test_crud');
      final updated = contactRepo.getContactById('contact_test_crud');
      expect(updated!.isFavorite, isTrue);

      // Block contact temporarily (24h)
      await contactRepo.blockContact('contact_test_crud', duration: '24 heures');
      final blocked = contactRepo.getContactById('contact_test_crud');
      expect(blocked!.isBlocked, isTrue);
      expect(blocked.blockedUntil, equals('24 heures'));

      // Verify excluded from search
      final blockedSearchResults = contactRepo.searchContacts('Test User');
      expect(blockedSearchResults.any((c) => c.id == 'contact_test_crud'), isFalse);

      // Unblock contact
      await contactRepo.unblockContact('contact_test_crud');
      final unblocked = contactRepo.getContactById('contact_test_crud');
      expect(unblocked!.isBlocked, isFalse);

      // Batch block
      await contactRepo.blockMultipleContacts(['contact_test_crud'], duration: 'Définitif');
      expect(contactRepo.getContactById('contact_test_crud')!.isBlocked, isTrue);

      // Delete contact
      await contactRepo.deleteContact('contact_test_crud');
      expect(contactRepo.getContactById('contact_test_crud'), isNull);
    });

    test('ConversationRepository filter and update CRUD operations', () async {
      final convRepo = ConversationRepository(db);

      // Filter all
      final all = convRepo.getFilteredConversations(filter: 'Tous');
      expect(all.length, greaterThanOrEqualTo(5));

      // Filter unread
      final unread = convRepo.getFilteredConversations(filter: 'Non lus');
      expect(unread.any((c) => c.title == 'Sophie Valade'), isTrue);

      // Filter groups
      final groups = convRepo.getFilteredConversations(filter: 'Groupes');
      expect(groups.any((c) => c.isGroup), isTrue);

      // Mark as read
      await convRepo.markAsRead('conv_sophie');
      final sophieUpdated = convRepo.getConversationById('conv_sophie');
      expect(sophieUpdated!.unreadCount, equals(0));

      // Update last message
      await convRepo.updateLastMessage(
        conversationId: 'conv_sophie',
        message: 'Nouveau message CRUD',
        time: '12:00',
      );
      final refreshed = convRepo.getConversationById('conv_sophie');
      expect(refreshed!.lastMessage, equals('Nouveau message CRUD'));
    });

    test('MessageRepository message sending, reactions and transcription', () async {
      final msgRepo = MessageRepository(db);
      final initialMessages = msgRepo.getMessagesForConversation('conv_sophie');
      expect(initialMessages.length, greaterThanOrEqualTo(4));

      // Check voice message and transcription
      final voiceMsg = initialMessages.firstWhere((m) => m.type == MessageType.voice);
      expect(voiceMsg.voiceDuration, equals('1:15'));
      expect(voiceMsg.voiceTranscription, contains('validations sont terminées'));

      // Send new message
      final newMsg = Message(
        id: 'msg_test_crud',
        conversationId: 'conv_sophie',
        senderId: 'user_richard',
        senderName: 'Richard MARE',
        senderAvatar: '',
        type: MessageType.text,
        content: 'Test message CRUD réussi !',
        time: '12:05',
        isOutgoing: true,
      );
      await msgRepo.sendMessage(newMsg);

      final updatedMessages = msgRepo.getMessagesForConversation('conv_sophie');
      expect(updatedMessages.length, equals(initialMessages.length + 1));

      // Toggle emoji reaction
      await msgRepo.toggleReaction('msg_test_crud', '🚀');
      final fetchedMsg = msgRepo.getMessageById('msg_test_crud');
      expect(fetchedMsg!.reactions['🚀'], equals(1));
    });

    test('MomentRepository like toggle and reactions', () async {
      final momentRepo = MomentRepository(db);
      final moments = momentRepo.getAllMoments();
      expect(moments.length, greaterThanOrEqualTo(3));

      final firstMoment = moments.first;
      final initialLikes = firstMoment.heartCount;

      // Toggle like
      await momentRepo.toggleLike(firstMoment.id);
      final likedMoment = momentRepo.getMomentById(firstMoment.id);
      expect(likedMoment!.userLiked, isTrue);
      expect(likedMoment.heartCount, equals(initialLikes + 1));

      // Untoggle like (verifies toggle off / no infinite increment bug)
      await momentRepo.toggleLike(firstMoment.id);
      final unlikedMoment = momentRepo.getMomentById(firstMoment.id);
      expect(unlikedMoment!.userLiked, isFalse);
      expect(unlikedMoment.heartCount, equals(initialLikes));

      // Test reaction toggle (mood)
      final initialMood = unlikedMoment.moodCount;
      await momentRepo.toggleReaction(firstMoment.id, 'mood');
      expect(momentRepo.getMomentById(firstMoment.id)!.moodCount, equals(initialMood + 1));
      // Tapping again toggles off
      await momentRepo.toggleReaction(firstMoment.id, 'mood');
      expect(momentRepo.getMomentById(firstMoment.id)!.moodCount, equals(initialMood));

      // Test adding comment and comment reaction
      await momentRepo.addComment(firstMoment.id, 'Superbe moment partagé !');
      final commentedMoment = momentRepo.getMomentById(firstMoment.id)!;
      expect(commentedMoment.comments.length, greaterThanOrEqualTo(1));
      final commentId = commentedMoment.comments.last.id;
      await momentRepo.toggleCommentLike(firstMoment.id, commentId);
      final likedCommentMoment = momentRepo.getMomentById(firstMoment.id)!;
      expect(likedCommentMoment.comments.last.userLiked, isTrue);
    });

    test('AssistantRepository local cognitive memory and semantic queries', () async {
      final assistantRepo = AssistantRepository(db);

      // Verify initial memory count
      expect(assistantRepo.getAllMemories().length, greaterThanOrEqualTo(4));

      // Ask question about devices/security -> should retrieve sovereign security state
      await assistantRepo.askAssistant('Quel est l\'état de sécurité de mes appareils ?');
      final history = assistantRepo.getAssistantMessages();
      final lastMsg = history.last;
      expect(lastMsg.text, contains('sécurité de vos appareils'));
      expect(lastMsg.sourceTitle, equals('Sécurité & Terminaux'));

      // Toggle private learning
      assistantRepo.togglePrivateLearning(false);
      expect(assistantRepo.isPrivateLearningActive, isFalse);

      // Add new memory
      final newMem = MemoryItem(
        id: 'mem_crud_test',
        title: 'Nouveau rappel de projet',
        detail: 'Confidentialité 100% respectée',
        category: 'Projet',
        createdAt: 'Aujourd\'hui',
      );
      await assistantRepo.addMemory(newMem);
      expect(assistantRepo.getAllMemories().length, greaterThanOrEqualTo(5));
    });

    test('ProfileRepository updates profile and theme mode', () async {
      final profileRepo = ProfileRepository(db);
      final initialProfile = profileRepo.getProfile();
      expect(initialProfile.displayName, equals('Richard MARE'));

      // Update status
      await profileRepo.updateStatus('En pleine création !');
      expect(profileRepo.getProfile().statusMessage, equals('En pleine création !'));

      // Toggle notifications
      await profileRepo.toggleNotifications(false);
      expect(profileRepo.getProfile().notificationsEnabled, isFalse);

      // Switch theme mode
      await profileRepo.setThemeMode('Nuit');
      expect(profileRepo.getProfile().themeMode, equals('Nuit'));
    });
  });
}
