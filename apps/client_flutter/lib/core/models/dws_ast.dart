import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/formula_engine.dart';
import 'dws_media.dart';

/// Node types in the MRixk DWS unified document AST
enum DwsAstNodeType {
  heading,
  paragraph,
  declaration, // C-style variable declaration e.g. {int prix = 1500;}
  evaluation,  // Calculator evaluation e.g. {{=total}}
  component,   // Structured component e.g. { id = "..."; type = "..."; style = { ... }; }
  table,       // Data table
  media,       // Images, videos, audios, PDFs
  math,        // Mathematical equations
  divider,     // Horizontal rule
  bulletList,
  numberedList,
  checkboxList,
}

/// A node in the MRixk DWS unified document AST
class DwsAstNode {
  final String id;
  final DwsAstNodeType type;
  final String content;
  final Map<String, dynamic> properties;
  final Map<String, dynamic> style;

  const DwsAstNode({
    required this.id,
    required this.type,
    required this.content,
    this.properties = const {},
    this.style = const {},
  });

  DwsAstNode copyWith({
    String? id,
    DwsAstNodeType? type,
    String? content,
    Map<String, dynamic>? properties,
    Map<String, dynamic>? style,
  }) {
    return DwsAstNode(
      id: id ?? this.id,
      type: type ?? this.type,
      content: content ?? this.content,
      properties: properties ?? this.properties,
      style: style ?? this.style,
    );
  }
}

/// Diagnostic item from the DWS Validator engine
class DwsDiagnostic {
  final String message;
  final String severity; // 'info', 'warning', 'error'
  final int? line;

  const DwsDiagnostic({
    required this.message,
    this.severity = 'info',
    this.line,
  });

  bool get isError => severity == 'error';
  bool get isWarning => severity == 'warning';
}

/// Unified Document AST model in MRixk DWS.
/// Operates as the single source of truth for:
/// 1. WORD (Visual authoring)
/// 2. CODE (Structural programming)
/// 3. DOCUMENT RENDU (Final read-only publication projection)
class DwsDocumentAst {
  final String id;
  final String title;
  final List<DwsAstNode> nodes;
  final Map<String, double> variables;
  final Map<String, String> components;
  final Map<String, DwsMedia> mediaRegistry;
  final List<DwsDiagnostic> diagnostics;

  const DwsDocumentAst({
    required this.id,
    required this.title,
    required this.nodes,
    required this.variables,
    this.components = const {},
    this.mediaRegistry = const {},
    this.diagnostics = const [],
  });

  bool get hasErrors => diagnostics.any((d) => d.isError);

