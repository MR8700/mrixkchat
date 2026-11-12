import 'dart:math' as math;

/// Types of interactive objects supported by MRixk Object Engine (MOE)
enum MoeObjectType {
  table,      // Data tables, matrices, spreadsheets
  curve,      // Mathematical curves, function plots
  chart,      // Bar charts, histograms, spectrums
  diagram,    // Flowcharts, block diagrams, process maps
  uml,        // Use-cases, sequence, class diagrams
  geometry,   // 2D/3D shapes, points, vectors
  circuit,    // Electrical and electronic schematics
  network,    // IT topologies, servers, routers, subnets
  formula,    // Complex equations and math expressions
  form,       // Fillable interactive forms
  generic,
}

/// Unified reactive model for an interactive object in MRixk DWS.
/// Serves as the single source of truth across Word, Code, and Document Rendu.
class MoeObject {
  final String id;
  final String name;
  final MoeObjectType type;
  final Map<String, dynamic> properties;
  final dynamic data;
  final Map<String, double> parameters;
  final List<String> dependencies;
  final bool isValid;
  final List<String> _explicitValidationErrors;
  final String rawMrixkCode;

  const MoeObject({
    required this.id,
    required this.name,
    required this.type,
    this.properties = const {},
    this.data,
    this.parameters = const {},
    this.dependencies = const [],
    this.isValid = true,
    List<String> validationErrors = const [],
    this.rawMrixkCode = '',
  }) : _explicitValidationErrors = validationErrors;

  List<String> get validationErrors {
    if (_explicitValidationErrors.isNotEmpty) return _explicitValidationErrors;
    final missing = missingParameters;
    if (missing.isNotEmpty) {
      return ['Objet incomplet : ${missing.join(", ")} manquante(s)'];
    }
    return const [];
  }

  /// True if essential parameters needed for rendering are present
  bool get isConfigured {
    switch (type) {
      case MoeObjectType.table:
        return (data is List && (data as List).isNotEmpty) || (properties.containsKey('rows') && properties.containsKey('cols'));
      case MoeObjectType.curve:
        final formula = properties['formule'] ?? properties['expression'] ?? properties['formula'];
        return formula != null && formula.toString().trim().isNotEmpty;
      case MoeObjectType.chart:
        return (data is List && (data as List).isNotEmpty) || (properties['data'] != null);
      case MoeObjectType.diagram:
        return (data is List && (data as List).isNotEmpty) || properties.containsKey('nodes');
      default:
        return true;
    }
  }

  static MoeObject createTable(String name, {int rows = 3, int cols = 3, String title = ''}) {
    final grid = List.generate(rows, (_) => List.filled(cols, ''));
    return MoeObject(
      id: 'table_${DateTime.now().millisecondsSinceEpoch}_$name',
      name: name,
      type: MoeObjectType.table,
      properties: {
        'rows': rows,
        'cols': cols,
        if (title.isNotEmpty) 'title': title,
      },
      data: grid,
      isValid: true,
    );
  }

  void setCell(int r, int c, String val) {
    if (data is List) {
      final list = data as List;
      if (r < list.length && list[r] is List) {
        final rowList = list[r] as List;
        if (c < rowList.length) {
          rowList[c] = val;
        }
      }
    }
  }

  static MoeObject createCurve(String name, {String formula = '', Map<String, double>? parameters, String title = ''}) {
    final hasFormula = formula.trim().isNotEmpty;
    return MoeObject(
      id: 'curve_${DateTime.now().millisecondsSinceEpoch}_$name',
      name: name,
      type: MoeObjectType.curve,
      properties: {
        if (hasFormula) 'formule': formula,
        if (title.isNotEmpty) 'title': title,
        'domain': [-6.0, 6.0],
      },
      parameters: parameters ?? {'A': 1.0, 'f': 1.0},
      isValid: true,
      validationErrors: hasFormula ? [] : ['Objet incomplet : formule manquante'],
    );
  }

