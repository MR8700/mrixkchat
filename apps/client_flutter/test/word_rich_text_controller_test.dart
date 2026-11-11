import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mrixk_client/features/discussions/controllers/word_rich_text_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WordRichTextController — Espace Intégré Spécialisé Word (Clean-Buffer & Spans)', () {
    testWidgets('Texte utilisateur de démonstration : tout est rendu avec styles purs, sans astérisques résiduels', (tester) async {
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

      // Verify character length parity with controller's clean text (1:1 visual to buffer)
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

      expect(totalSpanLength, equals(controller.text.length),
          reason: 'La longueur totale des spans doit être strictement égale à la longueur du texte propre.');

      // Check bold rendering
      bool foundBold = false;
      span.visitChildren((child) {
        if (child is TextSpan && child.text != null) {
          if (child.text == 'texte' && child.style?.fontWeight == FontWeight.bold) {
            foundBold = true;
          }
        }
        return true;
      });
      expect(foundBold, isTrue, reason: 'Le mot "texte" doit être affiché avec fontWeight: bold.');

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

      // In the specialized clean-buffer space: NO asterisks exist in the editing buffer
      expect(controller.text.contains('**'), isFalse,
          reason: 'Aucun astérisque de balisage ne doit polluer le tampon d\'édition.');
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
            if (child.style?.backgroundColor == const Color(0xFFEEF2FF) &&
                child.style?.color == const Color(0xFF3730A3) &&
                child.style?.fontFamily == 'monospace') {
              foundDoubleBraceHighlighted = true;
            }
          }
          if (child.text == '{int a = 5}') {
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

    test('Sélection et mise en forme : Aucune lettre ne disparaît et aucun astérisque n\'apparaît lors de l\'effacement', () {
      final controller = WordRichTextController();
      controller.text = 'Mon texte magnifique pour le rapport';

      // Select "magnifique" (indices 10 to 20)
      controller.selection = const TextSelection(baseOffset: 10, extentOffset: 20);

      // Apply Bold
      controller.toggleBoldSelection();

      // Text buffer must remain completely intact (1:1 parity, length unchanged)
      expect(controller.text, equals('Mon texte magnifique pour le rapport'));
      expect(controller.text.length, equals(36));
      expect(controller.selection.baseOffset, equals(10));
      expect(controller.selection.extentOffset, equals(20));

      // Check characters 'm' to 'e' are bold
      for (int i = 10; i < 20; i++) {
        expect(controller.charStyles[i].isBold, isTrue,
            reason: 'Toutes les lettres de "magnifique" doivent être en gras, y compris la dernière.');
      }

      // Check toMarkdown() serializes properly
      final markdown = controller.toMarkdown();
      expect(markdown, contains('**magnifique**'));

      // Now backspace the last letter 'e' from "magnifique" (simulate backspace at index 20)
      // Delete 1 character at index 19 ('e')
      controller.value = const TextEditingValue(
        text: 'Mon texte magnifiqu pour le rapport',
        selection: TextSelection.collapsed(offset: 19),
      );

      // Verify NO asterisks appear in the text
      expect(controller.text.contains('*'), isFalse,
          reason: 'L\'effacement d\'une lettre ne doit JAMAIS faire apparaître d\'astérisque.');
      expect(controller.toMarkdown(), contains('**magnifiqu**'));
    });
  });
}
