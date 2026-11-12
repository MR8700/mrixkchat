import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mrixk_client/core/database/database_seed.dart';
import 'package:mrixk_client/core/database/local_database.dart';
import 'package:mrixk_client/core/models/conversation.dart';
import 'package:mrixk_client/core/repositories/conversation_repository.dart';
import 'package:mrixk_client/core/repositories/device_repository.dart';
import 'package:mrixk_client/core/repositories/message_repository.dart';
import 'package:mrixk_client/core/repositories/profile_repository.dart';
import 'package:mrixk_client/core/services/real_media_service.dart';
import 'package:mrixk_client/core/theme/app_theme.dart';
import 'package:mrixk_client/features/discussions/conversation_detail_screen.dart';
import 'package:provider/provider.dart';

void main() {
  group('Media, Voice, Status & Emojis Suite', () {
    test('Issue 1 & 2: RealMediaService and RealDocumentFile validation', () async {
      final doc = await RealMediaService.instance.pickDocumentFile();
      expect(doc, isNotNull);
      expect(doc!.fileName, contains('Document'));
      expect(doc.fileSize, contains('Mo'));
      expect(doc.fileType, equals('PDF'));

      final wavData = RealMediaService.generateAuthenticWavDataUri(durationSeconds: 1, frequency: 130.0);
      expect(wavData.startsWith('data:audio/wav;base64,'), isTrue);
    });

    test('Issue 4: Emojis FontFamilyFallback configured on textTheme', () {
      final lightTheme = AppTheme.lightTheme;
      final darkTheme = AppTheme.darkTheme;

      expect(lightTheme.textTheme.bodyMedium?.fontFamilyFallback, containsAll(['Noto Color Emoji', 'Apple Color Emoji', 'Segoe UI Emoji', 'sans-serif']));
      expect(darkTheme.textTheme.bodyMedium?.fontFamilyFallback, containsAll(['Noto Color Emoji', 'Apple Color Emoji', 'Segoe UI Emoji', 'sans-serif']));
    });

    testWidgets('Issue 3: Message status checkmark displays single check when offline', (tester) async {
      final db = LocalDatabase();
      await db.initialize(onSeed: (database) async {
        await seedTestDataForUnitTestsOnly(database);
      });

      final convRepo = ConversationRepository(db);
      final msgRepo = MessageRepository(db);
      final profileRepo = ProfileRepository(db);
      final deviceRepo = DeviceRepository(db);

      // Find or create an offline conversation
      final offlineConv = Conversation(
        id: 'conv_offline_test',
        title: 'Offline Contact',
        peerAvatar: 'OC',
        lastMessage: 'En attente',
        lastMessageTime: '12:00',
        unreadCount: 0,
        isOnline: false,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: msgRepo),
            ChangeNotifierProvider.value(value: convRepo),
            ChangeNotifierProvider.value(value: profileRepo),
            ChangeNotifierProvider.value(value: deviceRepo),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: ConversationDetailScreen(conversation: offlineConv),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Enter text and send
      await tester.enterText(find.byType(TextField), 'Message pour contact hors-ligne');
      await tester.tap(find.byIcon(Icons.arrow_upward));
      await tester.pumpAndSettle();

      // The sent message should have isRead: false because conversation is offline
      final sentMessages = msgRepo.getMessagesForConversation('conv_offline_test');
      expect(sentMessages.isNotEmpty, isTrue);
      expect(sentMessages.last.isRead, isFalse);

      // Verify single checkmark is rendered for offline peer
      expect(find.byIcon(Icons.done), findsWidgets);
    });
  });
}
