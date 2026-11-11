import 'package:flutter/material.dart';
import '../../../core/services/formula_engine.dart';
import '../../../core/theme/app_theme.dart';

/// Sanitizes untrusted HTML inputs to strictly prevent script injection or unsafe attributes.
String sanitizeHtml(String input) {
  var sanitized = input;
  sanitized = sanitized.replaceAll(
    RegExp(r'<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>', caseSensitive: false),
    '',
  );
  sanitized = sanitized.replaceAll(
    RegExp(r'<iframe\b[^<]*(?:(?!<\/iframe>)<[^<]*)*<\/iframe>', caseSensitive: false),
    '',
  );
  sanitized = sanitized.replaceAll(
    RegExp(r'<object\b[^<]*(?:(?!<\/object>)<[^<]*)*<\/object>', caseSensitive: false),
    '',
  );
  sanitized = sanitized.replaceAll(RegExp(r'<embed\b[^>]*>', caseSensitive: false), '');
  sanitized = sanitized.replaceAll(
    RegExp(r'\bon\w+\s*=\s*(?:"[^"]*"|[^>\s]+)', caseSensitive: false),
    '',
  );
  sanitized = sanitized.replaceAll(RegExp(r'javascript:[^\s"<>]+', caseSensitive: false), '');
  return sanitized;
}

/// Native Flutter renderer for Word-style rich text, Macro components, Safe HTML, Math, Tables, and Diagrams.
class GroupNoteRenderer extends StatelessWidget {
  final String content;
  final Map<String, String> components;
  final double lineSpacing;
  final double paragraphSpacing;
  final void Function(String componentName)? onEditComponent;
  final VoidCallback? onStartEditing;

  const GroupNoteRenderer({
    super.key,
    required this.content,
    this.components = const {},
    this.lineSpacing = 1.5,
    this.paragraphSpacing = 12.0,
    this.onEditComponent,
    this.onStartEditing,
  });

