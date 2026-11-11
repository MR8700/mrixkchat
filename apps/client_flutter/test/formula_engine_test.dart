import 'package:flutter_test/flutter_test.dart';
import 'package:mrixk_client/core/services/formula_engine.dart';

void main() {
  group('FormulaEngine Tests', () {
    test('Evaluates C-style variable declarations and arithmetic assignments', () {
      const doc = '''
      Bienvenue dans les calculs.
      {a = 2; b = 5;}
      {int somme = a + b}
      {formule = somme * 2}
      ''';

      final vars = FormulaEngine.extractAndComputeVariables(doc);
      expect(vars['a'], 2.0);
      expect(vars['b'], 5.0);
      expect(vars['somme'], 7.0);
      expect(vars['formule'], 14.0);

      final result = FormulaEngine.evaluateCalculatorMacro('formule', vars);
      expect(result, '14');

      final resultCalc = FormulaEngine.evaluateCalculatorMacro('=somme * 3', vars);
      expect(resultCalc, '21');
    });

    test('Evaluates multiple variable assignment like {a, b = 5;}', () {
      const doc = '{a, b = 5;} {produit = a * b}';
      final vars = FormulaEngine.extractAndComputeVariables(doc);
      expect(vars['a'], 5.0);
      expect(vars['b'], 5.0);
      expect(vars['produit'], 25.0);
    });

    test('Evaluates complex mathematical functions like sqrt, pow, abs', () {
      final vars = {'x': 16.0, 'y': -5.0};
      final val1 = FormulaEngine.evaluateExpression('sqrt(x) + abs(y)', vars);
      expect(val1, 9.0);

      final val2 = FormulaEngine.evaluateExpression('2 ^ 3', vars);
      expect(val2, 8.0);
    });
  });
}
