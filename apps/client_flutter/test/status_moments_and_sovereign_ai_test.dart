import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:mrixk_client/core/database/local_database.dart';
import 'package:mrixk_client/core/database/database_seed.dart';
import 'package:mrixk_client/core/models/conversation.dart';
import 'package:mrixk_client/core/models/moment.dart';
import 'package:mrixk_client/core/repositories/assistant_repository.dart';
import 'package:mrixk_client/core/repositories/contact_repository.dart';
import 'package:mrixk_client/core/repositories/conversation_repository.dart';
import 'package:mrixk_client/core/repositories/device_repository.dart';
import 'package:mrixk_client/core/repositories/group_note_repository.dart';
import 'package:mrixk_client/core/repositories/message_repository.dart';
import 'package:mrixk_client/core/repositories/moment_repository.dart';
import 'package:mrixk_client/core/repositories/profile_repository.dart';
import 'package:mrixk_client/features/assistant/assistant_screen.dart';
import 'package:mrixk_client/features/discussions/conversation_info_screen.dart';
import 'package:mrixk_client/features/discussions/discussions_screen.dart';
import 'package:mrixk_client/features/moments/widgets/moment_story_viewer_dialog.dart';
import 'package:mrixk_client/shared/widgets/app_avatar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<LocalDatabase> resetDb() async {
    final db = LocalDatabase();
    if (!db.isInitialized) {
      await db.initialize();
    }
    await db.clearAll();
    await seedCleanProductionDatabase(db);
    return db;
  }

  group('Status / Moments & Story Viewer Tests', () {
    testWidgets('AppAvatar with isClickable: false does not open enlarged dialog on tap', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AppAvatar(
                name: 'Alice',
                isClickable: false,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(AppAvatar));
      await tester.pumpAndSettle();

      // No dialog opened
      expect(find.byType(Dialog), findsNothing);
    });

    testWidgets('AppAvatar with isClickable: true opens enlarged dialog on tap', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AppAvatar(
                name: 'Alice',
                isClickable: true,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(AppAvatar));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsOneWidget);
    });

    testWidgets('MomentStoryViewerDialog renders author info, content, reactions and progress', (tester) async {
      final db = await resetDb();
      final moment = Moment(
        id: 'moment_test_1',
        authorId: 'author_1',
        authorName: 'Dr. Sarah Connor',
        authorAvatar: '',
        authorBadge: 'verified',
        type: MomentType.quote,
        timeAgo: 'Il y a 10 min',
        caption: 'La technologie souveraine garantit notre liberté numérique.',
        location: 'Paris, France',
        heartCount: 3,
        moodCount: 2,
        celebrationCount: 1,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => MomentRepository(db)),
          ],
          child: MaterialApp(
            home: MomentStoryViewerDialog(initialMoment: moment),
          ),
        ),
      );

      expect(find.text('Dr. Sarah Connor'), findsOneWidget);
      expect(find.textContaining('Il y a 10 min'), findsOneWidget);
      expect(find.text('Paris, France'), findsOneWidget);
      expect(find.text('La technologie souveraine garantit notre liberté numérique.'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('DiscussionsScreen tapping contact moment opens MomentStoryViewerDialog', (tester) async {
      final db = await resetDb();
      final momentRepo = MomentRepository(db);
      final testMoment = Moment(
        id: 'm_sarah_1',
        authorId: 'contact_sarah',
        authorName: 'Dr. Sarah Connor',
        authorAvatar: '',
        authorBadge: 'verified',
        type: MomentType.quote,
        timeAgo: 'Il y a 5 min',
        caption: 'Chiffrement quantique validé en laboratoire.',
      );
      await momentRepo.createMoment(testMoment);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ContactRepository(db)),
            ChangeNotifierProvider(create: (_) => ConversationRepository(db)),
            ChangeNotifierProvider(create: (_) => MessageRepository(db)),
            ChangeNotifierProvider.value(value: momentRepo),
            ChangeNotifierProvider(create: (_) => DeviceRepository(db)),
            ChangeNotifierProvider(create: (_) => AssistantRepository(db)),
            ChangeNotifierProvider(create: (_) => ProfileRepository(db)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: DiscussionsScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find Sarah's moment circle in Moments du jour
      expect(find.text('Dr. Sarah Connor'), findsWidgets);
      await tester.tap(find.text('Dr. Sarah Connor').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify MomentStoryViewerDialog opened
      expect(find.byType(MomentStoryViewerDialog), findsOneWidget);
      expect(find.text('Chiffrement quantique validé en laboratoire.'), findsOneWidget);

      // Close dialog cleanly to dispose animation controller
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
    });

    testWidgets('MomentStoryViewerDialog plays multiple moments sequentially with segmented bars', (tester) async {
      final db = await resetDb();
      final moments = [
        Moment(
          id: 'moment_seq_1',
          authorId: 'author_sarah',
          authorName: 'Sarah Connor',
          authorAvatar: '',
          type: MomentType.quote,
          timeAgo: 'Il y a 5 min',
          caption: 'Premier statut souverain',
        ),
        Moment(
          id: 'moment_seq_2',
          authorId: 'author_sarah',
          authorName: 'Sarah Connor',
          authorAvatar: '',
          type: MomentType.quote,
          timeAgo: 'Il y a 2 min',
          caption: 'Deuxième statut souverain',
        ),
      ];

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => MomentRepository(db)),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (ctx) => Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: ctx,
                      builder: (_) => MomentStoryViewerDialog(moments: moments, initialIndex: 0),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify segmented progress indicators (2 segments for 2 moments)
      expect(find.byType(LinearProgressIndicator), findsNWidgets(2));
      expect(find.text('Premier statut souverain'), findsOneWidget);
      expect(find.text('Deuxième statut souverain'), findsNothing);

      // Tap right area to advance to next story immediately
      await tester.tapAt(const Offset(600, 300));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Now on second story
      expect(find.text('Deuxième statut souverain'), findsOneWidget);
      expect(find.text('Premier statut souverain'), findsNothing);

      // Tap right area again on the last story -> closes dialog cleanly
      await tester.tapAt(const Offset(600, 300));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byType(MomentStoryViewerDialog), findsNothing);
    });

    testWidgets('Groupe créé avec 1 membre et 1 appareil affiche fidèlement 1 compte et 1 appareil', (tester) async {
      tester.view.physicalSize = const Size(1080, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final db = await resetDb();
      final convRepo = ConversationRepository(db);
      final profileRepo = ProfileRepository(db);
      final contactRepo = ContactRepository(db);
      final deviceRepo = DeviceRepository(db);

      // Group with creator only
      final creator = GroupMember(
        id: 'user_richard',
        name: 'Richard MARE (Moi)',
        role: 'creator',
        connectedDevicesCount: 1,
      );
      final newGroup = Conversation(
        id: 'group_single_member_test',
        title: 'Nouveau Groupe Lab',
        peerAvatar: '',
        lastMessage: 'Discussion créée',
        lastMessageTime: '10:00',
        isGroup: true,
        groupMembersCount: 1,
        groupMembers: [creator],
      );
      await convRepo.createConversation(newGroup);

      // Verify conversation model computed properties
      expect(newGroup.totalUserAccountsCount, equals(1));
      expect(newGroup.totalConnectedDevicesCount, equals(1));

      // Verify UI rendering in ConversationInfoScreen
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: convRepo),
            ChangeNotifierProvider.value(value: profileRepo),
            ChangeNotifierProvider.value(value: contactRepo),
            ChangeNotifierProvider.value(value: deviceRepo),
            ChangeNotifierProvider(create: (_) => GroupNoteRepository(db)),
          ],
          child: MaterialApp(
            home: ConversationInfoScreen(conversation: newGroup),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Membres du groupe (1)'), findsOneWidget);
      expect(find.text('Total des comptes membres'), findsOneWidget);
      expect(find.text('Total des appareils'), findsOneWidget);
      // Both numbers must be 1, never 3
      expect(find.text('1'), findsNWidgets(2));
      expect(find.text('3'), findsNothing);
    });
  });

  group('Sovereign AI Engine Tests', () {
    test('AssistantRepository initial message list is empty (no mock data)', () async {
      final db = await resetDb();
      final assistantRepo = AssistantRepository(db);
      final messages = assistantRepo.getAssistantMessages();
      expect(messages, isEmpty);
    });

    test('AssistantRepository askAssistant queries real devices and answers authentically', () async {
      final db = await resetDb();
      final assistantRepo = AssistantRepository(db);

      await assistantRepo.askAssistant('Quel est l\'état de sécurité de mes appareils ?');
      final messages = assistantRepo.getAssistantMessages();

      expect(messages.length, equals(2));
      final userMsg = messages[0];
      final botMsg = messages[1];

      expect(userMsg.isUser, isTrue);
      expect(botMsg.isUser, isFalse);
      expect(botMsg.sourceTitle, equals('Sécurité & Terminaux'));
      expect(botMsg.text, contains('Téléphone Principal'));
      expect(botMsg.text, isNot(contains('#CTR-2024-88B')));
      expect(botMsg.text, isNot(contains('Sophie')));
    });

    test('AssistantRepository askAssistant queries real contacts and answers authentically', () async {
      final db = await resetDb();
      final assistantRepo = AssistantRepository(db);

      await assistantRepo.askAssistant('Qui sont mes contacts ?');
      final messages = assistantRepo.getAssistantMessages();

      expect(messages.length, equals(2));
      final botMsg = messages[1];
      expect(botMsg.sourceTitle, equals('Carnet d\'adresses chiffré'));
      expect(botMsg.text, contains('Dr. Sarah Connor'));
      expect(botMsg.text, contains('@sarah.connor'));
    });

    testWidgets('AssistantScreen displays sovereign welcome card when no messages exist', (tester) async {
      final db = await resetDb();
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AssistantRepository(db)),
          ],
          child: const MaterialApp(
            home: AssistantScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Assistant Privé & Souverain'), findsOneWidget);
      expect(find.text('Résumer mes échanges'), findsOneWidget);
      expect(find.text('Rechercher un document'), findsOneWidget);
      expect(find.text('Rédiger un message'), findsOneWidget);
      expect(find.text('Sécurité & Appareils'), findsOneWidget);
    });
  });
}