  /// Builds a unified AST from either Word or Code document source text
  static DwsDocumentAst fromSource(
    String rawText, {
    String id = 'doc_ast_1',
    String title = 'Document MRixk',
    Map<String, String>? components,
    Map<String, DwsMedia>? mediaRegistry,
    Map<String, Map<String, double>>? externalVariables,
    String? currentDocId,
  }) {
    final comps = Map<String, String>.from(components ?? {});
    final mediaReg = Map<String, DwsMedia>.from(mediaRegistry ?? {});
    final diagnostics = <DwsDiagnostic>[];

    // 1. Extract and compute variables via FormulaEngine
    Map<String, double> vars = {};
    try {
      vars = FormulaEngine.extractAndComputeVariables(
        rawText,
        externalDocumentsVariables: externalVariables,
        currentDocumentId: currentDocId,
      );
    } catch (e) {
      diagnostics.add(DwsDiagnostic(message: 'Erreur d\'évaluation des variables : $e', severity: 'error'));
    }

    final nodes = <DwsAstNode>[];
    final lines = rawText.split('\n');

    int nodeIndex = 0;
    int i = 0;

    while (i < lines.length) {
      final line = lines[i];
      final trimmed = line.trim();

      if (trimmed.isEmpty) {
        i++;
        continue;
      }

      // Check for structured Code component: { id = "..."; ... }
      if (trimmed.startsWith('{') &&
          trimmed.contains('id =') &&
          (trimmed.contains('type =') || trimmed.contains('style ='))) {
        final compBuffer = StringBuffer(line);
        if (!trimmed.endsWith('}') || trimmed == '{') {
          i++;
          while (i < lines.length) {
            compBuffer.writeln(lines[i]);
            if (lines[i].trim() == '}' || lines[i].trim().endsWith('}')) {
              break;
            }
            i++;
          }
        }
        final compStr = compBuffer.toString();
        final compId = RegExp(r'id\s*=\s*"([^"]+)"').firstMatch(compStr)?.group(1) ?? 'comp_$nodeIndex';
        final compType = RegExp(r'type\s*=\s*"([^"]+)"').firstMatch(compStr)?.group(1) ?? 'component';
        final textVal = RegExp(r'text\s*=\s*"([^"]+)"').firstMatch(compStr)?.group(1) ?? '';
        final levelVal = int.tryParse(RegExp(r'level\s*=\s*([0-9]+)').firstMatch(compStr)?.group(1) ?? '1') ?? 1;
        final colorVal = RegExp(r'color\s*=\s*"([^"]+)"').firstMatch(compStr)?.group(1);

        final nodeProps = <String, dynamic>{'rawCode': compStr, 'level': levelVal};
        final nodeStyle = <String, dynamic>{};
        if (colorVal != null) nodeStyle['color'] = colorVal;

        DwsAstNodeType nodeType = DwsAstNodeType.component;
        if (compType == 'heading') {
          nodeType = DwsAstNodeType.heading;
        } else if (compType == 'table') {
          nodeType = DwsAstNodeType.table;
        }

        nodes.add(DwsAstNode(
          id: compId,
          type: nodeType,
          content: textVal.isNotEmpty ? textVal : compStr,
          properties: nodeProps,
          style: nodeStyle,
        ));
        i++;
        continue;
      }

      // Check for variable declaration: {int prix = 1500;} or {a=2; b=5;}
      final varDeclRegex = RegExp(r'^\{([a-zA-Z_0-9,\s=;+\-*\/%^.]+)\}$');
      if (varDeclRegex.hasMatch(trimmed) &&
          !trimmed.startsWith('{{') &&
          !trimmed.startsWith('{image=') &&
          !trimmed.startsWith('{video=') &&
          !trimmed.startsWith('{audio=') &&
          !trimmed.startsWith('{pdf=')) {
        final inner = varDeclRegex.firstMatch(trimmed)!.group(1)!.trim();
        nodes.add(DwsAstNode(
          id: 'decl_$nodeIndex',
          type: DwsAstNodeType.declaration,
          content: trimmed,
          properties: {'declaration': inner},
        ));
        nodeIndex++;
        i++;
        continue;
      }

      // Check for Standalone Code variable: int prix = 1500;
      final codeDeclRegex = RegExp(r'^(int|float|double|number|string)\s+([a-zA-Z_0-9]+)\s*=\s*([^;]+);?$');
      if (codeDeclRegex.hasMatch(trimmed)) {
        nodes.add(DwsAstNode(
          id: 'decl_$nodeIndex',
          type: DwsAstNodeType.declaration,
          content: '{$trimmed}',
          properties: {'declaration': trimmed},
        ));
        nodeIndex++;
        i++;
        continue;
      }

      // Check for Headings: # Titre, ## Titre
      final headingMatch = RegExp(r'^(#{1,8})\s+(.*)$').firstMatch(trimmed);
      if (headingMatch != null) {
        final level = headingMatch.group(1)!.length;
        final headingText = headingMatch.group(2)!.trim();
        nodes.add(DwsAstNode(
          id: 'head_$nodeIndex',
          type: DwsAstNodeType.heading,
          content: headingText,
          properties: {'level': level},
        ));
        nodeIndex++;
        i++;
        continue;
      }

      // Check for Media component: {image="..."} or {{media.?slug}}
      if (trimmed.startsWith('{image=') ||
          trimmed.startsWith('{video=') ||
          trimmed.startsWith('{audio=') ||
          trimmed.startsWith('{pdf=') ||
          trimmed.startsWith('{{media.')) {
        nodes.add(DwsAstNode(
          id: 'media_$nodeIndex',
          type: DwsAstNodeType.media,
          content: trimmed,
        ));
        nodeIndex++;
        i++;
        continue;
      }

      // Check for Table: <table> or columns=[...]
      if (trimmed.toLowerCase().startsWith('<table') || trimmed.startsWith('columns=')) {
        nodes.add(DwsAstNode(
          id: 'table_$nodeIndex',
          type: DwsAstNodeType.table,
          content: trimmed,
        ));
        nodeIndex++;
        i++;
        continue;
      }

      // Default: Paragraph with potential inline evaluations
      nodes.add(DwsAstNode(
        id: 'para_$nodeIndex',
        type: DwsAstNodeType.paragraph,
        content: line,
      ));
      nodeIndex++;
      i++;
    }

    if (vars.isNotEmpty) {
      diagnostics.add(DwsDiagnostic(
        message: 'Modèle documentaire validé : ${vars.length} variable(s) active(s).',
        severity: 'info',
      ));
    }

    return DwsDocumentAst(
      id: id,
      title: title,
      nodes: nodes,
      variables: vars,
      components: comps,
      mediaRegistry: mediaReg,
      diagnostics: diagnostics,
    );
  }

