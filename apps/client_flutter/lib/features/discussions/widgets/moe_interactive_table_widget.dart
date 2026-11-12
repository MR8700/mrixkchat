import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/models/moe_object.dart';

/// In-place Interactive Table/Matrix Widget for MRixk DWS.
/// Allows direct cell editing, row/col addition and deletion, and Code modal trigger.
class MoeInteractiveTableWidget extends StatefulWidget {
  final MoeObject object;
  final bool isReadOnly;
  final ValueChanged<MoeObject>? onChanged;
  final VoidCallback? onOpenCodeModal;

  const MoeInteractiveTableWidget({
    super.key,
    required this.object,
    this.isReadOnly = false,
    this.onChanged,
    this.onOpenCodeModal,
  });

  @override
  State<MoeInteractiveTableWidget> createState() => _MoeInteractiveTableWidgetState();
}

class _MoeInteractiveTableWidgetState extends State<MoeInteractiveTableWidget> {
  late List<List<String>> _grid;
  List<String>? _headers;
  int? _editingRow;
  int? _editingCol;
  late TextEditingController _cellEditorController;
  final FocusNode _cellFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _initData();
    _cellEditorController = TextEditingController();
  }

  @override
  void didUpdateWidget(covariant MoeInteractiveTableWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.object != widget.object) {
      _initData();
    }
  }

  void _initData() {
    if (widget.object.data is List<List<String>>) {
      _grid = List<List<String>>.from(
        (widget.object.data as List<List<String>>).map((r) => List<String>.from(r)),
      );
    } else {
      final rows = widget.object.properties['rows'] as int? ?? 3;
      final cols = widget.object.properties['cols'] as int? ?? 3;
      _grid = List.generate(rows, (_) => List.generate(cols, (_) => ''));
    }
    _headers = (widget.object.properties['headers'] as List<dynamic>?)?.map((e) => e.toString()).toList();
  }

  @override
  void dispose() {
    _cellEditorController.dispose();
    _cellFocusNode.dispose();
    super.dispose();
  }

  void _saveCurrentCell() {
    if (_editingRow != null && _editingCol != null) {
      final text = _cellEditorController.text;
      if (_editingRow == -1 && _headers != null) {
        _headers![_editingCol!] = text;
      } else if (_editingRow! >= 0 && _editingRow! < _grid.length && _editingCol! < _grid[_editingRow!].length) {
        _grid[_editingRow!][_editingCol!] = text;
      }
      _notifyChange();
      setState(() {
        _editingRow = null;
        _editingCol = null;
      });
    }
  }

  void _startEditingCell(int r, int c, String currentVal) {
    if (widget.isReadOnly) return;
    _saveCurrentCell();
    setState(() {
      _editingRow = r;
      _editingCol = c;
      _cellEditorController.text = currentVal;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cellFocusNode.requestFocus();
      _cellEditorController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _cellEditorController.text.length,
      );
    });
  }

  void _notifyChange() {
    if (widget.onChanged != null) {
      final updated = widget.object.copyWith(
        data: _grid,
        properties: {
          ...widget.object.properties,
          'rows': _grid.length,
          'cols': _grid.isNotEmpty ? _grid.first.length : 0,
          if (_headers != null) 'headers': _headers,
        },
      );
      widget.onChanged!(updated);
    }
  }

  void _addRow() {
    if (widget.isReadOnly) return;
    _saveCurrentCell();
    final cols = _grid.isNotEmpty ? _grid.first.length : 3;
    setState(() {
      _grid.add(List.generate(cols, (_) => ''));
    });
    _notifyChange();
  }

  void _deleteLastRow() {
    if (widget.isReadOnly || _grid.length <= 1) return;
    _saveCurrentCell();
    setState(() {
      _grid.removeLast();
    });
    _notifyChange();
  }

  void _addColumn() {
    if (widget.isReadOnly) return;
    _saveCurrentCell();
    setState(() {
      for (final row in _grid) {
        row.add('');
      }
      _headers?.add('Col ${_grid.first.length}');
    });
    _notifyChange();
  }

  void _deleteLastColumn() {
    if (widget.isReadOnly || (_grid.isNotEmpty && _grid.first.length <= 1)) return;
    _saveCurrentCell();
    setState(() {
      for (final row in _grid) {
        row.removeLast();
      }
      if (_headers != null && _headers!.length > _grid.first.length) {
        _headers!.removeLast();
      }
    });
    _notifyChange();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.object.properties['title'] as String? ?? 'Tableau ${widget.object.name}';
    final rowsCount = _grid.length;
    final colsCount = _grid.isNotEmpty ? _grid.first.length : 0;

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
          // Header Bar with Code Modal button
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
                  child: const Icon(Icons.table_chart_rounded, size: 16, color: AppTheme.primary),
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
                            ? 'Tableau de données'
                            : 'Objet MOE : {${widget.object.name}[$rowsCount, $colsCount]}',
                        style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Text(
                    '$rowsCount × $colsCount',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155), fontFamily: 'monospace'),
                  ),
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

          // Interactive Grid Table
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Table(
                defaultColumnWidth: const FixedColumnWidth(110.0),
                border: TableBorder.all(color: const Color(0xFFE2E8F0), width: 1.0, borderRadius: BorderRadius.circular(6)),
                children: [
                  // Optional Headers row
                  if (_headers != null && _headers!.isNotEmpty)
                    TableRow(
                      decoration: const BoxDecoration(color: Color(0xFFF1F5F9)),
                      children: List.generate(_headers!.length, (c) {
                        final isEditing = _editingRow == -1 && _editingCol == c;
                        return _buildCellWidget(-1, c, _headers![c], isHeader: true, isEditing: isEditing);
                      }),
                    ),
                  // Data rows
                  ...List.generate(_grid.length, (r) {
                    final isEven = r % 2 == 0;
                    return TableRow(
                      decoration: BoxDecoration(color: isEven ? Colors.white : const Color(0xFFFAFAFA)),
                      children: List.generate(_grid[r].length, (c) {
                        final isEditing = _editingRow == r && _editingCol == c;
                        return _buildCellWidget(r, c, _grid[r][c], isHeader: false, isEditing: isEditing);
                      }),
                    );
                  }),
                ],
              ),
            ),
          ),

          // Direct Manipulation Controls (Add/Remove rows and cols)
          if (!widget.isReadOnly)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(15)),
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _actionButton(
                        icon: Icons.add_rounded,
                        label: '+ Ligne',
                        onTap: _addRow,
                      ),
                      const SizedBox(width: 6),
                      _actionButton(
                        icon: Icons.remove_rounded,
                        label: '- Ligne',
                        onTap: _deleteLastRow,
                        isDestructive: true,
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _actionButton(
                        icon: Icons.add_rounded,
                        label: '+ Colonne',
                        onTap: _addColumn,
                      ),
                      const SizedBox(width: 6),
                      _actionButton(
                        icon: Icons.remove_rounded,
                        label: '- Colonne',
                        onTap: _deleteLastColumn,
                        isDestructive: true,
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

  Widget _buildCellWidget(int r, int c, String val, {required bool isHeader, required bool isEditing}) {
    if (isEditing) {
      return Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        color: const Color(0xFFEFF6FF),
        child: Center(
          child: TextField(
            controller: _cellEditorController,
            focusNode: _cellFocusNode,
            autofocus: true,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
              color: const Color(0xFF1E293B),
            ),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              border: InputBorder.none,
            ),
            onSubmitted: (_) {
              _saveCurrentCell();
              // Navigate to next row or column on Enter
              if (r + 1 < _grid.length) {
                _startEditingCell(r + 1, c, _grid[r + 1][c]);
              }
            },
          ),
        ),
      );
    }

    return InkWell(
      onTap: widget.isReadOnly ? null : () => _startEditingCell(r, c, val),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        alignment: Alignment.centerLeft,
        child: Text(
          val.isNotEmpty ? val : (widget.isReadOnly ? '' : '—'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
            color: val.isEmpty ? const Color(0xFF94A3B8) : (isHeader ? const Color(0xFF0F172A) : const Color(0xFF334155)),
          ),
        ),
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isDestructive ? const Color(0xFFFECACA) : const Color(0xFFCBD5E1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: isDestructive ? const Color(0xFFDC2626) : const Color(0xFF475569)),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDestructive ? const Color(0xFFDC2626) : const Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
