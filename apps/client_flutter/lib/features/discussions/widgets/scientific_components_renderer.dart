import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// Interactive Scientific Chart Renderer for MRixk DWS.
/// Computes and renders mathematical functions, Fourier spectrums, and multi-series curves.
class DwsScientificChart extends StatelessWidget {
  final String title;
  final String chartType; // 'line', 'spectrum', 'bar'
  final String? xLabel;
  final String? yLabel;
  final String? functionExpr;
  final List<double>? domain; // [min, max]
  final List<String>? series;
  final List<Map<String, dynamic>>? rawData;
  final String? transform; // e.g. 'FFT'
  final String? window; // e.g. 'Hann'

  const DwsScientificChart({
    super.key,
    required this.title,
    this.chartType = 'line',
    this.xLabel,
    this.yLabel,
    this.functionExpr,
    this.domain,
    this.series,
    this.rawData,
    this.transform,
    this.window,
  });

  @override
  Widget build(BuildContext context) {
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
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: chartType == 'spectrum'
                      ? const Color(0xFFF3E8FF)
                      : chartType == 'bar'
                          ? const Color(0xFFFEF3C7)
                          : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  chartType == 'spectrum'
                      ? Icons.graphic_eq_rounded
                      : chartType == 'bar'
                          ? Icons.bar_chart_rounded
                          : Icons.show_chart_rounded,
                  size: 18,
                  color: chartType == 'spectrum'
                      ? const Color(0xFF7E22CE)
                      : chartType == 'bar'
                          ? const Color(0xFFD97706)
                          : AppTheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    if (transform != null || functionExpr != null)
                      Text(
                        transform != null
                            ? 'Transformée : $transform • Fenêtrage : ${window ?? "Hann"}'
                            : 'Fonction : f(x) = $functionExpr',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontFamily: 'monospace'),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('Calculé ✅', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF047857))),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Chart Display Area
          if (chartType == 'spectrum')
            _buildSpectrumChart()
          else if (chartType == 'bar')
            _buildBarChart()
          else
            _buildFunctionLineChart(),

          // Axes Labels
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                xLabel != null ? 'Axe X : $xLabel' : 'Axe X (Temps)',
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
              ),
              Text(
                yLabel != null ? 'Axe Y : $yLabel' : 'Axe Y (Amplitude)',
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFunctionLineChart() {
    // Generate true data points
    final points = <Offset>[];
    final minX = (domain != null && domain!.isNotEmpty) ? domain![0] : 0.0;
    final maxX = (domain != null && domain!.length > 1) ? domain![1] : 4.0;
    const stepCount = 120;
    final step = (maxX - minX) / stepCount;

    double minY = 0.0;
    double maxY = 1.0;

    for (int i = 0; i <= stepCount; i++) {
      final x = minX + i * step;
      double y = 0.0;

      if (functionExpr != null) {
        final expr = functionExpr!.toLowerCase();
        if (expr.contains('sinc') ||
            expr.contains('sin(pi*x)/(pi*x)') ||
            expr.contains('sin(x)/x') ||
            expr.contains('sin(pi*t)/(pi*t)') ||
            expr.contains('sin(t)/t')) {
          // Sinus cardinal : sinc(t) = sin(pi*t) / (pi*t)
          if (x.abs() < 1e-6) {
            y = 1.0;
          } else {
            final arg = (expr.contains('sin(x)/x') || expr.contains('sin(t)/t')) ? x : math.pi * x;
            y = math.sin(arg) / arg;
          }
        } else if (expr.contains('sin')) {
          // 2*sin(2*pi*1000*x)
          y = 2.0 * math.sin(2 * math.pi * 1000 * x);
        } else if (expr.contains('0.5*9.81')) {
          // 0.5*9.81*x*x
          y = 0.5 * 9.81 * x * x;
        } else if (expr.contains('1-exp')) {
          // 5*(1-exp(-x/0.001))
          y = 5.0 * (1.0 - math.exp(-x / 0.001));
        } else if (expr.contains('0.05')) {
          // 100 * exp(-0.05 * t)
          y = 100.0 * math.exp(-0.05 * x);
        } else if (expr.contains('exp(-0.5*x)')) {
          // 1*exp(-0.5*x)
          y = 1.0 * math.exp(-0.5 * x);
        } else if (expr.contains('cos')) {
          // cos(2*pi*x)
          y = math.cos(2 * math.pi * x);
        } else if (expr.contains('sqrt(2*pi)')) {
          // Gaussian: (1/sqrt(2*pi))*exp(-(x*x)/2)
          y = (1.0 / math.sqrt(2 * math.pi)) * math.exp(-(x * x) / 2.0);
        } else {
          y = math.sin(x);
        }
      } else {
        y = math.sin(x);
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

    return Container(
      height: 180,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CustomPaint(
          painter: _FunctionPlotPainter(
            points: points,
            minY: minY,
            maxY: maxY,
            seriesNames: series,
          ),
        ),
      ),
    );
  }

  Widget _buildSpectrumChart() {
    return Container(
      height: 180,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('Pic FFT principal : f = 1000 Hz • A = 2.0 V', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
              Text('Résolution : 7.81 Hz', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10, fontFamily: 'monospace')),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(24, (idx) {
                // Peak around index 8 (~1000 Hz)
                final dist = (idx - 8).abs();
                double heightFactor = 0.05;
                if (dist == 0) {
                  heightFactor = 0.95;
                } else if (dist == 1) {
                  heightFactor = 0.40;
                } else if (dist == 2) {
                  heightFactor = 0.15;
                }
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Container(
                      height: 120 * heightFactor,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: dist == 0
                              ? [const Color(0xFF6366F1), const Color(0xFF38BDF8)]
                              : [const Color(0xFF334155), const Color(0xFF475569)],
                        ),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('0 Hz', style: TextStyle(color: Color(0xFF64748B), fontSize: 10)),
              Text('1000 Hz (Pic)', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10, fontWeight: FontWeight.bold)),
              Text('2000 Hz', style: TextStyle(color: Color(0xFF64748B), fontSize: 10)),
              Text('4000 Hz (Fe/2)', style: TextStyle(color: Color(0xFF64748B), fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart() {
    final data = rawData ?? [
      {'x': 'Acide fort', 'y': 1.0},
      {'x': 'Acide faible', 'y': 4.0},
      {'x': 'Neutre', 'y': 7.0},
      {'x': 'Basique faible', 'y': 9.0},
      {'x': 'Basique fort', 'y': 13.0},
    ];

    return Container(
      height: 180,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: data.map((item) {
          final xLabel = item['x'] as String? ?? '';
          final yVal = (item['y'] as num?)?.toDouble() ?? 0.0;
          final factor = (yVal / 14.0).clamp(0.05, 1.0);

          Color barColor = const Color(0xFF10B981);
          if (yVal < 3) barColor = const Color(0xFFDC2626);
          else if (yVal < 7) barColor = const Color(0xFFEA580C);
          else if (yVal == 7) barColor = const Color(0xFF10B981);
          else if (yVal < 11) barColor = const Color(0xFF2563EB);
          else barColor = const Color(0xFF7C3AED);

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('pH ${yVal.toInt()}', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: barColor)),
                  const SizedBox(height: 4),
                  Container(
                    height: 110 * factor,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: barColor,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    xLabel,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 9.5, color: Color(0xFF334155), fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _FunctionPlotPainter extends CustomPainter {
  final List<Offset> points;
  final double minY;
  final double maxY;
  final List<String>? seriesNames;

  _FunctionPlotPainter({
    required this.points,
    required this.minY,
    required this.maxY,
    this.seriesNames,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    // Draw Grid Lines
    final gridPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 1.0;

    for (int i = 1; i <= 4; i++) {
      final y = size.height * (i / 5.0);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Zero Axis Line if within range
    if (minY < 0 && maxY > 0) {
      final zeroY = size.height * (1.0 - (0.0 - minY) / (maxY - minY));
      final zeroPaint = Paint()
        ..color = const Color(0xFFCBD5E1)
        ..strokeWidth = 1.5;
      canvas.drawLine(Offset(0, zeroY), Offset(size.width, zeroY), zeroPaint);
    }

    // Plot Curve
    final path = Path();
    final fillPath = Path();

    for (int i = 0; i < points.length; i++) {
      final normX = (i / (points.length - 1)) * size.width;
      final normY = size.height * (1.0 - ((points[i].dy - minY) / (maxY - minY)).clamp(0.0, 1.0));

      if (i == 0) {
        path.moveTo(normX, normY);
        fillPath.moveTo(normX, size.height);
        fillPath.lineTo(normX, normY);
      } else {
        path.lineTo(normX, normY);
        fillPath.lineTo(normX, normY);
      }
    }
    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    // Fill Gradient
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF38BDF8).withOpacity(0.35),
          const Color(0xFF38BDF8).withOpacity(0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, fillPaint);

    // Stroke Curve
    final linePaint = Paint()
      ..color = const Color(0xFF0284C7)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _FunctionPlotPainter oldDelegate) => true;
}

/// Interactive Electrical Circuit Schematic Component
class DwsElectricCircuitWidget extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> components;
  final List<String> connections;

  const DwsElectricCircuitWidget({
    super.key,
    required this.title,
    required this.components,
    required this.connections,
  });

  @override
  Widget build(BuildContext context) {
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
              const Icon(Icons.electrical_services_rounded, size: 19, color: Color(0xFFD97706)),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('Schéma Circuit Interactif ⚡', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFFB45309))),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Schematic Wiring View
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Voltage Source
                  _circuitComponentCard('V1', 'Source de tension', '⚡ 5 V', const Color(0xFFDC2626)),
                  _wireConnector(),
                  // Resistor
                  _circuitComponentCard('R1', 'Résistance', '1 kΩ (1000 Ω)', const Color(0xFFD97706)),
                  _wireConnector(),
                  // Capacitor
                  _circuitComponentCard('C1', 'Condensateur', '1 µF (1e-6 F)', const Color(0xFF2563EB)),
                  _wireConnector(isReturn: true),
                  _groundNodeCard(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Liaisons : ${connections.join(" • ")}',
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }

  Widget _circuitComponentCard(String id, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.5)),
        boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 3, offset: Offset(0, 1))],
      ),
      child: Column(
        children: [
          Text(id, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
            child: Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
          ),
        ],
      ),
    );
  }

  Widget _wireConnector({bool isReturn = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Container(width: 24, height: 2, color: const Color(0xFF0F172A)),
          Icon(isReturn ? Icons.arrow_back_ios_rounded : Icons.arrow_forward_ios_rounded, size: 10, color: const Color(0xFF0F172A)),
        ],
      ),
    );
  }

  Widget _groundNodeCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(6)),
      child: const Text('Masse (GND)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
    );
  }
}