  /// Converts the unified AST into the Word workspace representation
  /// (Visual text with intact editable declarations and live inline formatting)
  String toWordRepresentation() {
    final buffer = StringBuffer();
    for (final node in nodes) {
      switch (node.type) {
        case DwsAstNodeType.heading:
          final level = node.properties['level'] as int? ?? 1;
          final prefix = '#' * level;
          buffer.writeln('$prefix ${node.content}\n');
          break;
        case DwsAstNodeType.declaration:
          buffer.writeln('${node.content}\n');
          break;
        case DwsAstNodeType.paragraph:
          buffer.writeln('${node.content}\n');
          break;
        case DwsAstNodeType.media:
        case DwsAstNodeType.table:
        case DwsAstNodeType.component:
          buffer.writeln('${node.content}\n');
          break;
        default:
          buffer.writeln('${node.content}\n');
          break;
      }
    }
    return buffer.toString().trim();
  }

  /// Converts the unified AST into the Code workspace representation
  /// (Exposing exact structure, variables, types, and component definitions)
  String toCodeRepresentation() {
    final buffer = StringBuffer();
    for (final node in nodes) {
      switch (node.type) {
        case DwsAstNodeType.heading:
          final level = node.properties['level'] as int? ?? 1;
          final color = node.style['color'] as String?;
          if (color != null) {
            buffer.writeln('{\n  id = "${node.id}";\n  type = "heading";\n  level = $level;\n  text = "${node.content}";\n  style = {\n    color = "$color";\n  };\n}\n');
          } else {
            buffer.writeln('{\n  id = "${node.id}";\n  type = "heading";\n  level = $level;\n  text = "${node.content}";\n}\n');
          }
          break;
        case DwsAstNodeType.declaration:
          // Unwrapped C style in code mode
          String raw = node.content;
          if (raw.startsWith('{') && raw.endsWith('}')) {
            raw = raw.substring(1, raw.length - 1).trim();
          }
          buffer.writeln('$raw\n');
          break;
        case DwsAstNodeType.paragraph:
          buffer.writeln('${node.content}\n');
          break;
        case DwsAstNodeType.component:
        case DwsAstNodeType.media:
        case DwsAstNodeType.table:
          buffer.writeln('${node.content}\n');
          break;
        default:
          buffer.writeln('${node.content}\n');
          break;
      }
    }
    return buffer.toString().trim();
  }

  /// Projects the unified AST into Document Rendu
  /// (Strictly read-only, ZERO declarations, evaluations replaced by final results, pure publication)
  String toRenderedProjection() {
    final buffer = StringBuffer();
    for (final node in nodes) {
      switch (node.type) {
        case DwsAstNodeType.declaration:
          // STRICT RULE: Declarations are masked in final Document Rendu!
          continue;

        case DwsAstNodeType.heading:
          final level = node.properties['level'] as int? ?? 1;
          final prefix = '#' * level;
          final color = node.style['color'] as String?;
          if (color != null) {
            buffer.writeln('[color=$color]$prefix ${node.content}[/color]\n');
          } else {
            buffer.writeln('$prefix ${node.content}\n');
          }
          break;

        case DwsAstNodeType.paragraph:
          // Replace evaluations {{=var}} with evaluated numerical values
          String text = node.content;
          final evalRegex = RegExp(r'\{\{=([a-zA-Z_0-9]+)\}\}');
          text = text.replaceAllMapped(evalRegex, (m) {
            final varName = m.group(1)!;
            final val = variables[varName];
            if (val != null) {
              return FormulaEngine.formatNumber(val);
            }
            return '[Erreur: $varName indéfini]';
          });
          buffer.writeln('$text\n');
          break;

        case DwsAstNodeType.media:
        case DwsAstNodeType.table:
        case DwsAstNodeType.component:
          buffer.writeln('${node.content}\n');
          break;

        default:
          buffer.writeln('${node.content}\n');
          break;
      }
    }
    return buffer.toString().trim();
  }
}