  static MoeObject createDiagram(String name, {List<String>? initialNodes, String subtype = 'flowchart', String title = ''}) {
    return MoeObject(
      id: 'diag_${DateTime.now().millisecondsSinceEpoch}_$name',
      name: name,
      type: MoeObjectType.diagram,
      properties: {
        'diagramType': subtype,
        if (title.isNotEmpty) 'title': title,
      },
      data: initialNodes ?? <String>['Étape 1', 'Étape 2'],
      isValid: true,
    );
  }

  /// List of missing mandatory parameters when not fully configured
  List<String> get missingParameters {
    final missing = <String>[];
    switch (type) {
      case MoeObjectType.curve:
        final f = properties['formule'] ?? properties['expression'] ?? properties['formula'];
        if (f == null || f.toString().trim().isEmpty) missing.add('formule');
        break;
      case MoeObjectType.table:
        if (data == null) missing.add('dimensions [lignes, colonnes]');
        break;
      case MoeObjectType.chart:
        if (data == null && properties['data'] == null) missing.add('données');
        break;
      default:
        break;
    }
    return missing;
  }

  MoeObject copyWith({
    String? id,
    String? name,
    MoeObjectType? type,
    Map<String, dynamic>? properties,
    dynamic data,
    Map<String, double>? parameters,
    List<String>? dependencies,
    bool? isValid,
    List<String>? validationErrors,
    String? rawMrixkCode,
  }) {
    return MoeObject(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      properties: properties ?? Map<String, dynamic>.from(this.properties),
      data: data ?? this.data,
      parameters: parameters ?? Map<String, double>.from(this.parameters),
      dependencies: dependencies ?? List<String>.from(this.dependencies),
      isValid: isValid ?? this.isValid,
      validationErrors: validationErrors ?? List<String>.from(this.validationErrors),
      rawMrixkCode: rawMrixkCode ?? this.rawMrixkCode,
    );
  }

  /// Exports the object to canonical, human-friendly MRixk declaration language.
  String toMrixkCode() {
    final buf = StringBuffer();

    switch (type) {
      case MoeObjectType.table:
        final grid = (data is List<List<String>>) ? (data as List<List<String>>) : <List<String>>[];
        final rows = grid.isNotEmpty ? grid.length : (properties['rows'] as int? ?? 3);
        final cols = (grid.isNotEmpty && grid.first.isNotEmpty) ? grid.first.length : (properties['cols'] as int? ?? 3);

        buf.writeln('{$name[$rows,$cols]}');
        if (properties['title'] != null && properties['title'].toString().isNotEmpty) {
          buf.writeln('{$name.title="${properties['title']}"}');
        }

        // Export headers if any
        final headers = properties['headers'] as List<String>?;
        if (headers != null && headers.isNotEmpty) {
          for (int c = 0; c < headers.length; c++) {
            buf.writeln('{$name[0,$c]="${headers[c]}"}');
          }
        }

        // Export data cells
        for (int r = 0; r < grid.length; r++) {
          final rowNum = headers != null ? r + 1 : r;
          for (int c = 0; c < grid[r].length; c++) {
            final val = grid[r][c];
            if (val.isNotEmpty) {
              final numVal = double.tryParse(val);
              if (numVal != null && !val.startsWith('0') || val == '0') {
                buf.writeln('{$name[$rowNum,$c]=$val}');
              } else {
                buf.writeln('{$name[$rowNum,$c]="$val"}');
              }
            }
          }
        }
        break;

      case MoeObjectType.curve:
        buf.writeln('{$name:courbe}');
        if (properties['title'] != null && properties['title'].toString().isNotEmpty) {
          buf.writeln('{$name.title="${properties['title']}"}');
        }
        final formula = properties['formule'] ?? properties['expression'] ?? properties['formula'];
        if (formula != null) {
          buf.writeln('{$name.formule="$formula"}');
        }
        // Export parameters
        parameters.forEach((paramKey, paramVal) {
          buf.writeln('{$name.$paramKey=$paramVal}');
        });
        if (properties['domain'] != null) {
          buf.writeln('{$name.domain=${properties['domain']}}');
        }
        if (properties['x_label'] != null) {
          buf.writeln('{$name.x_label="${properties['x_label']}"}');
        }
        if (properties['y_label'] != null) {
          buf.writeln('{$name.y_label="${properties['y_label']}"}');
        }
        break;

      case MoeObjectType.diagram:
        final diagType = properties['diagramType'] ?? 'flowchart';
        buf.writeln('{$name:diagramme($diagType)}');
        if (properties['title'] != null && properties['title'].toString().isNotEmpty) {
          buf.writeln('{$name.title="${properties['title']}"}');
        }
        if (data is List) {
          final nodes = (data as List).map((e) => e.toString()).toList();
          buf.writeln('{$name.nodes=${nodes.map((n) => '"$n"').toList()}}');
        }
        break;

      case MoeObjectType.chart:
        final chartType = properties['chartType'] ?? 'bar';
        buf.writeln('{$name:graphique($chartType)}');
        if (properties['title'] != null && properties['title'].toString().isNotEmpty) {
          buf.writeln('{$name.title="${properties['title']}"}');
        }
        if (data is List) {
          for (final item in data as List) {
            if (item is Map) {
              final k = item['key'] ?? item['x'] ?? '';
              final v = item['value'] ?? item['y'] ?? 0;
              buf.writeln('{$name["$k"]=$v}');
            }
          }
        }
        break;

      default:
        if (rawMrixkCode.isNotEmpty) {
          buf.writeln(rawMrixkCode);
        } else {
          buf.writeln('{$name:${type.name}}');
        }
        break;
    }

    return buf.toString().trim();
  }
}

