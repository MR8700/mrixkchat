import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:mrixk_client/core/database/local_database.dart';
import 'package:mrixk_client/core/database/database_seed.dart';
import 'package:mrixk_client/core/models/moment.dart';
import 'package:mrixk_client/core/repositories/assistant_repository.dart';
import 'package:mrixk_client/core/repositories/contact_repository.dart';
import 'package:mrixk_client/core/repositories/conversation_repository.dart';
import 'package:mrixk_client/core/repositories/device_repository.dart';
import 'package:mrixk_client/core/repositories/message_repository.dart';
import 'package:mrixk_client/core/repositories/moment_repository.dart';
import 'package:mrixk_client/core/repositories/profile_repository.dart';
import 'package:mrixk_client/features/assistant/assistant_screen.dart';
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