  @override
  Widget build(BuildContext context) {
    if (content.trim().isEmpty) {
      return _buildEmptyState(context);
    }

    // 1. Compute variables from C-style declarations: {a=2; b=5;}, {int somme=a+b;}
    final computedVars = FormulaEngine.extractAndComputeVariables(content);

    // 2. Resolve component macros and single brace references {Titre du tableau}
    final resolvedContent = _resolveAllVariablesAndMacros(content, components, computedVars);

    // 3. Sanitize safely
    final safeContent = sanitizeHtml(resolvedContent);

    // 4. Parse into visual content blocks
    final blocks = _parseBlocks(safeContent, computedVars);

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      itemCount: blocks.length,
      itemBuilder: (context, index) {
        final block = blocks[index];
        return _buildBlock(context, block, computedVars);
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
              ),
              child: const Icon(Icons.article_outlined, size: 54, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 20),
            const Text(
              'Document vide',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Ce bloc-note ne contient aucun texte pour le moment. Rédigez normalement dans « Éditer » en mode Word, ou insérez vos variables et formules mathématiques.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
                height: 1.45,
              ),
            ),
            if (onStartEditing != null) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onStartEditing,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                icon: const Icon(Icons.edit_note_rounded, size: 20),
                label: const Text('Commencer la rédaction', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Resolves both double-curly {{name}} and single-curly {Titre du tableau} references,
  /// as well as scientific symbols and calculator formulas.
  String _resolveAllVariablesAndMacros(
    String text,
    Map<String, String> comps,
    Map<String, double> vars,
  ) {
    var result = text;

    // 1. Resolve scientific symbols: {{delta}}, {{lambda}}, {{gradient}}, etc.
    FormulaEngine.scientificSymbols.forEach((sym, unicode) {
      result = result.replaceAll('{{$sym}}', unicode);
    });

    // 2. Resolve calculator expressions {{=formule}} or {{=somme * 2}}
    final calcRegex = RegExp(r'\{\{(=[^{}]+)\}\}');
    result = result.replaceAllMapped(calcRegex, (match) {
      final expr = match.group(1)!;
      final valStr = FormulaEngine.evaluateCalculatorMacro(expr, vars);
      return ' <calc val="$valStr" expr="${expr.replaceAll('"', '')}"/> ';
    });

    // 3. Resolve components declared as {{id="Titre"; <table>...</table>}}
    final compDeclRegex = RegExp(r'\{\{id="([^"]+)";\s*(.*?)\}\}', dotAll: true);
    for (final match in compDeclRegex.allMatches(text)) {
      final compId = match.group(1);
      final compPayload = match.group(2);
      if (compId != null && compPayload != null && !comps.containsKey(compId)) {
        comps[compId] = compPayload.trim();
      }
    }

    // 4. Resolve double curly {{name}} from components map
    final macroRegex = RegExp(r'\{\{([a-zA-Z0-9_\-\s]+)\}\}');
    result = result.replaceAllMapped(macroRegex, (match) {
      final rawName = match.group(1)?.trim();
      if (rawName != null && comps.containsKey(rawName)) {
        return '\n<!-- macro:$rawName -->\n${comps[rawName]}\n<!-- endmacro -->\n';
      }
      return match.group(0) ?? '';
    });

    // 5. Resolve single curly {Titre du tableau} if matching a component
    final singleBraceRegex = RegExp(r'\{([^{}]+)\}');
    result = result.replaceAllMapped(singleBraceRegex, (match) {
      final inner = match.group(1)?.trim();
      if (inner != null && comps.containsKey(inner)) {
        return '\n<!-- macro:$inner -->\n${comps[inner]}\n<!-- endmacro -->\n';
      }
      return match.group(0) ?? '';
    });

    return result;
  }

  Widget _buildBlock(BuildContext context, _ContentBlock block, Map<String, double> vars) {
    Widget child;

    switch (block.type) {
      case _BlockType.heading:
        child = _buildHeading(block);
        break;

      case _BlockType.hr:
        return Padding(
          padding: EdgeInsets.symmetric(vertical: paragraphSpacing / 2),
          child: const Divider(color: Color(0xFFE2E8F0), thickness: 1),
        );

      case _BlockType.blockquote:
        child = Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: const BoxDecoration(
            color: Color(0xFFF0FDF4),
            border: Border(left: BorderSide(color: AppTheme.secondary, width: 4)),
            borderRadius: BorderRadius.only(
              topRight: Radius.circular(8),
              bottomRight: Radius.circular(8),
            ),
          ),
          child: Text(
            block.text,
            style: TextStyle(
              fontSize: 13.5,
              fontStyle: FontStyle.italic,
              color: const Color(0xFF065F46),
              height: lineSpacing,
            ),
          ),
        );
        break;

      case _BlockType.math:
        child = _buildMathCard(block.text, block.macroName);
        break;

      case _BlockType.table:
        child = _buildTableCard(block.tableData!, block.macroName);
        break;

      case _BlockType.diagram:
        child = _buildFlowchartDiagram(block.text, block.macroName);
        break;

      case _BlockType.graph:
        child = _buildBarGraph(
          block.title ?? 'Graphique des Métriques',
          block.graphData!,
          block.macroName,
        );
        break;

      case _BlockType.bulletList:
        child = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 6, right: 8),
              child: Icon(Icons.circle, size: 6, color: AppTheme.primary),
            ),
            Expanded(
              child: _buildRichParagraph(block.text),
            ),
          ],
        );
        break;

      case _BlockType.numberedList:
        child = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                block.listPrefix ?? '1.',
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary),
              ),
            ),
            Expanded(
              child: _buildRichParagraph(block.text),
            ),
          ],
        );
        break;

      case _BlockType.checkboxList:
        child = Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              block.isChecked == true ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
              size: 18,
              color: block.isChecked == true ? AppTheme.primary : const Color(0xFF94A3B8),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildRichParagraph(block.text),
            ),
          ],
        );
        break;

      case _BlockType.variableBadge:
        child = Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFBFDBFE)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.bolt_rounded, size: 16, color: Color(0xFF2563EB)),
              const SizedBox(width: 6),
              Text(
                block.text,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E40AF),
                ),
              ),
            ],
          ),
        );
        break;

      case _BlockType.code:
        child = Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            block.text,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12.5,
              color: Color(0xFF38BDF8),
              height: 1.3,
            ),
          ),
        );
        break;

      case _BlockType.paragraph:
      default:
        if (block.text.trim().isEmpty) return SizedBox(height: paragraphSpacing / 2);
        child = _buildRichParagraph(block.text, align: block.alignment);
        break;
    }

    return Padding(
      padding: EdgeInsets.only(bottom: paragraphSpacing),
      child: child,
    );
  }

  Widget _buildHeading(_ContentBlock block) {
    final level = block.headingLevel ?? 1;
    double fontSize;
    FontWeight weight;
    Color color;

    switch (level) {
      case 1:
        fontSize = 22;
        weight = FontWeight.bold;
        color = const Color(0xFF0F172A);
        break;
      case 2:
        fontSize = 19;
        weight = FontWeight.bold;
        color = const Color(0xFF1E293B);
        break;
      case 3:
        fontSize = 17;
        weight = FontWeight.w700;
        color = const Color(0xFF334155);
        break;
      case 4:
        fontSize = 15.5;
        weight = FontWeight.w700;
        color = const Color(0xFF334155);
        break;
      case 5:
        fontSize = 14.5;
        weight = FontWeight.w600;
        color = const Color(0xFF475569);
        break;
      case 6:
        fontSize = 13.5;
        weight = FontWeight.w600;
        color = const Color(0xFF475569);
        break;
      case 7:
        fontSize = 12.5;
        weight = FontWeight.w600;
        color = const Color(0xFF64748B);
        break;
      case 8:
      default:
        fontSize = 11.5;
        weight = FontWeight.w500;
        color = const Color(0xFF64748B);
        break;
    }

    return Text(
      block.text,
      textAlign: block.alignment ?? TextAlign.left,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: weight,
        color: block.textColor ?? color,
        fontFamily: block.fontFamily ?? 'Inter',
        letterSpacing: level <= 2 ? -0.4 : 0.0,
      ),
    );
  }

  /// Builds interactive RichText parsing inline tags, math formulas, indices and exponents
  Widget _buildRichParagraph(String rawText, {TextAlign? align}) {
    var text = rawText;

    // Replace Markdown
    text = text.replaceAllMapped(RegExp(r'\*\*(.*?)\*\*'), (m) => '<b>${m.group(1)}</b>');
    text = text.replaceAllMapped(RegExp(r'\*(.*?)\*'), (m) => '<i>${m.group(1)}</i>');
    text = text.replaceAllMapped(RegExp(r'`(.*?)`'), (m) => '<code>${m.group(1)}</code>');

    // Replace subscripts: {{A_1}} -> <sub>
    text = text.replaceAllMapped(RegExp(r'\{\{([a-zA-Z0-9]+)_([a-zA-Z0-9]+)\}\}'), (m) {
      return '${m.group(1)}<sub val="${m.group(2)}"/>';
    });

    // Replace superscripts: {{A^7}} -> <sup>
    text = text.replaceAllMapped(RegExp(r'\{\{([a-zA-Z0-9]+)\^([a-zA-Z0-9]+)\}\}'), (m) {
      return '${m.group(1)}<sup val="${m.group(2)}"/>';
    });

    // Replace fractions: {{(a+b)/(a-b)}}
    text = text.replaceAllMapped(RegExp(r'\{\{\((.*?)\)\/\((.*?)\)\}\}'), (m) {
      return '<frac num="${m.group(1)}" den="${m.group(2)}"/>';
    });

    // Replace integrals: {{integral(1:2)(2x^2 dx)}}
    text = text.replaceAllMapped(RegExp(r'\{\{integral\((.*?):(.*?)\)\((.*?)\)\}\}'), (m) {
      return '<integral from="${m.group(1)}" to="${m.group(2)}" expr="${m.group(3)}"/>';
    });

    // Replace sums: {{sigma(k=1:n)(k^2)}} or {{sum(1:n)(x)}}
    text = text.replaceAllMapped(RegExp(r'\{\{(sigma|sum)\((.*?):(.*?)\)\((.*?)\)\}\}'), (m) {
      return '<sigma from="${m.group(2)}" to="${m.group(3)}" expr="${m.group(4)}"/>';
    });

    // Replace square roots: {{sqrt(x+1)}}
    text = text.replaceAllMapped(RegExp(r'\{\{sqrt\((.*?)\)\}\}'), (m) {
      return '<sqrt expr="${m.group(1)}"/>';
    });

    final spans = <InlineSpan>[];
    final tagRegex = RegExp(
      r'<(b|i|u|mark|code|font|sub|sup|calc|frac|integral|sigma|sqrt)\b([^>]*)>(.*?)<\/\1>|<(sub|sup|calc|frac|integral|sigma|sqrt)\b([^>]*)\/>',
      caseSensitive: false,
      dotAll: true,
    );

    int lastIndex = 0;

    for (final match in tagRegex.allMatches(text)) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(text: text.substring(lastIndex, match.start)));
      }

      final tag = (match.group(1) ?? match.group(4))?.toLowerCase();
      final attrs = match.group(2) ?? match.group(5) ?? '';
      final innerText = match.group(3) ?? '';

      switch (tag) {
        case 'b':
          spans.add(TextSpan(text: innerText, style: const TextStyle(fontWeight: FontWeight.bold)));
          break;
        case 'i':
          spans.add(TextSpan(text: innerText, style: const TextStyle(fontStyle: FontStyle.italic)));
          break;
        case 'u':
          spans.add(TextSpan(text: innerText, style: const TextStyle(decoration: TextDecoration.underline)));
          break;
        case 'mark':
          final colorMatch = RegExp(r'color="([^"]+)"').firstMatch(attrs);
          final markColor = colorMatch != null ? _parseColor(colorMatch.group(1)!) : const Color(0xFFFEF08A);
          spans.add(TextSpan(
            text: innerText,
            style: TextStyle(backgroundColor: markColor, color: const Color(0xFF854D0E)),
          ));
          break;
        case 'font':
          final colorMatch = RegExp(r'color="([^"]+)"').firstMatch(attrs);
          final faceMatch = RegExp(r'face="([^"]+)"').firstMatch(attrs);
          final fontColor = colorMatch != null ? _parseColor(colorMatch.group(1)!) : null;
          spans.add(TextSpan(
            text: innerText,
            style: TextStyle(color: fontColor, fontFamily: faceMatch?.group(1)),
          ));
          break;
        case 'sub':
          final val = RegExp(r'val="([^"]+)"').firstMatch(attrs)?.group(1) ?? innerText;
          spans.add(WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Transform.translate(
              offset: const Offset(0, 4),
              child: Text(
                _toSubscriptUnicode(val),
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primary),
              ),
            ),
          ));
          break;
        case 'sup':
          final val = RegExp(r'val="([^"]+)"').firstMatch(attrs)?.group(1) ?? innerText;
          spans.add(WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Transform.translate(
              offset: const Offset(0, -5),
              child: Text(
                _toSuperscriptUnicode(val),
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primary),
              ),
            ),
          ));
          break;
        case 'calc':
          final val = RegExp(r'val="([^"]+)"').firstMatch(attrs)?.group(1) ?? '';
          final expr = RegExp(r'expr="([^"]+)"').firstMatch(attrs)?.group(1) ?? '';
          spans.add(WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)]),
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [BoxShadow(color: Color(0x18000000), blurRadius: 3, offset: Offset(0, 1))],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calculate_rounded, size: 13, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    val,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  if (expr.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Text(
                      '($expr)',
                      style: const TextStyle(fontSize: 10, color: Color(0xFFBFDBFE)),
                    ),
                  ],
                ],
              ),
            ),
          ));
          break;
        case 'frac':
          final num = RegExp(r'num="([^"]+)"').firstMatch(attrs)?.group(1) ?? '';
          final den = RegExp(r'den="([^"]+)"').firstMatch(attrs)?.group(1) ?? '';
          spans.add(WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(num, style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, fontWeight: FontWeight.w600)),
                  Container(height: 1.2, width: (num.length > den.length ? num.length : den.length) * 8.0 + 8.0, color: Colors.black87),
                  Text(den, style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ));
          break;
        case 'integral':
          final from = RegExp(r'from="([^"]+)"').firstMatch(attrs)?.group(1) ?? '';
          final to = RegExp(r'to="([^"]+)"').firstMatch(attrs)?.group(1) ?? '';
          final expr = RegExp(r'expr="([^"]+)"').firstMatch(attrs)?.group(1) ?? '';
          spans.add(WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(to, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                      const Text('∫', style: TextStyle(fontSize: 22, height: 0.9, fontWeight: FontWeight.w300)),
                      Text(from, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(width: 4),
                  Text(expr, style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ));
          break;
        case 'sigma':
          final from = RegExp(r'from="([^"]+)"').firstMatch(attrs)?.group(1) ?? '';
          final to = RegExp(r'to="([^"]+)"').firstMatch(attrs)?.group(1) ?? '';
          final expr = RegExp(r'expr="([^"]+)"').firstMatch(attrs)?.group(1) ?? '';
          spans.add(WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(to, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                      const Text('∑', style: TextStyle(fontSize: 20, height: 0.9, fontWeight: FontWeight.w400)),
                      Text(from, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(width: 4),
                  Text(expr, style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ));
          break;
        case 'sqrt':
          final expr = RegExp(r'expr="([^"]+)"').firstMatch(attrs)?.group(1) ?? '';
          spans.add(WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('√', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: Colors.black87, width: 1.2)),
                    ),
                    child: Text(expr, style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                  ),
                ],
              ),
            ),
          ));
          break;
        case 'code':
          spans.add(TextSpan(
            text: innerText,
            style: const TextStyle(
              fontFamily: 'monospace',
              backgroundColor: Color(0xFFF1F5F9),
              color: Color(0xFF0284C7),
            ),
          ));
          break;
        default:
          spans.add(TextSpan(text: innerText));
      }
      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      spans.add(TextSpan(text: text.substring(lastIndex)));
    }

    return Text.rich(
      TextSpan(
        style: TextStyle(
          fontSize: 14,
          color: const Color(0xFF334155),
          height: lineSpacing,
        ),
        children: spans,
      ),
      textAlign: align ?? TextAlign.left,
    );
  }

  static String _toSubscriptUnicode(String s) {
    const normal = '0123456789aehijklmnoprstuvx';
    const sub = '₀₁₂₃₄₅₆₇₈₉ₐₑₕᵢⱼₖₗₘₙₒₚᵣₛₜᵤᵥₓ';
    var out = '';
    for (int i = 0; i < s.length; i++) {
      final idx = normal.indexOf(s[i].toLowerCase());
      out += idx != -1 ? sub[idx] : s[i];
    }
    return out;
  }

  static String _toSuperscriptUnicode(String s) {
    const normal = '0123456789+-=()ni';
    const sup = '⁰¹²³⁴⁵⁶⁷⁸⁹⁺⁻⁼⁽⁾ⁿⁱ';
    var out = '';
    for (int i = 0; i < s.length; i++) {
      final idx = normal.indexOf(s[i]);
      out += idx != -1 ? sup[idx] : s[i];
    }
    return out;
  }

  Color _parseColor(String hex) {
    var c = hex.replaceAll('#', '').trim();
    if (c.length == 6) c = 'FF$c';
    final val = int.tryParse(c, radix: 16);
    return val != null ? Color(val) : const Color(0xFF0F172A);
  }

  Widget _buildMathCard(String formula, String? macroName) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.functions_rounded, size: 16, color: AppTheme.primary),
              const SizedBox(width: 6),
              Text(
                macroName != null ? 'Composant Formule : {{$macroName}}' : 'Formule Mathématique Exécutée',
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.primary),
              ),
              const Spacer(),
              if (macroName != null && onEditComponent != null)
                InkWell(
                  onTap: () => onEditComponent!(macroName),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('Modifier', style: TextStyle(fontSize: 10, color: AppTheme.primary, fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Center(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: _renderMathExpression(formula.trim()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _renderMathExpression(String expr) {
    if (expr.contains(r'\frac') && expr.contains(r'\sqrt')) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text('x = ', style: TextStyle(fontSize: 18, fontStyle: FontStyle.italic, fontWeight: FontWeight.bold)),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('-b ± ', style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic, fontWeight: FontWeight.bold)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: Colors.black87, width: 1.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text('√', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                        Text('(b² - 4ac)', style: TextStyle(fontSize: 15, fontStyle: FontStyle.italic)),
                      ],
                    ),
                  ),
                ],
              ),
              Container(margin: const EdgeInsets.symmetric(vertical: 3), height: 1.5, width: 130, color: Colors.black87),
              const Text('2a', style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      );
    }

    if (expr.contains(r'\int')) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text('+∞', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
              Text('∫', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w200, height: 0.9)),
              Text('-∞', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(width: 6),
          const Text('e⁻ˣ² dx  =  ', style: TextStyle(fontSize: 17, fontStyle: FontStyle.italic, fontWeight: FontWeight.w600)),
          const Text('√π', style: TextStyle(fontSize: 18, fontStyle: FontStyle.italic, fontWeight: FontWeight.bold)),
        ],
      );
    }

    if (expr.contains(r'\sum')) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text('n', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              Text('∑', style: TextStyle(fontSize: 28, height: 0.9, fontWeight: FontWeight.w400)),
              Text('k=1', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(width: 6),
          const Text('k  =  ', style: TextStyle(fontSize: 17, fontStyle: FontStyle.italic, fontWeight: FontWeight.w600)),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('n(n + 1)', style: TextStyle(fontSize: 15, fontStyle: FontStyle.italic)),
              Container(margin: const EdgeInsets.symmetric(vertical: 2), height: 1.5, width: 65, color: Colors.black87),
              const Text('2', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      );
    }

    final cleanExpr = expr
        .replaceAll(r'\frac', '')
        .replaceAll(r'\sqrt', '√')
        .replaceAll(r'\pm', '±')
        .replaceAll(r'\infty', '∞')
        .replaceAll('{', '(')
        .replaceAll('}', ')');

    return Text(
      cleanExpr,
      style: const TextStyle(
        fontSize: 16,
        fontFamily: 'serif',
        fontStyle: FontStyle.italic,
        fontWeight: FontWeight.bold,
        color: Color(0xFF0F172A),
      ),
    );
  }

  Widget _buildTableCard(_TableData data, String? macroName) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (macroName != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
              child: Row(
                children: [
                  const Icon(Icons.table_chart_rounded, size: 15, color: Color(0xFF0D9488)),
                  const SizedBox(width: 6),
                  Text(
                    'Tableau : {{$macroName}}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0D9488)),
                  ),
                  const Spacer(),
                  if (onEditComponent != null)
                    InkWell(
                      onTap: () => onEditComponent!(macroName),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDFA),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('Modifier', style: TextStyle(fontSize: 10, color: Color(0xFF0D9488), fontWeight: FontWeight.bold)),
                      ),
                    ),
                ],
              ),
            ),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: MaterialStateProperty.all(const Color(0xFFF1F5F9)),
                headingTextStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
                dataTextStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF334155)),
                horizontalMargin: 16,
                columnSpacing: 24,
                columns: data.headers.map((h) => DataColumn(label: Text(h))).toList(),
                rows: data.rows.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final row = entry.value;
                  return DataRow(
                    color: MaterialStateProperty.all(idx.isEven ? Colors.white : const Color(0xFFF8FAFC)),
                    cells: row.map((cell) => DataCell(Text(cell))).toList(),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlowchartDiagram(String text, String? macroName) {
    final nodes = <String>[];
    final stepMatches = RegExp(r'\[(.*?)\]').allMatches(text);
    for (final match in stepMatches) {
      nodes.add(match.group(1) ?? '');
    }

    if (nodes.isEmpty) {
      nodes.addAll(text.split('->').map((s) => s.trim()));
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_tree_outlined, size: 18, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(
                macroName != null ? 'Organigramme : {{$macroName}}' : 'Organigramme & Flux Dynamique',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primary),
              ),
              const Spacer(),
              if (macroName != null && onEditComponent != null)
                InkWell(
                  onTap: () => onEditComponent!(macroName),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('Modifier', style: TextStyle(fontSize: 10, color: AppTheme.primary, fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (int i = 0; i < nodes.length; i++) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: i == 0
                            ? [const Color(0xFF3B82F6), const Color(0xFF2563EB)]
                            : i == nodes.length - 1
                                ? [const Color(0xFF10B981), const Color(0xFF059669)]
                                : [Colors.white, const Color(0xFFF1F5F9)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: (i == 0 || i == nodes.length - 1)
                            ? Colors.transparent
                            : const Color(0xFFCBD5E1),
                      ),
                      boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 4, offset: Offset(0, 2))],
                    ),
                    child: Text(
                      nodes[i],
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: (i == 0 || i == nodes.length - 1) ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                  ),
                  if (i < nodes.length - 1)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: [
                          Container(width: 14, height: 2, color: const Color(0xFF94A3B8)),
                          const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Color(0xFF94A3B8)),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarGraph(String title, List<MapEntry<String, double>> items, String? macroName) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart_rounded, size: 18, color: AppTheme.secondary),
              const SizedBox(width: 8),
              Text(
                macroName != null ? '$title ($macroName)' : title,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const Spacer(),
              if (macroName != null && onEditComponent != null)
                InkWell(
                  onTap: () => onEditComponent!(macroName),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('Modifier', style: TextStyle(fontSize: 10, color: Color(0xFFB45309), fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          ...items.map((item) {
            final percentage = (item.value / 100.0).clamp(0.0, 1.0);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(item.key, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                      Text('${item.value.toInt()}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                    ],
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: percentage,
                      minHeight: 8,
                      backgroundColor: const Color(0xFFF1F5F9),
                      valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  List<_ContentBlock> _parseBlocks(String input, Map<String, double> vars) {
    final blocks = <_ContentBlock>[];
    final lines = input.split('\n');

    String? currentMacroName;

    int i = 0;
    while (i < lines.length) {
      var line = lines[i].trim();

      if (line.startsWith('<!-- macro:')) {
        currentMacroName = line.replaceAll('<!-- macro:', '').replaceAll('-->', '').trim();
        i++;
        continue;
      }
      if (line == '<!-- endmacro -->') {
        currentMacroName = null;
        i++;
        continue;
      }

      // Check for C variable definitions line: {a=2; b=5;}
      final varDeclRegex = RegExp(r'^\{([a-zA-Z_0-9,\s=;+\-*\/%^.]+)\}$');
      if (varDeclRegex.hasMatch(line) && !line.startsWith('{Titre') && !line.startsWith('{{')) {
        final inner = varDeclRegex.firstMatch(line)!.group(1)!.trim();
        blocks.add(_ContentBlock(
          type: _BlockType.variableBadge,
          text: 'Variables C : $inner',
        ));
        i++;
        continue;
      }

      // Table detection
      if (line.toLowerCase().startsWith('<table')) {
        final tableLines = <String>[line];
        i++;
        while (i < lines.length && !lines[i].toLowerCase().contains('</table>')) {
          tableLines.add(lines[i]);
          i++;
        }
        if (i < lines.length) tableLines.add(lines[i]);
        final tableData = _parseTable(tableLines.join('\n'));
        blocks.add(_ContentBlock(type: _BlockType.table, text: '', macroName: currentMacroName, tableData: tableData));
        i++;
        continue;
      }

      // Math block detection
      if (line.toLowerCase().startsWith('<math>') || line.toLowerCase().startsWith('<formula>')) {
        final mathLines = <String>[];
        if (line.contains('</math>') || line.contains('</formula>')) {
          final content = line
              .replaceAll(RegExp(r'<\/?math>', caseSensitive: false), '')
              .replaceAll(RegExp(r'<\/?formula>', caseSensitive: false), '');
          blocks.add(_ContentBlock(type: _BlockType.math, text: content, macroName: currentMacroName));
        } else {
          i++;
          while (i < lines.length &&
              !lines[i].toLowerCase().contains('</math>') &&
              !lines[i].toLowerCase().contains('</formula>')) {
            mathLines.add(lines[i]);
            i++;
          }
          blocks.add(_ContentBlock(type: _BlockType.math, text: mathLines.join('\n'), macroName: currentMacroName));
        }
        i++;
        continue;
      }

      // Diagram detection
      if (line.toLowerCase().startsWith('<diagram')) {
        final diagramLines = <String>[];
        i++;
        while (i < lines.length && !lines[i].toLowerCase().contains('</diagram>')) {
          diagramLines.add(lines[i]);
          i++;
        }
        blocks.add(_ContentBlock(type: _BlockType.diagram, text: diagramLines.join('\n'), macroName: currentMacroName));
        i++;
        continue;
      }

      // Graph detection
      if (line.toLowerCase().startsWith('<graph')) {
        final titleMatch = RegExp(r'title="([^"]+)"', caseSensitive: false).firstMatch(line);
        final title = titleMatch?.group(1);
        final graphLines = <String>[];
        i++;
        while (i < lines.length && !lines[i].toLowerCase().contains('</graph>')) {
          graphLines.add(lines[i]);
          i++;
        }
        final graphData = _parseGraph(graphLines.join('\n'));
        blocks.add(_ContentBlock(type: _BlockType.graph, text: '', title: title, macroName: currentMacroName, graphData: graphData));
        i++;
        continue;
      }

      // Headings 1 to 8: # to ########
      final headingRegex = RegExp(r'^(#{1,8})\s+(.*)$');
      final headingMatch = headingRegex.firstMatch(line);
      if (headingMatch != null) {
        final hashes = headingMatch.group(1)!;
        final headingText = headingMatch.group(2)!.trim();
        blocks.add(_ContentBlock(
          type: _BlockType.heading,
          text: headingText,
          headingLevel: hashes.length,
        ));
        i++;
        continue;
      }

      // HTML Headings <h1> to <h6>
      final htmlHRegex = RegExp(r'^<h([1-8])>(.*?)<\/h\1>$', caseSensitive: false);
      final htmlHMatch = htmlHRegex.firstMatch(line);
      if (htmlHMatch != null) {
        final level = int.tryParse(htmlHMatch.group(1)!) ?? 1;
        blocks.add(_ContentBlock(
          type: _BlockType.heading,
          text: htmlHMatch.group(2)!.trim(),
          headingLevel: level,
        ));
        i++;
        continue;
      }

      // HR
      if (line == '---' || line == '<hr/>' || line == '<hr>') {
        blocks.add(_ContentBlock(type: _BlockType.hr, text: ''));
        i++;
        continue;
      }

      // Blockquote
      if (line.startsWith('> ') || (line.startsWith('<blockquote>') && line.endsWith('</blockquote>'))) {
        final text = line.startsWith('> ') ? line.substring(2) : line.substring(12, line.length - 13);
        blocks.add(_ContentBlock(type: _BlockType.blockquote, text: text));
        i++;
        continue;
      }

      // Checkbox list [ ] or [x]
      if (line.startsWith('[ ] ') || line.startsWith('[x] ') || line.startsWith('[X] ')) {
        final isChecked = line.startsWith('[x] ') || line.startsWith('[X] ');
        blocks.add(_ContentBlock(
          type: _BlockType.checkboxList,
          text: line.substring(4).trim(),
          isChecked: isChecked,
        ));
        i++;
        continue;
      }

      // Numbered list: 1. 2.
      final numListMatch = RegExp(r'^(\d+\.)\s+(.*)$').firstMatch(line);
      if (numListMatch != null) {
        blocks.add(_ContentBlock(
          type: _BlockType.numberedList,
          text: numListMatch.group(2)!.trim(),
          listPrefix: numListMatch.group(1),
        ));
        i++;
        continue;
      }

      // Bullet list item
      if (line.startsWith('- ') || line.startsWith('* ') || (line.startsWith('<li>') && line.endsWith('</li>'))) {
        final text = (line.startsWith('- ') || line.startsWith('* ')) ? line.substring(2) : line.substring(4, line.length - 5);
        blocks.add(_ContentBlock(type: _BlockType.bulletList, text: text));
        i++;
        continue;
      }

      // Code block
      if (line.startsWith('<code>') && line.endsWith('</code>')) {
        blocks.add(_ContentBlock(type: _BlockType.code, text: line.substring(6, line.length - 7)));
        i++;
        continue;
      }

      // Check alignment tags <div align="center"> or [align=center]
      TextAlign? align;
      if (line.contains('[align=center]') || line.contains('align="center"')) {
        align = TextAlign.center;
        line = line.replaceAll('[align=center]', '').replaceAll(RegExp(r'<div\s+align="center">|<\/div>'), '');
      } else if (line.contains('[align=right]') || line.contains('align="right"')) {
        align = TextAlign.right;
        line = line.replaceAll('[align=right]', '').replaceAll(RegExp(r'<div\s+align="right">|<\/div>'), '');
      } else if (line.contains('[align=justify]') || line.contains('align="justify"')) {
        align = TextAlign.justify;
        line = line.replaceAll('[align=justify]', '').replaceAll(RegExp(r'<div\s+align="justify">|<\/div>'), '');
      }

      // Default paragraph
      var clean = line
          .replaceAll(RegExp(r'<\/?p>', caseSensitive: false), '')
          .replaceAll(RegExp(r'<\/?ul>', caseSensitive: false), '')
          .replaceAll(RegExp(r'<\/?ol>', caseSensitive: false), '');

      if (clean.isNotEmpty) {
        blocks.add(_ContentBlock(type: _BlockType.paragraph, text: clean, alignment: align));
      }
      i++;
    }

    return blocks;
  }

  _TableData _parseTable(String tableHtml) {
    final headers = <String>[];
    final rows = <List<String>>[];

    final thMatches = RegExp(r'<th>(.*?)<\/th>', caseSensitive: false).allMatches(tableHtml);
    for (final m in thMatches) {
      headers.add(m.group(1)?.trim() ?? '');
    }

    final trMatches = RegExp(r'<tr>(.*?)<\/tr>', caseSensitive: false, dotAll: true).allMatches(tableHtml);
    for (final tr in trMatches) {
      final inner = tr.group(1) ?? '';
      final tdMatches = RegExp(r'<td>(.*?)<\/td>', caseSensitive: false).allMatches(inner);
      if (tdMatches.isNotEmpty) {
        final rowCells = tdMatches.map((td) => td.group(1)?.trim() ?? '').toList();
        rows.add(rowCells);
      }
    }

    if (headers.isEmpty && rows.isNotEmpty) {
      headers.addAll(rows.removeAt(0));
    }

    return _TableData(headers: headers, rows: rows);
  }

  List<MapEntry<String, double>> _parseGraph(String content) {
    final entries = <MapEntry<String, double>>[];
    for (final line in content.split('\n')) {
      final parts = line.split(':');
      if (parts.length >= 2) {
        final key = parts[0].trim();
        final val = double.tryParse(parts[1].trim()) ?? 0.0;
        entries.add(MapEntry(key, val));
      }
    }
    return entries;
  }
}

enum _BlockType {
  heading,
  paragraph,
  hr,
  blockquote,
  bulletList,
  numberedList,
  checkboxList,
  variableBadge,
  code,
  math,
  table,
  diagram,
  graph,
}

class _ContentBlock {
  final _BlockType type;
  final String text;
  final String? title;
  final String? macroName;
  final int? headingLevel;
  final TextAlign? alignment;
  final Color? textColor;
  final String? fontFamily;
  final String? listPrefix;
  final bool? isChecked;
  final _TableData? tableData;
  final List<MapEntry<String, double>>? graphData;

  _ContentBlock({
    required this.type,
    required this.text,
    this.title,
    this.macroName,
    this.headingLevel,
    this.alignment,
    this.textColor,
    this.fontFamily,
    this.listPrefix,
    this.isChecked,
    this.tableData,
    this.graphData,
  });
}

class _TableData {
  final List<String> headers;
  final List<List<String>> rows;

  _TableData({required this.headers, required this.rows});
}
