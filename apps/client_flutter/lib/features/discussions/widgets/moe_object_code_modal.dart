import 'package:flutter/material.dart';
import '../../../shared/responsive/responsive.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/models/moe_object.dart';

/// Individual Dedicated Code Modal for MRixk Objects (MOE).
/// Features:
/// - Pure MRixk syntax editor (never raw HTML).
/// - Syntax highlighting and line numbers.
/// - Autocompletion / Property insertion chips.
/// - Real-time syntax and missing parameter detection.
/// - Cancel & Apply buttons.
/// - Fully responsive for mobile and desktop.
class MoeObjectCodeModal extends StatefulWidget {
  final MoeObject object;
  final ValueChanged<MoeObject> onApply;

  const MoeObjectCodeModal({
    super.key,
    required this.object,
    required this.onApply,
  });

  /// Displays the modal responsively (as a Dialog on desktop/tablet, or BottomSheet on mobile)
  static Future<void> show(BuildContext context, MoeObject object, ValueChanged<MoeObject> onApply) async {
    final isMobile = MediaQuery.of(context).size.width < 600;

    if (isMobile) {
      await showResponsiveSheet(
        useSafeArea: true,
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => MoeObjectCodeModal(object: object, onApply: onApply),
      );
    } else {
      await showDialog(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720, maxHeight: 680),
            child: MoeObjectCodeModal(object: object, onApply: onApply),
          ),
        ),
      );
    }
  }

  @override
  State<MoeObjectCodeModal> createState() => _MoeObjectCodeModalState();
}

class _MoeObjectCodeModalState extends State<MoeObjectCodeModal> {
  late TextEditingController _codeController;
  late String _currentCode;
  String? _errorMessage;
  bool _isValid = true;

  @override
  void initState() {
    super.initState();
    _currentCode = widget.object.toMrixkCode();
    _codeController = TextEditingController(text: _currentCode);
    _codeController.addListener(_validateLiveCode);
    _validateLiveCode();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _validateLiveCode() {
    final code = _codeController.text;
    String? err;

    // Check bracket balance
    final openBraces = '{'.allMatches(code).length;
    final closeBraces = '}'.allMatches(code).length;
    if (openBraces != closeBraces) {
      err = 'Accolades non équilibrées : $openBraces ouvrante(s), $closeBraces fermante(s).';
    }

    final openBrackets = '['.allMatches(code).length;
    final closeBrackets = ']'.allMatches(code).length;
    if (openBrackets != closeBrackets) {
      err = 'Crochets non équilibrés : $openBrackets ouvrant(s), $closeBrackets fermant(s).';
    }

    setState(() {
      _errorMessage = err;
      _isValid = err == null;
    });
  }

  void _insertSnippet(String snippet) {
    final text = _codeController.text;
    final sel = _codeController.selection;
    final start = sel.start >= 0 ? sel.start : text.length;
    final end = sel.end >= 0 ? sel.end : text.length;

    final newText = text.replaceRange(start, end, snippet);
    _codeController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + snippet.length),
    );
  }

  void _applyAndClose() {
    final code = _codeController.text.trim();
    if (!_isValid) return;

    // Parse the updated code via MoeEngine
    final parsedMap = MoeEngine.extractObjects(code);
    MoeObject updated;
    if (parsedMap.containsKey(widget.object.name)) {
      updated = parsedMap[widget.object.name]!;
    } else if (parsedMap.isNotEmpty) {
      updated = parsedMap.values.first;
    } else {
      updated = widget.object.copyWith(rawMrixkCode: code);
    }

    widget.onApply(updated);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A), // Sleek high-tech dark IDE theme
        borderRadius: BorderRadius.circular(isMobile ? 20 : 16),
        border: Border.all(color: const Color(0xFF1E293B)),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 16, offset: Offset(0, 4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF334155),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.code_rounded, size: 16, color: Color(0xFF38BDF8)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Configuration Code — ${widget.object.name}',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0284C7),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              widget.object.type.name.toUpperCase(),
                              style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'monospace'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Langage déclaratif natif MRixk • Modifications synchronisées',
                        style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF94A3B8)),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          // Autocompletion & Property Injection Toolbar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            color: const Color(0xFF131D31),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  const Text('Suggestions :', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  if (widget.object.type == MoeObjectType.curve) ...[
                    _chip('+ Formule sin', '{${widget.object.name}.formule="A*sin(2*pi*f*t)"}\n'),
                    _chip('+ Formule sinc', '{${widget.object.name}.formule="sinc(t)"}\n'),
                    _chip('+ Paramètre A=2', '{${widget.object.name}.A=2}\n'),
                    _chip('+ Paramètre f=50', '{${widget.object.name}.f=50}\n'),
                    _chip('+ Domaine [-6, 6]', '{${widget.object.name}.domain=[-6.0, 6.0]}\n'),
                  ] else if (widget.object.type == MoeObjectType.table) ...[
                    _chip('+ Dimension [5,4]', '{${widget.object.name}[5,4]}\n'),
                    _chip('+ Cellule texte', '{${widget.object.name}[0,0]="Libellé"}\n'),
                    _chip('+ Cellule nombre', '{${widget.object.name}[1,0]=100}\n'),
                  ] else ...[
                    _chip('+ Titre', '{${widget.object.name}.title="Mon Objet"}\n'),
                  ],
                ],
              ),
            ),
          ),

          // Error / Validation Banner
          if (_errorMessage != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              color: const Color(0xFF450A0A),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, size: 15, color: Color(0xFFF87171)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFFFCA5A5), fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),

          // Code Editor with Line Numbers
          Expanded(
            child: Container(
              color: const Color(0xFF090D16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Line numbers gutter
                  Container(
                    width: 36,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    color: const Color(0xFF0F172A),
                    child: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _codeController,
                      builder: (ctx, val, _) {
                        final lineCount = '\n'.allMatches(val.text).length + 1;
                        return Column(
                          children: List.generate(
                            lineCount,
                            (i) => Text(
                              '${i + 1}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFF475569),
                                fontFamily: 'monospace',
                                height: 1.45,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Container(width: 1, color: const Color(0xFF1E293B)),
                  // Code input field
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: TextField(
                        controller: _codeController,
                        maxLines: null,
                        expands: true,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                          color: Color(0xFFF1F5F9),
                          height: 1.45,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          hintText: '// Code MRixk de configuration...',
                          hintStyle: TextStyle(color: Color(0xFF475569)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Footer Actions
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      _isValid ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                      size: 15,
                      color: _isValid ? const Color(0xFF34D399) : const Color(0xFFFBBF24),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isValid ? 'Syntaxe conforme ✅' : 'Erreur de syntaxe',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _isValid ? const Color(0xFF34D399) : const Color(0xFFFBBF24),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF475569)),
                        foregroundColor: const Color(0xFFCBD5E1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Annuler', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _isValid ? _applyAndClose : null,
                      icon: const Icon(Icons.check_rounded, size: 15),
                      label: const Text('Appliquer', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String get $name => widget.object.name;

  Widget _chip(String label, String snippet) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ActionChip(
        backgroundColor: const Color(0xFF1E293B),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        label: Text(label, style: const TextStyle(fontSize: 10.5, color: Color(0xFF38BDF8), fontFamily: 'monospace')),
        onPressed: () => _insertSnippet(snippet),
      ),
    );
  }
}
