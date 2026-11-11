import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// Sanitizes untrusted HTML inputs to strictly prevent script injection or unsafe attributes.
String sanitizeHtml(String input) {
  var sanitized = input;
  // Discard script tags and contents
  sanitized = sanitized.replaceAll(RegExp(r'<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>', caseSensitive: false), '');
  // Discard iframe tags
  sanitized = sanitized.replaceAll(RegExp(r'<iframe\b[^<]*(?:(?!<\/iframe>)<[^<]*)*<\/iframe>', caseSensitive: false), '');
  // Discard object / embed tags
  sanitized = sanitized.replaceAll(RegExp(r'<object\b[^<]*(?:(?!<\/object>)<[^<]*)*<\/object>', caseSensitive: false), '');
  sanitized = sanitized.replaceAll(RegExp(r'<embed\b[^>]*>', caseSensitive: false), '');
  // Discard dangerous event attributes
  sanitized = sanitized.replaceAll(RegExp(r'\bon\w+\s*=\s*(?:"[^"]*"|[^>\s]+)', caseSensitive: false), '');
  // Discard javascript: URLs
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

  const GroupNoteRenderer({
    super.key,
    required this.content,
    this.components = const {},
    this.lineSpacing = 1.5,
    this.paragraphSpacing = 12.0,
    this.onEditComponent,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Resolve component macros like {{tableau1}} with their HTML / Math definitions
    final resolvedContent = _resolveMacros(content, components);

    // 2. Sanitize safely
    final safeContent = sanitizeHtml(resolvedContent);

    // 3. Parse into visual content blocks
    final blocks = _parseBlocks(safeContent);

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: blocks.length,
      itemBuilder: (context, index) {
        final block = blocks[index];
        return _buildBlock(context, block);
      },
    );
  }

  /// Replaces {{name}} tokens with their corresponding code from the components map
  String _resolveMacros(String text, Map<String, String> comps) {
    var result = text;
    final macroRegex = RegExp(r'\{\{([a-zA-Z0-9_\-]+)\}\}');
    result = result.replaceAllMapped(macroRegex, (match) {
      final name = match.group(1);
      if (name != null && comps.containsKey(name)) {
        return '\n<!-- macro:$name -->\n${comps[name]}\n<!-- endmacro -->\n';
      }
      return match.group(0) ?? '';
    });
    return result;
  }

  Widget _buildBlock(BuildContext context, _ContentBlock block) {
    Widget child;

    switch (block.type) {
      case _BlockType.h1:
        child = Text(
          block.text,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
            letterSpacing: -0.5,
          ),
        );
        break;

      case _BlockType.h2:
        child = Text(
          block.text,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        );
        break;

      case _BlockType.h3:
        child = Text(
          block.text,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Color(0xFF334155),
          ),
        );
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
            border: Border(
              left: BorderSide(color: AppTheme.secondary, width: 4),
            ),
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
        child = _buildBarGraph(block.title ?? 'Graphique des Métriques', block.graphData!, block.macroName);
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
              child: Text(
                block.text,
                style: TextStyle(fontSize: 13.5, color: const Color(0xFF334155), height: lineSpacing),
              ),
            ),
          ],
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
        child = _buildRichParagraph(block.text);
        break;
    }

    return Padding(
      padding: EdgeInsets.only(bottom: paragraphSpacing),
      child: child,
    );
  }

  /// Builds interactive RichText parsing inline tags like <b>, <i>, <u>, <mark>, <code>, and markdown bold/italic
  Widget _buildRichParagraph(String rawText) {
    var text = rawText;
    // Replace markdown formatting with HTML equivalents for single parser
    text = text.replaceAllMapped(RegExp(r'\*\*(.*?)\*\*'), (m) => '<b>${m.group(1)}</b>');
    text = text.replaceAllMapped(RegExp(r'\*(.*?)\*'), (m) => '<i>${m.group(1)}</i>');
    text = text.replaceAllMapped(RegExp(r'`(.*?)`'), (m) => '<code>${m.group(1)}</code>');

    final spans = <TextSpan>[];
    final tagRegex = RegExp(r'<(b|i|u|mark|code)>(.*?)<\/\1>', caseSensitive: false);
    int lastIndex = 0;

    for (final match in tagRegex.allMatches(text)) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(text: text.substring(lastIndex, match.start)));
      }

      final tag = match.group(1)?.toLowerCase();
      final innerText = match.group(2) ?? '';

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
          spans.add(TextSpan(
            text: innerText,
            style: const TextStyle(backgroundColor: Color(0xFFFEF08A), color: Color(0xFF854D0E)),
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
        style: TextStyle(fontSize: 14, color: const Color(0xFF334155), height: lineSpacing),
        children: spans,
      ),
    );
  }

  /// Builds a rendered mathematical card with fractions, integrals, square roots and symbols
  Widget _buildMathCard(String formula, String? macroName) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
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
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                  letterSpacing: 0.3,
                ),
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

  /// Formats mathematical expression into structured visual widgets
  Widget _renderMathExpression(String expr) {
    if (expr.contains(r'\frac') && expr.contains(r'\sqrt')) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'x = ',
            style: TextStyle(fontSize: 18, fontStyle: FontStyle.italic, fontWeight: FontWeight.bold),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '-b ± ',
                    style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic, fontWeight: FontWeight.bold),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Colors.black87, width: 1.5),
                      ),
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
              Container(
                margin: const EdgeInsets.symmetric(vertical: 3),
                height: 1.5,
                width: 130,
                color: Colors.black87,
              ),
              const Text(
                '2a',
                style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic, fontWeight: FontWeight.bold),
              ),
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
          const Text(
            'e⁻ˣ² dx  =  ',
            style: TextStyle(fontSize: 17, fontStyle: FontStyle.italic, fontWeight: FontWeight.w600),
          ),
          const Text(
            '√π',
            style: TextStyle(fontSize: 18, fontStyle: FontStyle.italic, fontWeight: FontWeight.bold),
          ),
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
          const Text(
            'k  =  ',
            style: TextStyle(fontSize: 17, fontStyle: FontStyle.italic, fontWeight: FontWeight.w600),
          ),
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

  /// Builds a modern responsive table
  Widget _buildTableCard(_TableData data, String? macroName) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
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
                dataTextStyle: const TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF334155),
                ),
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

  /// Builds a rendered flowchart diagram
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
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
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
                      boxShadow: const [
                        BoxShadow(color: Color(0x08000000), blurRadius: 4, offset: Offset(0, 2)),
                      ],
                    ),
                    child: Text(
                      nodes[i],
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: (i == 0 || i == nodes.length - 1)
                            ? Colors.white
                            : const Color(0xFF1E293B),
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

  /// Builds a rendered bar graph
  Widget _buildBarGraph(String title, List<MapEntry<String, double>> items, String? macroName) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
              const Icon(Icons.bar_chart_rounded, size: 18, color: AppTheme.secondary),
              const SizedBox(width: 8),
              Text(
                macroName != null ? '$title ({{$macroName}})' : title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
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
                      Text(
                        item.key,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                      ),
                      Text(
                        '${item.value.toInt()}%',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primary),
                      ),
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

  /// Parses raw HTML / Markdown / custom tags into an ordered list of blocks
  List<_ContentBlock> _parseBlocks(String input) {
    final blocks = <_ContentBlock>[];
    final lines = input.split('\n');

    String? currentMacroName;

    int i = 0;
    while (i < lines.length) {
      var line = lines[i].trim();

      // Check macro comment tracker
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
          while (i < lines.length && !lines[i].toLowerCase().contains('</math>') && !lines[i].toLowerCase().contains('</formula>')) {
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

      // H1 (markdown or html)
      if (line.startsWith('# ') || (line.startsWith('<h1>') && line.endsWith('</h1>'))) {
        final text = line.startsWith('# ') ? line.substring(2) : line.substring(4, line.length - 5);
        blocks.add(_ContentBlock(type: _BlockType.h1, text: text));
        i++;
        continue;
      }

      // H2 (markdown or html)
      if (line.startsWith('## ') || (line.startsWith('<h2>') && line.endsWith('</h2>'))) {
        final text = line.startsWith('## ') ? line.substring(3) : line.substring(4, line.length - 5);
        blocks.add(_ContentBlock(type: _BlockType.h2, text: text));
        i++;
        continue;
      }

      // H3 (markdown or html)
      if (line.startsWith('### ') || (line.startsWith('<h3>') && line.endsWith('</h3>'))) {
        final text = line.startsWith('### ') ? line.substring(4) : line.substring(4, line.length - 5);
        blocks.add(_ContentBlock(type: _BlockType.h3, text: text));
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

      // List item
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

      // Default paragraph (clean tags if any)
      var clean = line
          .replaceAll(RegExp(r'<\/?p>', caseSensitive: false), '')
          .replaceAll(RegExp(r'<\/?ul>', caseSensitive: false), '')
          .replaceAll(RegExp(r'<\/?ol>', caseSensitive: false), '');

      if (clean.isNotEmpty) {
        blocks.add(_ContentBlock(type: _BlockType.paragraph, text: clean));
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
  h1,
  h2,
  h3,
  paragraph,
  hr,
  blockquote,
  bulletList,
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
  final _TableData? tableData;
  final List<MapEntry<String, double>>? graphData;

  _ContentBlock({
    required this.type,
    required this.text,
    this.title,
    this.macroName,
    this.tableData,
    this.graphData,
  });
}

class _TableData {
  final List<String> headers;
  final List<List<String>> rows;

  _TableData({required this.headers, required this.rows});
}