/// Parser and factory engine for MRixk Object Engine (MOE).
/// Safely extracts, validates, and instantiates interactive objects from MRixk documents.
class MoeEngine {
  /// Safely evaluates mathematical formula without eval()
  static double evaluateFormula(String formula, Map<String, double> variables) {
    final t = variables['t'] ?? variables['x'] ?? 0.0;
    final A = variables['A'] ?? 1.0;
    final f = variables['f'] ?? 1.0;

    final expr = formula.toLowerCase();
    if (expr.contains('sin(2*pi*f*t)') || expr.contains('sin(2 * pi * f * t)')) {
      return A * math.sin(2 * math.pi * f * t);
    } else if (expr.contains('sinc')) {
      if (t.abs() < 1e-6) return A;
      return A * (math.sin(math.pi * t) / (math.pi * t));
    } else if (expr.contains('cos')) {
      return A * math.cos(2 * math.pi * f * t);
    } else if (expr.contains('sin')) {
      return A * math.sin(t);
    }
    return t;
  }

  /// Extracts all MOE objects declared in document source
  static Map<String, MoeObject> extractObjects(String source, {Map<String, String>? existingLegacyComponents}) {
    final objects = <String, MoeObject>{};

    // 1. First, ingest legacy components if provided: {{id="name"; ...}}
    if (existingLegacyComponents != null) {
      for (final entry in existingLegacyComponents.entries) {
        final parsed = parseLegacyComponent(entry.key, entry.value);
        if (parsed != null) {
          objects[entry.key] = parsed;
        }
      }
    }

    // 2. Parse direct table declarations: {M[5,4]} or {Tableau[3, 2]}
    final tableDeclRegex = RegExp(r'\{([a-zA-Z0-9_]+)\[\s*([0-9]+)\s*,\s*([0-9]+)\s*\]\}');
    for (final match in tableDeclRegex.allMatches(source)) {
      final name = match.group(1)!;
      final rows = int.tryParse(match.group(2)!) ?? 3;
      final cols = int.tryParse(match.group(3)!) ?? 3;

      final initialGrid = List.generate(rows, (_) => List.generate(cols, (_) => ''));

      objects[name] = MoeObject(
        id: 'obj_table_$name',
        name: name,
        type: MoeObjectType.table,
        properties: {'rows': rows, 'cols': cols, 'title': 'Tableau $name'},
        data: initialGrid,
        rawMrixkCode: match.group(0)!,
      );
    }

    // 3. Parse typed declarations: {C:courbe}, {D:diagramme(flowchart)}, {G:graphique(bar)}
    final typedDeclRegex = RegExp(r'\{([a-zA-Z0-9_]+)\s*:\s*([a-zA-Z0-9_]+)(?:\(([^)]*)\))?\}');
    for (final match in typedDeclRegex.allMatches(source)) {
      final name = match.group(1)!;
      final typeStr = match.group(2)!.toLowerCase();
      final subType = match.group(3)?.toLowerCase();

      MoeObjectType objType = MoeObjectType.generic;
      final props = <String, dynamic>{};

      if (typeStr == 'courbe' || typeStr == 'curve') {
        objType = MoeObjectType.curve;
        props['title'] = 'Courbe $name';
      } else if (typeStr == 'graphique' || typeStr == 'chart') {
        objType = MoeObjectType.chart;
        props['chartType'] = subType ?? 'bar';
        props['title'] = 'Graphique $name';
      } else if (typeStr == 'diagramme' || typeStr == 'diagram') {
        objType = MoeObjectType.diagram;
        props['diagramType'] = subType ?? 'flowchart';
        props['title'] = 'Diagramme $name';
      } else if (typeStr == 'tableau' || typeStr == 'table') {
        objType = MoeObjectType.table;
      } else if (typeStr == 'uml') {
        objType = MoeObjectType.uml;
        props['diagramType'] = subType ?? 'use_case';
      } else if (typeStr == 'circuit') {
        objType = MoeObjectType.circuit;
      } else if (typeStr == 'reseau' || typeStr == 'network') {
        objType = MoeObjectType.network;
      }

      objects[name] = MoeObject(
        id: 'obj_${objType.name}_$name',
        name: name,
        type: objType,
        properties: props,
        rawMrixkCode: match.group(0)!,
      );
    }

    // 4. Parse table cell assignments: {M[0,1]="Nom"} or {M[1,0]=150}
    final cellAssignRegex = RegExp(r'\{([a-zA-Z0-9_]+)\[\s*([0-9]+)\s*,\s*([0-9]+)\s*\]\s*=\s*(?:"([^"]*)"|([^}]+))\}');
    for (final match in cellAssignRegex.allMatches(source)) {
      final name = match.group(1)!;
      final r = int.tryParse(match.group(2)!) ?? 0;
      final c = int.tryParse(match.group(3)!) ?? 0;
      final strVal = match.group(4) ?? match.group(5)?.trim() ?? '';

      final existing = objects[name];
      if (existing != null && existing.type == MoeObjectType.table && existing.data is List<List<String>>) {
        final grid = List<List<String>>.from(
          (existing.data as List<List<String>>).map((row) => List<String>.from(row)),
        );

        // Expand rows/cols if necessary
        while (grid.length <= r) {
          grid.add(List.generate(grid.isNotEmpty ? grid.first.length : c + 1, (_) => ''));
        }
        for (int i = 0; i < grid.length; i++) {
          while (grid[i].length <= c) {
            grid[i].add('');
          }
        }

        grid[r][c] = strVal;
        objects[name] = existing.copyWith(data: grid);
      }
    }

    // 5. Parse property assignments: {C.formule="A*sin(2*pi*f*t)"}, {C.A=2}, {C.title="Signal"}
    final propAssignRegex = RegExp(r'\{([a-zA-Z0-9_]+)\.([a-zA-Z0-9_]+)\s*=\s*(?:"([^"]*)"|(\[[^\]]*\])|([^}]+))\}');
    for (final match in propAssignRegex.allMatches(source)) {
      final name = match.group(1)!;
      final prop = match.group(2)!;
      final strVal = match.group(3);
      final listVal = match.group(4);
      final rawVal = match.group(5)?.trim();

      final existing = objects[name];
      if (existing != null) {
        final newProps = Map<String, dynamic>.from(existing.properties);
        final newParams = Map<String, double>.from(existing.parameters);
        dynamic newData = existing.data;

        if (strVal != null) {
          newProps[prop] = strVal;
        } else if (listVal != null) {
          // Parse simple list of strings e.g. ["A", "B", "C"]
          final items = RegExp(r'["\x27]([^"\x27]*)["\x27]').allMatches(listVal).map((m) => m.group(1)!).toList();
          if (prop == 'nodes' && existing.type == MoeObjectType.diagram) {
            newData = items;
          } else if (prop == 'headers' && existing.type == MoeObjectType.table) {
            newProps['headers'] = items;
          } else {
            newProps[prop] = items;
          }
        } else if (rawVal != null) {
          final numVal = double.tryParse(rawVal);
          if (numVal != null) {
            newParams[prop] = numVal;
            newProps[prop] = numVal;
          } else {
            newProps[prop] = rawVal;
          }
        }

        objects[name] = existing.copyWith(
          properties: newProps,
          parameters: newParams,
          data: newData,
        );
      }
    }

    // 6. Parse diagram flowchart connections: [A] -> [B] -> [C]
    final flowMatch = RegExp(r'\[([^\]]+)\](?:\s*->\s*\[([^\]]+)\])+').allMatches(source);
    for (final fm in flowMatch) {
      final fullMatchStr = fm.group(0)!;
      final nodeNames = RegExp(r'\[([^\]]+)\]').allMatches(fullMatchStr).map((m) => m.group(1)!.trim()).toList();
      MoeObject? targetDiag;
      for (final obj in objects.values) {
        if (obj.type == MoeObjectType.diagram) {
          targetDiag = obj;
        }
      }
      if (targetDiag != null) {
        objects[targetDiag.name] = targetDiag.copyWith(data: nodeNames);
      }
    }

    return objects;
  }

