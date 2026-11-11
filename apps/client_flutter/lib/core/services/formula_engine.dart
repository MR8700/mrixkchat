import 'dart:math' as math;

/// Evaluator and parser for C-style variables, mathematical expressions,
/// fractions, integrals, sums and scientific symbols in MRixk Bloc-Note.
class FormulaEngine {
  /// Evaluates C-style declarations and assignments in text and extracts variable values.
  /// Examples:
  ///   {a=2; b=5;}
  ///   {a, b = 5;}
  ///   {int somme = a + b}
  ///   {formule = somme * 2}
  static Map<String, double> extractAndComputeVariables(String documentText) {
    final vars = <String, double>{};

    // Regex to match C-style variable blocks:
    // {a=2; b=5;} or {int somme = a + b} or {float x = 3.14;}
    final blockRegex = RegExp(r'\{([^{}]+)\}');
    final matches = blockRegex.allMatches(documentText);

    for (final m in matches) {
      final inner = m.group(1)?.trim() ?? '';
      // Skip if it looks like an HTML tag, macro ID or title formatting
      if (inner.startsWith('id=') || inner.startsWith('/') || inner.startsWith('<')) {
        continue;
      }

      // Split statements by ';' or newline
      final statements = inner.split(RegExp(r'[;\n]'));
      for (var stmt in statements) {
        stmt = stmt.trim();
        if (stmt.isEmpty) continue;

        // Strip C types: int, float, double, var, let, const
        stmt = stmt.replaceAll(RegExp(r'^(int|float|double|var|let|const|long)\s+', caseSensitive: false), '').trim();

        // Check for multiple assignments like "a, b = 5"
        final multiAssign = RegExp(r'^([a-zA-Z_][a-zA-Z0-9_]*(?:\s*,\s*[a-zA-Z_][a-zA-Z0-9_]*)+)\s*=\s*(.+)$');
        final multiMatch = multiAssign.firstMatch(stmt);
        if (multiMatch != null) {
          final varList = multiMatch.group(1)!.split(',').map((s) => s.trim()).toList();
          final expr = multiMatch.group(2)!.trim();
          final val = evaluateExpression(expr, vars);
          if (val != null) {
            for (final v in varList) {
              if (v.isNotEmpty) vars[v] = val;
            }
          }
          continue;
        }

        // Single assignment: "somme = a + b"
        final singleAssign = RegExp(r'^([a-zA-Z_][a-zA-Z0-9_]*)\s*=\s*(.+)$');
        final singleMatch = singleAssign.firstMatch(stmt);
        if (singleMatch != null) {
          final varName = singleMatch.group(1)!.trim();
          final expr = singleMatch.group(2)!.trim();
          final val = evaluateExpression(expr, vars);
          if (val != null) {
            vars[varName] = val;
          }
        }
      }
    }

    return vars;
  }

  /// Evaluates an arithmetic expression given a variables context.
  static double? evaluateExpression(String expr, Map<String, double> vars) {
    try {
      final sanitized = _substituteVariables(expr.trim(), vars);
      final tokens = _tokenize(sanitized);
      if (tokens.isEmpty) return null;
      final parser = _ExprParser(tokens);
      return parser.parseExpression();
    } catch (_) {
      return null;
    }
  }

  /// Replaces variable names with their numerical string values
  static String _substituteVariables(String expr, Map<String, double> vars) {
    var res = expr;
    // Sort variables by length descending to avoid partial prefix collisions
    final sortedKeys = vars.keys.toList()..sort((a, b) => b.length.compareTo(a.length));
    for (final key in sortedKeys) {
      final regex = RegExp('\\b$key\\b');
      res = res.replaceAllMapped(regex, (_) => vars[key].toString());
    }
    return res;
  }

  static List<String> _tokenize(String expr) {
    final tokens = <String>[];
    int i = 0;
    while (i < expr.length) {
      final ch = expr[i];
      if (ch == ' ' || ch == '\t') {
        i++;
        continue;
      }
      if ('+-*/%^()'.contains(ch)) {
        tokens.add(ch);
        i++;
      } else if (RegExp(r'[0-9.]').hasMatch(ch)) {
        final start = i;
        while (i < expr.length && RegExp(r'[0-9.]').hasMatch(expr[i])) {
          i++;
        }
        tokens.add(expr.substring(start, i));
      } else if (RegExp(r'[a-zA-Z_]').hasMatch(ch)) {
        final start = i;
        while (i < expr.length && RegExp(r'[a-zA-Z0-9_]').hasMatch(expr[i])) {
          i++;
        }
        tokens.add(expr.substring(start, i));
      } else {
        i++;
      }
    }
    return tokens;
  }

