import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mrixk_client/features/discussions/widgets/group_note_renderer.dart';
import 'package:mrixk_client/features/discussions/widgets/scientific_components_renderer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Telecom & Signal Processing Course renders all formulas, sinc curve, FM graph, table, and diagram cleanly', (tester) async {
    tester.binding.window.physicalSizeTestValue = const Size(1280, 3200);
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(() {
      tester.binding.window.clearPhysicalSizeTestValue();
      tester.binding.window.clearDevicePixelRatioTestValue();
    });

    const telecomDoc = '''
[align=center] # Cours : Traitement du Signal & Télécommunications

[align=center] <font color="#2563eb">**Théorie de l'Information, Échantillonnage de Shannon et Modulations Fréquentielles**</font>

---

## 1. Théorème d'Échantillonnage de Shannon-Nyquist

Pour reconstituer parfaitement un signal continu sans repliement spectral (aliasing), la fréquence d'échantillonnage doit respecter la condition de Nyquist :

{{fe >= 2 * fmax}}

La formule de reconstruction par interpolation s'écrit à l'aide de la base orthogonale des **sinus cardinaux** :

Transformer de Fourier : {{integral(-\\infty:+\\infty)(x(t) * exp(-2*pi*j*f*t) dt)}}

---

## 2. Courbe Temporelle du Sinus Cardinal sinc(t)

Le sinus cardinal normalisé s'annule à chaque instant entier non nul et présente son lobe d'énergie principal centré à t = 0 :

{sinus_cardinal}

{{id="sinus_cardinal";
  chart="line"
  title="Signal Temporel — Sinus Cardinal sinc(t)"
  expression="sinc(t)"
  domain=[-6.0, 6.0]
  x_label="Temps t (secondes)"
  y_label="Amplitude s(t)"
}}

---

## 3. Spectre Fréquentiel de la Modulation FM (Raies de Bessel)

Dans une modulation de fréquence FM d'indice beta, le spectre s'étale selon la règle de Carson B = 2(df + fm) :

{spectre_signal_FM}

{{id="spectre_signal_FM";
<graph type="bar" title="Spectre Fréquentiel FM — Raies Discrètes de Bessel">
Porteuse fc (100.0 MHz): 88
Raie fc + fm (100.1 MHz): 54
Raie fc - fm (99.9 MHz): 54
Harmonique fc + 2fm (100.2 MHz): 22
Harmonique fc - 2fm (99.8 MHz): 22
Harmonique fc + 3fm (100.3 MHz): 8
Harmonique fc - 3fm (99.7 MHz): 8
Bruit de fond résiduel: 3
</graph>
}}

---

## 4. Chaîne de Transmission Numérique Complète

Architecture matérielle d'une liaison numérique souveraine :

{chaine_transmission}

{{id="chaine_transmission";
<diagram type="flowchart">
[1. Source Analogique] -> [2. Échantillonnage sinc(t)] -> [3. Codage Canal FEC] -> [4. Modulation FM / QAM] -> [5. Canal avec Bruit AWGN] -> [6. Démodulation & Filtrage]
</diagram>
}}

---

## 5. Matrice Comparative des Modulations Télécom

{comparatif_modulations}

{{id="comparatif_modulations";
<table border="1">
  <thead>
    <tr>
      <th>Modulation</th>
      <th>Efficacité Spectrale</th>
      <th>Résistance au Bruit</th>
      <th>Bande Passante</th>
      <th>Applications Typiques</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>AM (Amplitude)</td>
      <td>Faible (1 bit/s/Hz)</td>
      <td>Faible (Sensible au fading)</td>
      <td>Étroite (2 fm)</td>
      <td>Radiodiffusion GO/PO</td>
    </tr>
    <tr>
      <td>FM (Fréquence)</td>
      <td>Moyenne (Large bande)</td>
      <td>Excellente (Immunité amplitude)</td>
      <td>Large (Carson : 2(df+fm))</td>
      <td>Radio FM stéréo, VHF</td>
    </tr>
    <tr>
      <td>QPSK / 4-QAM</td>
      <td>2 bits/s/Hz</td>
      <td>Très bonne</td>
      <td>Optimisée</td>
      <td>Satellites, DVB-S, 4G</td>
    </tr>
    <tr>
      <td>64-QAM / OFDM</td>
      <td>6 bits/s/Hz</td>
      <td>Exigeante (Fort SNR)</td>
      <td>Multi-porteuses</td>
      <td>Wi-Fi 6, 5G NR, TNT</td>
    </tr>
  </tbody>
</table>
}}
''';

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: GroupNoteRenderer(
              content: telecomDoc,
              isFinalRenderMode: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Heading
    expect(find.text('Cours : Traitement du Signal & Télécommunications'), findsOneWidget);

    // Verify Sinus Cardinal scientific chart
    expect(find.byType(DwsScientificChart), findsOneWidget);
    expect(find.text('Signal Temporel — Sinus Cardinal sinc(t)'), findsOneWidget);

    // Verify FM Bar Graph
    expect(find.textContaining('Spectre Fréquentiel FM — Raies Discrètes de Bessel'), findsOneWidget);
    expect(find.text('Porteuse fc (100.0 MHz)'), findsOneWidget);

    // Verify Diagram
    expect(find.text('1. Source Analogique'), findsOneWidget);
    expect(find.text('6. Démodulation & Filtrage'), findsOneWidget);

    // Verify Table
    expect(find.text('Modulation'), findsOneWidget);
    expect(find.text('FM (Fréquence)'), findsOneWidget);
    expect(find.text('Radio FM stéréo, VHF'), findsOneWidget);
  });

  testWidgets('User course snippet with flexible brackets, sinc curve and FM spectrum renders without residual braces', (tester) async {
    tester.binding.window.physicalSizeTestValue = const Size(1280, 3200);
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(() {
      tester.binding.window.clearPhysicalSizeTestValue();
      tester.binding.window.clearDevicePixelRatioTestValue();
    });

    const userSnippet = '''
Cours : Traitement du Signal & Télécommunications
Théorie de l'Information, Échantillonnage de Shannon et Modulations Fréquentielles

1. Théorème d'Échantillonnage de Shannon-Nyquist
Nyquist :
{(fe>=2*fmax)}
La formule de décomposition et reconstruction s'appuie sur la Transformée de Fourier et la base orthogonale des sinus cardinaux:
Transformée de Fourier: {(integral(-\\infty:+\\infty)(x(t)exp(-2pijft)dt)))

2. Courbe Temporelle du Signal Sinus Cardinal sinc(t)
Le sinus cardinal normalisé s(t) = sin(pit)/(pit) est le filtre de reconstruction idéal :
{sinus_cardinal}

3. Spectre Fréquentiel de la Modulation FM (Raies de Bessel)
Dans une modulation de fréquence FM d'indice beta, le spectre s'étale autour de la porteuse :
{spetre_du_signal_FM}

4. Chaîne de Transmission Numérique Complète
Architecture séquentielle de traitement du signal sur une liaison télécom :
Organigramme:(chaine_transmission))

5. Matrice Comparative des Modulations Télécom
Tableau : ((comparatif_modulations)}

{{id="sinus_cardinal";
    chart="line"
    title="Signal Temporel — Sinus Cardinal sinc(t)"
    expression="sinc(t)"
    domain=[-6.0, 6.0]
    x_label="Temps t (secondes)"
    y_label="Amplitude s(t)"
}}

{{id="spectre_signal_FM";
<graph type="bar" title="Spectre Fréquentiel de la Modulation FM (Raies de Bessel)">
Porteuse fc (100.0 MHz): 88%
Raie fc + fm (100.1 MHz): 54%
Raie fc - fm (99.9 MHz): 54%
Harmonique fc + 2fm (100.2 MHz): 22%
Harmonique fc - 2fm (99.8 MHz): 22%
Harmonique fc + 3fm (100.3 MHz): 8%
Harmonique fc - 3fm (99.7 MHz): 8%
Bruit de fond résiduel: 3%
</graph>
}}

{{id="chaine_transmission";
<diagram type="flowchart">
[1. Source Analogique] -> [2. Échantillonnage sinc(t)] -> [3. Modulation FM / QAM] -> [4. Réception & Filtrage]
</diagram>
}}

{{id="comparatif_modulations";
<table border="1">
  <thead>
    <tr>
      <th>Modulation</th>
      <th>Efficacité Spectrale</th>
      <th>Résistance au Bruit</th>
      <th>Bande Passante</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>AM (Amplitude)</td>
      <td>Faible (1 bit/s/Hz)</td>
      <td>Faible (Sensible au fading)</td>
      <td>Étroite (2 fm)</td>
    </tr>
    <tr>
      <td>FM (Fréquence)</td>
      <td>Moyenne (Large bande)</td>
      <td>Excellente (Immunité amplitude)</td>
      <td>Large (Carson)</td>
    </tr>
  </tbody>
</table>
}}
''';

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: GroupNoteRenderer(
              content: userSnippet,
              isFinalRenderMode: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Title and Subtitle
    expect(find.textContaining('Traitement du Signal'), findsWidgets);

    // Verify sinc curve chart is rendered
    expect(find.byType(DwsScientificChart), findsOneWidget);
    expect(find.text('Signal Temporel — Sinus Cardinal sinc(t)'), findsOneWidget);

    // Verify FM Bar Graph spectrum is rendered with horizontal frequency X-axis
    expect(find.textContaining('Spectre Fréquentiel de la Modulation FM'), findsNWidgets(2));
    expect(find.text('Porteuse fc (100.0 MHz)'), findsOneWidget);
    expect(find.text('Axe X : Fréquence f (MHz)'), findsOneWidget);
    expect(find.text('88%'), findsOneWidget);

    // Verify flowchart diagram
    expect(find.text('1. Source Analogique'), findsOneWidget);

    // Verify table
    expect(find.text('Modulation'), findsOneWidget);
    expect(find.text('FM (Fréquence)'), findsOneWidget);

    // Verify integral rendered
    expect(find.text('∫'), findsOneWidget);
    expect(find.text('-∞'), findsOneWidget);
    expect(find.text('+∞'), findsOneWidget);

    // Verify NO raw curly braces in the rendered widgets
    expect(find.textContaining('{(fe>='), findsNothing);
    expect(find.textContaining('{(integral'), findsNothing);
    expect(find.textContaining('{sinus_cardinal}'), findsNothing);
    expect(find.textContaining('{spetre_du_signal_FM}'), findsNothing);
    expect(find.textContaining('((comparatif_modulations)}'), findsNothing);
  });
}
