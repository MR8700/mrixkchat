import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mrixk_client/core/database/local_database.dart';
import 'package:mrixk_client/core/models/call_log.dart';
import 'package:mrixk_client/core/repositories/assistant_repository.dart';
import 'package:mrixk_client/core/repositories/call_history_repository.dart';
import 'package:mrixk_client/core/repositories/conversation_repository.dart';
import 'package:mrixk_client/features/assistant/assistant_screen.dart';
import 'package:mrixk_client/features/calls/call_history_screen.dart';

void main() {
  group('Call History & Reorganized Assistant Suite', () {
    late LocalDatabase db;
    late CallHistoryRepository callRepo;
    late AssistantRepository assistantRepo;
    late ConversationRepository convRepo;

    setUp(() async {
      db = LocalDatabase();
      await db.initialize(usePlatformStorage: false);
      callRepo = CallHistoryRepository(db);
      assistantRepo = AssistantRepository(db);
      convRepo = ConversationRepository(db);
    });

    test('CallHistoryRepository handles CRUD operations correctly', () async {
      expect(callRepo.getAllLogs(), isEmpty);

      // Add call log
      final log = CallLog(
        id: 'test_call_1',
        peerName: 'Dr. Elena Rostova',
        peerAvatar: '',
        isVideo: false,
        direction: CallDirection.outgoing,
        timestamp: 'Aujourd\'hui à 10:00',
        duration: '02:30',
      );
      await callRepo.addCallLog(log);

      expect(callRepo.getAllLogs().length, equals(1));
      expect(callRepo.getAllLogs().first.peerName, equals('Dr. Elena Rostova'));

      // Add missed call
      final missed = CallLog(
        id: 'test_call_2',
        peerName: 'Dr. Elena Rostova',
        peerAvatar: '',
        isVideo: true,
        direction: CallDirection.missed,
        timestamp: 'Hier à 14:00',
        duration: 'Sans réponse',
      );
      await callRepo.addCallLog(missed);

      expect(callRepo.getAllLogs().length, equals(2));
      expect(callRepo.getMissedLogs().length, equals(1));
      expect(callRepo.getVideoLogs().length, equals(1));

      // Delete log
      await callRepo.deleteLog('test_call_1');
      expect(callRepo.getAllLogs().length, equals(1));

      // Clear all
      await callRepo.clearAll();
      expect(callRepo.getAllLogs(), isEmpty);
    });

    testWidgets('CallHistoryScreen displays call items, filter pills and empty state', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: callRepo),
            ChangeNotifierProvider.value(value: convRepo),
          ],
          child: const MaterialApp(
            home: CallHistoryScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Empty state
      expect(find.text('Appels'), findsOneWidget);
      expect(find.text('Aucun appel dans l\'historique'), findsOneWidget);

      // Add a log
      await callRepo.addCallLog(
        CallLog(
          id: 'log_elena',
          peerName: 'Dr. Elena Rostova',
          peerAvatar: '',
          isVideo: false,
          direction: CallDirection.outgoing,
          timestamp: 'Aujourd\'hui à 11:20',
          duration: '05:12',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Dr. Elena Rostova'), findsOneWidget);
      expect(find.text('Aujourd\'hui à 11:20 • 05:12'), findsOneWidget);
    });

    testWidgets('AssistantScreen allows conversation and prompt submission', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: assistantRepo),
          ],
          child: const MaterialApp(
            home: AssistantScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Assistant MRixk'), findsOneWidget);
      expect(find.text('Assistant Privé & Souverain'), findsOneWidget);

      // Ask question via text field
      await tester.enterText(find.byType(TextField), 'Bonjour');
      await tester.tap(find.byIcon(Icons.arrow_upward));
      await tester.pumpAndSettle();

      // Message appears in chat stream
      expect(find.text('Bonjour'), findsOneWidget);
      expect(assistantRepo.getAssistantMessages().isNotEmpty, isTrue);
    });
  });
}