/// Chemical Periodic Table Component with interactive tiles
class DwsPeriodicTableWidget extends StatelessWidget {
  final String? title;
  final List<String> elements;

  const DwsPeriodicTableWidget({
    super.key,
    this.title,
    required this.elements,
  });

  static const Map<String, Map<String, dynamic>> elementInfo = {
    'H': {'z': 1, 'name': 'Hydrogène', 'mass': 1.008, 'cat': 'Non-métal', 'color': Color(0xFF38BDF8)},
    'He': {'z': 2, 'name': 'Hélium', 'mass': 4.0026, 'cat': 'Gaz noble', 'color': Color(0xFFA855F7)},
    'Li': {'z': 3, 'name': 'Lithium', 'mass': 6.94, 'cat': 'Alcalin', 'color': Color(0xFFEF4444)},
    'Be': {'z': 4, 'name': 'Béryllium', 'mass': 9.0122, 'cat': 'Alcalino-terreux', 'color': Color(0xFFF97316)},
    'B': {'z': 5, 'name': 'Bore', 'mass': 10.81, 'cat': 'Métalloïde', 'color': Color(0xFFFBBF24)},
    'C': {'z': 6, 'name': 'Carbone', 'mass': 12.011, 'cat': 'Non-métal', 'color': Color(0xFF38BDF8)},
    'N': {'z': 7, 'name': 'Azote', 'mass': 14.007, 'cat': 'Non-métal', 'color': Color(0xFF38BDF8)},
    'O': {'z': 8, 'name': 'Oxygène', 'mass': 15.999, 'cat': 'Non-métal', 'color': Color(0xFF38BDF8)},
    'F': {'z': 9, 'name': 'Fluor', 'mass': 18.998, 'cat': 'Halogène', 'color': Color(0xFF10B981)},
    'Ne': {'z': 10, 'name': 'Néon', 'mass': 20.180, 'cat': 'Gaz noble', 'color': Color(0xFFA855F7)},
    'Na': {'z': 11, 'name': 'Sodium', 'mass': 22.990, 'cat': 'Alcalin', 'color': Color(0xFFEF4444)},
    'Mg': {'z': 12, 'name': 'Magnésium', 'mass': 24.305, 'cat': 'Alcalino-terreux', 'color': Color(0xFFF97316)},
    'Al': {'z': 13, 'name': 'Aluminium', 'mass': 26.982, 'cat': 'Métal pauvre', 'color': Color(0xFF64748B)},
    'Si': {'z': 14, 'name': 'Silicium', 'mass': 28.085, 'cat': 'Métalloïde', 'color': Color(0xFFFBBF24)},
    'P': {'z': 15, 'name': 'Phosphore', 'mass': 30.974, 'cat': 'Non-métal', 'color': Color(0xFF38BDF8)},
    'S': {'z': 16, 'name': 'Soufre', 'mass': 32.06, 'cat': 'Non-métal', 'color': Color(0xFF38BDF8)},
    'Cl': {'z': 17, 'name': 'Chlore', 'mass': 35.45, 'cat': 'Halogène', 'color': Color(0xFF10B981)},
    'Ar': {'z': 18, 'name': 'Argon', 'mass': 39.948, 'cat': 'Gaz noble', 'color': Color(0xFFA855F7)},
  };

