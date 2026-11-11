import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:mrixk_client/core/database/local_database.dart';
import 'package:mrixk_client/core/models/conversation.dart';
import 'package:mrixk_client/core/repositories/call_history_repository.dart';
import 'package:mrixk_client/core/repositories/contact_repository.dart';
import 'package:mrixk_client/core/repositories/conversation_repository.dart';
import 'package:mrixk_client/core/repositories/device_repository.dart';
import 'package:mrixk_client/core/repositories/group_note_repository.dart';
import 'package:mrixk_client/core/repositories/message_repository.dart';
import 'package:mrixk_client/core/repositories/profile_repository.dart';
import 'package:mrixk_client/features/discussions/group_notepad_screen.dart';
import 'package:mrixk_client/features/discussions/widgets/group_note_renderer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalDatabase db;
  late ConversationRepository convRepo;
  late GroupNoteRepository noteRepo;
  late MessageRepository messageRepo;
  late ProfileRepository profileRepo;
  late ContactRepository contactRepo;
  late DeviceRepository deviceRepo;
  late CallHistoryRepository callRepo;

  setUp(() async {
    db = LocalDatabase();
    await db.initialize(usePlatformStorage: false);
    convRepo = ConversationRepository(db);
    noteRepo = GroupNoteRepository(db);
    messageRepo = MessageRepository(db);
    profileRepo = ProfileRepository(db);
    contactRepo = ContactRepository(db);
    deviceRepo = DeviceRepository(db);
    callRepo = CallHistoryRepository(db);
  });

  Widget buildTestApp(Widget child) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: convRepo),
        ChangeNotifierProvider.value(value: noteRepo),
        ChangeNotifierProvider.value(value: messageRepo),
        ChangeNotifierProvider.value(value: profileRepo),
        ChangeNotifierProvider.value(value: contactRepo),
        ChangeNotifierProvider.value(value: deviceRepo),
        ChangeNotifierProvider.value(value: callRepo),
      ],
      child: MaterialApp(
        home: Scaffold(body: child),
      ),
    );
  }

  group('Word & Document Rendu — Alignments and Zero Raw Tags Suite', () {
    testWidgets('Document Rendu renders centered and right aligned headings and paragraphs with width infinity', (tester) async {
      const content = '''
[align=center] # Titre Centré
[align=right] Paragraphe aligné à droite
[align=left] Paragraphe aligné à gauche
''';

      await tester.pumpWidget(
        buildTestApp(
          const GroupNoteRenderer(
            content: content,
            isFinalRenderMode: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Heading centered
      final headingFinder = find.text('Titre Centré');
      expect(headingFinder, findsOneWidget);
      final headingTextWidget = tester.widget<Text>(headingFinder);
      expect(headingTextWidget.textAlign, TextAlign.center);

      // Paragraphs
      final rightParagraphFinder = find.byWidgetPredicate((w) =>
          w is Text &&
          w.textSpan != null &&
          w.textAlign == TextAlign.right);
      expect(rightParagraphFinder, findsOneWidget);

      final leftParagraphFinder = find.byWidgetPredicate((w) =>
          w is Text &&
          w.textSpan != null &&
          w.textAlign == TextAlign.left);
      expect(leftParagraphFinder, findsWidgets);

      // Zero raw tags leak into the rendered text
      expect(find.textContaining('[align='), findsNothing);
      expect(find.textContaining('<div>'), findsNothing);
      expect(find.textContaining('</div>'), findsNothing);
    });

    testWidgets('Document Rendu parses all nested tags cleanly without any raw tag leaking to screen', (tester) async {
      const userSample = '''
**texte**
*texte* <u>texte</u> <font face="Inter">texte</font> <font color="#059669">texte</font> [align=left] texte
-  texte texte
t
- exte
texte
tex
- te
texte texte texte texte texte
texte
texte
texte
''';

      await tester.pumpWidget(
        buildTestApp(
          const GroupNoteRenderer(
            content: userSample,
            isFinalRenderMode: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify that NO raw formatting tags leak into visible text strings
      expect(find.textContaining('[align='), findsNothing);
      expect(find.textContaining('<font'), findsNothing);
      expect(find.textContaining('</font>'), findsNothing);
      expect(find.textContaining('<u>'), findsNothing);
      expect(find.textContaining('</u>'), findsNothing);
      expect(find.textContaining('<b>'), findsNothing);
      expect(find.textContaining('</b>'), findsNothing);
      expect(find.textContaining('<i>'), findsNothing);
      expect(find.textContaining('</i>'), findsNothing);
      expect(find.textContaining('<s>'), findsNothing);
      expect(find.textContaining('</s>'), findsNothing);
      expect(find.textContaining('<div>'), findsNothing);
      expect(find.textContaining('</div>'), findsNothing);

      // Verify styled font color #059669 span is present in the tree
      bool foundGreenSpan = false;
      final textWidgets = tester.widgetList<Text>(find.byType(Text));
      for (final tw in textWidgets) {
        if (tw.textSpan != null) {
          tw.textSpan!.visitChildren((span) {
            if (span is TextSpan && span.style?.color == const Color(0xFF059669)) {
              foundGreenSpan = true;
              return false;
            }
            return true;
          });
        }
      }
      expect(foundGreenSpan, isTrue);
    });

    testWidgets('Document Rendu renders {x=10} and {{x*2}} raw with warm amber and soft indigo badges', (tester) async {
      const content = '''
Déclaration : {prix = 1500}
Calcul : {{prix * 1.2}}
''';

      await tester.pumpWidget(
        buildTestApp(
          const GroupNoteRenderer(
            content: content,
            isFinalRenderMode: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      bool foundAmberBadge = false;
      bool foundIndigoBadge = false;

      final textWidgets = tester.widgetList<Text>(find.byType(Text));
      for (final tw in textWidgets) {
        if (tw.textSpan != null) {
          tw.textSpan!.visitChildren((span) {
            if (span is TextSpan) {
              if (span.text == '{prix = 1500}' &&
                  span.style?.backgroundColor == const Color(0xFFFEF3C7)) {
                foundAmberBadge = true;
              }
              if (span.text == '{{prix * 1.2}}' &&
                  span.style?.backgroundColor == const Color(0xFFEEF2FF)) {
                foundIndigoBadge = true;
              }
            }
            return true;
          });
        }
      }

      expect(foundAmberBadge, isTrue);
      expect(foundIndigoBadge, isTrue);
    });

    testWidgets('Word editor updates alignment in real-time when formatting buttons are clicked', (tester) async {
      final conv = Conversation(
        id: 'group-align-editor-test',
        title: 'Groupe Édition Word',
        peerAvatar: '',
        lastMessage: '',
        lastMessageTime: 'Maintenant',
        unreadCount: 0,
        isOnline: false,
        isGroup: true,
        groupMembersCount: 3,
      );

      await tester.pumpWidget(
        buildTestApp(
          GroupNotepadScreen(conversation: conv),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Éditer compartment
      await tester.tap(find.text('Éditer'));
      await tester.pumpAndSettle();

      // Verify Word sub-mode is active
      expect(find.text('Édition visuelle Word • Styles rendus en direct'), findsOneWidget);

      // Initially TextField is aligned left
      var textField = tester.widget<TextField>(find.byType(TextField).last);
      expect(textField.textAlign, TextAlign.left);

      // Click Center alignment button
      await tester.tap(find.byTooltip('Centrer'));
      await tester.pumpAndSettle();

      textField = tester.widget<TextField>(find.byType(TextField).last);
      expect(textField.textAlign, TextAlign.center);

      // Click Right alignment button
      await tester.tap(find.byTooltip('Aligner à droite'));
      await tester.pumpAndSettle();

      textField = tester.widget<TextField>(find.byType(TextField).last);
      expect(textField.textAlign, TextAlign.right);

      // Click Left alignment button
      await tester.tap(find.byTooltip('Aligner à gauche'));
      await tester.pumpAndSettle();

      textField = tester.widget<TextField>(find.byType(TextField).last);
      expect(textField.textAlign, TextAlign.left);
    });

    testWidgets('Code mode contains EXACTLY what user wrote without phantom test components or banners', (tester) async {
      final conv = Conversation(
        id: 'group-clean-code-test',
        title: 'Groupe Test Propre',
        peerAvatar: '',
        lastMessage: '',
        lastMessageTime: 'Maintenant',
        unreadCount: 0,
        isOnline: false,
        isGroup: true,
        groupMembersCount: 3,
      );

      await tester.pumpWidget(
        buildTestApp(
          GroupNotepadScreen(conversation: conv),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Éditer compartment
      await tester.tap(find.text('Éditer'));
      await tester.pumpAndSettle();

      // Enter Word text
      final wordInput = find.byType(TextField).last;
      await tester.enterText(wordInput, 'bonjour nnnnnnnnnnnnnn');
      await tester.pumpAndSettle();

      // Switch to Code mode
      await tester.tap(find.text('Code'));
      await tester.pumpAndSettle();

      // Verify the text in Code mode
      final codeInput = tester.widget<TextField>(find.byType(TextField).last);
      final codeText = codeInput.controller!.text;

      // Must be EXACTLY what the user wrote
      expect(codeText, equals('bonjour nnnnnnnnnnnnnn'));

      // MUST NOT contain legacy banners or dummy components
      expect(codeText.contains('// === Document MRixk'), isFalse);
      expect(codeText.contains('// === Définitions des Composants'), isFalse);
      expect(codeText.contains('tableau1'), isFalse);
      expect(codeText.contains('formule1'), isFalse);
      expect(codeText.contains('integrale1'), isFalse);
      expect(codeText.contains('somme1'), isFalse);
      expect(codeText.contains('diagramme1'), isFalse);
      expect(codeText.contains('graphe1'), isFalse);
      expect(codeText.contains('tableau_indicateurs'), isFalse);
      expect(codeText.contains('resultats_calculs'), isFalse);
    });
  });
}
