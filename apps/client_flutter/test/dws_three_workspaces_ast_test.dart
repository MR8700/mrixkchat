import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:mrixk_client/core/database/local_database.dart';
import 'package:mrixk_client/core/models/conversation.dart';
import 'package:mrixk_client/core/models/dws_ast.dart';
import 'package:mrixk_client/core/repositories/call_history_repository.dart';
import 'package:mrixk_client/core/repositories/contact_repository.dart';
import 'package:mrixk_client/core/repositories/conversation_repository.dart';
import 'package:mrixk_client/core/repositories/device_repository.dart';
import 'package:mrixk_client/core/repositories/dws_media_repository.dart';
import 'package:mrixk_client/core/repositories/group_note_repository.dart';
import 'package:mrixk_client/core/repositories/message_repository.dart';
import 'package:mrixk_client/core/repositories/profile_repository.dart';
import 'package:mrixk_client/core/services/formula_engine.dart';
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
  late DwsMediaRepository mediaRepo;

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
    mediaRepo = DwsMediaRepository(db);
  });

  group('MRixk DWS Three Workspaces (Word, Code, Document Rendu) & AST Suite', () {
    test('FormulaEngine formats numbers with optional thousands separators (e.g. 6 000)', () {
      expect(FormulaEngine.formatNumber(6000.0, withThousandSeparators: true), '6 000');
      expect(FormulaEngine.formatNumber(1500000.0, withThousandSeparators: true), '1 500 000');
      expect(FormulaEngine.formatNumber(42.0, withThousandSeparators: true), '42');
      expect(FormulaEngine.formatNumber(12.5), '12.5');
    });

    test('DwsDocumentAst parses invoice example and generates Word, Code, and Document Rendu projections', () {
      const source = '''
# Facture
{int prix = 1500;}
{int quantite = 4;}
{int total = prix * quantite;}

Le montant total est : {{=total}} FCFA
''';

      final ast = DwsDocumentAst.fromSource(source, title: 'Facture Client');
      expect(ast.variables['prix'], 1500.0);
      expect(ast.variables['quantite'], 4.0);
      expect(ast.variables['total'], 6000.0);
      expect(ast.hasErrors, isFalse);

      // 1. Word Workspace representation: declarations are visible and editable
      final wordRep = ast.toWordRepresentation();
      expect(wordRep, contains('# Facture'));
      expect(wordRep, contains('{int prix = 1500;}'));
      expect(wordRep, contains('{int total = prix * quantite;}'));
      expect(wordRep, contains('Le montant total est : {{=total}} FCFA'));

      // 2. Code Workspace representation: exposed structural syntax
      final codeRep = ast.toCodeRepresentation();
      expect(codeRep, contains('int prix = 1500;'));
      expect(codeRep, contains('int total = prix * quantite;'));

      // 3. Document Rendu Projection: declarations STRICTLY hidden, evaluations replaced by final calculated numbers
      final rendered = ast.toRenderedProjection();
      expect(rendered, contains('Facture'));
      expect(rendered, isNot(contains('{int prix')));
      expect(rendered, isNot(contains('{int total')));
      expect(rendered, isNot(contains('{{=total}}')));
      expect(rendered, contains('Le montant total est : 6000 FCFA'));
    });

    testWidgets('GroupNoteRenderer in Document Rendu (isFinalRenderMode=true) masks declarations and shows clean results', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const docText = '''
# Facture
{int prix = 1500;}
{int quantite = 4;}
{int total = prix * quantite;}

Le montant total est : {{=total}} FCFA
''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GroupNoteRenderer(
              content: docText,
              isFinalRenderMode: true, // Document Rendu: Consultation finale
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Heading Facture is visible
      expect(find.text('Facture'), findsOneWidget);

      // Declarations {int ...} MUST NOT BE DISPLAYED in Document Rendu
      expect(find.textContaining('Variables C :'), findsNothing);
      expect(find.textContaining('prix = 1500'), findsNothing);

      // Evaluation is replaced by final calculated clean value (6 000 FCFA)
      expect(find.textContaining('Le montant total est : 6 000 FCFA'), findsOneWidget);
    });

    testWidgets('GroupNoteRenderer in Word mode (isFinalRenderMode=false) keeps declarations visible and identifiable', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const docText = '''
# Facture
{int prix = 1500;}
{int quantite = 4;}
{int total = prix * quantite;}

Le montant total est : {{=total}} FCFA
''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GroupNoteRenderer(
              content: docText,
              isFinalRenderMode: false, // Word mode: declarations are visible to the author
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Declarations are identifiable as technical chips so the author can edit them
      expect(find.textContaining('Variables C : int prix = 1500;'), findsOneWidget);
      expect(find.textContaining('Variables C : int total = prix * quantite;'), findsOneWidget);

      // Calculated value with evaluation expression badge
      expect(find.text('6000'), findsOneWidget);
    });

    testWidgets('GroupNotepadScreen provides Document Rendu (Print/PDF) and Code AST diagnostic tools', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final conv = Conversation(
        id: 'conv_group_dws',
        title: 'Groupe Finance DWS',
        peerAvatar: '',
        isGroup: true,
        groupMembersCount: 2,
        groupMembers: [
          GroupMember(id: 'user_richard', name: 'Richard MARE', role: 'creator'),
        ],
        lastMessage: 'Facture créée',
        lastMessageTime: '11:00',
      );
      await convRepo.createConversation(conv);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: convRepo),
            ChangeNotifierProvider.value(value: noteRepo),
            ChangeNotifierProvider.value(value: messageRepo),
            ChangeNotifierProvider.value(value: profileRepo),
            ChangeNotifierProvider.value(value: contactRepo),
            ChangeNotifierProvider.value(value: deviceRepo),
            ChangeNotifierProvider.value(value: callRepo),
            ChangeNotifierProvider.value(value: mediaRepo),
          ],
          child: MaterialApp(
            home: GroupNotepadScreen(conversation: conv),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verify Document Rendu workspace header with Print and PDF export
      expect(find.text('Document Rendu • Consultation finale'), findsOneWidget);
      expect(find.byIcon(Icons.print_rounded), findsOneWidget);
      expect(find.byIcon(Icons.picture_as_pdf_rounded), findsOneWidget);

      // Open Print Preview dialog
      await tester.tap(find.byIcon(Icons.print_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Aperçu avant Impression'), findsOneWidget);
      expect(find.text('Lancer l\'impression'), findsOneWidget);

      // Close print dialog
      await tester.tap(find.text('Fermer'));
      await tester.pumpAndSettle();

      // 2. Switch to Éditer -> Code
      await tester.tap(find.text('Éditer'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Code'));
      await tester.pumpAndSettle();

      // Verify Code workspace with AST Diagnostics & Snippet chips
      expect(find.textContaining('CODE AST'), findsOneWidget);
      expect(find.text('+ Variable int'), findsOneWidget);
      expect(find.text('+ Composant Titre'), findsOneWidget);
      expect(find.text('+ Calcul {{=}}'), findsOneWidget);
    });
  });
}
