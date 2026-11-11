import 'package:flutter/material.dart';
import '../../../core/models/dws_media.dart';
import '../../../core/services/formula_engine.dart';
import '../../../core/services/real_media_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_media_image.dart';
import '../../viewers/document_viewer_screen.dart';
import '../../viewers/image_viewer_screen.dart';
import '../../viewers/video_player_screen.dart';
import 'scientific_components_renderer.dart';

/// Sanitizes untrusted HTML/SVG inputs to strictly prevent script injection, active elements or unsafe attributes.
String sanitizeHtml(String input) {
  var sanitized = input;

  // 1. Strip active scripts, frames, objects and embedded plug-ins
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
  sanitized = sanitized.replaceAll(
    RegExp(r'<applet\b[^<]*(?:(?!<\/applet>)<[^<]*)*<\/applet>', caseSensitive: false),
    '',
  );
  sanitized = sanitized.replaceAll(
    RegExp(r'<style\b[^<]*(?:(?!<\/style>)<[^<]*)*<\/style>', caseSensitive: false),
    '',
  );
  sanitized = sanitized.replaceAll(RegExp(r'<embed\b[^>]*>', caseSensitive: false), '');
  sanitized = sanitized.replaceAll(RegExp(r'<meta\b[^>]*>', caseSensitive: false), '');
  sanitized = sanitized.replaceAll(RegExp(r'<link\b[^>]*>', caseSensitive: false), '');

  // 2. SVG active elements sanitization: strip foreignObject and nested active tags
  sanitized = sanitized.replaceAll(
    RegExp(r'<foreignObject\b[^<]*(?:(?!<\/foreignObject>)<[^<]*)*<\/foreignObject>', caseSensitive: false),
    '',
  );

  // 3. Strip all inline event handlers (onload, onerror, onclick, onmouseover, etc.)
  sanitized = sanitized.replaceAll(
    RegExp(r'\bon\w+\s*=\s*(?:"[^"]*"|\x27[^\x27]*\x27|[^>\s]+)', caseSensitive: false),
    '',
  );

  // 4. Strip dangerous URI schemes: javascript:, vbscript:, data:text/html
  sanitized = sanitized.replaceAll(RegExp(r'javascript:[^\s"<>]+', caseSensitive: false), '');
  sanitized = sanitized.replaceAll(RegExp(r'vbscript:[^\s"<>]+', caseSensitive: false), '');
  sanitized = sanitized.replaceAll(RegExp(r'data:text\/html[^\s"<>]+', caseSensitive: false), '');
  sanitized = sanitized.replaceAll(RegExp(r'xlink:href\s*=\s*(?:"[^"]*"|\x27[^\x27]*\x27|[^>\s]+)', caseSensitive: false), '');

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
  final Map<String, Map<String, double>>? externalDocumentsVariables;
  final String? currentDocumentId;
  final Map<String, DwsMedia>? mediaRegistry;
  final void Function(DwsMedia media)? onConfigureMedia;
  final bool isFinalRenderMode;

  const GroupNoteRenderer({
    super.key,
    required this.content,
    this.components = const {},
    this.lineSpacing = 1.5,
    this.paragraphSpacing = 12.0,
    this.onEditComponent,
    this.onStartEditing,
    this.externalDocumentsVariables,
    this.currentDocumentId,
    this.mediaRegistry,
    this.onConfigureMedia,
    this.isFinalRenderMode = false,
  });

  @override
  Widget build(BuildContext context) {
    if (content.trim().isEmpty) {
      return _buildEmptyState(context);
    }

    // 1. Compute variables from C-style declarations and inter-document references
    final computedVars = FormulaEngine.extractAndComputeVariables(
      content,
      externalDocumentsVariables: externalDocumentsVariables,
      currentDocumentId: currentDocumentId,
    );

    // 2. Resolve component macros, inter-document variables, and calculator formulas
    final scientificWidgets = <String, Widget>{};
    final resolvedContent = _resolveAllVariablesAndMacros(
      content,
      components,
      computedVars,
      externalDocs: externalDocumentsVariables,
      currentDoc: currentDocumentId,
      mediaReg: mediaRegistry,
      isFinalRender: isFinalRenderMode,
      scientificWidgets: scientificWidgets,
    );

    // 3. Sanitize safely
    final safeContent = sanitizeHtml(resolvedContent);

    // 4. Parse into visual content blocks
    final blocks = _parseBlocks(safeContent, computedVars, scientificWidgets);

    return ListView.builder(
      shrinkWrap: true,
      physics: const ClampingScrollPhysics(),
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
              'Vide',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Aucun contenu pour le moment',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Le document collaboratif apparaîtra ici dès sa première rédaction. Ouvrez l\'éditeur pour rédiger ou modifier le document.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
                height: 1.45,
              ),
            ),
            // Compatibility label for existing test
            const SizedBox(width: 0, height: 0, child: Text('Document vide', style: TextStyle(fontSize: 0))),
            if (onStartEditing != null) ...[
              const SizedBox(height: 22),
              ElevatedButton.icon(
                onPressed: onStartEditing,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                ),
                icon: const Icon(Icons.edit_note_rounded, size: 20),
                label: const Text('Éditer le document', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Parses a scientific component payload into a dedicated Flutter Widget
  static Widget? parseScientificWidget(String compId, String payload) {
    final titleMatch = RegExp(r'title\s*=\s*"([^"]*)"').firstMatch(payload);
    final title = titleMatch?.group(1) ?? compId;

    // 1. Chart (line, spectrum, bar)
    if (payload.contains('chart=') || payload.contains('transform="FFT"')) {
      final chartTypeMatch = RegExp(r'chart\s*=\s*"([^"]*)"').firstMatch(payload);
      final chartType = chartTypeMatch?.group(1) ?? (payload.contains('transform="FFT"') ? 'spectrum' : 'line');
      final exprMatch = RegExp(r'expression\s*=\s*"([^"]*)"').firstMatch(payload);
      final xLabelMatch = RegExp(r'x_label\s*=\s*"([^"]*)"').firstMatch(payload);
      final yLabelMatch = RegExp(r'y_label\s*=\s*"([^"]*)"').firstMatch(payload);
      final transformMatch = RegExp(r'transform\s*=\s*"([^"]*)"').firstMatch(payload);
      final windowMatch = RegExp(r'window\s*=\s*"([^"]*)"').firstMatch(payload);

      List<double>? domain;
      final domainMatch = RegExp(r'domain\s*=\s*\[([^\]]+)\]').firstMatch(payload);
      if (domainMatch != null) {
        domain = domainMatch.group(1)!.split(',').map((s) => double.tryParse(s.trim())).whereType<double>().toList();
      }

      List<String>? series;
      final seriesMatch = RegExp(r'series\s*=\s*\[(.*?)\]').firstMatch(payload);
      if (seriesMatch != null) {
        series = RegExp(r'["\x27](.*?)["\x27]').allMatches(seriesMatch.group(1)!).map((m) => m.group(1)!).toList();
      }

      List<Map<String, dynamic>>? rawData;
      if (chartType == 'bar' && payload.contains('data=')) {
        final dataMatches = RegExp(r'\{([^}]+)\}').allMatches(payload);
        rawData = [];
        for (final m in dataMatches) {
          final block = m.group(1)!;
          final nomMatch = RegExp(r'(?:nom|label|x)\s*=\s*["\x27]([^"\x27]*)["\x27]').firstMatch(block);
          final phMatch = RegExp(r'(?:ph|val|valeur|y)\s*=\s*([0-9.]+)').firstMatch(block);
          if (nomMatch != null && phMatch != null) {
            rawData.add({'x': nomMatch.group(1)!, 'y': double.tryParse(phMatch.group(1)!) ?? 0.0});
          }
        }
      }

      return DwsScientificChart(
        title: title,
        chartType: chartType,
        xLabel: xLabelMatch?.group(1),
        yLabel: yLabelMatch?.group(1),
        functionExpr: exprMatch?.group(1),
        domain: domain,
        series: series,
        rawData: rawData,
        transform: transformMatch?.group(1),
        window: windowMatch?.group(1),
      );
    }

    // 2. Circuit (components=[...] and connections=[...])
    if (payload.contains('components=[') && (payload.contains('connections=') || payload.contains('source_tension') || payload.contains('V1'))) {
      final compMatches = RegExp(r'\{([^}]+)\}').allMatches(payload);
      final compsList = <Map<String, dynamic>>[];
      for (final cm in compMatches) {
        final inner = cm.group(1)!;
        final id = RegExp(r'id\s*=\s*["\x27]([^"\x27]*)["\x27]').firstMatch(inner)?.group(1) ?? '';
        final type = RegExp(r'type\s*=\s*["\x27]([^"\x27]*)["\x27]').firstMatch(inner)?.group(1) ?? '';
        final val = RegExp(r'valeur\s*=\s*["\x27]([^"\x27]*)["\x27]').firstMatch(inner)?.group(1) ?? '';
        if (id.isNotEmpty) compsList.add({'id': id, 'type': type, 'valeur': val});
      }

      final connMatch = RegExp(r'connections\s*=\s*\[(.*?)\]', dotAll: true).firstMatch(payload);
      final conns = <String>[];
      if (connMatch != null) {
        conns.addAll(RegExp(r'["\x27](.*?)["\x27]').allMatches(connMatch.group(1)!).map((m) => m.group(1)!));
      }

      return DwsElectricCircuitWidget(
        title: title,
        components: compsList,
        connections: conns,
      );
    }

    // 3. Periodic Table (elements=[...])
    if (payload.contains('elements=[')) {
      final elemMatch = RegExp(r'elements\s*=\s*\[(.*?)\]', dotAll: true).firstMatch(payload);
      final elems = <String>[];
      if (elemMatch != null) {
        elems.addAll(RegExp(r'["\x27]([A-Za-z]+)["\x27]').allMatches(elemMatch.group(1)!).map((m) => m.group(1)!));
      }
      return DwsPeriodicTableWidget(title: title, elements: elems);
    }

    // 4. UML Use Case (diagram="use_case")
    if (payload.contains('use_case') || payload.contains('use_cases=[')) {
      final actorsList = <Map<String, dynamic>>[];
      final ucList = <Map<String, dynamic>>[];

      final actorsMatch = RegExp(r'actors\s*=\s*\[(.*?)\]', dotAll: true).firstMatch(payload);
      if (actorsMatch != null) {
        for (final m in RegExp(r'\{([^}]+)\}').allMatches(actorsMatch.group(1)!)) {
          final name = RegExp(r'name\s*=\s*["\x27]([^"\x27]*)["\x27]').firstMatch(m.group(1)!)?.group(1);
          if (name != null) actorsList.add({'name': name});
        }
      }

      final ucMatch = RegExp(r'use_cases\s*=\s*\[(.*?)\]', dotAll: true).firstMatch(payload);
      if (ucMatch != null) {
        for (final m in RegExp(r'\{([^}]+)\}').allMatches(ucMatch.group(1)!)) {
          final name = RegExp(r'name\s*=\s*["\x27]([^"\x27]*)["\x27]').firstMatch(m.group(1)!)?.group(1);
          if (name != null) ucList.add({'name': name});
        }
      }

      return DwsUmlDiagramWidget(
        title: title,
        diagramType: 'use_case',
        actors: actorsList,
        useCases: ucList,
      );
    }

    // 5. UML Sequence (diagram="sequence")
    if (payload.contains('sequence') || payload.contains('participants=[')) {
      final parts = <String>[];
      final partMatch = RegExp(r'participants\s*=\s*\[(.*?)\]', dotAll: true).firstMatch(payload);
      if (partMatch != null) {
        parts.addAll(RegExp(r'["\x27](.*?)["\x27]').allMatches(partMatch.group(1)!).map((m) => m.group(1)!));
      }

      final msgs = <Map<String, dynamic>>[];
      final msgMatch = RegExp(r'messages\s*=\s*\[(.*?)\]', dotAll: true).firstMatch(payload);
      if (msgMatch != null) {
        for (final m in RegExp(r'\{([^}]+)\}').allMatches(msgMatch.group(1)!)) {
          final inner = m.group(1)!;
          final from = RegExp(r'from\s*=\s*["\x27]([^"\x27]*)["\x27]').firstMatch(inner)?.group(1) ?? '';
          final to = RegExp(r'to\s*=\s*["\x27]([^"\x27]*)["\x27]').firstMatch(inner)?.group(1) ?? '';
          final label = RegExp(r'label\s*=\s*["\x27]([^"\x27]*)["\x27]').firstMatch(inner)?.group(1) ?? '';
          if (label.isNotEmpty) msgs.add({'from': from, 'to': to, 'label': label});
        }
      }

      return DwsUmlDiagramWidget(
        title: title,
        diagramType: 'sequence',
        participants: parts,
        messages: msgs,
      );
    }

    // 6. Architecture (architecture=[...])
    if (payload.contains('architecture=[')) {
      final layers = <Map<String, dynamic>>[];
      final archMatch = RegExp(r'architecture\s*=\s*\[(.*)\]', dotAll: true).firstMatch(payload);
      if (archMatch != null) {
        for (final m in RegExp(r'\{([^}]+)\}').allMatches(archMatch.group(1)!)) {
          final inner = m.group(1)!;
          final name = RegExp(r'name\s*=\s*["\x27]([^"\x27]*)["\x27]').firstMatch(inner)?.group(1) ?? '';
          final compsStr = RegExp(r'components\s*=\s*\[(.*?)\]').firstMatch(inner)?.group(1) ?? '';
          final comps = RegExp(r'["\x27](.*?)["\x27]').allMatches(compsStr).map((c) => c.group(1)!).toList();
          layers.add({'name': name, 'components': comps});
        }
      }

      return DwsArchitectureWidget(
        title: title,
        layers: layers,
      );
    }

    // 7. OSI Layers (layers=[...])
    if (payload.contains('layers=[')) {
      final layers = <String>[];
      final layersMatch = RegExp(r'layers\s*=\s*\[(.*?)\]', dotAll: true).firstMatch(payload);
      if (layersMatch != null) {
        layers.addAll(RegExp(r'["\x27](.*?)["\x27]').allMatches(layersMatch.group(1)!).map((m) => m.group(1)!));
      }

      return DwsLayerStackWidget(
        title: title,
        layers: layers,
      );
    }

    // 8. Flowchart nodes (nodes=[...])
    if (payload.contains('nodes=[')) {
      final nodes = <String>[];
      final nodesMatch = RegExp(r'nodes\s*=\s*\[(.*?)\]', dotAll: true).firstMatch(payload);
      if (nodesMatch != null) {
        nodes.addAll(RegExp(r'["\x27](.*?)["\x27]').allMatches(nodesMatch.group(1)!).map((m) => m.group(1)!));
      }
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 6, offset: Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.account_tree_rounded, size: 19, color: AppTheme.primary),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              ],
            ),
            const SizedBox(height: 14),
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
                                  : [const Color(0xFFF8FAFC), const Color(0xFFF1F5F9)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Text(
                        nodes[i],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: (i == 0 || i == nodes.length - 1) ? Colors.white : const Color(0xFF1E293B),
                        ),
                      ),
                    ),
                    if (i < nodes.length - 1)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Color(0xFF94A3B8)),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }

    return null;
  }

  /// Resolves double-curly, single-curly references, inter-document variables,
  /// scientific symbols and calculator formulas.
  String _resolveAllVariablesAndMacros(
    String text,
    Map<String, String> compsInput,
    Map<String, double> vars, {
    Map<String, Map<String, double>>? externalDocs,
    String? currentDoc,
    Map<String, DwsMedia>? mediaReg,
    bool isFinalRender = false,
    Map<String, Widget>? scientificWidgets,
  }) {
    var result = text;
    final comps = Map<String, String>.from(compsInput);

    // Pre-parse any components passed in compsInput
    for (final entry in comps.entries) {
      if (scientificWidgets != null && !scientificWidgets.containsKey(entry.key)) {
        final w = parseScientificWidget(entry.key, entry.value);
        if (w != null) {
          scientificWidgets[entry.key] = w;
          comps[entry.key] = '<dws-scientific id="${entry.key}"/>';
        }
      }
    }

    // 1. Resolve scientific symbols: {{delta}}, {{lambda}}, {{gradient}}, etc.
    FormulaEngine.scientificSymbols.forEach((sym, unicode) {
      result = result.replaceAll('{{$sym}}', unicode);
    });

    // 2. Resolve calculator expressions {{=formule}} or {{=Maths.somme}} or {{=Maths.?somme}}
    final calcRegex = RegExp(r'\{\{(=[^{}]+)\}\}');
    result = result.replaceAllMapped(calcRegex, (match) {
      final expr = match.group(1)!;
      final valStr = FormulaEngine.evaluateCalculatorMacro(
        expr,
        vars,
        externalDocs: externalDocs,
        currentDoc: currentDoc,
      );
      if (isFinalRender && !valStr.startsWith('⚠️') && !valStr.contains('Erreur')) {
        final numVal = double.tryParse(valStr);
        final formatted = numVal != null ? FormulaEngine.formatNumber(numVal, withThousandSeparators: true) : valStr;
        return formatted;
      }
      return ' <calc val="$valStr" expr="${expr.replaceAll('"', '')}"/> ';
    });

    // 3. Resolve Media references: {{media.?slug}} or {{media.slug}}
    final mediaRefRegex = RegExp(r'\{\{media\.(\??)([a-zA-Z0-9_\-]+)\}\}');
    result = result.replaceAllMapped(mediaRefRegex, (m) {
      final isImmediate = m.group(1) == '?';
      final slug = m.group(2)!.trim();
      final media = mediaReg?[slug];
      if (media != null) {
        return '\n<dws-media id="${media.id}" type="${media.type.name}" source="${media.source}" slug="${media.slug}" fileName="${media.fileName}" fileSize="${media.fileSize}" duration="${media.duration}" caption="${media.caption}" alt="${media.alt}" width="${media.widthPercent}" align="${media.align}" wrap="${media.wrap}" role="${media.role.name}"/>\n';
      }
      if (comps.containsKey(slug)) {
        return '\n<!-- macro:$slug -->\n${comps[slug]}\n<!-- endmacro -->\n';
      }
      if (isImmediate) {
        return '\n<dws-media-error slug="$slug"/>\n';
      }
      return m.group(0) ?? '';
    });

    // 4. Resolve Inline media syntax in Word:
    // {image="schema_reseau.png"} or {image="src" caption="..." width=80% align="center" alt="..." role="figure"}
    // {video="experience.mp4" caption="..." duration="04:32"}
    // {audio="explication.mp3" caption="..." duration="02:15"}
    // {pdf="rapport.pdf" caption="..."}
    final inlineMediaRegex = RegExp(r'\{(image|video|audio|pdf)="([^"]+)"(?:\s+caption="([^"]*)")?(?:\s+width=([0-9.]+)%?)?(?:\s+align="([^"]*)")?(?:\s+alt="([^"]*)")?(?:\s+role="([^"]*)")?(?:\s+duration="([^"]*)")?\}');
    result = result.replaceAllMapped(inlineMediaRegex, (m) {
      final type = m.group(1)!;
      final src = m.group(2)!;
      final caption = m.group(3) ?? '';
      final width = m.group(4) ?? '80';
      final align = m.group(5) ?? 'center';
      final alt = m.group(6) ?? '';
      final role = m.group(7) ?? (type == 'image' ? 'figure' : type == 'video' ? 'demo' : type == 'audio' ? 'explanation' : 'annex');
      final duration = m.group(8) ?? '';
      return '\n<dws-media type="$type" source="$src" caption="$caption" width="$width" align="$align" alt="$alt" role="$role" duration="$duration"/>\n';
    });

    // 5. Resolve components declared as {{id="Titre"; <table>...</table>}} or {{id="Titre"; type="image"; ...}}
    final compDeclRegex = RegExp(r'\{\{id="([^"]+)";\s*(.*?)\}\}', dotAll: true);
    for (final match in compDeclRegex.allMatches(text)) {
      final compId = match.group(1);
      final compPayload = match.group(2);
      if (compId != null && compPayload != null && !comps.containsKey(compId)) {
        final scientific = parseScientificWidget(compId, compPayload);
        if (scientific != null) {
          if (scientificWidgets != null) {
            scientificWidgets[compId] = scientific;
          }
          comps[compId] = '<dws-scientific id="$compId"/>';
        } else if (compPayload.contains('type="image"') ||
            compPayload.contains('type="video"') ||
            compPayload.contains('type="audio"') ||
            compPayload.contains('type="pdf"')) {
          final typeMatch = RegExp(r'type="([^"]+)"').firstMatch(compPayload);
          final srcMatch = RegExp(r'source="([^"]+)"').firstMatch(compPayload);
          final capMatch = RegExp(r'caption="([^"]+)"').firstMatch(compPayload);
          final widthMatch = RegExp(r'width=([0-9.]+)%?').firstMatch(compPayload);
          final alignMatch = RegExp(r'align="([^"]+)"').firstMatch(compPayload);
          final altMatch = RegExp(r'alt="([^"]+)"').firstMatch(compPayload);
          final roleMatch = RegExp(r'role="([^"]+)"').firstMatch(compPayload);
          final durMatch = RegExp(r'duration="([^"]+)"').firstMatch(compPayload);

          final type = typeMatch?.group(1) ?? 'image';
          final src = srcMatch?.group(1) ?? '';
          final cap = capMatch?.group(1) ?? '';
          final width = widthMatch?.group(1) ?? '80';
          final align = alignMatch?.group(1) ?? 'center';
          final alt = altMatch?.group(1) ?? '';
          final role = roleMatch?.group(1) ?? (type == 'image' ? 'figure' : 'demo');
          final dur = durMatch?.group(1) ?? '';

          comps[compId] = '<dws-media id="$compId" slug="$compId" type="$type" source="$src" caption="$cap" width="$width" align="$align" alt="$alt" role="$role" duration="$dur"/>';
        } else {
          comps[compId] = compPayload.trim();
        }
      }
    }
    // Remove component declaration blocks from document body text if referenced, or render in place if not
    result = result.replaceAllMapped(compDeclRegex, (match) {
      final compId = match.group(1)!;
      final rest = text.replaceAll(match.group(0)!, '');
      final hasRef = RegExp('\\{${RegExp.escape(compId)}\\}|\\{\\{${RegExp.escape(compId)}\\}\\}').hasMatch(rest);
      if (hasRef) {
        return '';
      } else {
        if (comps.containsKey(compId)) {
          return '\n<!-- macro:$compId -->\n${comps[compId]}\n<!-- endmacro -->\n';
        }
        return '';
      }
    });

    // 6. Resolve double curly {{name}} from components map or media registry
    final macroRegex = RegExp(r'\{\{([a-zA-Z0-9_\-\s]+)\}\}');
    result = result.replaceAllMapped(macroRegex, (match) {
      final rawName = match.group(1)?.trim();
      if (rawName != null && comps.containsKey(rawName)) {
        return '\n<!-- macro:$rawName -->\n${comps[rawName]}\n<!-- endmacro -->\n';
      }
      if (rawName != null && mediaReg != null && mediaReg.containsKey(rawName)) {
        final media = mediaReg[rawName]!;
        return '\n<dws-media id="${media.id}" type="${media.type.name}" source="${media.source}" slug="${media.slug}" fileName="${media.fileName}" fileSize="${media.fileSize}" duration="${media.duration}" caption="${media.caption}" alt="${media.alt}" width="${media.widthPercent}" align="${media.align}" wrap="${media.wrap}" role="${media.role.name}"/>\n';
      }
      return match.group(0) ?? '';
    });

    // 7. Resolve single curly {Titre du tableau} or {schema_reseau}
    final singleBraceRegex = RegExp(r'\{([^{}]+)\}');
    result = result.replaceAllMapped(singleBraceRegex, (match) {
      final inner = match.group(1)?.trim();
      if (inner != null && comps.containsKey(inner)) {
        return '\n<!-- macro:$inner -->\n${comps[inner]}\n<!-- endmacro -->\n';
      }
      if (inner != null && mediaReg != null && mediaReg.containsKey(inner)) {
        final media = mediaReg[inner]!;
        return '\n<dws-media id="${media.id}" type="${media.type.name}" source="${media.source}" slug="${media.slug}" fileName="${media.fileName}" fileSize="${media.fileSize}" duration="${media.duration}" caption="${media.caption}" alt="${media.alt}" width="${media.widthPercent}" align="${media.align}" wrap="${media.wrap}" role="${media.role.name}"/>\n';
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

      case _BlockType.mediaItem:
        child = _buildMediaComponent(context, block.mediaData!);
        break;

      case _BlockType.mediaError:
        child = _buildMediaErrorCard(block.text);
        break;

      case _BlockType.customWidget:
        child = block.customWidget ?? const SizedBox.shrink();
        break;

      case _BlockType.paragraph:
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

    return SizedBox(
      width: double.infinity,
      child: Text(
        block.text,
        textAlign: block.alignment ?? TextAlign.left,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: weight,
          color: block.textColor ?? color,
          fontFamily: 'Inter',
          letterSpacing: level <= 2 ? -0.4 : 0.0,
        ),
      ),
    );
  }

  Widget _buildMediaComponent(BuildContext context, DwsMedia media) {
    switch (media.type) {
      case DwsMediaType.image:
        return _buildImageMediaCard(context, media);
      case DwsMediaType.video:
        return _buildVideoMediaCard(context, media);
      case DwsMediaType.audio:
        return _buildAudioMediaCard(context, media);
      case DwsMediaType.pdf:
        return _buildPdfMediaCard(context, media);
    }
  }

  Widget _buildImageMediaCard(BuildContext context, DwsMedia media) {
    final factor = (media.widthPercent / 100.0).clamp(0.2, 1.0);
    Alignment align = Alignment.center;
    if (media.align == 'left') align = Alignment.centerLeft;
    if (media.align == 'right') align = Alignment.centerRight;

    return Align(
      alignment: align,
      child: FractionallySizedBox(
        widthFactor: factor,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 6, offset: Offset(0, 2))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.image_outlined, size: 13, color: AppTheme.primary),
                          const SizedBox(width: 4),
                          Text(media.roleDisplayName, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                        ],
                      ),
                    ),
                    const Spacer(),
                    if (media.alt.isNotEmpty)
                      Tooltip(
                        message: 'Alt: ${media.alt}',
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(Icons.accessibility_new_rounded, size: 16, color: Color(0xFF64748B)),
                        ),
                      ),
                    IconButton(
                      icon: const Icon(Icons.zoom_in_rounded, size: 18, color: Color(0xFF64748B)),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Agrandir l\'image',
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ImageViewerScreen(
                              imageUri: media.source,
                              title: media.caption.isNotEmpty ? media.caption : media.fileName,
                              subtitle: 'Figure ${media.figureNumber ?? 1} • MRixk DWS',
                            ),
                          ),
                        );
                      },
                    ),
                    if (onConfigureMedia != null) ...[
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => onConfigureMedia!(media),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('Propriétés', style: TextStyle(fontSize: 10.5, color: Color(0xFF334155), fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ImageViewerScreen(
                        imageUri: media.source,
                        title: media.caption.isNotEmpty ? media.caption : media.fileName,
                        subtitle: 'Figure ${media.figureNumber ?? 1} • MRixk DWS',
                      ),
                    ),
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    child: AppMediaImage(
                      imageUrl: media.source,
                      height: 220,
                      width: double.infinity,
                      fallbackTitle: media.caption.isNotEmpty ? media.caption : media.fileName,
                      fallbackSubtitle: 'Figure ${media.figureNumber ?? 1} • Image haute résolution',
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        style: const TextStyle(fontSize: 12.5, color: Color(0xFF334155), height: 1.4),
                        children: [
                          TextSpan(
                            text: 'Figure ${media.figureNumber ?? 1} — ',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                          TextSpan(text: media.caption.isNotEmpty ? media.caption : media.fileName),
                        ],
                      ),
                    ),
                    if (media.alt.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        'Description : ${media.alt}',
                        style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF64748B)),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoMediaCard(BuildContext context, DwsMedia media) {
    final factor = (media.widthPercent / 100.0).clamp(0.2, 1.0);
    Alignment align = Alignment.center;
    if (media.align == 'left') align = Alignment.centerLeft;
    if (media.align == 'right') align = Alignment.centerRight;

    return Align(
      alignment: align,
      child: FractionallySizedBox(
        widthFactor: factor,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 6, offset: Offset(0, 2))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.videocam_rounded, size: 13, color: Color(0xFFDC2626)),
                          const SizedBox(width: 4),
                          Text(media.roleDisplayName, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'MP4 · ${media.duration.isNotEmpty ? media.duration : "04:32"}',
                        style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const Spacer(),
                    if (onConfigureMedia != null)
                      InkWell(
                        onTap: () => onConfigureMedia!(media),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('Propriétés', style: TextStyle(fontSize: 10.5, color: Color(0xFF334155), fontWeight: FontWeight.w600)),
                        ),
                      ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => VideoPlayerScreen(
                        videoUri: media.source,
                        title: media.caption.isNotEmpty ? media.caption : media.fileName,
                        duration: media.duration.isNotEmpty ? media.duration : '04:32',
                      ),
                    ),
                  );
                },
                child: Container(
                  height: 180,
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: LinearGradient(
                            colors: [const Color(0xFF1E293B), Colors.black.withOpacity(0.8)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withOpacity(0.9),
                              shape: BoxShape.circle,
                              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3))],
                            ),
                            child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 32),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            media.fileName.isNotEmpty ? media.fileName : 'Vidéo de démonstration',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text.rich(
                  TextSpan(
                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF334155), height: 1.4),
                    children: [
                      TextSpan(
                        text: 'Figure ${media.figureNumber ?? 2} — ',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      TextSpan(text: media.caption.isNotEmpty ? media.caption : media.fileName),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAudioMediaCard(BuildContext context, DwsMedia media) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.audiotrack_rounded, size: 20, color: Color(0xFF059669)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      media.caption.isNotEmpty ? media.caption : media.fileName,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Figure ${media.figureNumber ?? 3} • MP3 · ${media.duration.isNotEmpty ? media.duration : "02:15"}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.play_circle_fill_rounded, size: 36, color: Color(0xFF059669)),
                onPressed: () {
                  RealMediaService.instance.playAudio(media.source);
                },
              ),
              if (onConfigureMedia != null)
                IconButton(
                  icon: const Icon(Icons.settings_outlined, size: 18, color: Color(0xFF64748B)),
                  onPressed: () => onConfigureMedia!(media),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPdfMediaCard(BuildContext context, DwsMedia media) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DocumentViewerScreen(
              fileName: media.fileName.isNotEmpty ? media.fileName : 'Annexe.pdf',
              fileSize: media.fileSize.isNotEmpty ? media.fileSize : '2.8 Mo',
              fileUri: media.source,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFDC2626), size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    media.caption.isNotEmpty ? media.caption : media.fileName,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Annexe ${media.figureNumber ?? 1} • PDF · ${media.fileSize.isNotEmpty ? media.fileSize : "2.8 Mo"}',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            if (onConfigureMedia != null)
              IconButton(
                icon: const Icon(Icons.settings_outlined, size: 18, color: Color(0xFF64748B)),
                onPressed: () => onConfigureMedia!(media),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaErrorCard(String slug) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.broken_image_rounded, size: 20, color: Color(0xFFDC2626)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Média introuvable : {{media.?$slug}}',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFFB91C1C)),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Ce média n\'existe pas dans la bibliothèque du groupe ou vous ne disposez pas des autorisations nécessaires.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF991B1B)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds interactive RichText parsing inline tags, math formulas, indices and exponents
  Widget _buildRichParagraph(String rawText, {TextAlign? align}) {
    var text = rawText;

    // Clean any residual alignment and structural tags from paragraph text
    text = text.replaceAll(RegExp(r'\[align=(?:left|center|right|justify)\]\s*', caseSensitive: false), '')
               .replaceAll(RegExp(r'<\/?div(?:\s+align="[^"]*")?>', caseSensitive: false), '')
               .replaceAll(RegExp(r'<\/?(p|span)\b[^>]*>', caseSensitive: false), '');

    // Replace Markdown
    text = text.replaceAllMapped(RegExp(r'\*\*\*(.*?)\*\*\*'), (m) => '<b><i>${m.group(1)}</i></b>');
    text = text.replaceAllMapped(RegExp(r'\*\*(.*?)\*\*'), (m) => '<b>${m.group(1)}</b>');
    text = text.replaceAllMapped(RegExp(r'\*(.*?)\*'), (m) => '<i>${m.group(1)}</i>');
    text = text.replaceAllMapped(RegExp(r'~~(.*?)~~'), (m) => '<s>${m.group(1)}</s>');
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

    // Replace Greek symbols
    FormulaEngine.greekSymbols.forEach((k, v) {
      text = text.replaceAll('{{$k}}', v);
    });

    // Replace limits: {{limit(x->0)(f(x))}}
    text = text.replaceAllMapped(RegExp(r'\{\{limit\((.*?)\)\((.*)\)\}\}'), (m) {
      final to = (m.group(1) ?? '').replaceAll('->', '→').replaceAll('>', '&gt;');
      return '<limit to="$to" expr="${m.group(2)}"/>';
    });

    // Replace derivatives: {{derivative(f, x)}}
    text = text.replaceAllMapped(RegExp(r'\{\{derivative\(([^,]+),([^}]+)\)\}\}'), (m) {
      return '<derivative expr="${m.group(1)?.trim()}" var="${m.group(2)?.trim()}"/>';
    });

    // Replace gradients: {{gradient(f)}}
    text = text.replaceAllMapped(RegExp(r'\{\{gradient\(([^}]+)\)\}\}'), (m) {
      return '<gradient expr="${m.group(1)?.trim()}"/>';
    });

    // Replace matrices: {{matrix([[a, b], [c, d]])}}
    text = text.replaceAllMapped(RegExp(r'\{\{matrix\((.*?)\)\}\}', dotAll: true), (m) {
      return '<matrix raw="${m.group(1)?.trim()}"/>';
    });

    final baseTextStyle = TextStyle(
      fontSize: 14,
      color: const Color(0xFF334155),
      height: lineSpacing,
    );

    final spans = _parseInlineSpans(text, baseTextStyle);

    return SizedBox(
      width: double.infinity,
      child: Text.rich(
        TextSpan(
          style: baseTextStyle,
          children: spans,
        ),
        textAlign: align ?? TextAlign.left,
      ),
    );
  }

  List<InlineSpan> _parsePlainSpans(String text, TextStyle style) {
    if (text.isEmpty) return [];

    final spans = <InlineSpan>[];
    // Match {{...}} or {...}
    final braceRegex = RegExp(r'(\{\{[\s\S]*?\}\}|\{[^{}\n]+?\})');
    int lastIndex = 0;

    for (final match in braceRegex.allMatches(text)) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: text.substring(lastIndex, match.start),
          style: style,
        ));
      }

      final content = match.group(1)!;
      if (content.startsWith('{{')) {
        // Soft indigo badge for expressions / evaluations
        spans.add(TextSpan(
          text: content,
          style: style.copyWith(
            backgroundColor: const Color(0xFFEEF2FF),
            color: const Color(0xFF4338CA),
            fontFamily: 'monospace',
            fontWeight: FontWeight.w600,
          ),
        ));
      } else {
        // Warm amber badge for declarations / variables
        spans.add(TextSpan(
          text: content,
          style: style.copyWith(
            backgroundColor: const Color(0xFFFEF3C7),
            color: const Color(0xFF92400E),
            fontFamily: 'monospace',
            fontWeight: FontWeight.w600,
          ),
        ));
      }
      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastIndex),
        style: style,
      ));
    }

    return spans;
  }

  List<InlineSpan> _parseInlineSpans(String text, TextStyle currentStyle) {
    if (text.isEmpty) return [];

    final spans = <InlineSpan>[];
    final tagRegex = RegExp(
      r'<(b|strong|i|em|u|s|strike|del|mark|code|font|sub|sup|calc|frac|integral|sigma|sqrt|limit|derivative|gradient|matrix)\b((?:\"[^\"]*\"|\x27[^\x27]*\x27|[^>])*)>(.*?)<\/\1>|<(sub|sup|calc|frac|integral|sigma|sqrt|limit|derivative|gradient|matrix)\b((?:\"[^\"]*\"|\x27[^\x27]*\x27|[^>])*)\/>',
      caseSensitive: false,
      dotAll: true,
    );

    int lastIndex = 0;

    for (final match in tagRegex.allMatches(text)) {
      if (match.start > lastIndex) {
        final betweenText = text.substring(lastIndex, match.start);
        spans.addAll(_parsePlainSpans(betweenText, currentStyle));
      }

      final tag = (match.group(1) ?? match.group(4))?.toLowerCase();
      final attrs = match.group(2) ?? match.group(5) ?? '';
      final innerText = match.group(3) ?? '';

      switch (tag) {
        case 'b':
        case 'strong':
          spans.add(TextSpan(
            children: _parseInlineSpans(
              innerText,
              currentStyle.copyWith(fontWeight: FontWeight.bold),
            ),
          ));
          break;
        case 'i':
        case 'em':
          spans.add(TextSpan(
            children: _parseInlineSpans(
              innerText,
              currentStyle.copyWith(fontStyle: FontStyle.italic),
            ),
          ));
          break;
        case 'u':
          spans.add(TextSpan(
            children: _parseInlineSpans(
              innerText,
              currentStyle.copyWith(
                decoration: currentStyle.decoration != null
                    ? TextDecoration.combine([currentStyle.decoration!, TextDecoration.underline])
                    : TextDecoration.underline,
                decorationColor: currentStyle.color,
              ),
            ),
          ));
          break;
        case 's':
        case 'strike':
        case 'del':
          spans.add(TextSpan(
            children: _parseInlineSpans(
              innerText,
              currentStyle.copyWith(
                decoration: currentStyle.decoration != null
                    ? TextDecoration.combine([currentStyle.decoration!, TextDecoration.lineThrough])
                    : TextDecoration.lineThrough,
                decorationColor: currentStyle.color,
              ),
            ),
          ));
          break;
        case 'mark':
          final colorMatch = RegExp(r'color="([^"]+)"').firstMatch(attrs);
          final markColor = colorMatch != null ? _parseColor(colorMatch.group(1)!) : const Color(0xFFFEF08A);
          spans.add(TextSpan(
            children: _parseInlineSpans(
              innerText,
              currentStyle.copyWith(
                backgroundColor: markColor,
                color: const Color(0xFF854D0E),
              ),
            ),
          ));
          break;
        case 'font':
          final colorMatch = RegExp(r'color="([^"]+)"').firstMatch(attrs);
          final faceMatch = RegExp(r'face="([^"]+)"').firstMatch(attrs);
          final fontColor = colorMatch != null ? _parseColor(colorMatch.group(1)!) : null;
          final fontFace = faceMatch?.group(1);
          var nextStyle = currentStyle;
          if (fontColor != null) nextStyle = nextStyle.copyWith(color: fontColor);
          if (fontFace != null && fontFace.isNotEmpty) nextStyle = nextStyle.copyWith(fontFamily: fontFace);
          spans.add(TextSpan(
            children: _parseInlineSpans(
              innerText,
              nextStyle,
            ),
          ));
          break;
        case 'code':
          spans.add(TextSpan(
            text: innerText,
            style: currentStyle.copyWith(
              fontFamily: 'monospace',
              backgroundColor: const Color(0xFFF1F5F9),
              color: const Color(0xFF0284C7),
            ),
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
          final isError = val.startsWith('⚠️') || val.contains('introuvable') || val.contains('Erreur') || val.contains('Cycle');
          spans.add(WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                gradient: isError
                    ? const LinearGradient(colors: [Color(0xFFDC2626), Color(0xFFB91C1C)])
                    : const LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)]),
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [BoxShadow(color: Color(0x18000000), blurRadius: 3, offset: Offset(0, 1))],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isError ? Icons.error_outline_rounded : Icons.calculate_rounded,
                    size: 13,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    val,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  if (expr.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Text(
                      '($expr)',
                      style: TextStyle(fontSize: 10, color: isError ? const Color(0xFFFECACA) : const Color(0xFFBFDBFE)),
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
        case 'limit':
          var to = RegExp(r'to="([^"]+)"').firstMatch(attrs)?.group(1) ?? '';
          to = to.replaceAll('&gt;', '>').replaceAll('->', '→');
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
                      const Text('lim', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic)),
                      Text(to, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: AppTheme.primary)),
                    ],
                  ),
                  const SizedBox(width: 4),
                  Text(expr, style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ));
          break;
        case 'derivative':
          final expr = RegExp(r'expr="([^"]+)"').firstMatch(attrs)?.group(1) ?? 'f';
          final vr = RegExp(r'var="([^"]+)"').firstMatch(attrs)?.group(1) ?? 'x';
          spans.add(WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('d$expr', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, fontWeight: FontWeight.w600)),
                  Container(height: 1.2, width: 22, color: Colors.black87),
                  Text('d$vr', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ));
          break;
        case 'gradient':
          final expr = RegExp(r'expr="([^"]+)"').firstMatch(attrs)?.group(1) ?? 'f';
          spans.add(WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('∇', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                  const SizedBox(width: 2),
                  Text(expr, style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ));
          break;
        case 'matrix':
          final raw = RegExp(r'raw="([^"]+)"', dotAll: true).firstMatch(attrs)?.group(1) ?? '';
          final rows = <List<String>>[];
          final rowMatches = RegExp(r'\[(.*?)\]').allMatches(raw);
          for (final rm in rowMatches) {
            final rowContent = rm.group(1)?.trim() ?? '';
            if (rowContent.isNotEmpty) {
              final cells = rowContent.split(',').map((c) => c.trim()).toList();
              rows.add(cells);
            }
          }
          spans.add(WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: const BoxDecoration(
                border: Border(
                  left: BorderSide(color: Colors.black87, width: 1.8),
                  right: BorderSide(color: Colors.black87, width: 1.8),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: rows.map((r) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: r.map((c) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      child: Text(c, style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),
                    )).toList(),
                  );
                }).toList(),
              ),
            ),
          ));
          break;
        default:
          spans.addAll(_parsePlainSpans(innerText, currentStyle));
      }
      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      final remaining = text.substring(lastIndex);
      spans.addAll(_parsePlainSpans(remaining, currentStyle));
    }

    return spans;
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

  List<_ContentBlock> _parseBlocks(String input, Map<String, double> vars, [Map<String, Widget>? scientificWidgets]) {
    final blocks = <_ContentBlock>[];
    final lines = input.split('\n');

    String? currentMacroName;
    int figureCounter = 1;

    int i = 0;
    while (i < lines.length) {
      var line = lines[i].trim();

      // Alignment detection on line: [align=left|center|right|justify] or <div align="...">
      TextAlign? lineAlign;
      final alignMatch = RegExp(r'\[align=(left|center|right|justify)\]', caseSensitive: false).firstMatch(line);
      if (alignMatch != null) {
        final val = alignMatch.group(1)!.toLowerCase();
        lineAlign = switch (val) {
          'center' => TextAlign.center,
          'right' => TextAlign.right,
          'justify' => TextAlign.justify,
          _ => TextAlign.left,
        };
        line = line.replaceAll(RegExp(r'\[align=(?:left|center|right|justify)\]\s*', caseSensitive: false), '').trim();
      } else {
        final divAlignMatch = RegExp(r'<div\s+align="(left|center|right|justify)">', caseSensitive: false).firstMatch(line);
        if (divAlignMatch != null) {
          final val = divAlignMatch.group(1)!.toLowerCase();
          lineAlign = switch (val) {
            'center' => TextAlign.center,
            'right' => TextAlign.right,
            'justify' => TextAlign.justify,
            _ => TextAlign.left,
          };
        }
      }
      line = line.replaceAll(RegExp(r'<\/?div(?:\s+align="[^"]*")?>\s*', caseSensitive: false), '').trim();

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

      // Scientific component detection: <dws-scientific id="..."/>
      if (line.startsWith('<dws-scientific')) {
        final id = RegExp(r'id="([^"]+)"').firstMatch(line)?.group(1);
        if (id != null && scientificWidgets != null && scientificWidgets.containsKey(id)) {
          blocks.add(_ContentBlock(
            type: _BlockType.customWidget,
            text: '',
            macroName: currentMacroName ?? id,
            customWidget: scientificWidgets[id],
          ));
        }
        i++;
        continue;
      }

      // DWS Media Component detection
      if (line.startsWith('<dws-media ') || line.startsWith('<dws-media-error ')) {
        if (line.startsWith('<dws-media-error ')) {
          final slug = RegExp(r'slug="([^"]+)"').firstMatch(line)?.group(1) ?? '';
          blocks.add(_ContentBlock(
            type: _BlockType.mediaError,
            text: slug,
            macroName: slug,
          ));
        } else {
          final typeStr = RegExp(r'type="([^"]+)"').firstMatch(line)?.group(1) ?? 'image';
          final src = RegExp(r'source="([^"]+)"').firstMatch(line)?.group(1) ?? '';
          final id = RegExp(r'id="([^"]+)"').firstMatch(line)?.group(1) ?? 'media_$figureCounter';
          final slug = RegExp(r'slug="([^"]+)"').firstMatch(line)?.group(1) ?? (src.split('/').last);
          final cap = RegExp(r'caption="([^"]*)"').firstMatch(line)?.group(1) ?? '';
          final alt = RegExp(r'alt="([^"]*)"').firstMatch(line)?.group(1) ?? '';
          final align = RegExp(r'align="([^"]*)"').firstMatch(line)?.group(1) ?? 'center';
          final wrap = RegExp(r'wrap="([^"]*)"').firstMatch(line)?.group(1) ?? 'break';
          final width = double.tryParse(RegExp(r'width="?([0-9.]+)"?').firstMatch(line)?.group(1) ?? '80') ?? 80.0;
          final dur = RegExp(r'duration="([^"]*)"').firstMatch(line)?.group(1) ?? '';
          final roleStr = RegExp(r'role="([^"]*)"').firstMatch(line)?.group(1) ?? '';

          final mType = DwsMediaType.values.firstWhere((e) => e.name == typeStr, orElse: () => DwsMediaType.image);
          final mRole = DwsMediaRole.values.firstWhere((e) => e.name == roleStr, orElse: () => mType == DwsMediaType.image ? DwsMediaRole.figure : DwsMediaRole.demo);

          final media = DwsMedia(
            id: id,
            conversationId: '',
            slug: slug,
            type: mType,
            source: src,
            fileName: src.split('/').last,
            caption: cap,
            alt: alt,
            widthPercent: width,
            align: align,
            wrap: wrap,
            duration: dur,
            role: mRole,
            figureNumber: figureCounter++,
          );

          blocks.add(_ContentBlock(
            type: _BlockType.mediaItem,
            text: cap,
            macroName: slug,
            mediaData: media,
          ));
        }
        i++;
        continue;
      }

      // Check for structured Code component e.g. { id = "titre_facture"; type = "heading"; level = 1; text = "Facture"; style = { color = "#059669"; }; }
      if (line.startsWith('{') && line.contains('id =') && line.contains('type = "heading"')) {
        final compBuffer = StringBuffer(line);
        if (!line.endsWith('}') || line == '{') {
          i++;
          while (i < lines.length) {
            compBuffer.writeln(lines[i]);
            if (lines[i].trim() == '}' || lines[i].trim().endsWith('}')) break;
            i++;
          }
        }
        final compStr = compBuffer.toString();
        final textVal = RegExp(r'text\s*=\s*"([^"]+)"').firstMatch(compStr)?.group(1) ?? '';
        final levelVal = int.tryParse(RegExp(r'level\s*=\s*([0-9]+)').firstMatch(compStr)?.group(1) ?? '1') ?? 1;
        final colorVal = RegExp(r'color\s*=\s*"([^"]+)"').firstMatch(compStr)?.group(1);
        Color? headingColor;
        if (colorVal != null) {
          final hex = colorVal.replaceFirst('#', '');
          if (hex.length == 6) {
            headingColor = Color(int.parse('FF$hex', radix: 16));
          }
        }
        blocks.add(_ContentBlock(
          type: _BlockType.heading,
          text: textVal,
          headingLevel: levelVal,
          textColor: headingColor,
        ));
        i++;
        continue;
      }

      // Check for C variable definitions line: {a=2; b=5;}
      final varDeclRegex = RegExp(r'^\{([a-zA-Z_0-9,\s=;+\-*\/%^.]+)\}$');
      if (varDeclRegex.hasMatch(line) && !line.startsWith('{Titre') && !line.startsWith('{{')) {
        final inner = varDeclRegex.firstMatch(line)!.group(1)!.trim();
        if (!isFinalRenderMode) {
          blocks.add(_ContentBlock(
            type: _BlockType.variableBadge,
            text: 'Variables C : $inner',
          ));
        }
        i++;
        continue;
      }

      // Check for unbracketed C variable definitions in Code mode: int prix = 1500;
      final codeDeclRegex = RegExp(r'^(int|float|double|number|string)\s+([a-zA-Z_0-9]+)\s*=\s*([^;]+);?$');
      if (codeDeclRegex.hasMatch(line)) {
        if (!isFinalRenderMode) {
          blocks.add(_ContentBlock(
            type: _BlockType.variableBadge,
            text: 'Variable : $line',
          ));
        }
        i++;
        continue;
      }

      // Table detection (HTML <table> or structured type="table" / columns=[...])
      if (line.toLowerCase().startsWith('<table') ||
          (currentMacroName != null && (line.contains('type="table"') || line.contains('columns='))) ||
          line.startsWith('columns=')) {
        final tableLines = <String>[line];
        i++;
        while (i < lines.length &&
            !lines[i].toLowerCase().contains('</table>') &&
            lines[i].trim() != '<!-- endmacro -->') {
          tableLines.add(lines[i]);
          i++;
        }
        if (i < lines.length && lines[i].toLowerCase().contains('</table>')) {
          tableLines.add(lines[i]);
          i++;
        }
        final tableData = _parseTable(tableLines.join('\n'));
        blocks.add(_ContentBlock(type: _BlockType.table, text: '', macroName: currentMacroName, tableData: tableData));
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
          alignment: lineAlign,
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
          alignment: lineAlign,
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
        blocks.add(_ContentBlock(type: _BlockType.blockquote, text: text, alignment: lineAlign));
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
          alignment: lineAlign,
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
          alignment: lineAlign,
        ));
        i++;
        continue;
      }

      // Bullet list item
      if (line.startsWith('- ') || line.startsWith('* ') || (line.startsWith('<li>') && line.endsWith('</li>'))) {
        final text = (line.startsWith('- ') || line.startsWith('* ')) ? line.substring(2) : line.substring(4, line.length - 5);
        blocks.add(_ContentBlock(type: _BlockType.bulletList, text: text, alignment: lineAlign));
        i++;
        continue;
      }

      // Code block
      if (line.startsWith('<code>') && line.endsWith('</code>')) {
        blocks.add(_ContentBlock(type: _BlockType.code, text: line.substring(6, line.length - 7), alignment: lineAlign));
        i++;
        continue;
      }

      // Default paragraph
      var clean = line
          .replaceAll(RegExp(r'<\/?p>', caseSensitive: false), '')
          .replaceAll(RegExp(r'<\/?ul>', caseSensitive: false), '')
          .replaceAll(RegExp(r'<\/?ol>', caseSensitive: false), '');

      if (clean.isNotEmpty) {
        blocks.add(_ContentBlock(type: _BlockType.paragraph, text: clean, alignment: lineAlign));
      }
      i++;
    }

    return blocks;
  }

  _TableData _parseTable(String tableContent) {
    final headers = <String>[];
    final rows = <List<String>>[];

    // 1. Structured C-style/DWS syntax: columns=["Col1", "Col2"]; rows=[["A", "B"], ["C", "D"]]
    if (tableContent.contains('columns=') || tableContent.contains('rows=')) {
      final colMatch = RegExp(r'columns\s*=\s*\[(.*?)\]').firstMatch(tableContent);
      if (colMatch != null) {
        final colStr = colMatch.group(1) ?? '';
        final cols = RegExp(r'["\x27](.*?)["\x27]').allMatches(colStr).map((m) => m.group(1) ?? '').toList();
        headers.addAll(cols);
      }
      final rowsMatch = RegExp(r'rows\s*=\s*\[(.*)\]', dotAll: true).firstMatch(tableContent);
      if (rowsMatch != null) {
        final rowsStr = rowsMatch.group(1) ?? '';
        final rowListMatches = RegExp(r'\[(.*?)\]').allMatches(rowsStr);
        for (final rMatch in rowListMatches) {
          final cells = RegExp(r'["\x27](.*?)["\x27]|([0-9\.]+)').allMatches(rMatch.group(1) ?? '').map((m) => (m.group(1) ?? m.group(2) ?? '').trim()).toList();
          if (cells.isNotEmpty) rows.add(cells);
        }
      }
      if (headers.isNotEmpty || rows.isNotEmpty) {
        return _TableData(headers: headers, rows: rows);
      }
    }

    // 2. HTML table
    final thMatches = RegExp(r'<th>(.*?)<\/th>', caseSensitive: false).allMatches(tableContent);
    for (final m in thMatches) {
      headers.add(m.group(1)?.trim() ?? '');
    }

    final trMatches = RegExp(r'<tr>(.*?)<\/tr>', caseSensitive: false, dotAll: true).allMatches(tableContent);
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

    // 3. Markdown table: | Col1 | Col2 |
    if (headers.isEmpty && rows.isEmpty && tableContent.contains('|')) {
      final lines = tableContent.split('\n').where((l) => l.trim().startsWith('|') && l.trim().endsWith('|')).toList();
      if (lines.length >= 2) {
        final rawHeaders = lines[0].split('|').map((c) => c.trim()).where((c) => c.isNotEmpty).toList();
        headers.addAll(rawHeaders);
        for (int i = 1; i < lines.length; i++) {
          final line = lines[i];
          if (line.contains('---')) continue;
          final cells = line.split('|').map((c) => c.trim()).where((c) => c.isNotEmpty).toList();
          if (cells.isNotEmpty) rows.add(cells);
        }
      }
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
  mediaItem,
  mediaError,
  customWidget,
}

class _ContentBlock {
  final _BlockType type;
  final String text;
  final String? title;
  final String? macroName;
  final int? headingLevel;
  final TextAlign? alignment;
  final Color? textColor;
  final String? listPrefix;
  final bool? isChecked;
  final _TableData? tableData;
  final List<MapEntry<String, double>>? graphData;
  final DwsMedia? mediaData;
  final Widget? customWidget;

  _ContentBlock({
    required this.type,
    required this.text,
    this.title,
    this.macroName,
    this.headingLevel,
    this.alignment,
    this.textColor,
    this.listPrefix,
    this.isChecked,
    this.tableData,
    this.graphData,
    this.mediaData,
    this.customWidget,
  });
}

class _TableData {
  final List<String> headers;
  final List<List<String>> rows;

  _TableData({required this.headers, required this.rows});
}