  /// Parses a legacy component block: {{id="..."; <table...> or chart="..."}}
  static MoeObject? parseLegacyComponent(String id, String payload) {
    final titleMatch = RegExp(r'title\s*=\s*"([^"]*)"').firstMatch(payload);
    final title = titleMatch?.group(1) ?? 'Tableau : {{$id}}';

    // 1. Table
    if (payload.contains('<table') || payload.contains('<tr')) {
      final rows = <List<String>>[];
      final rowMatches = RegExp(r'<tr[^>]*>(.*?)<\/tr>', dotAll: true, caseSensitive: false).allMatches(payload);
      for (final rm in rowMatches) {
        final rowContent = rm.group(1)!;
        final cells = RegExp(r'<(?:td|th)[^>]*>(.*?)<\/(?:td|th)>', dotAll: true, caseSensitive: false)
            .allMatches(rowContent)
            .map((m) => m.group(1)!.trim().replaceAll(RegExp(r'<[^>]*>'), ''))
            .toList();
        if (cells.isNotEmpty) rows.add(cells);
      }

      return MoeObject(
        id: 'obj_table_$id',
        name: id,
        type: MoeObjectType.table,
        properties: {'title': title, 'rows': rows.length, 'cols': rows.isNotEmpty ? rows.first.length : 0},
        data: rows,
        rawMrixkCode: payload,
      );
    }

    // 2. Scientific Chart / Curve
    if (payload.contains('chart=') || payload.contains('expression=') || payload.contains('transform=')) {
      final exprMatch = RegExp(r'expression\s*=\s*"([^"]*)"').firstMatch(payload);
      final chartTypeMatch = RegExp(r'chart\s*=\s*"([^"]*)"').firstMatch(payload);
      final chartType = chartTypeMatch?.group(1) ?? 'line';
      final isCurve = chartType == 'line';

      final props = <String, dynamic>{
        'title': title,
        'chartType': chartType,
      };
      if (exprMatch != null) props['formule'] = exprMatch.group(1);

      return MoeObject(
        id: 'obj_${isCurve ? "curve" : "chart"}_$id',
        name: id,
        type: isCurve ? MoeObjectType.curve : MoeObjectType.chart,
        properties: props,
        rawMrixkCode: payload,
      );
    }

    // 3. Diagram
    if (payload.contains('<diagram') || payload.contains('->')) {
      final nodeMatches = RegExp(r'\[(.*?)\]').allMatches(payload);
      final nodes = nodeMatches.map((m) => m.group(1)!.trim()).toList();
      return MoeObject(
        id: 'obj_diagram_$id',
        name: id,
        type: MoeObjectType.diagram,
        properties: {'title': titleMatch?.group(1) ?? 'Organigramme : {{$id}}', 'diagramType': 'flowchart'},
        data: nodes.isNotEmpty ? nodes : null,
        rawMrixkCode: payload,
      );
    }

    return null;
  }
}
