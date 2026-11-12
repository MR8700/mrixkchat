import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mrixk_client/core/models/moe_object.dart';
import 'package:mrixk_client/features/discussions/widgets/group_note_renderer.dart';
import 'package:mrixk_client/features/discussions/widgets/moe_interactive_chart_widget.dart';
import 'package:mrixk_client/features/discussions/widgets/moe_interactive_diagram_widget.dart';
import 'package:mrixk_client/features/discussions/widgets/moe_interactive_table_widget.dart';
import 'package:mrixk_client/features/discussions/widgets/moe_object_code_modal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MRixk Object Engine (MOE) - Parser & Unified Model', () {
    test('declares and parses matrix/table {M[5,4]}', () {
      const code = '''
{M[5,4]}
{M[0,0]="Module"}
{M[0,1]="Protocole"}
{M[1,0]="Crypto"}
{M[1,1]="X25519"}
''';
      final objects = MoeEngine.extractObjects(code);
      expect(objects.containsKey('M'), isTrue);
      final m = objects['M']!;
      expect(m.type, MoeObjectType.table);
      expect(m.name, 'M');
      expect(m.properties['rows'], 5);
      expect(m.properties['cols'], 4);

      final grid = m.data as List<List<dynamic>>;
      expect(grid.length, 5);
      expect(grid[0].length, 4);
      expect(grid[0][0], 'Module');
      expect(grid[0][1], 'Protocole');
      expect(grid[1][0], 'Crypto');
      expect(grid[1][1], 'X25519');
      expect(m.isConfigured, isTrue);

      final mrixkOutput = m.toMrixkCode();
      expect(mrixkOutput, contains('{M[5,4]}'));
      expect(mrixkOutput, contains('{M[0,0]="Module"}'));
      expect(mrixkOutput, contains('{M[1,1]="X25519"}'));
      expect(mrixkOutput, isNot(contains('<table')));
    });

    test('declares and parses curve object {C:courbe} with parameters and formulas', () {
      const code = '''
{C:courbe}
{C.formule="A*sin(2*pi*f*t)"}
{C.A=2}
{C.f=50}
{C.domain=[-0.05, 0.05]}
{C.title="Onde Sinusoïdale"}
''';
      final objects = MoeEngine.extractObjects(code);
      expect(objects.containsKey('C'), isTrue);
      final c = objects['C']!;
      expect(c.type, MoeObjectType.curve);
      expect(c.properties['formule'], 'A*sin(2*pi*f*t)');
      expect(c.properties['title'], 'Onde Sinusoïdale');
      expect(c.parameters['A'], 2.0);
      expect(c.parameters['f'], 50.0);
      expect(c.isConfigured, isTrue);

      // Verify formula evaluator safely without eval
      final yAtZero = MoeEngine.evaluateFormula(
        c.properties['formule'],
        {'t': 0.0, 'A': 2.0, 'f': 50.0},
      );
      expect(yAtZero, closeTo(0.0, 1e-5));
    });

    test('evaluates sinc(t) function correctly', () {
      expect(MoeEngine.evaluateFormula('sinc(t)', {'t': 0.0}), 1.0);
      expect(MoeEngine.evaluateFormula('sinc(t)', {'t': 1.0}), closeTo(0.0, 1e-5));
      expect(MoeEngine.evaluateFormula('sinc(t)', {'t': 2.0}), closeTo(0.0, 1e-5));
    });

    test('flags unconfigured curve without crashing or blocking', () {
      const code = '{C_vide:courbe}';
      final objects = MoeEngine.extractObjects(code);
      expect(objects.containsKey('C_vide'), isTrue);
      final c = objects['C_vide']!;
      expect(c.isConfigured, isFalse);
      expect(c.validationErrors.isNotEmpty, isTrue);
      expect(c.validationErrors.first, contains('formule manquante'));
    });

    test('declares and parses flowchart diagram {D:diagramme(flowchart)}', () {
      const code = '''
{D:diagramme(flowchart)}
[1. Saisie Locale] -> [2. Signature Ed25519] -> [3. Chiffrement X25519]
''';
      final objects = MoeEngine.extractObjects(code);
      expect(objects.containsKey('D'), isTrue);
      final d = objects['D']!;
      expect(d.type, MoeObjectType.diagram);
      final nodes = d.data as List<String>;
      expect(nodes.length, 3);
      expect(nodes[0], '1. Saisie Locale');
      expect(nodes[1], '2. Signature Ed25519');
      expect(nodes[2], '3. Chiffrement X25519');
    });
  });

  group('MOE Interactive Visual Widgets', () {
    testWidgets('MoeInteractiveTableWidget allows direct in-place editing and dimension modifications', (tester) async {
      final obj = MoeObject.createTable('M_test', rows: 3, cols: 2);
      obj.setCell(0, 0, 'Entête A');
      obj.setCell(0, 1, 'Entête B');
      obj.setCell(1, 0, 'Donnée 1');
      obj.setCell(1, 1, 'Donnée 2');

      MoeObject? updatedObj;
      bool codeModalOpened = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MoeInteractiveTableWidget(
              object: obj,
              isReadOnly: false,
              onChanged: (val) => updatedObj = val,
              onOpenCodeModal: () => codeModalOpened = true,
            ),
          ),
        ),
      );

      // Verify dimensions badge
      expect(find.text('3 × 2'), findsOneWidget);
      expect(find.text('Entête A'), findsOneWidget);
      expect(find.text('Donnée 1'), findsOneWidget);

      // Click on Code button
      final codeBtn = find.text('Code');
      expect(codeBtn, findsOneWidget);
      await tester.tap(codeBtn);
      await tester.pumpAndSettle();
      expect(codeModalOpened, isTrue);

      // Tap on "+ Ligne"
      final addRowBtn = find.text('+ Ligne');
      expect(addRowBtn, findsOneWidget);
      await tester.tap(addRowBtn);
      await tester.pumpAndSettle();

      expect(updatedObj, isNotNull);
      expect(updatedObj!.properties['rows'], 4);
      expect(find.text('4 × 2'), findsOneWidget);

      // Tap on "+ Colonne"
      final addColBtn = find.text('+ Colonne');
      expect(addColBtn, findsOneWidget);
      await tester.tap(addColBtn);
      await tester.pumpAndSettle();

      expect(updatedObj!.properties['cols'], 3);
      expect(find.text('4 × 3'), findsOneWidget);
    });

    testWidgets('MoeInteractiveChartWidget shows non-blocking warning when unconfigured', (tester) async {
      final incomplete = MoeObject.createCurve('C_vide');
      bool codeOpened = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MoeInteractiveChartWidget(
              object: incomplete,
              isReadOnly: false,
              onOpenCodeModal: () => codeOpened = true,
            ),
          ),
        ),
      );

      expect(find.textContaining('manquants'), findsOneWidget);
      expect(find.text('Ouvrir le Code MRixk'), findsOneWidget);

      await tester.tap(find.text('Ouvrir le Code MRixk'));
      await tester.pumpAndSettle();
      expect(codeOpened, isTrue);
    });

    testWidgets('MoeInteractiveChartWidget renders curve and parameter controls when configured', (tester) async {
      final curve = MoeObject.createCurve('C_sin', formula: 'A*sin(2*pi*f*t)');
      curve.parameters['A'] = 2.0;
      curve.parameters['f'] = 50.0;
      curve.properties['title'] = 'Signal Sinusoïdal';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MoeInteractiveChartWidget(
                object: curve,
                isReadOnly: false,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Signal Sinusoïdal'), findsOneWidget);
      expect(find.textContaining('f(t) = A*sin(2*pi*f*t)'), findsOneWidget);
      expect(find.text('Paramètres interactifs en temps réel :'), findsOneWidget);
      expect(find.text('A ='), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('f ='), findsOneWidget);
      expect(find.text('50'), findsOneWidget);
    });

    testWidgets('MoeInteractiveDiagramWidget displays flowchart nodes and allows adding steps', (tester) async {
      final diag = MoeObject.createDiagram('D_proc', initialNodes: ['Étape 1', 'Étape 2']);
      MoeObject? updated;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MoeInteractiveDiagramWidget(
                object: diag,
                isReadOnly: false,
                onChanged: (val) => updated = val,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Étape 1'), findsOneWidget);
      expect(find.text('Étape 2'), findsOneWidget);
      expect(find.text('+ Étape'), findsOneWidget);

      await tester.tap(find.text('+ Étape'));
      await tester.pumpAndSettle();

      expect(updated, isNotNull);
      final nodes = updated!.data as List<String>;
      expect(nodes.length, 3);
      expect(nodes.last, '3. Nouvelle Étape');
    });

    testWidgets('MoeObjectCodeModal provides code editing, syntax check, and applies updates', (tester) async {
      final obj = MoeObject.createCurve('C_modal');
      MoeObject? savedObj;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  MoeObjectCodeModal.show(ctx, obj, (updated) {
                    savedObj = updated;
                  });
                },
                child: const Text('Open Modal'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      expect(find.text('Configuration Code — C_modal'), findsOneWidget);
      expect(find.text('Appliquer'), findsOneWidget);

      // Tap suggestion chip "+ Formule sinc"
      final sincChip = find.text('+ Formule sinc');
      expect(sincChip, findsOneWidget);
      await tester.tap(sincChip);
      await tester.pumpAndSettle();

      // Tap apply
      await tester.tap(find.text('Appliquer'));
      await tester.pumpAndSettle();

      expect(savedObj, isNotNull);
      expect(savedObj!.properties['formule'], 'sinc(t)');
    });
  });

  group('GroupNoteRenderer & DWS Integration', () {
    testWidgets('renders MOE table directly within note text', (tester) async {
      const noteContent = '''
# Rapport Financier Souverain

Voici les métriques validées :

{M[3,2]}
{M[0,0]="Métrique"}
{M[0,1]="Score"}
{M[1,0]="Disponibilité"}
{M[1,1]="99.9%"}
{M[2,0]="Résilience"}
{M[2,1]="100%"}

Fin du rapport.
''';

      final moeMap = MoeEngine.extractObjects(noteContent);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GroupNoteRenderer(
              content: noteContent,
              moeObjects: moeMap,
              isFinalRenderMode: false,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Rapport Financier Souverain'), findsOneWidget);
      expect(find.text('Métrique'), findsOneWidget);
      expect(find.text('Score'), findsOneWidget);
      expect(find.text('Disponibilité'), findsOneWidget);
      expect(find.text('99.9%'), findsOneWidget);
      expect(find.text('Fin du rapport.'), findsOneWidget);
    });

    testWidgets('renders MOE table in Document Rendu (isFinalRenderMode=true) as final polished table', (tester) async {
      const noteContent = '''
# Document Final

{M[3,2]}
{M[0,0]="Article"}
{M[0,1]="Prix"}
{M[1,0]="Clavier"}
{M[1,1]="50€"}
''';

      final moeMap = MoeEngine.extractObjects(noteContent);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GroupNoteRenderer(
              content: noteContent,
              moeObjects: moeMap,
              isFinalRenderMode: true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Document Final'), findsOneWidget);
      expect(find.text('Article'), findsOneWidget);
      expect(find.text('Prix'), findsOneWidget);
      expect(find.text('Clavier'), findsOneWidget);
      expect(find.text('50€'), findsOneWidget);
      // Braces are never shown in final rendered document
      expect(find.textContaining('{M['), findsNothing);
    });
  });
}
