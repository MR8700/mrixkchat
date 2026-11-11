import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:mrixk_client/core/database/local_database.dart';
import 'package:mrixk_client/core/models/conversation.dart';
import 'package:mrixk_client/core/models/message.dart';
import 'package:mrixk_client/core/repositories/call_history_repository.dart';
import 'package:mrixk_client/core/repositories/contact_repository.dart';
import 'package:mrixk_client/core/repositories/conversation_repository.dart';
import 'package:mrixk_client/core/repositories/device_repository.dart';
import 'package:mrixk_client/core/repositories/group_note_repository.dart';
import 'package:mrixk_client/core/repositories/message_repository.dart';
import 'package:mrixk_client/core/repositories/profile_repository.dart';
import 'package:mrixk_client/core/services/formula_engine.dart';
import 'package:mrixk_client/features/discussions/conversation_detail_screen.dart';
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

  group('Collaborative Bloc-Note & Group Workspace Spec v2 Suite', () {
    test('FormulaEngine computes C-style variables and evaluates calculator formula {{=formule}}', () {
      const doc = '''
      {a=2; b=5;}
      {int somme = a + b}
      {formule = somme * 2}
      Résultat : {{=formule}}
      ''';

      final vars = FormulaEngine.extractAndComputeVariables(doc);
      expect(vars['a'], 2.0);
      expect(vars['b'], 5.0);
      expect(vars['somme'], 7.0);
      expect(vars['formule'], 14.0);

      final calcResult = FormulaEngine.evaluateCalculatorMacro('formule', vars);
      expect(calcResult, '14');

      final directExpr = FormulaEngine.evaluateCalculatorMacro('=somme * 3', vars);
      expect(directExpr, '21');
    });

    testWidgets('GroupNoteRenderer renders empty state when content is empty', (tester) async {
      bool editTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GroupNoteRenderer(
              content: '',
              onStartEditing: () => editTapped = true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Vide'), findsOneWidget);
      expect(find.text('Aucun contenu pour le moment'), findsOneWidget);
      expect(find.text('Éditer le document'), findsOneWidget);

      await tester.tap(find.text('Éditer le document'));
      await tester.pumpAndSettle();

      expect(editTapped, isTrue);
    });

    testWidgets('GroupNoteRenderer renders math indices, exponents, fractions, integrals, and C variables', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const mathDoc = '''
# Titre Principal Niveau 1
## Sous-titre Niveau 2
{a=2; b=5;}
{int somme = a + b}
{formule = somme * 2}

Indice: {{A_1}}
Exposant: {{A^7}}
Fraction: {{(a+b)/(a-b)}}
Intégrale: {{integral(1:2)(2x^2 dx)}}
Somme: {{sigma(k=1:n)(k^2)}}
Racine: {{sqrt(x+1)}}
Symboles: {{delta}} {{gradient}} {{lambda}} {{epsilon}}
Calculatrice: {{=formule}}
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GroupNoteRenderer(
              content: mathDoc,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Heading levels
      expect(find.text('Titre Principal Niveau 1'), findsOneWidget);
      expect(find.text('Sous-titre Niveau 2'), findsOneWidget);

      // C variables badge
      expect(find.textContaining('Variables C'), findsWidgets);

      // Calculator pill
      expect(find.text('14'), findsOneWidget);

      // Integrals and symbols
      expect(find.text('∫'), findsOneWidget);
      expect(find.text('∑'), findsOneWidget);
      expect(find.text('√'), findsWidgets);
    });

    testWidgets('GroupNotepadScreen displays Document and Éditer with Word and Code toggle', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final groupConv = Conversation(
        id: 'conv_group_v2',
        title: 'Groupe Architecture',
        peerAvatar: '',
        isGroup: true,
        groupMembersCount: 3,
        groupMembers: const [
          GroupMember(id: 'user_richard', name: 'Richard MARE', role: 'creator'),
        ],
        lastMessage: 'Ouverture du document',
        lastMessageTime: '12:00',
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

      // 1. Two top compartments: Document and Éditer
      expect(find.text('Document'), findsOneWidget);
      expect(find.text('Éditer'), findsOneWidget);
      expect(find.byIcon(Icons.more_vert_rounded), findsOneWidget);

      // 2. Switch to Éditer
      await tester.tap(find.text('Éditer'));
      await tester.pumpAndSettle();

      // 3. Bascule Word / Code
      expect(find.text('Word'), findsOneWidget);
      expect(find.text('Code'), findsOneWidget);

      // Word toolbar formatting tools
      expect(find.text('Police'), findsOneWidget);
      expect(find.text('Titre (H1-H8)'), findsOneWidget);

      // Open Heading configuration modal
      await tester.tap(find.text('Titre (H1-H8)'));
      await tester.pumpAndSettle();
      expect(find.text('Configurer le Titre (Niveaux 1 à 8)'), findsOneWidget);
      expect(find.text('H1'), findsOneWidget);
      expect(find.text('H8'), findsOneWidget);
      expect(find.text('Appliquer le Titre'), findsOneWidget);

      // Close modal
      await tester.tap(find.text('Appliquer le Titre'));
      await tester.pumpAndSettle();

      // 4. Switch to Code mode
      await tester.tap(find.text('Code'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Source du Document & Définitions'), findsOneWidget);
    });

    testWidgets('In-Chat Bloc-Note message renders Name, Date/Time, Ouvrir, Supprimer, and Options', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final groupConv = Conversation(
        id: 'conv_in_chat_note',
        title: 'Groupe R&D',
        peerAvatar: '',
        isGroup: true,
        groupMembersCount: 3,
        groupMembers: const [
          GroupMember(id: 'user_richard', name: 'Richard MARE', role: 'creator'),
        ],
        lastMessage: 'Nouveau document',
        lastMessageTime: '14:30',
      );
      await convRepo.createConversation(groupConv);

      // Add a Bloc-Note message in chat
      final noteMsg = Message(
        id: 'msg_note_123',
        conversationId: groupConv.id,
        senderId: 'user_richard',
        senderName: 'Richard MARE',
        senderAvatar: '',
        type: MessageType.document,
        content: '📝 [Bloc-Note du Groupe] "Spécifications Système"\nEspace de travail collaboratif, variables et formules mathématiques.',
        time: '14:30',
        isOutgoing: true,
      );
      await messageRepo.sendMessage(noteMsg);

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

      // Verify the in-chat message card
      expect(find.text('Spécifications Système'), findsOneWidget);
      expect(find.text('Bloc-Notes du groupe • Collaboratif'), findsOneWidget);
      expect(find.text('Synchronisé ✅'), findsOneWidget);
      expect(find.textContaining('Créé le'), findsOneWidget);
      expect(find.text('Ouvrir'), findsWidgets);
      expect(find.text('Supprimer'), findsOneWidget);
    });

    test('Inter-document referencing and immediate verification operator ?', () {
      final extDocs = {
        'Maths': {'somme': 42.0, 'pi_approx': 3.14},
        'Physique': {'vitesse': 300000.0},
      };

      // 1. Normal inter-document reference
      final exprVal = FormulaEngine.evaluateExpression('Maths.somme * 2', {}, externalDocs: extDocs);
      expect(exprVal, 84.0);

      // 2. Immediate verification operator ? with existing variable
      final checkOk = FormulaEngine.checkImmediateVariableExistence('Maths.?somme', extDocs);
      expect(checkOk.exists, isTrue);
      expect(checkOk.value, 42.0);
      expect(checkOk.documentName, 'Maths');
      expect(checkOk.variableName, 'somme');

      // 3. Immediate verification operator ? with missing variable
      final checkMissing = FormulaEngine.checkImmediateVariableExistence('Maths.?inconnue', extDocs);
      expect(checkMissing.exists, isFalse);
      expect(checkMissing.errorMessage, contains('n\'existe pas dans le document "Maths"'));

      // 4. Missing document
      final checkDocMissing = FormulaEngine.checkImmediateVariableExistence('Chimie.?ph', extDocs);
      expect(checkDocMissing.exists, isFalse);
      expect(checkDocMissing.errorMessage, contains('Chimie'));

      // 5. Calculator macro with ?
      final macroRes = FormulaEngine.evaluateCalculatorMacro('Maths.?somme + 8', {}, externalDocs: extDocs);
      expect(macroRes, '50');

      final macroErr = FormulaEngine.evaluateCalculatorMacro('Maths.?absente', {}, externalDocs: extDocs);
      expect(macroErr, contains('⚠️ Variable introuvable'));
    });

    test('Circular dependency detection in inter-document formulas', () {
      final extDocs = {
        'DocA': {'valA': 10.0},
        'DocB': {'valB': 20.0},
      };

      // Graph with cycle: DocA -> DocB -> DocA
      final graph = {
        'DocA': {'DocB'},
        'DocB': {'DocA'},
      };

      expect(
        () => FormulaEngine.evaluateExpression(
          'DocB.valB + 1',
          {},
          externalDocs: extDocs,
          currentDoc: 'DocA',
          graph: graph,
        ),
        throwsA(isA<CircularDependencyException>()),
      );
    });

    testWidgets('GroupNoteRenderer renders limits, derivatives, gradients, matrices and structured tables', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const advancedDoc = '''
Calcul différentiel et tensoriel :
Limite : {{limit(x->0)((sin(x))/x)}}
Dérivée : {{derivative(f, x)}}
Gradient : {{gradient(T)}}
Matrice : {{matrix([[1, 2], [3, 4]])}}
Symboles : {{delta}} {{lambda}} {{sigma}}

{{id="TableauNotes";
type="table";
columns=["Étudiant", "Note", "Mention"];
rows=[["Kaboré", 18, "Très Bien"], ["Diallo", 16, "Bien"]];
}}

{TableauNotes}
''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GroupNoteRenderer(
              content: advancedDoc,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('lim'), findsOneWidget);
      expect(find.text('df'), findsOneWidget);
      expect(find.text('dx'), findsOneWidget);
      expect(find.text('∇'), findsOneWidget);
      expect(find.text('Étudiant'), findsOneWidget);
      expect(find.text('Kaboré'), findsOneWidget);
      expect(find.text('Diallo'), findsOneWidget);
    });
  });
}
