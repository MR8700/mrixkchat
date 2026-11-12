import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/models/moe_object.dart';

/// In-place Interactive Curve and Chart Widget for MRixk DWS.
/// Calculates and plots mathematical curves from formulas and parameters,
/// displays live sliders, non-blocking configuration warnings for incomplete objects,
/// and provides a direct Code button.
class MoeInteractiveChartWidget extends StatefulWidget {
  final MoeObject object;
  final bool isReadOnly;
  final ValueChanged<MoeObject>? onChanged;
  final VoidCallback? onOpenCodeModal;

  const MoeInteractiveChartWidget({
    super.key,
    required this.object,
    this.isReadOnly = false,
    this.onChanged,
    this.onOpenCodeModal,
  });

  @override
  State<MoeInteractiveChartWidget> createState() => _MoeInteractiveChartWidgetState();
}

class _MoeInteractiveChartWidgetState extends State<MoeInteractiveChartWidget> {
  late Map<String, double> _params;

  @override
  void initState() {
    super.initState();
    _params = Map<String, double>.from(widget.object.parameters);
  }

  @override
  void didUpdateWidget(covariant MoeInteractiveChartWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.object != widget.object) {
      _params = Map<String, double>.from(widget.object.parameters);
    }
  }

  void _updateParam(String key, double val) {
    if (widget.isReadOnly) return;
    setState(() {
      _params[key] = val;
    });
    if (widget.onChanged != null) {
      final updated = widget.object.copyWith(
        parameters: _params,
      );
      widget.onChanged!(updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.object.properties['title'] as String? ?? 'Courbe ${widget.object.name}';
    final formula = widget.object.properties['formule'] ??
        widget.object.properties['expression'] ??
        widget.object.properties['formula'];

    final isConfigured = widget.object.isConfigured;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isConfigured ? const Color(0xFFE2E8F0) : const Color(0xFFFDE68A)),
        boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isConfigured ? const Color(0xFFF8FAFC) : const Color(0xFFFFFBEB),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              border: Border(bottom: BorderSide(color: isConfigured ? const Color(0xFFE2E8F0) : const Color(0xFFFDE68A))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: isConfigured ? const Color(0xFFEFF6FF) : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    isConfigured ? Icons.show_chart_rounded : Icons.tune_rounded,
                    size: 16,
                    color: isConfigured ? AppTheme.primary : const Color(0xFFD97706),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      Text(
                        formula != null
                            ? 'f(t) = $formula'
                            : (widget.isReadOnly ? 'Courbe mathématique' : 'Objet MOE : {${widget.object.name}:${widget.object.type.name}}'),
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                ),
                if (!isConfigured)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFF59E0B)),
                    ),
                    child: const Text('À configurer ⚠️', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFFB45309))),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('Calculé ✅', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF047857))),
                  ),
                const SizedBox(width: 8),
                // Code button
                if (widget.onOpenCodeModal != null && !widget.isReadOnly)
                  InkWell(
                    onTap: widget.onOpenCodeModal,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.code_rounded, size: 13, color: Color(0xFF38BDF8)),
                          SizedBox(width: 4),
                          Text('Code', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'monospace')),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Body: Incomplete Warning Card OR Rendered Chart
          if (!isConfigured)
            _buildIncompleteWarningCard()
          else
            _buildConfiguredChartBody(formula.toString()),

          // Live Interactive Parameter Adjusters
          if (!widget.isReadOnly && _params.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(15)),
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Paramètres interactifs en temps réel :', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: _params.entries.map((param) {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${param.key} =', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, fontFamily: 'monospace', color: AppTheme.primary)),
                          const SizedBox(width: 4),
                          Text(param.value.toStringAsFixed(param.value.truncateToDouble() == param.value ? 0 : 2), style: const TextStyle(fontSize: 11.5, fontFamily: 'monospace')),
                          const SizedBox(width: 4),
                          InkWell(
                            onTap: () => _updateParam(param.key, param.value + 1),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(4)),
                              child: const Icon(Icons.add, size: 12),
                            ),
                          ),
                          const SizedBox(width: 2),
                          InkWell(
                            onTap: () => _updateParam(param.key, (param.value - 1).clamp(0.1, 10000.0)),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(4)),
                              child: const Icon(Icons.remove, size: 12),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildIncompleteWarningCard() {
    final missing = widget.object.missingParameters;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFFB45309)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Paramètres indispensables manquants',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Pour tracer automatiquement cette courbe, veuillez spécifier la formule ou les paramètres suivants : ${missing.join(', ')}.',
            style: const TextStyle(fontSize: 12, height: 1.4, color: Color(0xFF78350F)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: widget.onOpenCodeModal,
                icon: const Icon(Icons.code_rounded, size: 14, color: Color(0xFF38BDF8)),
                label: const Text('Ouvrir le Code MRixk', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  // Apply default formula
                  if (widget.onChanged != null) {
                    final updated = widget.object.copyWith(
                      properties: {
                        ...widget.object.properties,
                        'formule': 'A * sin(2 * pi * f * t)',
                      },
                      parameters: {'A': 2.0, 'f': 50.0},
                    );
                    widget.onChanged!(updated);
                  }
                },
                child: const Text('Exemple sinusoïde', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConfiguredChartBody(String formula) {
    // Generate data points from formula & live parameters
    final domain = (widget.object.properties['domain'] as List<dynamic>?)
        ?.map((e) => double.tryParse(e.toString()) ?? 0.0)
        .toList() ?? [0.0, 0.04];

    final minX = domain.isNotEmpty ? domain[0] : 0.0;
    final maxX = domain.length > 1 ? domain[1] : 0.04;
    const stepCount = 120;
    final step = (maxX - minX) / stepCount;

    final points = <Offset>[];
    double minY = 0.0;
    double maxY = 1.0;

    final A = _params['A'] ?? 1.0;
    final f = _params['f'] ?? 50.0;

    for (int i = 0; i <= stepCount; i++) {
      final x = minX + i * step;
      double y = 0.0;

      final expr = formula.toLowerCase();
      if (expr.contains('sin(2*pi*f*t)') || expr.contains('sin(2 * pi * f * t)')) {
        y = A * math.sin(2 * math.pi * f * x);
      } else if (expr.contains('sinc')) {
        if (x.abs() < 1e-6) {
          y = A;
        } else {
          y = A * (math.sin(math.pi * x) / (math.pi * x));
        }
      } else if (expr.contains('cos')) {
        y = A * math.cos(2 * math.pi * f * x);
      } else if (expr.contains('exp')) {
        y = A * math.exp(-x * f);
      } else {
        y = A * math.sin(x * f);
      }

      if (i == 0) {
        minY = y;
        maxY = y;
      } else {
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
      points.add(Offset(x, y));
    }

    if ((maxY - minY).abs() < 0.0001) {
      maxY = minY + 1.0;
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF1E293B)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CustomPaint(
            painter: FunctionPlotPainterWrapper(
              points: points,
              minY: minY,
              maxY: maxY,
              minX: minX,
              maxX: maxX,
            ),
          ),
        ),
      ),
    );
  }
}

