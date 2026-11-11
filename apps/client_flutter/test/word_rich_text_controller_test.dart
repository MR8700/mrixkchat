import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mrixk_client/features/discussions/controllers/word_rich_text_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WordRichTextController — Spécification MRixk DWS Word', () {
    testWidgets('Texte utilisateur de démonstration : tout est rendu sauf {} et {{}}', (tester) async {
      const rawInput = '''**texte**
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
texte''';

      final controller = WordRichTextController(text: rawInput);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) {
                final span = controller.buildTextSpan(context: ctx, withComposing: false);
                return Text.rich(span);
              },
            ),
          ),
        ),
      );

      // Verify character length parity
      final span = controller.buildTextSpan(
        context: tester.element(find.byType(Scaffold)),
        withComposing: false,
      );

      int totalSpanLength = 0;
      span.visitChildren((child) {
        if (child is TextSpan && child.text != null) {
          totalSpanLength += child.text!.length;
        }
        return true;
      });

      expect(totalSpanLength, equals(rawInput.length),
          reason: 'La longueur totale des spans doit être strictement égale à la longueur du texte brut.');

      // Check bold rendering
      bool foundBold = false;
      bool foundHiddenDoubleStar = false;
      span.visitChildren((child) {
        if (child is TextSpan && child.text != null) {
          if (child.text == 'texte' && child.style?.fontWeight == FontWeight.bold) {
            foundBold = true;
          }
          if (child.text == '**' && child.style?.color == Colors.transparent) {
            foundHiddenDoubleStar = true;
          }
        }
        return true;
      });
      expect(foundBold, isTrue, reason: 'Le mot "texte" doit être affiché avec fontWeight: bold.');
      expect(foundHiddenDoubleStar, isTrue, reason: 'Les balises "**" doivent être masquées.');

      // Check underline rendering
      bool foundUnderline = false;
      span.visitChildren((child) {
        if (child is TextSpan && child.text == 'texte' && child.style?.decoration == TextDecoration.underline) {
          foundUnderline = true;
        }
        return true;
      });
      expect(foundUnderline, isTrue, reason: 'Le mot sous <u> doit être souligné directement.');

      // Check font color #059669 rendering
      bool foundEmeraldColor = false;
      span.visitChildren((child) {
        if (child is TextSpan && child.text == 'texte' && child.style?.color == const Color(0xFF059669)) {
          foundEmeraldColor = true;
        }
        return true;
      });
      expect(foundEmeraldColor, isTrue, reason: 'Le mot sous <font color="#059669"> doit avoir la vraie couleur.');

      // Check font face "Inter" rendering
      bool foundInterFont = false;
      span.visitChildren((child) {
        if (child is TextSpan && child.text == 'texte' && child.style?.fontFamily == 'Inter') {
          foundInterFont = true;
        }
        return true;
      });
      expect(foundInterFont, isTrue, reason: 'Le mot sous <font face="Inter"> doit appliquer la police Inter.');

      // Check [align=left] hidden
      bool foundHiddenAlign = false;
      span.visitChildren((child) {
        if (child is TextSpan && child.text == '[align=left]' && child.style?.color == Colors.transparent) {
          foundHiddenAlign = true;
        }
        return true;
      });
      expect(foundHiddenAlign, isTrue, reason: 'La balise [align=left] doit être masquée.');
    });

    testWidgets('Les déclarations {...} et formules {{...}} restent brutes avec fond de mise en valeur', (tester) async {
      const rawText = 'Calcul de la puissance {{=a*b}} avec variable {int a = 5} et {b = 20}.';
      final controller = WordRichTextController(text: rawText);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) {
                final span = controller.buildTextSpan(context: ctx, withComposing: false);
                return Text.rich(span);
              },
            ),
          ),
        ),
      );

      final span = controller.buildTextSpan(
        context: tester.element(find.byType(Scaffold)),
        withComposing: false,
      );

      bool foundDoubleBraceHighlighted = false;
      bool foundSingleBraceHighlighted = false;

      span.visitChildren((child) {
        if (child is TextSpan && child.text != null) {
          if (child.text == '{{=a*b}}') {
            // Must remain raw visible and have soft indigo background
            if (child.style?.backgroundColor == const Color(0xFFEEF2FF) &&
                child.style?.color == const Color(0xFF3730A3) &&
                child.style?.fontFamily == 'monospace') {
              foundDoubleBraceHighlighted = true;
            }
          }
          if (child.text == '{int a = 5}') {
            // Must remain raw visible and have warm amber background
            if (child.style?.backgroundColor == const Color(0xFFFEF3C7) &&
                child.style?.color == const Color(0xFF92400E) &&
                child.style?.fontFamily == 'monospace') {
              foundSingleBraceHighlighted = true;
            }
          }
        }
        return true;
      });

      expect(foundDoubleBraceHighlighted, isTrue,
          reason: '{{=a*b}} doit rester brut avec un fond indigo qui le met en valeur.');
      expect(foundSingleBraceHighlighted, isTrue,
          reason: '{int a = 5} doit rester brut avec un fond ambre qui le met en valeur.');
    });
  });
}
