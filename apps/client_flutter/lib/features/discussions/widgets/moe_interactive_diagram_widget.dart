import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/models/moe_object.dart';

/// In-place Interactive Diagram & Flowchart Widget for MRixk DWS.
/// Displays nodes as interactive chips, allows adding/removing blocks,
/// editing node texts, and includes a direct Code button.
class MoeInteractiveDiagramWidget extends StatefulWidget {
  final MoeObject object;
  final bool isReadOnly;
  final ValueChanged<MoeObject>? onChanged;
  final VoidCallback? onOpenCodeModal;

  const MoeInteractiveDiagramWidget({
    super.key,
    required this.object,
    this.isReadOnly = false,
    this.onChanged,
    this.onOpenCodeModal,
  });

  @override
  State<MoeInteractiveDiagramWidget> createState() => _MoeInteractiveDiagramWidgetState();
}

class _MoeInteractiveDiagramWidgetState extends State<MoeInteractiveDiagramWidget> {
  late List<String> _nodes;

  @override
  void initState() {
    super.initState();
    _initNodes();
  }

  @override
  void didUpdateWidget(covariant MoeInteractiveDiagramWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.object != widget.object) {
      _initNodes();
    }
  }

  void _initNodes() {
    if (widget.object.data is List) {
      _nodes = (widget.object.data as List).map((e) => e.toString()).toList();
    } else {
      _nodes = ['1. Source', '2. Traitement', '3. Sortie'];
    }
  }

  void _addNode() {
    if (widget.isReadOnly) return;
    setState(() {
      _nodes.add('${_nodes.length + 1}. Nouvelle Étape');
    });
    _notifyChange();
  }

  void _removeLastNode() {
    if (widget.isReadOnly || _nodes.length <= 1) return;
    setState(() {
      _nodes.removeLast();
    });
    _notifyChange();
  }

  void _editNodeDialog(int index) {
    if (widget.isReadOnly) return;
    final textController = TextEditingController(text: _nodes[index]);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Modifier le Nœud', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Libellé de l\'étape',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
            onPressed: () {
              setState(() {
                _nodes[index] = textController.text.trim();
              });
              _notifyChange();
              Navigator.of(ctx).pop();
            },
            child: const Text('Valider'),
          ),
        ],
      ),
    );
  }

  void _notifyChange() {
    if (widget.onChanged != null) {
      final updated = widget.object.copyWith(
        data: _nodes,
      );
      widget.onChanged!(updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.object.properties['title'] as String? ?? 'Diagramme ${widget.object.name}';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.account_tree_rounded, size: 16, color: AppTheme.primary),
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
                        widget.isReadOnly
                            ? 'Organigramme séquentiel • ${_nodes.length} étapes'
                            : 'Objet MOE : {${widget.object.name}:diagramme} • ${_nodes.length} nœuds',
                        style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
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

          // Horizontal Process Flowchart
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                for (int i = 0; i < _nodes.length; i++) ...[
                  InkWell(
                    onTap: widget.isReadOnly ? null : () => _editNodeDialog(i),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: i == 0
                              ? [const Color(0xFF2563EB), const Color(0xFF1D4ED8)]
                              : i == _nodes.length - 1
                                  ? [const Color(0xFF10B981), const Color(0xFF059669)]
                                  : [Colors.white, const Color(0xFFF1F5F9)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: (i == 0 || i == _nodes.length - 1)
                              ? Colors.transparent
                              : const Color(0xFFCBD5E1),
                        ),
                        boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 4, offset: Offset(0, 2))],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _nodes[i],
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: (i == 0 || i == _nodes.length - 1) ? Colors.white : const Color(0xFF1E293B),
                            ),
                          ),
                          if (!widget.isReadOnly) ...[
                            const SizedBox(width: 6),
                            Icon(
                              Icons.edit_rounded,
                              size: 11,
                              color: (i == 0 || i == _nodes.length - 1) ? Colors.white70 : const Color(0xFF94A3B8),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (i < _nodes.length - 1)
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

          // Actions Toolbar
          if (!widget.isReadOnly)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(15)),
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  InkWell(
                    onTap: _addNode,
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.add_rounded, size: 12, color: Color(0xFF475569)),
                          SizedBox(width: 4),
                          Text('+ Étape', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: _removeLastNode,
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.remove_rounded, size: 12, color: Color(0xFFDC2626)),
                          SizedBox(width: 4),
                          Text('- Étape', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFDC2626))),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
