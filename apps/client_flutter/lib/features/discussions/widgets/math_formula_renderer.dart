import 'package:flutter/material.dart';

/// A native, dynamic, dependency-free mathematical expression renderer for MRixk.
/// Supports natural math writing ($a/b$, $sqrt(x)$, $x^2$, $u_n$, $int_0^1$, etc.)
/// and standard LaTeX commands (\frac, \sqrt, \int, \sum, \lim, greek letters, etc.).
class MathFormulaRenderer extends StatelessWidget {
  final String formula;
  final bool isDisplayMode; // true = centered block formula, false = inline
  final double fontSize;
  final Color? color;
  final String? equationNumber;

  const MathFormulaRenderer({
    super.key,
    required this.formula,
    this.isDisplayMode = false,
    this.fontSize = 16.0,
    this.color,
    this.equationNumber,
  });

  @override
  Widget build(BuildContext context) {
    final cleanExpr = _stripDelimiters(formula).trim();
    if (cleanExpr.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultTextColor = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final textColor = color ?? defaultTextColor;
    final parsed = _MathParser.parse(cleanExpr);

    final mathWidget = _MathNodeWidget(
      node: parsed,
      fontSize: fontSize,
      color: textColor,
    );

    if (!isDisplayMode) {
      return mathWidget;
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFFBFBFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFEAEFF5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: mathWidget,
              ),
            ),
          ),
          if (equationNumber != null && equationNumber!.isNotEmpty) ...[
            const SizedBox(width: 12),
            Text(
              '($equationNumber)',
              style: TextStyle(
                fontFamily: 'serif',
                fontStyle: FontStyle.italic,
                fontSize: fontSize * 0.85,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _stripDelimiters(String raw) {
    var s = raw.trim();
    if (s.startsWith(r'$$') && s.endsWith(r'$$') && s.length >= 4) {
      return s.substring(2, s.length - 2);
    }
    if (s.startsWith(r'$') && s.endsWith(r'$') && s.length >= 2) {
      return s.substring(1, s.length - 1);
    }
    if (s.toLowerCase().startsWith('<math>') && s.toLowerCase().endsWith('</math>')) {
      return s.substring(6, s.length - 7);
    }
    if (s.toLowerCase().startsWith('<formula>') && s.toLowerCase().endsWith('</formula>')) {
      return s.substring(9, s.length - 10);
    }
    return s;
  }
}

// ============================================================================
// Abstract Syntax Tree (AST) for Mathematical Expressions
// ============================================================================

abstract class _MathNode {}

class _RowNode extends _MathNode {
  final List<_MathNode> children;
  _RowNode(this.children);
}

class _TextNode extends _MathNode {
  final String text;
  final bool isVariable;
  final bool isOperator;
  final bool isFunction;
  _TextNode(this.text, {this.isVariable = false, this.isOperator = false, this.isFunction = false});
}

class _FractionNode extends _MathNode {
  final _MathNode numerator;
  final _MathNode denominator;
  _FractionNode(this.numerator, this.denominator);
}

class _RadicalNode extends _MathNode {
  final _MathNode body;
  final _MathNode? degree;
  _RadicalNode(this.body, {this.degree});
}

class _ScriptNode extends _MathNode {
  final _MathNode base;
  final _MathNode? sub;
  final _MathNode? sup;
  _ScriptNode(this.base, {this.sub, this.sup});
}

class _BigOpNode extends _MathNode {
  final String symbol; // '∫', '∑', '∏', 'lim'
  final _MathNode? lower;
  final _MathNode? upper;
  _BigOpNode(this.symbol, {this.lower, this.upper});
}

class _ParenthesesNode extends _MathNode {
  final _MathNode inner;
  final String open;
  final String close;
  _ParenthesesNode(this.inner, {this.open = '(', this.close = ')'});
}

class _MatrixNode extends _MathNode {
  final List<List<_MathNode>> rows;
  final String bracket; // '(', '[', '|'
  _MatrixNode(this.rows, {this.bracket = '('});
}

// ============================================================================
// Parser: converts natural & LaTeX math into AST
// ============================================================================

class _MathParser {
  static final Map<String, String> _greekMap = {
    'alpha': 'α', 'beta': 'β', 'gamma': 'γ', 'delta': 'δ', 'epsilon': 'ε',
    'zeta': 'ζ', 'eta': 'η', 'theta': 'θ', 'iota': 'ι', 'kappa': 'κ',
    'lambda': 'λ', 'mu': 'μ', 'nu': 'ν', 'xi': 'ξ', 'pi': 'π',
    'rho': 'ρ', 'sigma': 'σ', 'tau': 'τ', 'upsilon': 'υ', 'phi': 'φ',
    'chi': 'χ', 'psi': 'ψ', 'omega': 'ω',
    'Gamma': 'Γ', 'Delta': 'Δ', 'Theta': 'Θ', 'Lambda': 'Λ', 'Xi': 'Ξ',
    'Pi': 'Π', 'Sigma': 'Σ', 'Upsilon': 'Υ', 'Phi': 'Φ', 'Psi': 'Ψ', 'Omega': 'Ω',
  };

  static final Map<String, String> _operatorMap = {
    'pm': '±', 'times': '×', 'cdot': '·', 'div': '÷',
    'leq': '≤', 'le': '≤', 'geq': '≥', 'ge': '≥', 'neq': '≠', 'ne': '≠',
    'approx': '≈', 'infty': '∞', 'inf': '∞',
    'in': '∈', 'notin': '∉', 'subset': '⊂', 'cup': '∪', 'cap': '∩',
    'rightarrow': '→', 'to': '→', 'leftarrow': '←',
    'Rightarrow': '⇒', 'Leftarrow': '⇐', 'iff': '⇔',
    'partial': '∂', 'nabla': '∇', 'forall': '∀', 'exists': '∃',
    'empty': '∅', 'circ': '∘',
  };

  static final Set<String> _functions = {
    'sin', 'cos', 'tan', 'arcsin', 'arccos', 'arctan',
    'sinh', 'cosh', 'tanh', 'ln', 'log', 'exp', 'det', 'min', 'max', 'lim'
  };

  static _MathNode parse(String input) {
    final tokens = _tokenize(input);
    final reader = _TokenReader(tokens);
    return _parseExpression(reader);
  }

  static List<String> _tokenize(String s) {
    final tokens = <String>[];
    int i = 0;
    while (i < s.length) {
      final ch = s[i];
      if (ch == ' ' || ch == '\t') {
        i++;
        continue;
      }

      // Backslash command \frac, \sqrt, \alpha, etc.
      if (ch == '\\') {
        int start = i;
        i++;
        while (i < s.length && RegExp(r'[a-zA-Z]').hasMatch(s[i])) {
          i++;
        }
        tokens.add(s.substring(start, i));
        continue;
      }

      // Multi-character numbers e.g. 123.45
      if (RegExp(r'[0-9]').hasMatch(ch)) {
        int start = i;
        while (i < s.length && (RegExp(r'[0-9]').hasMatch(s[i]) || s[i] == '.')) {
          i++;
        }
        tokens.add(s.substring(start, i));
        continue;
      }

      // Multi-character words (functions or variables)
      if (RegExp(r'[a-zA-Z]').hasMatch(ch)) {
        int start = i;
        while (i < s.length && RegExp(r'[a-zA-Z]').hasMatch(s[i])) {
          i++;
        }
        tokens.add(s.substring(start, i));
        continue;
      }

      // Two-character operators like <=, >=, !=, ->, =>
      if (i + 1 < s.length) {
        final pair = s.substring(i, i + 2);
        if (pair == '<=' || pair == '>=' || pair == '!=' || pair == '->' || pair == '=>') {
          tokens.add(pair);
          i += 2;
          continue;
        }
      }

      // Single characters like +, -, *, /, ^, _, {, }, (, ), [, ]
      tokens.add(ch);
      i++;
    }
    return tokens;
  }

  static _MathNode _parseExpression(_TokenReader reader, {String? stopToken}) {
    final children = <_MathNode>[];

    while (!reader.isEnd) {
      if (stopToken != null && reader.peek == stopToken) {
        break;
      }

      final tok = reader.peek;

      // Group end
      if (tok == '}' || tok == ')' || tok == ']') {
        break;
      }

      final node = _parsePrimary(reader);
      if (node != null) {
        if (node is _TextNode && node.text == '=' && children.isNotEmpty && children.last is _TextNode && (children.last as _TextNode).isVariable) {
          final prev = children.removeLast() as _TextNode;
          children.add(_TextNode('${prev.text} = '));
        } else {
          children.add(node);
        }
      }
    }

    if (children.isEmpty) return _TextNode('');
    if (children.length == 1) return children.first;

    // Post-process natural fractions (e.g. A / B where / is a child)
    return _foldNaturalFractions(children);
  }

  static _MathNode _foldNaturalFractions(List<_MathNode> nodes) {
    final result = <_MathNode>[];
    int i = 0;
    while (i < nodes.length) {
      final cur = nodes[i];
      if (cur is _TextNode && cur.text == '/' && i > 0 && i + 1 < nodes.length) {
        final prev = result.removeLast();
        final next = nodes[i + 1];
        result.add(_FractionNode(prev, next));
        i += 2;
        continue;
      }
      result.add(cur);
      i++;
    }

    if (result.length == 1) return result.first;
    return _RowNode(result);
  }

  static _MathNode? _parsePrimary(_TokenReader reader) {
    if (reader.isEnd) return null;
    final token = reader.read();

    // 1. Group in braces: { ... }
    if (token == '{') {
      final inner = _parseExpression(reader, stopToken: '}');
      if (reader.peek == '}') reader.read();
      return _attachScripts(inner, reader);
    }

    // 2. Parentheses: ( ... )
    if (token == '(') {
      final inner = _parseExpression(reader, stopToken: ')');
      if (reader.peek == ')') reader.read();
      final pNode = _ParenthesesNode(inner, open: '(', close: ')');
      return _attachScripts(pNode, reader);
    }

    // 3. Brackets: [ ... ]
    if (token == '[') {
      final inner = _parseExpression(reader, stopToken: ']');
      if (reader.peek == ']') reader.read();
      final pNode = _ParenthesesNode(inner, open: '[', close: ']');
      return _attachScripts(pNode, reader);
    }

    // 4. LaTeX \frac{num}{den} or \dfrac
    if (token == r'\frac' || token == r'\dfrac') {
      final num = _parseArgument(reader);
      final den = _parseArgument(reader);
      final frac = _FractionNode(num, den);
      return _attachScripts(frac, reader);
    }

    // 5. Square root: \sqrt{...} or \sqrt[n]{...} or sqrt(...)
    if (token == r'\sqrt' || token == 'sqrt') {
      _MathNode? degree;
      if (reader.peek == '[') {
        reader.read(); // '['
        degree = _parseExpression(reader, stopToken: ']');
        if (reader.peek == ']') reader.read();
      }
      final body = _parseArgument(reader);
      final rad = _RadicalNode(body, degree: degree);
      return _attachScripts(rad, reader);
    }

    // 6. Integrals: \int, int, \iint, \oint
    if (token == r'\int' || token == 'int' || token == r'\iint' || token == r'\oint') {
      final symbol = token == r'\iint' ? '∬' : token == r'\oint' ? '∮' : '∫';
      _MathNode? lower;
      _MathNode? upper;

      if (reader.peek == '_') {
        reader.read();
        lower = _parseArgument(reader);
      }
      if (reader.peek == '^') {
        reader.read();
        upper = _parseArgument(reader);
      }
      final bigOp = _BigOpNode(symbol, lower: lower, upper: upper);
      return _attachScripts(bigOp, reader);
    }

    // 7. Summations: \sum, sum, \prod, prod, \lim, lim
    if (token == r'\sum' || token == 'sum' || token == r'\prod' || token == 'prod' || token == r'\lim' || token == 'lim') {
      final symbol = (token == r'\sum' || token == 'sum')
          ? '∑'
          : (token == r'\prod' || token == 'prod')
              ? '∏'
              : 'lim';
      _MathNode? lower;
      _MathNode? upper;

      if (reader.peek == '_') {
        reader.read();
        lower = _parseArgument(reader);
      }
      if (reader.peek == '^') {
        reader.read();
        upper = _parseArgument(reader);
      }
      final bigOp = _BigOpNode(symbol, lower: lower, upper: upper);
      return _attachScripts(bigOp, reader);
    }

    // 8. Matrix: \begin{pmatrix} or matrix(...)
    if (token == r'\begin' && reader.peek == '{') {
      reader.read(); // '{'
      final env = reader.read();
      if (reader.peek == '}') reader.read();

      if (env.contains('matrix')) {
        final bracket = env == 'bmatrix' ? '[' : env == 'vmatrix' ? '|' : '(';
        final rows = _parseMatrixRows(reader, env);
        return _MatrixNode(rows, bracket: bracket);
      }
    }

    // 9. Standard commands or greek letters
    final name = token.startsWith('\\') ? token.substring(1) : token;

    if (_greekMap.containsKey(name)) {
      return _attachScripts(_TextNode(_greekMap[name]!, isVariable: true), reader);
    }
    if (_operatorMap.containsKey(name)) {
      return _attachScripts(_TextNode(_operatorMap[name]!, isOperator: true), reader);
    }
    if (_functions.contains(name)) {
      return _attachScripts(_TextNode(name, isFunction: true), reader);
    }

    // Operators and special punctuation
    if (token == '<=') return _TextNode('≤', isOperator: true);
    if (token == '>=') return _TextNode('≥', isOperator: true);
    if (token == '!=') return _TextNode('≠', isOperator: true);
    if (token == '->') return _TextNode('→', isOperator: true);
    if (token == '=>') return _TextNode('⇒', isOperator: true);
    if (token == '*') return _TextNode('·', isOperator: true);
    if (token == '+' || token == '-' || token == '=' || token == '<' || token == '>') {
      return _TextNode(token, isOperator: true);
    }

    // Numbers
    if (RegExp(r'^[0-9]+(\.[0-9]+)?$').hasMatch(token)) {
      return _attachScripts(_TextNode(token), reader);
    }

    // Latin letters / variable names
    final isVar = RegExp(r'^[a-zA-Z]$').hasMatch(token);
    return _attachScripts(_TextNode(token, isVariable: isVar), reader);
  }

  static _MathNode _parseArgument(_TokenReader reader) {
    if (reader.isEnd) return _TextNode('');
    if (reader.peek == '{') {
      reader.read(); // '{'
      final inner = _parseExpression(reader, stopToken: '}');
      if (reader.peek == '}') reader.read();
      return inner;
    }
    if (reader.peek == '(') {
      reader.read(); // '('
      final inner = _parseExpression(reader, stopToken: ')');
      if (reader.peek == ')') reader.read();
      return inner;
    }
    // Single token argument (e.g. \sqrt 2 or x^2)
    final node = _parsePrimary(reader);
    return node ?? _TextNode('');
  }

  static _MathNode _attachScripts(_MathNode base, _TokenReader reader) {
    _MathNode? sub;
    _MathNode? sup;

    while (!reader.isEnd && (reader.peek == '^' || reader.peek == '_')) {
      final op = reader.read();
      if (op == '^') {
        sup = _parseArgument(reader);
      } else if (op == '_') {
        sub = _parseArgument(reader);
      }
    }

    if (sub == null && sup == null) return base;
    return _ScriptNode(base, sub: sub, sup: sup);
  }

  static List<List<_MathNode>> _parseMatrixRows(_TokenReader reader, String env) {
    final rows = <List<_MathNode>>[];
    var currentRow = <_MathNode>[];

    while (!reader.isEnd) {
      if (reader.peek == r'\end') {
        reader.read(); // '\end'
        if (reader.peek == '{') {
          reader.read();
          reader.read(); // env
          if (reader.peek == '}') reader.read();
        }
        break;
      }

      if (reader.peek == '&') {
        reader.read();
        continue;
      }
      if (reader.peek == r'\\') {
        reader.read();
        rows.add(List.from(currentRow));
        currentRow.clear();
        continue;
      }

      final cell = _parseExpression(reader, stopToken: '&');
      currentRow.add(cell);
      if (reader.peek == '&') {
        reader.read();
      }
    }

    if (currentRow.isNotEmpty) {
      rows.add(currentRow);
    }
    return rows;
  }
}

class _TokenReader {
  final List<String> _tokens;
  int _idx = 0;

  _TokenReader(this._tokens);

  bool get isEnd => _idx >= _tokens.length;
  String get peek => isEnd ? '' : _tokens[_idx];

  String read() {
    if (isEnd) return '';
    return _tokens[_idx++];
  }
}

// ============================================================================
// Visual Widget Tree Renderer for AST
// ============================================================================

class _MathNodeWidget extends StatelessWidget {
  final _MathNode node;
  final double fontSize;
  final Color color;

  const _MathNodeWidget({
    required this.node,
    required this.fontSize,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (node is _RowNode) {
      final row = node as _RowNode;
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: row.children
            .map((c) => _MathNodeWidget(node: c, fontSize: fontSize, color: color))
            .toList(),
      );
    }

    if (node is _TextNode) {
      final tn = node as _TextNode;
      if (tn.isOperator) {
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: fontSize * 0.18),
          child: Text(
            tn.text,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        );
      }
      if (tn.isFunction) {
        return Padding(
          padding: EdgeInsets.only(right: fontSize * 0.15),
          child: Text(
            tn.text,
            style: TextStyle(
              fontSize: fontSize,
              fontFamily: 'serif',
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        );
      }
      return Text(
        tn.text,
        style: TextStyle(
          fontSize: fontSize,
          fontFamily: 'serif',
          fontStyle: tn.isVariable ? FontStyle.italic : FontStyle.normal,
          fontWeight: tn.isVariable ? FontWeight.w600 : FontWeight.normal,
          color: color,
        ),
      );
    }

    if (node is _FractionNode) {
      final fn = node as _FractionNode;
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: fontSize * 0.15),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: _MathNodeWidget(
                node: fn.numerator,
                fontSize: fontSize * 0.88,
                color: color,
              ),
            ),
            Container(
              height: 1.4,
              constraints: BoxConstraints(minWidth: fontSize * 0.8),
              color: color,
            ),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: _MathNodeWidget(
                node: fn.denominator,
                fontSize: fontSize * 0.88,
                color: color,
              ),
            ),
          ],
        ),
      );
    }

    if (node is _RadicalNode) {
      final rn = node as _RadicalNode;
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: fontSize * 0.1),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (rn.degree != null)
              Transform.translate(
                offset: Offset(fontSize * 0.15, -fontSize * 0.25),
                child: _MathNodeWidget(
                  node: rn.degree!,
                  fontSize: fontSize * 0.65,
                  color: color,
                ),
              ),
            Text(
              '√',
              style: TextStyle(
                fontSize: fontSize * 1.35,
                fontWeight: FontWeight.w300,
                color: color,
                height: 1.0,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: color, width: 1.4)),
              ),
              child: _MathNodeWidget(
                node: rn.body,
                fontSize: fontSize,
                color: color,
              ),
            ),
          ],
        ),
      );
    }

    if (node is _BigOpNode) {
      final bo = node as _BigOpNode;
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: fontSize * 0.2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (bo.upper != null)
              _MathNodeWidget(
                node: bo.upper!,
                fontSize: fontSize * 0.68,
                color: color,
              ),
            Text(
              bo.symbol,
              style: TextStyle(
                fontSize: fontSize * 1.6,
                fontWeight: FontWeight.w200,
                color: color,
                height: 1.0,
              ),
            ),
            if (bo.lower != null)
              _MathNodeWidget(
                node: bo.lower!,
                fontSize: fontSize * 0.68,
                color: color,
              ),
          ],
        ),
      );
    }

    if (node is _ScriptNode) {
      final sn = node as _ScriptNode;
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _MathNodeWidget(node: sn.base, fontSize: fontSize, color: color),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (sn.sup != null)
                Transform.translate(
                  offset: Offset(0, -fontSize * 0.35),
                  child: _MathNodeWidget(
                    node: sn.sup!,
                    fontSize: fontSize * 0.7,
                    color: color,
                  ),
                ),
              if (sn.sub != null)
                Transform.translate(
                  offset: Offset(0, fontSize * 0.2),
                  child: _MathNodeWidget(
                    node: sn.sub!,
                    fontSize: fontSize * 0.7,
                    color: color,
                  ),
                ),
            ],
          ),
        ],
      );
    }

    if (node is _ParenthesesNode) {
      final pn = node as _ParenthesesNode;
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            pn.open,
            style: TextStyle(
              fontSize: fontSize * 1.15,
              fontWeight: FontWeight.w300,
              color: color,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.5),
            child: _MathNodeWidget(node: pn.inner, fontSize: fontSize, color: color),
          ),
          Text(
            pn.close,
            style: TextStyle(
              fontSize: fontSize * 1.15,
              fontWeight: FontWeight.w300,
              color: color,
            ),
          ),
        ],
      );
    }

    if (node is _MatrixNode) {
      final mn = node as _MatrixNode;
      final openChar = mn.bracket;
      final closeChar = openChar == '(' ? ')' : openChar == '[' ? ']' : '|';

      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(openChar, style: TextStyle(fontSize: fontSize * 1.8, fontWeight: FontWeight.w200, color: color)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: mn.rows.map((r) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: r.map((c) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: _MathNodeWidget(node: c, fontSize: fontSize, color: color),
                      );
                    }).toList(),
                  ),
                );
              }).toList(),
            ),
          ),
          Text(closeChar, style: TextStyle(fontSize: fontSize * 1.8, fontWeight: FontWeight.w200, color: color)),
        ],
      );
    }

    return const SizedBox.shrink();
  }
}
