import 'dart:math' as math;

/// Exception thrown when a circular dependency is detected between document variables
class CircularDependencyException implements Exception {
  final List<String> cycle;
  CircularDependencyException(this.cycle);

  @override
  String toString() => 'Dépendance circulaire détectée : ${cycle.join(' -> ')}';
}

/// Verification result for inter-document references like Maths.?somme
class VariableCheckResult {
  final bool exists;
  final String documentName;
  final String variableName;
  final double? value;
  final String? errorMessage;

  const VariableCheckResult({
    required this.exists,
    required this.documentName,
    required this.variableName,
    this.value,
    this.errorMessage,
  });
}

/// Evaluator and parser for C-style variables, inter-document references,
/// mathematical expressions, fractions, integrals, sums, matrices and scientific symbols in MRixk DWS.
class FormulaEngine {
  /// Evaluates C-style declarations and assignments in text and extracts variable values.
  /// Supports:
  ///   {a=2; b=5;}
  ///   {a, b = 5;}
  ///   {int somme = a + b}
  ///   {formule = somme * 2}
  ///   export int somme = 7;
  ///   Inter-document: {val = Maths.somme * 2}
  static Map<String, double> extractAndComputeVariables(
    String documentText, {
    Map<String, Map<String, double>>? externalDocumentsVariables,
    String? currentDocumentId,
    Map<String, Set<String>>? dependencyGraph,
  }) {
    final vars = <String, double>{};

    final blockRegex = RegExp(r'\{([^{}]+)\}');
    final matches = blockRegex.allMatches(documentText);

    for (final m in matches) {
      final inner = m.group(1)?.trim() ?? '';
      if (inner.startsWith('id=') ||
          inner.startsWith('/') ||
          inner.startsWith('<') ||
          inner.startsWith('type=') ||
          inner.startsWith('columns=') ||
          inner.startsWith('rows=')) {
        continue;
      }

      final statements = inner.split(RegExp(r'[;\n]'));
      for (var stmt in statements) {
        stmt = stmt.trim();
        if (stmt.isEmpty) continue;

        // Strip C types and export keyword: export, int, float, double, var, let, const
        stmt = stmt.replaceAll(
          RegExp(r'^(global\s+)?(export\s+)?(int|float|double|var|let|const|long)\s+', caseSensitive: false),
          '',
        ).trim();

        // Multiple assignments: "a, b = 5"
        final multiAssign = RegExp(r'^([a-zA-Z_][a-zA-Z0-9_]*(?:\s*,\s*[a-zA-Z_][a-zA-Z0-9_]*)+)\s*=\s*(.+)$');
        final multiMatch = multiAssign.firstMatch(stmt);
        if (multiMatch != null) {
          final varList = multiMatch.group(1)!.split(',').map((s) => s.trim()).toList();
          final expr = multiMatch.group(2)!.trim();
          final val = evaluateExpression(
            expr,
            vars,
            externalDocs: externalDocumentsVariables,
            currentDoc: currentDocumentId,
            graph: dependencyGraph,
          );
          if (val != null) {
            for (final v in varList) {
              if (v.isNotEmpty) vars[v] = val;
            }
          }
          continue;
        }

        // Single assignment: "somme = a + b" or "val = Maths.somme"
        final singleAssign = RegExp(r'^([a-zA-Z_][a-zA-Z0-9_]*)\s*=\s*(.+)$');
        final singleMatch = singleAssign.firstMatch(stmt);
        if (singleMatch != null) {
          final varName = singleMatch.group(1)!.trim();
          final expr = singleMatch.group(2)!.trim();
          final val = evaluateExpression(
            expr,
            vars,
            externalDocs: externalDocumentsVariables,
            currentDoc: currentDocumentId,
            graph: dependencyGraph,
          );
          if (val != null) {
            vars[varName] = val;
          }
        }
      }
    }

    // Scan unbracketed C variable declarations (e.g. float delta = b*b - 4*a*c; or global float pi = 3.14159...)
    final lines = documentText.split('\n');
    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty || line.startsWith('//') || line.startsWith('#') || line.startsWith('{')) continue;

      // Array definition: float notes[] = [12,14,15,16,18];
      final arrayMatch = RegExp(r'^(?:global\s+)?(?:float|int|double)\s+([a-zA-Z_0-9]+)\[\]\s*=\s*\[([^\]]+)\];?$', caseSensitive: false).firstMatch(line);
      if (arrayMatch != null) {
        final arrName = arrayMatch.group(1)!;
        final rawItems = arrayMatch.group(2)!.split(',').map((s) => double.tryParse(s.trim())).whereType<double>().toList();
        if (rawItems.isNotEmpty) {
          final m = rawItems.reduce((a, b) => a + b) / rawItems.length;
          final v = rawItems.map((x) => math.pow(x - m, 2)).reduce((a, b) => a + b) / rawItems.length;
          vars[arrName] = m;
          vars['${arrName}_mean'] = m;
          vars['${arrName}_variance'] = v;
        }
        continue;
      }

