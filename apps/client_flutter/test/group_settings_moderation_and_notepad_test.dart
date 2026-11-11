import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mrixk_client/core/database/local_database.dart';
import 'package:mrixk_client/core/models/conversation.dart';
import 'package:mrixk_client/core/models/user_profile.dart';
import 'package:mrixk_client/core/repositories/call_history_repository.dart';
import 'package:mrixk_client/core/repositories/contact_repository.dart';
import 'package:mrixk_client/core/repositories/conversation_repository.dart';
import 'package:mrixk_client/core/repositories/device_repository.dart';
import 'package:mrixk_client/core/repositories/group_note_repository.dart';
import 'package:mrixk_client/core/repositories/message_repository.dart';
import 'package:mrixk_client/core/repositories/profile_repository.dart';
import 'package:mrixk_client/features/discussions/conversation_detail_screen.dart';
import 'package:mrixk_client/features/discussions/conversation_info_screen.dart';
import 'package:mrixk_client/features/discussions/group_notepad_screen.dart';
import 'package:mrixk_client/features/discussions/widgets/group_note_renderer.dart';

void main() {
  group('Group Settings, Moderation & Collaborative Notepad Suite', () {
    late LocalDatabase db;
    late ConversationRepository convRepo;
    late GroupNoteRepository noteRepo;
    late ProfileRepository profileRepo;
    late ContactRepository contactRepo;
    late MessageRepository messageRepo;
    late DeviceRepository deviceRepo;
    late CallHistoryRepository callRepo;

    setUp(() async {
      db = LocalDatabase();
      await db.initialize(usePlatformStorage: false);
      convRepo = ConversationRepository(db);
      noteRepo = GroupNoteRepository(db);
      profileRepo = ProfileRepository(db);
      contactRepo = ContactRepository(db);
      messageRepo = MessageRepository(db);
      deviceRepo = DeviceRepository(db);
      callRepo = CallHistoryRepository(db);

      // Seed current user
      final myProfile = UserProfile(
        id: 'user_richard',
        displayName: 'Richard MARE',
        handle: '@mrixk.richard',
        avatarUrl: '',
        statusMessage: 'Innovateur Souverain',
      );
      await profileRepo.updateProfile(myProfile);
    });

    test('GroupNoteRepository seeds and manages collaborative note and macro components', () async {
      const convId = 'conv_group_test';
      final note = noteRepo.getNote(convId, groupTitle: 'Équipe Alpha');

      expect(note.conversationId, equals(convId));
      expect(note.title, contains('Équipe Alpha'));
      expect(note.content, contains('{{tableau1}}'));
      expect(note.content, contains('{{formule1}}'));
      expect(note.components.containsKey('tableau1'), isTrue);
      expect(note.components['tableau1'], contains('<table'));
      expect(note.components['formule1'], contains('<math>'));
      expect(note.isLocked, isFalse);

      // Lock note
      await noteRepo.setLock(convId, true, 'Richard MARE');
      final lockedNote = noteRepo.getNote(convId);
      expect(lockedNote.isLocked, isTrue);
      expect(lockedNote.lastModifiedBy, equals('Richard MARE'));
    });

    test('Conversation model correctly handles group members, roles and admin permissions', () {
      final members = [
        const GroupMember(id: 'user_richard', name: 'Richard MARE', role: 'creator'),
        const GroupMember(id: 'member_2', name: 'Sophie Valade', role: 'admin'),
        const GroupMember(id: 'member_3', name: 'Marc Delaunay', role: 'member'),
      ];

      final groupConv = Conversation(
        id: 'conv_group_1',
        title: 'Équipe MRixk',
        peerAvatar: '',
        isGroup: true,
        groupMembersCount: 3,
        description: 'Projet d\'innovation souveraine',
        groupMembers: members,
        onlyAdminsCanSendMessages: true,
        onlyAdminsCanEditNotes: true,
        lastMessage: 'Début des travaux',
        lastMessageTime: '10:00',
      );

      expect(groupConv.isUserAdmin('user_richard'), isTrue);
      expect(groupConv.isUserAdmin('member_2'), isTrue);
      expect(groupConv.isUserAdmin('member_3'), isFalse);
      expect(groupConv.onlyAdminsCanSendMessages, isTrue);
      expect(groupConv.onlyAdminsCanEditNotes, isTrue);
    });

    testWidgets('GroupNoteRenderer resolves macros and renders Word text, Math, Tables and Flowcharts', (tester) async {
      const sampleText = '''
# Titre Document
Ceci est un **paragraphe en gras** avec du *texte en italique*.
> Citation sécurisée

{{mon_calcul}}

{{mon_tableau}}

{{mon_flux}}
''';

      final sampleComponents = {
        'mon_calcul': r'''
<math>
x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}
</math>
''',
        'mon_tableau': '''
<table border="1">
  <thead>
    <tr><th>Colonne 1</th><th>Colonne 2</th></tr>
  </thead>
  <tbody>
    <tr><td>Donnée A</td><td>Donnée B</td></tr>
  </tbody>
</table>
''',
        'mon_flux': '''
<diagram type="flowchart">
[Départ] -> [Chiffrement] -> [Succès]
</diagram>
''',
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GroupNoteRenderer(
              content: sampleText,
              components: sampleComponents,
              lineSpacing: 1.6,
              paragraphSpacing: 16.0,
            ),
          ),
        ),
      );

      // Verify Word typography without HTML tags
      expect(find.text('Titre Document'), findsOneWidget);
      expect(find.text('Citation sécurisée'), findsOneWidget);

      // Verify Math resolved from macro
      expect(find.textContaining('Composant Formule : {{mon_calcul}}'), findsOneWidget);
      expect(find.text('x = '), findsOneWidget);

      // Verify Table resolved from macro
      expect(find.text('Tableau : {{mon_tableau}}'), findsOneWidget);
      expect(find.text('Colonne 1'), findsOneWidget);
      expect(find.text('Donnée A'), findsOneWidget);

      // Verify Diagram resolved from macro
      expect(find.text('Organigramme : {{mon_flux}}'), findsOneWidget);
      expect(find.text('Départ'), findsOneWidget);
      expect(find.text('Succès'), findsOneWidget);
    });

    testWidgets('GroupNotepadScreen displays Document, Word Editor, and Component Manager with actions', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final groupConv = Conversation(
        id: 'conv_group_notepad',
        title: 'Groupe Recherche',
        peerAvatar: '',
        isGroup: true,
        groupMembersCount: 2,
        groupMembers: const [
          GroupMember(id: 'user_richard', name: 'Richard MARE', role: 'creator'),
        ],
        lastMessage: 'Ouverture du document',
        lastMessageTime: '11:00',
      );
      await convRepo.createConversation(groupConv);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: convRepo),
            ChangeNotifierProvider.value(value: noteRepo),
            ChangeNotifierProvider.value(value: profileRepo),
            ChangeNotifierProvider.value(value: contactRepo),
            ChangeNotifierProvider.value(value: messageRepo),
          ],
          child: MaterialApp(
            home: GroupNotepadScreen(conversation: groupConv),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check AppBar and Compartments: Document and Éditer
      expect(find.text('Bloc-Note Collaboratif'), findsOneWidget);
      expect(find.text('Document'), findsOneWidget);
      expect(find.text('Éditer'), findsOneWidget);

      // Switch to Éditer compartment
      await tester.tap(find.text('Éditer'));
      await tester.pumpAndSettle();

      // Check Word and Code toggle
      expect(find.text('Word'), findsOneWidget);
      expect(find.text('Code'), findsOneWidget);

      // Check contextual Word toolbar formatting items
      expect(find.text('Police'), findsOneWidget);
      expect(find.text('Titre (H1-H8)'), findsOneWidget);

      // Switch to Code mode
      await tester.tap(find.text('Code'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Source du Document & Définitions'), findsOneWidget);
    });

    testWidgets('ConversationDetailScreen renders in-chat Group Notepad banner for groups', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final groupConv = Conversation(
        id: 'conv_group_chat_banner',
        title: 'Équipe MRixk Core',
        peerAvatar: '',
        isGroup: true,
        groupMembersCount: 3,
        groupMembers: const [
          GroupMember(id: 'user_richard', name: 'Richard MARE', role: 'creator'),
        ],
        lastMessage: 'Bienvenue',
        lastMessageTime: '10:00',
      );
      await convRepo.createConversation(groupConv);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: convRepo),
            ChangeNotifierProvider.value(value: noteRepo),
            ChangeNotifierProvider.value(value: profileRepo),
            ChangeNotifierProvider.value(value: contactRepo),
            ChangeNotifierProvider.value(value: messageRepo),
            ChangeNotifierProvider.value(value: deviceRepo),
            ChangeNotifierProvider.value(value: callRepo),
          ],
          child: MaterialApp(
            home: ConversationDetailScreen(conversation: groupConv),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check that the in-chat banner appears directly inside the conversation
      expect(find.text('Bloc-Note Collaboratif du Groupe'), findsOneWidget);
      expect(find.text('Word léger • Formules & Tableaux sans balises'), findsOneWidget);
      expect(find.text('Ouvrir'), findsOneWidget);
    });

    testWidgets('ConversationInfoScreen renders Group info, Bloc-Note Hero Card and Admin Permissions', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final groupConv = Conversation(
        id: 'conv_group_info_test',
        title: 'Projet Secret MRixk',
        peerAvatar: '',
        isGroup: true,
        description: 'Coordination secrète et souveraine',
        groupMembersCount: 2,
        groupMembers: const [
          GroupMember(id: 'user_richard', name: 'Richard MARE', role: 'creator'),
          GroupMember(id: 'contact_sarah', name: 'Dr. Sarah Connor', role: 'admin'),
        ],
        lastMessage: 'Session démarrée',
        lastMessageTime: '09:00',
      );
      await convRepo.createConversation(groupConv);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: convRepo),
            ChangeNotifierProvider.value(value: noteRepo),
            ChangeNotifierProvider.value(value: profileRepo),
            ChangeNotifierProvider.value(value: contactRepo),
            ChangeNotifierProvider.value(value: messageRepo),
          ],
          child: MaterialApp(
            home: ConversationInfoScreen(conversation: groupConv),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Group title & description
      expect(find.text('Projet Secret MRixk'), findsOneWidget);
      expect(find.text('Coordination secrète et souveraine'), findsOneWidget);

      // Bloc-Note Hero Card
      expect(find.text('Bloc-Note Collaboratif'), findsOneWidget);

      // Admin Permissions section
      expect(find.text('Permissions Administrateur du Groupe'), findsOneWidget);
      expect(find.text('Envoi de messages restreint'), findsOneWidget);
      expect(find.text('Modification des infos du groupe'), findsOneWidget);
      expect(find.text('Édition du Bloc-note collaboratif'), findsOneWidget);

      // Members list & badges
      expect(find.text('👑 Créateur'), findsOneWidget);
      expect(find.text('⭐ Admin'), findsOneWidget);
    });
  });
}