  /// Evaluates a calculator expression like {{=formule}} or {{=somme * 2}}
  static String evaluateCalculatorMacro(String macroContent, Map<String, double> vars) {
    var expr = macroContent.trim();
    if (expr.startsWith('=')) {
      expr = expr.substring(1).trim();
    }
    final val = evaluateExpression(expr, vars);
    if (val == null) {
      return 'Erreur de calcul ($expr)';
    }
    // Pretty print integer if no fractional part
    if (val == val.roundToDouble() && !val.isInfinite && !val.isNaN) {
      return val.toInt().toString();
    }
    return val.toStringAsFixed(4).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }

  /// Scientific and Greek symbols mapping
  static const Map<String, String> scientificSymbols = {
    'delta': 'Δ',
    'Delta': 'Δ',
    'delta_min': 'δ',
    'gradiant': '∇',
    'gradient': '∇',
    'nabla': '∇',
    'lamda': 'λ',
    'lambda': 'λ',
    'Lambda': 'Λ',
    'epsilon': 'ε',
    'pi': 'π',
    'Pi': 'Π',
    'sigma': 'Σ',
    'sum': 'Σ',
    'omega': 'ω',
    'Omega': 'Ω',
    'alpha': 'α',
    'beta': 'β',
    'theta': 'θ',
    'inf': '∞',
    'infinity': '∞',
    'sqrt': '√',
    'approx': '≈',
    'neq': '≠',
    'leq': '≤',
    'geq': '≥',
    'pm': '±',
  };

  /// Autocomplete catalog of available formula templates and macros for the Excel-like guide
  static const List<FormulaSuggestion> suggestions = [
    FormulaSuggestion(
      label: '{{=formule}}',
      description: 'Évalue une formule ou calculatrice C',
      template: '{{=somme * 2}}',
      category: 'Calculatrice',
    ),
    FormulaSuggestion(
      label: '{int nom = a + b}',
      description: 'Déclare une variable C dans le document',
      template: '{int somme = a + b;}',
      category: 'Variables',
    ),
    FormulaSuggestion(
      label: '{a=2; b=5;}',
      description: 'Assignation de variables multiples C',
      template: '{a=2; b=5;}',
      category: 'Variables',
    ),
    FormulaSuggestion(
      label: '{{A_1}}',
      description: 'Indice mathématique (A₁)',
      template: '{{A_1}}',
      category: 'Mathématiques',
    ),
    FormulaSuggestion(
      label: '{{A^7}}',
      description: 'Exposant mathématique (A⁷)',
      template: '{{A^7}}',
      category: 'Mathématiques',
    ),
    FormulaSuggestion(
      label: '{{(a+b)/(a-b)}}',
      description: 'Fraction mathématique élégante',
      template: '{{(a+b)/(a-b)}}',
      category: 'Mathématiques',
    ),
    FormulaSuggestion(
      label: '{{integral(1:2)(2x^2 dx)}}',
      description: 'Intégrale définie avec bornes (∫)',
      template: '{{integral(1:2)(2x^2 dx)}}',
      category: 'Calcul Intégral',
    ),
    FormulaSuggestion(
      label: '{{sigma(k=1:n)(k^2)}}',
      description: 'Sommation / Sigma avec bornes (∑)',
      template: '{{sigma(k=1:n)(k^2)}}',
      category: 'Séries',
    ),
    FormulaSuggestion(
      label: '{{sqrt(x+1)}}',
      description: 'Racine carrée (√)',
      template: '{{sqrt(x+1)}}',
      category: 'Mathématiques',
    ),
    FormulaSuggestion(
      label: '{{delta}}',
      description: 'Symbole Delta scientifique (Δ)',
      template: '{{delta}}',
      category: 'Symboles',
    ),
    FormulaSuggestion(
      label: '{{gradient}}',
      description: 'Opérateur Gradient / Nabla (∇)',
      template: '{{gradient}}',
      category: 'Symboles',
    ),
    FormulaSuggestion(
      label: '{{lambda}}',
      description: 'Symbole Lambda (λ)',
      template: '{{lambda}}',
      category: 'Symboles',
    ),
    FormulaSuggestion(
      label: '{{epsilon}}',
      description: 'Symbole Epsilon (ε)',
      template: '{{epsilon}}',
      category: 'Symboles',
    ),
    FormulaSuggestion(
      label: '{{pi}}',
      description: 'Constante Pi (π)',
      template: '{{pi}}',
      category: 'Symboles',
    ),
    FormulaSuggestion(
      label: '{Titre du tableau}',
      description: 'Crée une variable/tableau réutilisable',
      template: '{Titre du tableau}',
      category: 'Composants',
    ),
  ];
}