/// Helper custom painter for live MOE curves
class FunctionPlotPainterWrapper extends CustomPainter {
  final List<Offset> points;
  final double minY;
  final double maxY;
  final double minX;
  final double maxX;

  FunctionPlotPainterWrapper({
    required this.points,
    required this.minY,
    required this.maxY,
    required this.minX,
    required this.maxX,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    const leftPad = 40.0;
    const rightPad = 16.0;
    const topPad = 26.0;
    const bottomPad = 24.0;

    final plotRect = Rect.fromLTRB(leftPad, topPad, size.width - rightPad, size.height - bottomPad);

    // 1. Grid Lines
    final gridPaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..strokeWidth = 1.0;

    for (int i = 0; i <= 4; i++) {
      final y = plotRect.top + plotRect.height * (i / 4.0);
      canvas.drawLine(Offset(plotRect.left, y), Offset(plotRect.right, y), gridPaint);

      final val = maxY - (i / 4.0) * (maxY - minY);
      final tp = TextPainter(
        text: TextSpan(
          text: val.toStringAsFixed(1),
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 9.5, fontFamily: 'monospace'),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(plotRect.left - tp.width - 6, y - tp.height / 2));
    }

    // 2. Vertical Grid Lines
    for (int i = 0; i <= 4; i++) {
      final x = plotRect.left + plotRect.width * (i / 4.0);
      canvas.drawLine(Offset(x, plotRect.top), Offset(x, plotRect.bottom), gridPaint);

      final xVal = minX + (i / 4.0) * (maxX - minX);
      final tp = TextPainter(
        text: TextSpan(
          text: '${xVal.toStringAsFixed(2)}s',
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 9.5, fontFamily: 'monospace'),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, plotRect.bottom + 5));
    }

    // 3. Zero Axis
    double? zeroY;
    if (minY < 0 && maxY > 0) {
      zeroY = plotRect.top + plotRect.height * (1.0 - (0.0 - minY) / (maxY - minY));
      final zeroPaint = Paint()
        ..color = const Color(0xFF475569)
        ..strokeWidth = 1.5;
      canvas.drawLine(Offset(plotRect.left, zeroY), Offset(plotRect.right, zeroY), zeroPaint);
    }

    // 4. Plot Curve
    final path = Path();
    final fillPath = Path();

    for (int i = 0; i < points.length; i++) {
      final normX = plotRect.left + (i / (points.length - 1)) * plotRect.width;
      final normY = plotRect.top + plotRect.height * (1.0 - ((points[i].dy - minY) / (maxY - minY)).clamp(0.0, 1.0));

      if (i == 0) {
        path.moveTo(normX, normY);
        fillPath.moveTo(normX, zeroY ?? plotRect.bottom);
        fillPath.lineTo(normX, normY);
      } else {
        path.lineTo(normX, normY);
        fillPath.lineTo(normX, normY);
      }
    }
    fillPath.lineTo(plotRect.right, zeroY ?? plotRect.bottom);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF38BDF8).withOpacity(0.35),
          const Color(0xFF38BDF8).withOpacity(0.0),
        ],
      ).createShader(plotRect);
    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = const Color(0xFF38BDF8)
      ..strokeWidth = 2.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant FunctionPlotPainterWrapper oldDelegate) => true;
}