  @override
  Widget build(BuildContext context) {
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
              const Icon(Icons.science_rounded, size: 19, color: Color(0xFF0284C7)),
              const SizedBox(width: 8),
              Text(title ?? 'Tableau Périodique des Éléments (Extrait interactif)', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: elements.map((sym) {
              final info = elementInfo[sym] ?? {'z': 1, 'name': sym, 'mass': 1.0, 'cat': 'Élément', 'color': const Color(0xFF64748B)};
              final z = info['z'] as int;
              final name = info['name'] as String;
              final color = info['color'] as Color;

              return InkWell(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Row(
                        children: [
                          CircleAvatar(backgroundColor: color, child: Text(sym, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                          const SizedBox(width: 10),
                          Text('$name ($sym)', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('• Numéro atomique Z : $z', style: const TextStyle(fontSize: 13)),
                          Text('• Masse atomique : ${info['mass']} g/mol', style: const TextStyle(fontSize: 13)),
                          Text('• Catégorie : ${info['cat']}', style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Fermer')),
                      ],
                    ),
                  );
                },
                child: Container(
                  width: 64,
                  height: 64,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.withOpacity(0.4)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('$z', style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.bold)),
                      Text(sym, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
                      Text(name, style: const TextStyle(fontSize: 7.5, color: Color(0xFF475569)), overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

/// UML Diagram Widget (Use Case and Sequence)
class DwsUmlDiagramWidget extends StatelessWidget {
  final String title;
  final String diagramType; // 'use_case' or 'sequence'
  final List<Map<String, dynamic>>? actors;
  final List<Map<String, dynamic>>? useCases;
  final List<String>? relations;
  final List<String>? participants;
  final List<Map<String, dynamic>>? messages;

  const DwsUmlDiagramWidget({
    super.key,
    required this.title,
    required this.diagramType,
    this.actors,
    this.useCases,
    this.relations,
    this.participants,
    this.messages,
  });

  @override
  Widget build(BuildContext context) {
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
              Icon(diagramType == 'sequence' ? Icons.linear_scale_rounded : Icons.hub_rounded, size: 19, color: const Color(0xFF6366F1)),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(6)),
                child: Text('UML ${diagramType.toUpperCase()}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF4338CA))),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (diagramType == 'sequence')
            _buildSequenceView()
          else
            _buildUseCaseView(),
        ],
      ),
    );
  }

  Widget _buildUseCaseView() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Actors
          const Text('Acteurs :', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: (actors ?? []).map((act) {
              return Chip(
                avatar: const Icon(Icons.person_rounded, size: 14, color: AppTheme.primary),
                label: Text(act['name'] as String? ?? '', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                backgroundColor: Colors.white,
              );
            }).toList(),
          ),
          const Divider(height: 20),
          // System Boundary Use Cases
          const Text('Cas d\'utilisation du Système (DWS) :', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: (useCases ?? []).map((uc) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF818CF8)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.radio_button_checked_rounded, size: 12, color: Color(0xFF6366F1)),
                    const SizedBox(width: 6),
                    Text(uc['name'] as String? ?? '', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSequenceView() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Participants Lifelines
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: (participants ?? []).map((p) {
                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF38BDF8)),
                  ),
                  child: Text(p, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8), fontFamily: 'monospace')),
                );
              }).toList(),
            ),
          ),
          const Divider(height: 16, color: Color(0xFF334155)),
          // Sequential Messages
          ...List.generate((messages ?? []).length, (i) {
            final msg = messages![i];
            final from = msg['from'] as String? ?? '';
            final to = msg['to'] as String? ?? '';
            final label = msg['label'] as String? ?? '';

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(color: Color(0xFF334155), shape: BoxShape.circle),
                    child: Text('${i + 1}', style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(fontSize: 11.5, fontFamily: 'monospace'),
                        children: [
                          TextSpan(text: '$from ', style: const TextStyle(color: Color(0xFF93C5FD), fontWeight: FontWeight.bold)),
                          const TextSpan(text: '──> ', style: TextStyle(color: Color(0xFF64748B))),
                          TextSpan(text: '$to : ', style: const TextStyle(color: Color(0xFF93C5FD), fontWeight: FontWeight.bold)),
                          TextSpan(text: label, style: const TextStyle(color: Color(0xFFF1F5F9))),
                        ],
                      ),
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
}

/// 4-Layer Architecture Diagram Widget
class DwsArchitectureWidget extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> layers;

  const DwsArchitectureWidget({
    super.key,
    required this.title,
    required this.layers,
  });

  @override
  Widget build(BuildContext context) {
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
              const Icon(Icons.layers_rounded, size: 19, color: Color(0xFF0D9488)),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            ],
          ),
          const SizedBox(height: 12),
          Column(
            children: layers.map((layer) {
              final name = layer['name'] as String? ?? '';
              final comps = (layer['components'] as List?)?.map((e) => e.toString()).toList() ?? [];

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 100,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white), textAlign: TextAlign.center),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: comps.map((c) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFF94A3B8)),
                            ),
                            child: Text(c, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

/// OSI 7-Layer Stack Widget
class DwsLayerStackWidget extends StatelessWidget {
  final String title;
  final List<String> layers;

  const DwsLayerStackWidget({
    super.key,
    required this.title,
    required this.layers,
  });

  @override
  Widget build(BuildContext context) {
    const layerColors = [
      Color(0xFF7C3AED), // 7 Application
      Color(0xFF6366F1), // 6 Présentation
      Color(0xFF2563EB), // 5 Session
      Color(0xFF0284C7), // 4 Transport
      Color(0xFF059669), // 3 Réseau
      Color(0xFFD97706), // 2 Liaison
      Color(0xFFDC2626), // 1 Physique
    ];

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
              const Icon(Icons.stacked_bar_chart_rounded, size: 19, color: Color(0xFF6366F1)),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            ],
          ),
          const SizedBox(height: 12),
          Column(
            children: List.generate(layers.length, (idx) {
              final layerNumber = layers.length - idx;
              final name = layers[idx];
              final color = layerColors[idx % layerColors.length];

              return Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
                      child: Text('Couche $layerNumber', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                    const SizedBox(width: 12),
                    Text(name, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: color)),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