      // Variable definition: global float c_lumiere = 299792458;
      final varMatch = RegExp(r'^(?:global\s+)?(?:export\s+)?(?:int|float|double|number|var|let|const|long)\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*=\s*([^;]+);?$', caseSensitive: false).firstMatch(line);
      if (varMatch != null) {
        final varName = varMatch.group(1)!;
        var expr = varMatch.group(2)!.trim();
        if (expr.contains('mean(')) {
          final target = RegExp(r'mean\(([a-zA-Z_0-9]+)\)').firstMatch(expr)?.group(1);
          if (target != null && vars.containsKey('${target}_mean')) {
            expr = expr.replaceAll('mean($target)', vars['${target}_mean']!.toString());
          }
        }
        if (expr.contains('population_variance(')) {
          final target = RegExp(r'population_variance\(([a-zA-Z_0-9]+)\)').firstMatch(expr)?.group(1);
          if (target != null && vars.containsKey('${target}_variance')) {
            expr = expr.replaceAll('population_variance($target)', vars['${target}_variance']!.toString());
          }
        }
        final val = evaluateExpression(
          expr,
          vars,
          externalDocs: externalDocumentsVariables,
          currentDoc: currentDocumentId,
          graph: dependencyGraph,
        );
        if (val != null) {
          vars[varName] = val;
        }
      }
    }

    return vars;
  }

  /// Checks immediately if an inter-document variable exists (for the ? operator)
  /// e.g. Maths.?somme or Maths.?inconnue
  static VariableCheckResult checkImmediateVariableExistence(
    String reference,
    Map<String, Map<String, double>> externalDocumentsVariables,
  ) {
    // Syntax: DocName.?varName
    final match = RegExp(r'^([a-zA-Z0-9_\-]+)\.\?([a-zA-Z0-9_\-]+)$').firstMatch(reference.trim());
    if (match == null) {
      return VariableCheckResult(
        exists: false,
        documentName: '',
        variableName: reference,
        errorMessage: 'Syntaxe de référence invalide (attendu: Document.?variable)',
      );
    }

    final docName = match.group(1)!;
    final varName = match.group(2)!;

    final docVars = externalDocumentsVariables[docName];
    if (docVars == null) {
      return VariableCheckResult(
        exists: false,
        documentName: docName,
        variableName: varName,
        errorMessage: 'Document "$docName" introuvable dans ce groupe.',
      );
    }

    if (!docVars.containsKey(varName)) {
      return VariableCheckResult(
        exists: false,
        documentName: docName,
        variableName: varName,
        errorMessage: 'La variable "$varName" n\'existe pas dans le document "$docName". Vérifiez le nom du document ou de la variable.',
      );
    }

    return VariableCheckResult(
      exists: true,
      documentName: docName,
      variableName: varName,
      value: docVars[varName],
    );
  }

  /// Evaluates an arithmetic expression given local and external inter-document variables.
  static double? evaluateExpression(
    String expr,
    Map<String, double> localVars, {
    Map<String, Map<String, double>>? externalDocs,
    String? currentDoc,
    Map<String, Set<String>>? graph,
  }) {
    try {
      final sanitized = _substituteVariables(
        expr.trim(),
        localVars,
        externalDocs: externalDocs,
        currentDoc: currentDoc,
        graph: graph,
      );
      final tokens = _tokenize(sanitized);
      if (tokens.isEmpty) return null;
      final parser = _ExprParser(tokens);
      return parser.parseExpression();
    } on CircularDependencyException {
      rethrow;
    } catch (_) {
      return null;
    }
  }

  /// Replaces local and inter-document variable names with their numerical string values
  static String _substituteVariables(
    String expr,
    Map<String, double> localVars, {
    Map<String, Map<String, double>>? externalDocs,
    String? currentDoc,
    Map<String, Set<String>>? graph,
  }) {
    var res = expr;

    // 1. Resolve inter-document references: DocName.varName or DocName.?varName
    if (externalDocs != null && externalDocs.isNotEmpty) {
      final interDocRegex = RegExp(r'\b([a-zA-Z0-9_\-]+)\.(\??)([a-zA-Z0-9_\-]+)\b');
      res = res.replaceAllMapped(interDocRegex, (m) {
        final targetDoc = m.group(1)!;
        final isImmediate = m.group(2) == '?';
        final targetVar = m.group(3)!;

        // Circular dependency check
        if (currentDoc != null && graph != null) {
          graph.putIfAbsent(currentDoc, () => <String>{}).add(targetDoc);
          _detectCycles(currentDoc, graph, [currentDoc]);
        }

        final docMap = externalDocs[targetDoc];
        if (docMap != null && docMap.containsKey(targetVar)) {
          return docMap[targetVar].toString();
        }

        if (isImmediate) {
          throw ArgumentError('Variable introuvable: $targetDoc.?$targetVar');
        }

        return 'NaN';
      });
    }

    // 2. Resolve local variables (sorted by length descending)
    final sortedKeys = localVars.keys.toList()..sort((a, b) => b.length.compareTo(a.length));
    for (final key in sortedKeys) {
      final regex = RegExp('\\b$key\\b');
      res = res.replaceAllMapped(regex, (_) => localVars[key].toString());
    }

    return res;
  }

  static void _detectCycles(String current, Map<String, Set<String>> graph, List<String> path) {
    final targets = graph[current] ?? {};
    for (final next in targets) {
      if (path.contains(next)) {
        throw CircularDependencyException([...path, next]);
      }
      _detectCycles(next, graph, [...path, next]);
    }
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
      if ('+-*/%^()[],'.contains(ch)) {
        tokens.add(ch);
        i++;
      } else if (RegExp(r'[0-9]').hasMatch(ch) || (ch == '.' && i + 1 < expr.length && RegExp(r'[0-9]').hasMatch(expr[i + 1]))) {
        final start = i;
        while (i < expr.length && RegExp(r'[0-9.eE]').hasMatch(expr[i])) {
          if ((expr[i] == 'e' || expr[i] == 'E') && i + 1 < expr.length && (expr[i + 1] == '+' || expr[i + 1] == '-')) {
            i += 2;
          } else {
            i++;
          }
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

  /// Evaluates a calculator expression like {{=formule}} or {{=Maths.somme * 2}} or {{=Maths.?somme}}
  static String evaluateCalculatorMacro(
    String macroContent,
    Map<String, double> localVars, {
    Map<String, Map<String, double>>? externalDocs,
    String? currentDoc,
    Map<String, Set<String>>? graph,
  }) {
    var expr = macroContent.trim();
    if (expr.startsWith('=')) {
      expr = expr.substring(1).trim();
    }

    // Check for immediate verification operator ?
    final immediateMatch = RegExp(r'\b([a-zA-Z0-9_\-]+)\.\?([a-zA-Z0-9_\-]+)\b').firstMatch(expr);
    if (immediateMatch != null && externalDocs != null) {
      final docName = immediateMatch.group(1)!;
      final varName = immediateMatch.group(2)!;
      final check = checkImmediateVariableExistence('$docName.?$varName', externalDocs);
      if (!check.exists) {
        return '⚠️ Variable introuvable ($docName.$varName)';
      }
    }

    try {
      final val = evaluateExpression(
        expr,
        localVars,
        externalDocs: externalDocs,
        currentDoc: currentDoc,
        graph: graph,
      );
      if (val == null || val.isNaN) {
        return 'Erreur de calcul ($expr)';
      }
      if (val.isInfinite) {
        return 'Division par zéro';
      }
      if (val == val.roundToDouble()) {
        return val.toInt().toString();
      }
      if (val == val.toInt()) {
        return formatNumber(val);
      }
      return val.toStringAsFixed(4).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    } on CircularDependencyException catch (e) {
      return '⚠️ ${e.toString()}';
    } catch (_) {
      return 'Erreur de calcul ($expr)';
    }
  }

  /// Formats a number cleanly, handling integer rounding and optional thousands separator (e.g. 6 000)
  static String formatNumber(double val, {bool withThousandSeparators = false}) {
    if (val == val.toInt()) {
      final intVal = val.toInt();
      if (!withThousandSeparators || intVal.abs() < 1000) {
        return '$intVal';
      }
      final str = '$intVal';
      final buffer = StringBuffer();
      int count = 0;
      for (int i = str.length - 1; i >= 0; i--) {
        buffer.write(str[i]);
        count++;
        if (count % 3 == 0 && i > 0 && str[i - 1] != '-') {
          buffer.write(' ');
        }
      }
      return buffer.toString().split('').reversed.join('');
    }
    return val.toStringAsFixed(4).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }

  /// Scientific and Greek symbols mapping
  static const Map<String, String> scientificSymbols = {
    'delta': 'δ',
    'Delta': 'Δ',
    'lambda': 'λ',
    'Lambda': 'Λ',
    'lamda': 'λ',
    'epsilon': 'ε',
    'pi': 'π',
    'Pi': 'Π',
    'sigma': 'σ',
    'Sigma': 'Σ',
    'sum': 'Σ',
    'gradient': '∇',
    'gradiant': '∇',
    'nabla': '∇',
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
  static const Map<String, String> greekSymbols = scientificSymbols;

  /// Autocomplete catalog of available formula templates and macros for the Excel-like guide
  static const List<FormulaSuggestion> suggestions = [
    FormulaSuggestion(
      label: '{{=formule}}',
      description: 'Évalue une formule ou calculatrice C',
      template: '{{=somme * 2}}',
      category: 'Calculatrice',
    ),
    FormulaSuggestion(
      label: '{{=Doc.variable}}',
      description: 'Référence interdocument (ex: {{=Maths.somme}})',
      template: '{{=Maths.somme}}',
      category: 'Interdocuments',
    ),
    FormulaSuggestion(
      label: '{{=Doc.?variable}}',
      description: 'Vérification immédiate d\'existence externe',
      template: '{{=Maths.?somme}}',
      category: 'Interdocuments',
    ),
    FormulaSuggestion(
      label: '{int nom = a + b}',
      description: 'Déclare une variable locale C',
      template: '{int somme = a + b;}',
      category: 'Variables',
    ),
    FormulaSuggestion(
      label: 'export int var = val',
      description: 'Exporte une variable pour les autres documents',
      template: '{export int total = 100;}',
      category: 'Variables',
    ),
    FormulaSuggestion(
      label: '{a=2; b=5;}',
      description: 'Assignation de variables multiples C',
      template: '{a=2; b=5;}',
      category: 'Variables',
    ),
    FormulaSuggestion(
      label: '{a, b = 5;}',
      description: 'Initialisation commune multiple (a=5 et b=5)',
      template: '{a, b = 5;}',
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
      description: 'Fraction mathématique centrée',
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
      label: '{{sum(i=1:n)(i)}}',
      description: 'Sommation avec bornes (∑)',
      template: '{{sum(i=1:n)(i)}}',
      category: 'Séries',
    ),
    FormulaSuggestion(
      label: '{{limit(x->0)(f(x))}}',
      description: 'Limite mathématique (lim)',
      template: '{{limit(x->0)(f(x))}}',
      category: 'Analyse',
    ),
    FormulaSuggestion(
      label: '{{derivative(f, x)}}',
      description: 'Dérivée (df/dx)',
      template: '{{derivative(f, x)}}',
      category: 'Analyse',
    ),
    FormulaSuggestion(
      label: '{{gradient(f)}}',
      description: 'Gradient mathématique (∇f)',
      template: '{{gradient(f)}}',
      category: 'Analyse',
    ),
    FormulaSuggestion(
      label: '{{matrix([[a, b], [c, d]])}}',
      description: 'Matrice mathématique',
      template: '{{matrix([[a, b], [c, d]])}}',
      category: 'Algèbre',
    ),
    FormulaSuggestion(
      label: '{{sqrt(x)}}',
      description: 'Racine carrée (√)',
      template: '{{sqrt(x)}}',
      category: 'Mathématiques',
    ),
    FormulaSuggestion(
      label: '{Tableau des résultats}',
      description: 'Crée un emplacement de composant tableau',
      template: '{Tableau des résultats}',
      category: 'Composants',
    ),
    FormulaSuggestion(
      label: '{image="nom.png"}',
      description: 'Incorpore une image native avec légende',
      template: '{image="schema_reseau.png"}',
      category: 'Médias',
    ),
    FormulaSuggestion(
      label: '{video="video.mp4"}',
      description: 'Incorpore une vidéo native avec lecteur',
      template: '{video="experience.mp4"}',
      category: 'Médias',
    ),
    FormulaSuggestion(
      label: '{audio="audio.mp3"}',
      description: 'Incorpore un enregistrement audio',
      template: '{audio="explication.mp3"}',
      category: 'Médias',
    ),
    FormulaSuggestion(
      label: '{{media.?nom}}',
      description: 'Référence un média existant sans duplication',
      template: '{{media.?schema_reseau}}',
      category: 'Médias',
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
          if (next == 0) return double.infinity;
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

    if (token.toLowerCase() == 'det') {
      pos++;
      while (pos < tokens.length && (tokens[pos] == '(' || tokens[pos] == '[')) {
        pos++;
      }
      final a = parseExpression() ?? 0.0;
      while (pos < tokens.length && (tokens[pos] == ',' || tokens[pos] == ']' || tokens[pos] == '[')) {
        pos++;
      }
      final b = parseExpression() ?? 0.0;
      while (pos < tokens.length && (tokens[pos] == ',' || tokens[pos] == ']' || tokens[pos] == '[')) {
        pos++;
      }
      final c = parseExpression() ?? 0.0;
      while (pos < tokens.length && (tokens[pos] == ',' || tokens[pos] == ']' || tokens[pos] == '[')) {
        pos++;
      }
      final d = parseExpression() ?? 0.0;
      while (pos < tokens.length && (tokens[pos] == ']' || tokens[pos] == ')')) {
        pos++;
      }
      return a * d - b * c;
    }

    final numVal = double.tryParse(token);
    if (numVal != null) {
      pos++;
      return numVal;
    }

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
