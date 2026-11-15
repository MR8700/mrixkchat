import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mrixk_client/features/discussions/widgets/group_note_renderer.dart';
import 'package:mrixk_client/features/discussions/widgets/math_formula_renderer.dart';

void main() {
  testWidgets('GroupNoteRenderer renders intuitive blocks and dynamic math', (tester) async {
    const sampleContent = '''
# Mon Titre de Document

!theoreme Théorème Fondamental
Soit f une fonction continue sur [a, b]. L'intégrale est bien définie.

!definition Espace Préhilbertien
Un espace vectoriel muni d'un produit scalaire.

!note Remarque Importante
Cette propriété reste vraie pour toute dimension finie.

!astuce Astuce de Calcul
Factoriser par l'exponentielle avant d'intégrer.

!attention Attention aux Divisions
Vérifier que le dénominateur ne s'annule jamais.

!exemple Cas Particulier
Pour n = 2, nous retrouvons la formule classique.

!preuve Démonstration
La preuve découle immédiatement du théorème précédent.

Voici une formule en ligne : \$x^2 + y^2 = r^2\$ et une fraction \$a/b\$.

\$\$
\\int_0^1 x^2 dx = \\frac{1}{3}
\$\$
''';

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: GroupNoteRenderer(
              content: sampleContent,
              isFinalRenderMode: true,
            ),
          ),
        ),
      ),
    );

    // Verify theorem, definition, note, etc. are rendered
    expect(find.textContaining('THÉORÈME : Théorème Fondamental'), findsOneWidget);
    expect(find.textContaining('DÉFINITION : Espace Préhilbertien'), findsOneWidget);
    expect(find.textContaining('REMARQUE : Remarque Importante'), findsOneWidget);
    expect(find.textContaining('ASTUCE : Astuce de Calcul'), findsOneWidget);
    expect(find.textContaining('ATTENTION : Attention aux Divisions'), findsOneWidget);
    expect(find.textContaining('EXEMPLE : Cas Particulier'), findsOneWidget);
    expect(find.textContaining('DÉMONSTRATION : Démonstration'), findsOneWidget);
    expect(find.text('∎'), findsOneWidget); // QED symbol

    // Verify MathFormulaRenderer was invoked for inline and display math
    expect(find.byType(MathFormulaRenderer), findsWidgets);
  });

  testWidgets('GroupNoteRenderer renders automatic TOC, fenced code blocks, and footnotes', (tester) async {
    const academicDoc = '''
!sommaire

# Introduction Générale
Contenu de l'introduction[^1].

## Contexte Théorique
Détails du contexte théorique.

# Algorithmes et Implémentation
Voici l'algorithme :

```python
def fibonacci(n):
    return n if n <= 1 else fibonacci(n-1) + fibonacci(n-2)
```

> La simplicité est la sophistication suprême.
> Léonard de Vinci

[^1]: Référence bibliographique principale 2026.
''';

    await tester.pumpWidget(
      const MaterialApp(
        themeMode: ThemeMode.dark,
        home: Scaffold(
          body: SingleChildScrollView(
            child: GroupNoteRenderer(
              content: academicDoc,
              isFinalRenderMode: true,
            ),
          ),
        ),
      ),
    );

    // Verify TOC header and sections
    expect(find.text('SOMMAIRE'), findsOneWidget);
    expect(find.text('1. Introduction Générale'), findsNothing); // Number prefix is separate Text widget
    expect(find.text('Introduction Générale'), findsWidgets); // Appears in TOC and heading
    expect(find.text('Contexte Théorique'), findsWidgets);
    expect(find.text('Algorithmes et Implémentation'), findsWidgets);

    // Verify Code block
    expect(find.text('PYTHON'), findsOneWidget);
    expect(find.textContaining('def fibonacci(n):'), findsOneWidget);

    // Verify Blockquote
    expect(find.textContaining('La simplicité est la sophistication suprême.'), findsOneWidget);

    // Verify Footnote
    expect(find.textContaining('Référence bibliographique principale 2026.'), findsOneWidget);
  });
}