class FormulaSuggestion {
  final String label;
  final String description;
  final String template;
  final String category;

  const FormulaSuggestion({
    required this.label,
    required this.description,
    required this.template,
    required this.category,
  });
}

class _ExprParser {
  final List<String> tokens;
  int pos = 0;

  _ExprParser(this.tokens);

  double? parseExpression() {
    var val = _parseTerm();
    if (val == null) return null;

    while (pos < tokens.length) {
      final op = tokens[pos];
      if (op == '+' || op == '-') {
        pos++;
        final next = _parseTerm();
        if (next == null) return null;
        val = op == '+' ? val! + next : val! - next;
      } else {
        break;
      }
    }
    return val;
  }

  double? _parseTerm() {
    var val = _parseFactor();
    if (val == null) return null;

    while (pos < tokens.length) {
      final op = tokens[pos];
      if (op == '*' || op == '/' || op == '%') {
        pos++;
        final next = _parseFactor();
        if (next == null) return null;
        if (op == '*') {
          val = val! * next;
        } else if (op == '/') {
          if (next == 0) return double.nan;
          val = val! / next;
        } else {
          val = val! % next;
        }
      } else {
        break;
      }
    }
    return val;
  }

  double? _parseFactor() {
    var val = _parsePrimary();
    if (val == null) return null;

    if (pos < tokens.length && tokens[pos] == '^') {
      pos++;
      final exponent = _parseFactor();
      if (exponent == null) return null;
      val = math.pow(val, exponent).toDouble();
    }
    return val;
  }

  double? _parsePrimary() {
    if (pos >= tokens.length) return null;
    final token = tokens[pos];

    if (token == '-') {
      pos++;
      final next = _parsePrimary();
      return next != null ? -next : null;
    }
    if (token == '+') {
      pos++;
      return _parsePrimary();
    }

    if (token == '(') {
      pos++;
      final val = parseExpression();
      if (pos < tokens.length && tokens[pos] == ')') {
        pos++;
      }
      return val;
    }

    // Function calls: sqrt, abs, sin, cos, tan, log, exp
    if (token.toLowerCase() == 'sqrt' ||
        token.toLowerCase() == 'abs' ||
        token.toLowerCase() == 'sin' ||
        token.toLowerCase() == 'cos' ||
        token.toLowerCase() == 'tan' ||
        token.toLowerCase() == 'log' ||
        token.toLowerCase() == 'exp') {
      final fn = token.toLowerCase();
      pos++;
      if (pos < tokens.length && tokens[pos] == '(') {
        pos++;
        final arg = parseExpression();
        if (pos < tokens.length && tokens[pos] == ')') {
          pos++;
        }
        if (arg == null) return null;
        switch (fn) {
          case 'sqrt':
            return math.sqrt(arg);
          case 'abs':
            return arg.abs();
          case 'sin':
            return math.sin(arg);
          case 'cos':
            return math.cos(arg);
          case 'tan':
            return math.tan(arg);
          case 'log':
            return math.log(arg);
          case 'exp':
            return math.exp(arg);
        }
      }
    }

    final numVal = double.tryParse(token);
    if (numVal != null) {
      pos++;
      return numVal;
    }

    // If it's a known constant like pi or e
    if (token.toLowerCase() == 'pi') {
      pos++;
      return math.pi;
    }
    if (token.toLowerCase() == 'e') {
      pos++;
      return math.e;
    }

    return null;
  }
}
