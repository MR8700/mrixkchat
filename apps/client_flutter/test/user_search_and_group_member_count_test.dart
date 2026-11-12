import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:mrixk_client/core/models/conversation.dart';
import 'package:mrixk_client/core/database/local_database.dart';
import 'package:mrixk_client/core/services/identity_directory_service.dart';
import 'package:mrixk_client/core/repositories/conversation_repository.dart';
import 'package:mrixk_client/core/repositories/profile_repository.dart';
import 'package:mrixk_client/core/repositories/contact_repository.dart';
import 'package:mrixk_client/core/repositories/message_repository.dart';
import 'package:mrixk_client/core/repositories/device_repository.dart';
import 'package:mrixk_client/core/repositories/group_note_repository.dart';
import 'package:mrixk_client/features/discussions/conversation_info_screen.dart';
import 'package:mrixk_client/features/discussions/conversation_detail_screen.dart';

void main() {
  group('Recherche de contact dynamique (@mareaugustin, @isabelle)', () {
    test('IdentityDirectoryService résout dynamiquement les handles saisis', () {
      final aug = IdentityDirectoryService.findUser('@mareaugustin');
      expect(aug, isNotNull);
      expect(aug!.handle, equals('@mareaugustin'));
      expect(aug.name, equals('Mareaugustin'));
      expect(aug.isVerified, isTrue);

      final isa = IdentityDirectoryService.findUser('@isabelle');
      expect(isa, isNotNull);
      expect(isa!.handle, equals('@isabelle'));
      expect(isa.name, equals('Isabelle'));
      expect(isa.isVerified, isTrue);

      final results = IdentityDirectoryService.searchUsers('isabelle');
      expect(results.any((u) => u.handle == '@isabelle'), isTrue);
    });
  });

  group('Comptage exact des membres de groupe (1 membre vs plusieurs appareils)', () {
    test('Conversation.fromJson déduplique les membres par user_id et aligne groupMembersCount', () {
      final json = {
        'id': 'conv_test_signal',
        'title': 'Projet de signal',
        'peerAvatar': '',
        'isGroup': true,
        'groupMembersCount': 3, // Ancienne valeur polluée
        'lastMessage': 'Hello',
        'lastMessageTime': '12:00',
        'groupMembers': [
          {
            'id': 'usr_augustin',
            'user_id': 'usr_augustin',
            'name': 'Augustin',
            'role': 'creator',
            'connectedDevicesCount': 3, // 3 appareils pour 1 seul utilisateur
          },
          {
            'id': 'usr_augustin',
            'user_id': 'usr_augustin',
            'name': 'Augustin',
            'role': 'creator',
            'connectedDevicesCount': 3,
          },
        ],
      };

      final conv = Conversation.fromJson(json);
      expect(conv.groupMembers.length, equals(1)); // Dédupliqué
      expect(conv.totalUserAccountsCount, equals(1));
      expect(conv.groupMembersCount, equals(1));
      expect(conv.totalConnectedDevicesCount, equals(3));
    });

    testWidgets('ConversationInfoScreen affiche "1 membre sécurisé" au singulier', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final db = LocalDatabase();
      if (!db.isInitialized) {
        await db.initialize();
      }

      final convRepo = ConversationRepository(db);
      final profileRepo = ProfileRepository(db);
      final contactRepo = ContactRepository(db);
      final deviceRepo = DeviceRepository(db);
      final noteRepo = GroupNoteRepository(db);

      final group = Conversation(
        id: 'conv_signal_1',
        title: 'Projet de signal',
        peerAvatar: '',
        isGroup: true,
        groupMembersCount: 1,
        lastMessage: 'Discussion créée',
        lastMessageTime: '12:00',
        groupMembers: const [
          GroupMember(
            id: 'user_augustin',
            name: 'Augustin',
            role: 'creator',
            connectedDevicesCount: 3, // 3 appareils mais 1 seul compte
          ),
        ],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: convRepo),
            ChangeNotifierProvider.value(value: profileRepo),
            ChangeNotifierProvider.value(value: contactRepo),
            ChangeNotifierProvider.value(value: deviceRepo),
            ChangeNotifierProvider.value(value: noteRepo),
          ],
          child: MaterialApp(
            home: ConversationInfoScreen(conversation: group),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // En-tête doit afficher fidèlement 1 membre sécurisé au singulier
      expect(find.text('1 membre sécurisé'), findsOneWidget);
      expect(find.text('3 membres sécurisés'), findsNothing);
      expect(find.text('1 membres sécurisés'), findsNothing);

      // Résumé des comptes vs appareils
      expect(find.text('Total des comptes membres'), findsOneWidget);
      expect(find.text('Total des appareils'), findsOneWidget);
    });

    testWidgets('ConversationDetailScreen affiche "1 membre • Chiffré" au singulier', (tester) async {
      final db = LocalDatabase();
      if (!db.isInitialized) {
        await db.initialize();
      }

      final convRepo = ConversationRepository(db);
      final profileRepo = ProfileRepository(db);
      final contactRepo = ContactRepository(db);
      final deviceRepo = DeviceRepository(db);

      final msgRepo = MessageRepository(db);

      final group = Conversation(
        id: 'conv_signal_2',
        title: 'Projet de signal',
        peerAvatar: '',
        isGroup: true,
        groupMembersCount: 1,
        lastMessage: 'Bonjour',
        lastMessageTime: '12:00',
        groupMembers: const [
          GroupMember(
            id: 'user_isabelle',
            name: 'Isabelle',
            role: 'creator',
            connectedDevicesCount: 3,
          ),
        ],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: convRepo),
            ChangeNotifierProvider.value(value: profileRepo),
            ChangeNotifierProvider.value(value: contactRepo),
            ChangeNotifierProvider.value(value: deviceRepo),
            ChangeNotifierProvider.value(value: msgRepo),
          ],
          child: MaterialApp(
            home: ConversationDetailScreen(conversation: group),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1 membre • Chiffré'), findsOneWidget);
      expect(find.text('3 membres • Chiffré'), findsNothing);
    });
  });
}
