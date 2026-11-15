import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mrixk_client/features/discussions/widgets/math_formula_renderer.dart';

void main() {
  testWidgets('MathFormulaRenderer renders natural and LaTeX math without errors', (tester) async {
    final testFormulas = [
      'a / b',
      r'\frac{1}{2}',
      'sqrt(x + 1)',
      r'\sqrt[3]{8}',
      'x^2 + y^2 = r^2',
      'u_n = 2*n + 1',
      'int_0^1 x dx',
      r'\int_{-\infty}^{+\infty} e^{-x^2} dx',
      r'\sum_{k=1}^n k = \frac{n(n+1)}{2}',
      r'\alpha + \beta = \gamma',
      r'\begin{pmatrix} 1 & 2 \\ 3 & 4 \end{pmatrix}',
    ];

    for (final f in testFormulas) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MathFormulaRenderer(formula: f, isDisplayMode: true, equationNumber: '1'),
          ),
        ),
      );
      expect(find.byType(MathFormulaRenderer), findsOneWidget);
    }
  });
}
