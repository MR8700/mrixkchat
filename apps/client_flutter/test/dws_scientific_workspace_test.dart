import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mrixk_client/core/services/formula_engine.dart';
import 'package:mrixk_client/features/discussions/widgets/group_note_renderer.dart';
import 'package:mrixk_client/features/discussions/widgets/scientific_components_renderer.dart';

void main() {
  group('MRIXK SCIENTIFIC WORKSPACE — Laboratoire Scientifique & Calculs AST', () {
    test('Calculs mathématiques fondamentaux et équation du second degré', () {
      const doc = '''
float a = 1;
float b = -5;
float c = 6;
float delta = b*b - 4*a*c;
float x1 = (-b + sqrt(delta)) / (2*a);
float x2 = (-b - sqrt(delta)) / (2*a);
''';
      final vars = FormulaEngine.extractAndComputeVariables(doc);
      expect(vars['a'], equals(1.0));
      expect(vars['b'], equals(-5.0));
      expect(vars['c'], equals(6.0));
      expect(vars['delta'], equals(1.0));
      expect(vars['x1'], equals(3.0));
      expect(vars['x2'], equals(2.0));

      final x1Str = FormulaEngine.evaluateCalculatorMacro('x1', vars);
      final x2Str = FormulaEngine.evaluateCalculatorMacro('x2', vars);
      expect(x1Str, equals('3'));
      expect(x2Str, equals('2'));
    });

    test('Calculs traitement du signal et électronique (Nyquist, coupure RC, durée)', () {
      const doc = '''
global float f_signal = 1000;
global float f_echantillonnage = 8000;
global float n_points = 1024;
float duree_totale = n_points / f_echantillonnage;
float R = 1000;
float C = 1e-6;
float f_coupure = 1 / (2 * 3.141592653589793 * R * C);
''';
      final vars = FormulaEngine.extractAndComputeVariables(doc);
      expect(vars['f_signal'], equals(1000.0));
      expect(vars['f_echantillonnage'], equals(8000.0));
      expect(vars['n_points'], equals(1024.0));
      expect(vars['duree_totale'], equals(0.128));
      expect(vars['f_coupure'], closeTo(159.15, 0.05));
    });

    test('Algèbre linéaire — Déterminant de matrice 2x2', () {
      const doc = '''
float det_A = det([[1, 2], [3, 4]]);
''';
      final vars = FormulaEngine.extractAndComputeVariables(doc);
      expect(vars['det_A'], equals(-2.0));
      final detResult = FormulaEngine.evaluateCalculatorMacro('det_A', vars);
      expect(detResult, equals('-2'));
    });

    test('Statistiques — Moyenne, variance de population et écart-type', () {
      const doc = '''
float notes[] = [12, 14, 15, 16, 18];
float moyenne = mean(notes);
float variance = population_variance(notes);
float ecart_type = sqrt(variance);
''';
      final vars = FormulaEngine.extractAndComputeVariables(doc);
      expect(vars['moyenne'], equals(15.0));
      expect(vars['variance'], equals(4.0));
      expect(vars['ecart_type'], equals(2.0));

      final meanStr = FormulaEngine.evaluateCalculatorMacro('moyenne', vars);
      final stdStr = FormulaEngine.evaluateCalculatorMacro('ecart_type', vars);
      expect(meanStr, equals('15'));
      expect(stdStr, equals('2'));
    });

    testWidgets('Rendu complet des 8 composants scientifiques natifs DWS', (WidgetTester tester) async {
      tester.binding.window.physicalSizeTestValue = const Size(1280, 2400);
      tester.binding.window.devicePixelRatioTestValue = 1.0;
      addTearDown(() {
        tester.binding.window.clearPhysicalSizeTestValue();
        tester.binding.window.clearDevicePixelRatioTestValue();
      });

      const scientificDoc = '''
# MRIXK SCIENTIFIC WORKSPACE

## 1. Traitement du Signal
{signal_sinus}
{{id="signal_sinus";
  title="Signal sinusoïdal temporel";
  chart="line";
  expression="A * sin(2 * pi * f * t)";
  domain=[0.0, 0.004];
  series=["s(t)"];
  x_label="Temps (s)";
  y_label="Amplitude (V)";
}}

{spectre_fft}
{{id="spectre_fft";
  title="Densité spectrale de puissance (DSP)";
  chart="spectrum";
  transform="FFT";
  window="Hann";
  x_label="Fréquence (Hz)";
  y_label="Magnitude (dB)";
}}

## 2. Électronique & Circuits
{circuit_rc}
{{id="circuit_rc";
  title="Circuit RC Série";
  components=[
    {id="V1", type="source_tension", valeur="5 V"},
    {id="R1", type="resistance", valeur="1000 Ohm"},
    {id="C1", type="condensateur", valeur="1e-6 F"}
  ];
  connections=["V1+ -> R1", "R1 -> C1", "C1 -> V1- (GND)"];
}}

## 3. Chimie & Tableau Périodique
{tableau_mendeleiev}
{{id="tableau_mendeleiev";
  title="Classification Périodique (H à Ar)";
  elements=["H", "He", "Li", "Be", "B", "C", "N", "O", "F", "Ne", "Na", "Mg", "Al", "Si", "P", "S", "Cl", "Ar"];
}}

{echelle_ph}
{{id="echelle_ph";
  title="Échelle des pH usuels";
  chart="bar";
  data=[
    {nom="Acide fort", ph=1},
    {nom="Jus de citron", ph=2},
    {nom="Eau pure", ph=7},
    {nom="Eau de javel", ph=12}
  ];
}}

## 4. Génie Logiciel & Architecture
{use_case_dws}
{{id="use_case_dws";
  title="Diagramme de Cas d'Utilisation — MRixk DWS";
  diagram="use_case";
  actors=[
    {name="Auteur Scientifique"},
    {name="Collaborateur"}
  ];
  use_cases=[
    {name="Rédiger équations et formules"},
    {name="Insérer graphes et circuits"}
  ];
}}

{sequence_dws}
{{id="sequence_dws";
  title="Diagramme de Séquence — Synchronisation DWS";
  diagram="sequence";
  participants=["Auteur", "Éditeur MRixk", "Moteur AST"];
  messages=[
    {from="Auteur", to="Éditeur MRixk", label="Frappe {signal_sinus}"},
    {from="Éditeur MRixk", to="Moteur AST", label="Parse et calcule variables"}
  ];
}}

{architecture_systeme}
{{id="architecture_systeme";
  title="Architecture 4 Couches MRixk DWS";
  architecture=[
    {name="Présentation", components=["Word Visual Editor", "Code AST Editor"]},
    {name="Services", components=["FormulaEngine", "RealMediaService"]}
  ];
}}

{modele_osi}
{{id="modele_osi";
  title="Modèle de Référence OSI (7 Couches)";
  layers=[
    "Application",
    "Présentation",
    "Session",
    "Transport",
    "Réseau",
    "Liaison de données",
    "Physique"
  ];
}}
''';

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: GroupNoteRenderer(
                content: scientificDoc,
                isFinalRenderMode: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verify Document Headings
      expect(find.text('MRIXK SCIENTIFIC WORKSPACE'), findsOneWidget);
      expect(find.text('1. Traitement du Signal'), findsOneWidget);
      expect(find.text('2. Électronique & Circuits'), findsOneWidget);
      expect(find.text('3. Chimie & Tableau Périodique'), findsOneWidget);
      expect(find.text('4. Génie Logiciel & Architecture'), findsOneWidget);

      // 2. Verify Scientific Charts (Line, FFT Spectrum, pH Bar)
      expect(find.byType(DwsScientificChart), findsNWidgets(3));
      expect(find.text('Signal sinusoïdal temporel'), findsOneWidget);
      expect(find.text('Densité spectrale de puissance (DSP)'), findsOneWidget);
      expect(find.text('Échelle des pH usuels'), findsOneWidget);

      // 3. Verify Electrical Circuit Schematic
      expect(find.byType(DwsElectricCircuitWidget), findsOneWidget);
      expect(find.text('Circuit RC Série'), findsOneWidget);
      expect(find.text('V1'), findsOneWidget);
      expect(find.text('R1'), findsOneWidget);
      expect(find.text('C1'), findsOneWidget);

      // 4. Verify Periodic Table
      expect(find.byType(DwsPeriodicTableWidget), findsOneWidget);
      expect(find.text('Classification Périodique (H à Ar)'), findsOneWidget);
      expect(find.text('He'), findsOneWidget);
      expect(find.text('Ar'), findsOneWidget);

      // 5. Verify UML Diagrams
      expect(find.byType(DwsUmlDiagramWidget), findsNWidgets(2));
      expect(find.text('Diagramme de Cas d\'Utilisation — MRixk DWS'), findsOneWidget);
      expect(find.text('Auteur Scientifique'), findsOneWidget);
      expect(find.text('Diagramme de Séquence — Synchronisation DWS'), findsOneWidget);

      // 6. Verify 4-Layer Architecture Widget
      expect(find.byType(DwsArchitectureWidget), findsOneWidget);
      expect(find.text('Architecture 4 Couches MRixk DWS'), findsOneWidget);
      expect(find.text('Présentation'), findsWidgets);
      expect(find.text('Services'), findsWidgets);

      // 7. Verify OSI Layer Stack
      expect(find.byType(DwsLayerStackWidget), findsOneWidget);
      expect(find.text('Modèle de Référence OSI (7 Couches)'), findsOneWidget);
      expect(find.text('Application'), findsOneWidget);
      expect(find.text('Physique'), findsOneWidget);

      // 8. Document Rendu Verification: Technical declarations are strictly masked
      expect(find.textContaining('{{id="signal_sinus"'), findsNothing);
      expect(find.textContaining('{{id="spectre_fft"'), findsNothing);
      expect(find.textContaining('{{id="circuit_rc"'), findsNothing);
    });
  });
}
