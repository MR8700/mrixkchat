import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mrixk_client/core/database/local_database.dart';
import 'package:mrixk_client/core/models/conversation.dart';
import 'package:mrixk_client/core/models/user_profile.dart';
import 'package:mrixk_client/core/repositories/conversation_repository.dart';
import 'package:mrixk_client/core/repositories/profile_repository.dart';
import 'package:mrixk_client/core/repositories/contact_repository.dart';
import 'package:mrixk_client/core/repositories/group_note_repository.dart';
import 'package:mrixk_client/features/discussions/conversation_info_screen.dart';

void main() {
  group('Règle Fondamentale MRixk : user_id comme Référence Unique d\'Identité', () {
    late LocalDatabase db;
    late ConversationRepository convRepo;
    late ProfileRepository profileRepo;
    late ContactRepository contactRepo;
    late GroupNoteRepository noteRepo;

    setUp(() async {
      db = LocalDatabase();
      await db.initialize(usePlatformStorage: false);
      convRepo = ConversationRepository(db);
      profileRepo = ProfileRepository(db);
      contactRepo = ContactRepository(db);
      noteRepo = GroupNoteRepository(db);

      await profileRepo.updateProfile(
        UserProfile(
          id: 'user_richard',
          displayName: 'Richard MARE',
          handle: '@mrixk.richard',
          avatarUrl: '',
          statusMessage: 'Innovateur Souverain',
        ),
      );
    });
    test('GroupMember : user_id, rôles et appareils connectés (1 à 3)', () {
      final member1 = GroupMember(
        id: 'USR-001',
        name: 'Richard',
        handle: '@richard',
        role: 'admin',
        connectedDevicesCount: 3,
      );

      expect(member1.userId, equals('USR-001'));
      expect(member1.roleLabel, equals('Administrateur'));
      expect(member1.connectedDevicesCount, equals(3));
      expect(member1.deviceCountLabel, equals('3 appareils connectés'));

      final member2 = GroupMember(
        id: 'USR-002',
        name: 'Aïcha',
        handle: '@aicha',
        role: 'member',
        connectedDevicesCount: 1,
      );

      expect(member2.userId, equals('USR-002'));
      expect(member2.roleLabel, equals('Membre'));
      expect(member2.connectedDevicesCount, equals(1));
      expect(member2.deviceCountLabel, equals('1 appareil connecté'));

      final member3 = GroupMember(
        id: 'USR-000',
        name: 'Directeur',
        handle: '@directeur',
        role: 'creator',
        connectedDevicesCount: 2,
      );
      expect(member3.roleLabel, equals('Créateur'));
      expect(member3.deviceCountLabel, equals('2 appareils connectés'));
    });

    test('Sérialisation JSON compatible user_id et id', () {
      final member = GroupMember(
        id: 'USR-777',
        name: 'Marc',
        handle: '@marc',
        role: 'admin',
        connectedDevicesCount: 2,
      );

      final json = member.toJson();
      expect(json['id'], equals('USR-777'));
      expect(json['user_id'], equals('USR-777'));
      expect(json['connectedDevicesCount'], equals(2));

      // Desérialisation depuis 'user_id'
      final fromUserId = GroupMember.fromJson({
        'user_id': 'USR-888',
        'name': 'Sophie',
        'role': 'member',
        'connectedDevicesCount': 3,
      });
      expect(fromUserId.id, equals('USR-888'));
      expect(fromUserId.userId, equals('USR-888'));
      expect(fromUserId.connectedDevicesCount, equals(3));
    });

    test('Conversation : Calcul exact des comptes membres vs nombre total d\'appareils', () {
      final members = [
        GroupMember(id: 'USR-001', name: 'Richard', role: 'creator', connectedDevicesCount: 3), // PC, Phone, Tablet
        GroupMember(id: 'USR-002', name: 'Sophie', role: 'admin', connectedDevicesCount: 2),   // PC, Phone
        GroupMember(id: 'USR-003', name: 'Marc', role: 'member', connectedDevicesCount: 1),     // Phone
      ];

      final conv = Conversation(
        id: 'group-100',
        title: 'Équipe Projet MRixk',
        peerAvatar: '',
        lastMessage: 'Bonjour',
        lastMessageTime: '10:00',
        isGroup: true,
        groupMembers: members,
        onlyAdminsCanAddMembers: true,
        onlyAdminsCanEditGroupInfo: true,
        onlyAdminsCanSendMessages: false,
        onlyAdminsCanEditNotes: false,
      );

      // 3 comptes d'utilisateurs distincts
      expect(conv.totalUserAccountsCount, equals(3));
      expect(conv.groupMembers.length, equals(3));

      // 3 + 2 + 1 = 6 appareils connectés au total
      expect(conv.totalConnectedDevicesCount, equals(6));

      // Vérification : les 3 appareils de Richard ne font JAMAIS 3 membres distincts
      final richardMembers = conv.groupMembers.where((m) => m.userId == 'USR-001').toList();
      expect(richardMembers.length, equals(1));
    });

    test('Idempotence et unicité de l\'adhésion dans le groupe', () {
      final members = <GroupMember>[
        GroupMember(id: 'USR-001', name: 'Richard', role: 'creator', connectedDevicesCount: 3),
        GroupMember(id: 'USR-002', name: 'Sophie', role: 'admin', connectedDevicesCount: 2),
      ];

      final existingUserIds = members.map((m) => m.userId).toSet();

      // Tentative de réinvitation ou réadhésion de Richard depuis un 2ème ou 3ème appareil
      const newDeviceJoiningUserId = 'USR-001';
      final isAlreadyMember = existingUserIds.contains(newDeviceJoiningUserId);
      expect(isAlreadyMember, isTrue, reason: 'L\'utilisateur existe déjà via son user_id unique');

      // Un nouvel utilisateur avec un user_id inédit peut être ajouté
      const newUserId = 'USR-004';
      final isNewMemberAlready = existingUserIds.contains(newUserId);
      expect(isNewMemberAlready, isFalse);

      if (!isNewMemberAlready) {
        members.add(GroupMember(id: newUserId, name: 'Amine', connectedDevicesCount: 1));
      }
      expect(members.length, equals(3));
      expect(members.map((m) => m.userId).toSet().length, equals(3));
    });

    testWidgets('Rendu UI ConversationInfoScreen : Membres, appareils et règle d\'identité', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final testConv = Conversation(
        id: 'group_test_1',
        title: 'Groupe Recherche MRixk',
        peerAvatar: '',
        lastMessage: 'Synchronisé',
        lastMessageTime: '10:48',
        isGroup: true,
        groupMembers: [
          GroupMember(
            id: 'user_richard',
            name: 'Richard',
            handle: '@richard',
            role: 'creator',
            connectedDevicesCount: 3,
          ),
          GroupMember(
            id: 'user_sophie',
            name: 'Sophie',
            handle: '@sophie',
            role: 'admin',
            connectedDevicesCount: 2,
          ),
          GroupMember(
            id: 'user_marc',
            name: 'Marc',
            handle: '@marc',
            role: 'member',
            connectedDevicesCount: 1,
          ),
        ],
        onlyAdminsCanAddMembers: false,
        onlyAdminsCanEditGroupInfo: false,
        onlyAdminsCanSendMessages: false,
        onlyAdminsCanEditNotes: false,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: convRepo),
            ChangeNotifierProvider.value(value: profileRepo),
            ChangeNotifierProvider.value(value: contactRepo),
            ChangeNotifierProvider.value(value: noteRepo),
          ],
          child: MaterialApp(
            home: ConversationInfoScreen(conversation: testConv),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Vérifier le titre de la liste des membres
      expect(find.text('Membres du groupe (3)'), findsOneWidget);

      // Vérifier les sous-titres détaillant rôle et appareils connectés
      expect(find.text('Créateur · 3 appareils connectés'), findsOneWidget);
      expect(find.text('Administrateur · 2 appareils connectés'), findsOneWidget);
      expect(find.text('Membre · 1 appareil connecté'), findsOneWidget);

      // Vérifier le bloc de résumé des comptes vs appareils
      expect(find.text('Total des comptes membres'), findsOneWidget);
      expect(find.text('3'), findsOneWidget); // 3 comptes membres
      expect(find.text('Total des appareils'), findsOneWidget);
      expect(find.text('6'), findsOneWidget); // 6 appareils au total (3 + 2 + 1)

      // Vérifier la mention de la règle MRixk
      expect(
        find.text(
          'Un utilisateur = une identité unique (user_id). Les appareils autorisés sont rattachés au compte et ne constituent jamais des membres distincts.',
        ),
        findsOneWidget,
      );
    });
  });
}
