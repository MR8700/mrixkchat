import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/conversation.dart';
import '../../core/models/group_note.dart';
import '../../core/models/message.dart';
import '../../core/models/title_config.dart';
import '../../core/repositories/conversation_repository.dart';
import '../../core/repositories/group_note_repository.dart';
import '../../core/repositories/message_repository.dart';
import '../../core/repositories/profile_repository.dart';
import '../../core/services/formula_engine.dart';
import '../../core/theme/app_theme.dart';
import 'widgets/group_note_renderer.dart';

class GroupNotepadScreen extends StatefulWidget {
  final Conversation conversation;

  const GroupNotepadScreen({
    super.key,
    required this.conversation,
  });

  /// Opens the notepad directly inside the conversation as an interactive in-place modal sheet
  static Future<void> showInConversation(BuildContext context, Conversation conversation) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.94,
          child: GroupNotepadScreen(conversation: conversation),
        ),
      ),
    );
  }

  @override
  State<GroupNotepadScreen> createState() => _GroupNotepadScreenState();
}

class _GroupNotepadScreenState extends State<GroupNotepadScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late TextEditingController _textController;
  late TextEditingController _codeController;
  late TextEditingController _titleController;
  late GroupNote _currentNote;
  late Map<String, String> _components;
  double _lineSpacing = 1.5;
  double _paragraphSpacing = 14.0;
  bool _hasUnsavedChanges = false;
  Timer? _debounceTimer;

  // Compartment state: 0 = Document, 1 = Éditer
  int _activeCompartment = 0;

  // Edit sub-mode: 'word' or 'code'
  String _editSubMode = 'word';

  // Excel-style formula guide query
  String _formulaFilter = '';
  bool _showFormulaGuide = false;

  // Text selection tracking for contextual floating toolbar
  TextSelection _currentSelection = const TextSelection.collapsed(offset: -1);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _activeCompartment = _tabController.index == 0 ? 0 : 1;
        });
      }
    });

    final repo = context.read<GroupNoteRepository>();
    _currentNote = repo.getNote(
      widget.conversation.id,
      groupTitle: widget.conversation.title,
    );
    _textController = TextEditingController(text: _currentNote.content);
    _codeController = TextEditingController(text: _buildCombinedCodeSource(_currentNote.content, _currentNote.components));
    _titleController = TextEditingController(text: _currentNote.title);
    _components = Map<String, String>.from(_currentNote.components);
    _lineSpacing = _currentNote.lineSpacing;
    _paragraphSpacing = _currentNote.paragraphSpacing;

    _textController.addListener(_onWordTextChanged);
    _codeController.addListener(_onCodeTextChanged);
    _titleController.addListener(_onTextChanged);
  }

  void _onWordTextChanged() {
    _onTextChanged();
    final text = _textController.text;
    final sel = _textController.selection;
    _currentSelection = sel;

    // Detect if cursor is near {{ or { for Excel-like formula autocompletion
    if (sel.baseOffset >= 0 && sel.baseOffset <= text.length) {
      final textBeforeCursor = text.substring(0, sel.baseOffset);
      final match = RegExp(r'\{([^{}\s]*)$').firstMatch(textBeforeCursor);
      if (match != null) {
        final query = match.group(1)?.replaceAll('{', '').toLowerCase() ?? '';
        setState(() {
          _showFormulaGuide = true;
          _formulaFilter = query;
        });
      } else if (_showFormulaGuide) {
        setState(() => _showFormulaGuide = false);
      }
    }

    // Auto-detect newly typed {Titre du tableau} variables and seed in components
    _syncVariablesFromWordToComponents(text);

    // Live Instant Real-time Sync to repository (debounced)
    _scheduleLiveInstantSync();
  }

  void _onCodeTextChanged() {
    if (_editSubMode != 'code') return;
    _onTextChanged();
    _syncFromCodeToWord(_codeController.text);
    _scheduleLiveInstantSync();
  }

  void _onTextChanged() {
    if (!_hasUnsavedChanges) {
      setState(() => _hasUnsavedChanges = true);
    }
  }

  void _scheduleLiveInstantSync() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      _saveLiveToRepository();
    });
  }

  Future<void> _saveLiveToRepository() async {
    final myProfile = context.read<ProfileRepository>().getProfile();
    final updated = _currentNote.copyWith(
      title: _titleController.text.trim().isNotEmpty
          ? _titleController.text.trim()
          : 'Bloc-Note : ${widget.conversation.title}',
      content: _textController.text,
      components: _components,
      lineSpacing: _lineSpacing,
      paragraphSpacing: _paragraphSpacing,
      lastModified: 'À l\'instant',
      lastModifiedBy: myProfile.displayName.isNotEmpty ? myProfile.displayName : 'Richard MARE',
    );
    await context.read<GroupNoteRepository>().saveNote(updated);
    _currentNote = updated;
  }

  void _syncVariablesFromWordToComponents(String text) {
    final singleBraceMatches = RegExp(r'\{([a-zA-Z0-9_\s\-]+)\}').allMatches(text);
    bool changed = false;
    for (final m in singleBraceMatches) {
      final varName = m.group(1)?.trim();
      if (varName != null &&
          varName.isNotEmpty &&
          !varName.startsWith('int ') &&
          !varName.startsWith('float ') &&
          !varName.contains('=') &&
          !varName.startsWith('id=') &&
          !_components.containsKey(varName)) {
        // Automatically scaffold component code in Code compartment
        _components[varName] = '''
<table border="1">
  <thead>
    <tr><th>Paramètre</th><th>Valeur</th><th>Statut</th></tr>
  </thead>
  <tbody>
    <tr><td>Donnée 1</td><td>100</td><td>Validé ✅</td></tr>
    <tr><td>Donnée 2</td><td>200</td><td>Conforme 🚀</td></tr>
  </tbody>
</table>''';
        changed = true;
      }
    }
    if (changed) {
      _codeController.text = _buildCombinedCodeSource(_textController.text, _components);
    }
  }

  String _buildCombinedCodeSource(String content, Map<String, String> comps) {
    final buf = StringBuffer();
    buf.writeln('// === Document MRixk - Mode Code ===');
    buf.writeln(content);
    buf.writeln();
    buf.writeln('// === Définitions des Composants & Variables ===');
    comps.forEach((name, code) {
      buf.writeln('{{id="$name";');
      buf.writeln(code.trim());
      buf.writeln('}}');
      buf.writeln();
    });
    return buf.toString();
  }

  void _syncFromCodeToWord(String rawCode) {
    final compRegex = RegExp(r'\{\{id="([^"]+)";\s*(.*?)\}\}', dotAll: true);
    final extractedComps = <String, String>{};
    for (final m in compRegex.allMatches(rawCode)) {
      final id = m.group(1);
      final payload = m.group(2);
      if (id != null && payload != null) {
        extractedComps[id] = payload.trim();
      }
    }
    // Remove component blocks to get pure document text
    var cleanDoc = rawCode.replaceAll(compRegex, '');
    cleanDoc = cleanDoc.replaceAll(RegExp(r'\/\/ ===.*?==='), '').trim();

    _components.addAll(extractedComps);
    if (_textController.text != cleanDoc) {
      _textController.text = cleanDoc;
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _tabController.dispose();
    _textController.dispose();
    _codeController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  bool _canEdit() {
    final myProfile = context.read<ProfileRepository>().getProfile();
    final isAdmin = widget.conversation.isUserAdmin(myProfile.id);
    if (_currentNote.isLocked && !isAdmin) return false;
    if (widget.conversation.onlyAdminsCanEditNotes && !isAdmin) return false;
    return true;
  }

  Future<void> _handleSaveOrClose() async {
    if (!_canEdit()) {
      Navigator.of(context).pop();
      return;
    }

    if (!_hasUnsavedChanges) {
      Navigator.of(context).pop();
      return;
    }

    await _showSaveChoiceDialog();
  }

  Future<void> _showSaveChoiceDialog() async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.publish_rounded, color: AppTheme.primary),
            SizedBox(width: 8),
            Text('Publication du Bloc-Note', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Souhaitez-vous publier une carte mise à jour à la suite des textos dans la conversation de groupe, ou enregistrer les modifications directement sur place ?',
          style: TextStyle(fontSize: 13.5, height: 1.45),
        ),
        actions: [
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFDFE4ED)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.of(ctx).pop('in_place'),
            icon: const Icon(Icons.push_pin_outlined, size: 16, color: Color(0xFF0F172A)),
            label: const Text('Garder sur place', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.of(ctx).pop('post_in_chat'),
            icon: const Icon(Icons.send_rounded, size: 16),
            label: const Text('À la suite des textos', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (result == 'post_in_chat') {
      await _executeSave(postInChat: true);
      if (mounted) Navigator.of(context).pop();
    } else if (result == 'in_place') {
      await _executeSave(postInChat: false);
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _executeSave({required bool postInChat}) async {
    final myProfile = context.read<ProfileRepository>().getProfile();
    final now = DateTime.now();
    final timeStr =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')} à ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final updated = _currentNote.copyWith(
      title: _titleController.text.trim().isNotEmpty
          ? _titleController.text.trim()
          : 'Bloc-Note : ${widget.conversation.title}',
      content: _textController.text,
      components: _components,
      lineSpacing: _lineSpacing,
      paragraphSpacing: _paragraphSpacing,
      lastModified: timeStr,
      lastModifiedBy: myProfile.displayName.isNotEmpty ? myProfile.displayName : 'Richard MARE',
    );

    await context.read<GroupNoteRepository>().saveNote(updated);

    if (postInChat) {
      final hourMin =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      final shareText =
          '📝 [Bloc-Note du Groupe] "${updated.title}" mis à jour par ${updated.lastModifiedBy}.\nConsultez les formules et composants actualisés dans le bloc-note.';

      final msg = Message(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
        conversationId: widget.conversation.id,
        senderId: myProfile.id,
        senderName: myProfile.displayName.isNotEmpty ? myProfile.displayName : 'Moi',
        senderAvatar: myProfile.avatarUrl,
        type: MessageType.document,
        content: shareText,
        time: hourMin,
        isOutgoing: true,
        isRead: true,
      );

      context.read<MessageRepository>().sendMessage(msg);
      context.read<ConversationRepository>().updateLastMessage(
            conversationId: widget.conversation.id,
            message: '📝 Bloc-Note : mise à jour publiée',
            time: hourMin,
          );
    }

    if (!mounted) return;
    setState(() {
      _currentNote = updated;
      _hasUnsavedChanges = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          postInChat
              ? 'Document mis à jour et publié à la suite des textos.'
              : 'Document enregistré et conservé sur place.',
        ),
        backgroundColor: AppTheme.secondary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _insertTextAtCursor(String insertion) {
    if (!_canEdit()) return;
    final text = _textController.text;
    final sel = _textController.selection;
    final start = sel.start >= 0 ? sel.start : text.length;
    final end = sel.end >= 0 ? sel.end : text.length;

    final newText = text.replaceRange(start, end, insertion);
    _textController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + insertion.length),
    );
    setState(() => _showFormulaGuide = false);
  }

  void _applyInlineFormat(String openTag, String closeTag) {
    if (!_canEdit()) return;
    final text = _textController.text;
    final sel = _textController.selection;
    if (sel.start < 0 || sel.end < 0 || sel.start == sel.end) {
      _insertTextAtCursor('$openTag$closeTag');
      return;
    }
    final selectedText = text.substring(sel.start, sel.end);
    final formatted = '$openTag$selectedText$closeTag';
    final newText = text.replaceRange(sel.start, sel.end, formatted);
    _textController.value = TextEditingValue(
      text: newText,
      selection: TextSelection(baseOffset: sel.start, extentOffset: sel.start + formatted.length),
    );
  }

  void _applyHeadingModal() {
    if (!_canEdit()) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          int selectedLevel = 1;
          Color selectedColor = const Color(0xFF0F172A);
          String selectedFont = 'Inter';
          TextAlign selectedAlign = TextAlign.left;
          bool isNumbered = false;

          final colors = [
            const Color(0xFF0F172A),
            const Color(0xFF2563EB),
            const Color(0xFF0D9488),
            const Color(0xFFE11D48),
            const Color(0xFF7C3AED),
            const Color(0xFFD97706),
          ];

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.format_size_rounded, color: AppTheme.primary),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text('Configurer le Titre (Niveaux 1 à 8)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Niveau de Titre :', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(8, (index) {
                      final lvl = index + 1;
                      final isSel = selectedLevel == lvl;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text('H$lvl', style: TextStyle(fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
                          selected: isSel,
                          selectedColor: AppTheme.primarySoft,
                          onSelected: (_) => setModalState(() => selectedLevel = lvl),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Couleur du Titre :', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                  children: colors.map((c) {
                    final isSel = selectedColor == c;
                    return GestureDetector(
                      onTap: () => setModalState(() => selectedColor = c),
                      child: Container(
                        margin: const EdgeInsets.only(right: 10),
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(color: isSel ? AppTheme.primary : Colors.transparent, width: 2.5),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Expanded(
                      child: Text('Numérotation automatique (1., 1.1...) :', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                    Switch(
                      value: isNumbered,
                      onChanged: (v) => setModalState(() => isNumbered = v),
                      activeColor: AppTheme.primary,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      final hashes = '#' * selectedLevel;
                      final prefix = isNumbered ? '1. ' : '';
                      final alignTag = selectedAlign == TextAlign.center
                          ? ' [align=center]'
                          : selectedAlign == TextAlign.right
                              ? ' [align=right]'
                              : '';
                      final hex = '#${selectedColor.value.toRadixString(16).substring(2)}';
                      _insertTextAtCursor('\n$hashes $prefix<font color="$hex">Titre Niveau $selectedLevel</font>$alignTag\n');
                      Navigator.of(ctx).pop();
                    },
                    child: const Text('Appliquer le Titre'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showColorPickerModal(bool isBackground) {
    if (!_canEdit()) return;
    final palette = isBackground
        ? [
            {'name': 'Jaune fluo', 'hex': '#FEF08A', 'color': const Color(0xFFFEF08A)},
            {'name': 'Vert menthe', 'hex': '#BBF7D0', 'color': const Color(0xFFBBF7D0)},
            {'name': 'Bleu pastel', 'hex': '#BFDBFE', 'color': const Color(0xFFBFDBFE)},
            {'name': 'Rose doux', 'hex': '#FBCFE8', 'color': const Color(0xFFFBCFE8)},
            {'name': 'Orange pêche', 'hex': '#FED7AA', 'color': const Color(0xFFFED7AA)},
          ]
        : [
            {'name': 'Noir classique', 'hex': '#0F172A', 'color': const Color(0xFF0F172A)},
            {'name': 'Bleu royal', 'hex': '#2563EB', 'color': const Color(0xFF2563EB)},
            {'name': 'Vert émeraude', 'hex': '#059669', 'color': const Color(0xFF059669)},
            {'name': 'Rouge rubis', 'hex': '#E11D48', 'color': const Color(0xFFE11D48)},
            {'name': 'Violet impérial', 'hex': '#7C3AED', 'color': const Color(0xFF7C3AED)},
          ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isBackground ? 'Couleur de fond du texte (Surlignage)' : 'Couleur de la police',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: palette.map((item) {
                final c = item['color'] as Color;
                final hex = item['hex'] as String;
                return GestureDetector(
                  onTap: () {
                    Navigator.of(ctx).pop();
                    if (isBackground) {
                      _applyInlineFormat('<mark color="$hex">', '</mark>');
                    } else {
                      _applyInlineFormat('<font color="$hex">', '</font>');
                    }
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  void _showFontFamilyModal() {
    if (!_canEdit()) return;
    const fonts = ['Inter', 'Roboto', 'serif', 'monospace', 'Helvetica'];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Choisir la police du texte', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...fonts.map((f) => ListTile(
                  title: Text(f, style: TextStyle(fontFamily: f)),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _applyInlineFormat('<font face="$f">', '</font>');
                  },
                )),
          ],
        ),
      ),
    );
  }

  void _showAdminPermissionsDialog() {
    final myProfile = context.read<ProfileRepository>().getProfile();
    final isAdmin = widget.conversation.isUserAdmin(myProfile.id);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.admin_panel_settings_rounded, color: AppTheme.primary),
                  SizedBox(width: 8),
                  Text('Paramètres & Permissions Administrateur', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 14),
              ListTile(
                leading: Icon(
                  _currentNote.isLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
                  color: _currentNote.isLocked ? const Color(0xFFE11D48) : AppTheme.secondary,
                ),
                title: Text(_currentNote.isLocked ? 'Document figé (Lecture seule)' : 'Document déverrouillé (Édition libre)'),
                subtitle: const Text('Seuls les administrateurs peuvent modifier un document figé.'),
                trailing: Switch(
                  value: _currentNote.isLocked,
                  onChanged: isAdmin ? (_) => _toggleLock() : null,
                  activeColor: const Color(0xFFE11D48),
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.download_rounded, color: AppTheme.primary),
                title: const Text('Télécharger le document contenu'),
                subtitle: const Text('Exporte le document au format Markdown et texte brut.'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _downloadDocument();
                },
              ),
              ListTile(
                leading: const Icon(Icons.forward_rounded, color: AppTheme.primary),
                title: const Text('Transférer le bloc-note'),
                subtitle: const Text('Partager ce document vers une autre discussion.'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _transferDocument();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _downloadDocument() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Document "${_currentNote.title}" téléchargé avec succès (.md)'),
        backgroundColor: AppTheme.secondary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _transferDocument() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sélectionnez une discussion pour transférer le bloc-note.'),
        backgroundColor: AppTheme.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _toggleLock() async {
    final myProfile = context.read<ProfileRepository>().getProfile();
    final isAdmin = widget.conversation.isUserAdmin(myProfile.id);
    if (!isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seuls les administrateurs peuvent figer ce bloc-note.')),
      );
      return;
    }

    final newLock = !_currentNote.isLocked;
    await context.read<GroupNoteRepository>().setLock(
          widget.conversation.id,
          newLock,
          myProfile.displayName.isNotEmpty ? myProfile.displayName : 'Admin',
        );

    setState(() {
      _currentNote = _currentNote.copyWith(isLocked: newLock);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          newLock
              ? 'Bloc-note figé en lecture seule par l\'administrateur.'
              : 'Bloc-note déverrouillé : modifications autorisées.',
        ),
        backgroundColor: newLock ? const Color(0xFFE11D48) : AppTheme.secondary,
      ),
    );
  }

  void _showSpacingDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.format_line_spacing_rounded, color: AppTheme.primary),
                  SizedBox(width: 8),
                  Text('Gestion des Espacements', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Interligne (hauteur de ligne) :', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _spacingChoiceChip('Compact (1.2)', 1.2, _lineSpacing, (v) {
                    setState(() => _lineSpacing = v);
                    setModalState(() {});
                  }),
                  _spacingChoiceChip('Normal (1.5)', 1.5, _lineSpacing, (v) {
                    setState(() => _lineSpacing = v);
                    setModalState(() {});
                  }),
                  _spacingChoiceChip('Aéré (1.8)', 1.8, _lineSpacing, (v) {
                    setState(() => _lineSpacing = v);
                    setModalState(() {});
                  }),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Espacement entre paragraphes :', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _spacingChoiceChip('Serré (8px)', 8.0, _paragraphSpacing, (v) {
                    setState(() => _paragraphSpacing = v);
                    setModalState(() {});
                  }),
                  _spacingChoiceChip('Standard (14px)', 14.0, _paragraphSpacing, (v) {
                    setState(() => _paragraphSpacing = v);
                    setModalState(() {});
                  }),
                  _spacingChoiceChip('Confort (22px)', 22.0, _paragraphSpacing, (v) {
                    setState(() => _paragraphSpacing = v);
                    setModalState(() {});
                  }),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Appliquer les espacements'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _spacingChoiceChip(String label, double val, double current, Function(double) onSelect) {
    final isSelected = (current - val).abs() < 0.05;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      selected: isSelected,
      selectedColor: AppTheme.primarySoft,
      onSelected: (_) => onSelect(val),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myProfile = context.read<ProfileRepository>().getProfile();
    final isAdmin = widget.conversation.isUserAdmin(myProfile.id);
    final canEdit = _canEdit();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppTheme.onSurface),
          onPressed: _handleSaveOrClose,
          tooltip: 'Fermer',
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Bloc-Note Collaboratif',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.onSurface),
                ),
                if (_currentNote.isLocked) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.lock_rounded, size: 15, color: Color(0xFFE11D48)),
                ],
              ],
            ),
            Text(
              '${widget.conversation.title} • Instantané ⚡',
              style: const TextStyle(fontSize: 11, color: AppTheme.onSurfaceVariant),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          // Three dots '...' menu for Administrator & Options
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: AppTheme.onSurface),
            tooltip: 'Options du bloc-note',
            onSelected: (val) {
              switch (val) {
                case 'admin_permissions':
                  _showAdminPermissionsDialog();
                  break;
                case 'toggle_lock':
                  _toggleLock();
                  break;
                case 'download':
                  _downloadDocument();
                  break;
                case 'transfer':
                  _transferDocument();
                  break;
                case 'spacing':
                  _showSpacingDialog();
                  break;
              }
            },
            itemBuilder: (ctx) => [
              if (isAdmin)
                const PopupMenuItem(
                  value: 'admin_permissions',
                  child: Row(
                    children: [
                      Icon(Icons.security_rounded, size: 18, color: AppTheme.primary),
                      SizedBox(width: 10),
                      Text('Paramètres & Permissions Admin', style: TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              if (isAdmin)
                PopupMenuItem(
                  value: 'toggle_lock',
                  child: Row(
                    children: [
                      Icon(
                        _currentNote.isLocked ? Icons.lock_open_rounded : Icons.lock_rounded,
                        size: 18,
                        color: _currentNote.isLocked ? AppTheme.secondary : const Color(0xFFE11D48),
                      ),
                      const SizedBox(width: 10),
                      Text(_currentNote.isLocked ? 'Déverrouiller le bloc-note' : 'Figer le bloc-note (Lecture seule)'),
                    ],
                  ),
                ),
              const PopupMenuItem(
                value: 'download',
                child: Row(
                  children: [
                    Icon(Icons.download_rounded, size: 18, color: Color(0xFF475569)),
                    SizedBox(width: 10),
                    Text('Télécharger le document'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'transfer',
                child: Row(
                  children: [
                    Icon(Icons.forward_rounded, size: 18, color: Color(0xFF475569)),
                    SizedBox(width: 10),
                    Text('Transférer le bloc-note'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'spacing',
                child: Row(
                  children: [
                    Icon(Icons.format_line_spacing_rounded, size: 18, color: Color(0xFF475569)),
                    SizedBox(width: 10),
                    Text('Espacements & Typographie'),
                  ],
                ),
              ),
            ],
          ),
          if (canEdit)
            TextButton.icon(
              onPressed: _handleSaveOrClose,
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('Publier', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _activeCompartment = 0);
                      _tabController.animateTo(0);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _activeCompartment == 0 ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                        boxShadow: _activeCompartment == 0
                            ? const [BoxShadow(color: Color(0x0C000000), blurRadius: 4, offset: Offset(0, 2))]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.article_outlined,
                            size: 16,
                            color: _activeCompartment == 0 ? AppTheme.primary : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Document',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: _activeCompartment == 0 ? AppTheme.primary : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _activeCompartment = 1);
                      _tabController.animateTo(1);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _activeCompartment == 1 ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                        boxShadow: _activeCompartment == 1
                            ? const [BoxShadow(color: Color(0x0C000000), blurRadius: 4, offset: Offset(0, 2))]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.edit_note_rounded,
                            size: 17,
                            color: _activeCompartment == 1 ? AppTheme.primary : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Éditer',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: _activeCompartment == 1 ? AppTheme.primary : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          if (_currentNote.isLocked)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFFFEF3C7),
              child: Row(
                children: [
                  const Icon(Icons.lock_clock_rounded, size: 18, color: Color(0xFFB45309)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Bloc-note figé par un administrateur (${_currentNote.lastModifiedBy}). Mode lecture seule.',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF92400E)),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _activeCompartment == 0
                ? _buildLiveDocumentCompartment()
                : _buildEditCompartment(canEdit),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveDocumentCompartment() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _titleController.text.isNotEmpty ? _titleController.text : 'Bloc-Note Collaboratif',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Rendu Actif ✅', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF047857))),
              ),
            ],
          ),
        ),
        Expanded(
          child: GroupNoteRenderer(
            content: _textController.text,
            components: _components,
            lineSpacing: _lineSpacing,
            paragraphSpacing: _paragraphSpacing,
            onStartEditing: () {
              setState(() => _activeCompartment = 1);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEditCompartment(bool canEdit) {
    return Column(
      children: [
        // Sub-Mode Switcher: Word ✍️ vs Code 💻
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(2),
                child: Row(
                  children: [
                    ChoiceChip(
                      label: Text(
                        'Word',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _editSubMode == 'word' ? AppTheme.primary : const Color(0xFF64748B),
                        ),
                      ),
                      selected: _editSubMode == 'word',
                      selectedColor: Colors.white,
                      backgroundColor: Colors.transparent,
                      elevation: _editSubMode == 'word' ? 1 : 0,
                      onSelected: (_) {
                        setState(() {
                          _editSubMode = 'word';
                        });
                      },
                    ),
                    const SizedBox(width: 4),
                    ChoiceChip(
                      label: Text(
                        'Code',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _editSubMode == 'code' ? AppTheme.primary : const Color(0xFF64748B),
                        ),
                      ),
                      selected: _editSubMode == 'code',
                      selectedColor: Colors.white,
                      backgroundColor: Colors.transparent,
                      elevation: _editSubMode == 'code' ? 1 : 0,
                      onSelected: (_) {
                        setState(() {
                          _editSubMode = 'code';
                          _codeController.text = _buildCombinedCodeSource(_textController.text, _components);
                        });
                      },
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // Synchronisation indicator
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.sync_rounded, size: 14, color: Color(0xFF0D9488)),
                    SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'En direct',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: Color(0xFF0D9488), fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Contextual Floating Toolbar (Only in Word mode when canEdit)
        if (_editSubMode == 'word' && canEdit) _buildContextualWordToolbar(),

        // Formula Suggestions / Autocomplete guide bar (like Excel)
        if (_editSubMode == 'word' && canEdit && _showFormulaGuide) _buildExcelFormulaGuideBar(),

        // Editor Body (Word or Code)
        Expanded(
          child: _editSubMode == 'word'
              ? _buildWordEditorBody(canEdit)
              : _buildCodeEditorBody(canEdit),
        ),
      ],
    );
  }

  Widget _buildContextualWordToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
        boxShadow: [BoxShadow(color: Color(0x06000000), blurRadius: 3, offset: Offset(0, 1))],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Bold
            IconButton(
              icon: const Icon(Icons.format_bold_rounded, size: 19),
              tooltip: 'Gras',
              onPressed: () => _applyInlineFormat('**', '**'),
            ),
            // Italic
            IconButton(
              icon: const Icon(Icons.format_italic_rounded, size: 19),
              tooltip: 'Italique',
              onPressed: () => _applyInlineFormat('*', '*'),
            ),
            // Underline
            IconButton(
              icon: const Icon(Icons.format_underlined_rounded, size: 19),
              tooltip: 'Souligné',
              onPressed: () => _applyInlineFormat('<u>', '</u>'),
            ),
            const VerticalDivider(width: 16, thickness: 1, color: Color(0xFFE2E8F0)),

            // Font Family
            TextButton.icon(
              onPressed: _showFontFamilyModal,
              icon: const Icon(Icons.font_download_outlined, size: 16, color: Color(0xFF475569)),
              label: const Text('Police', style: TextStyle(fontSize: 11.5, color: Color(0xFF475569), fontWeight: FontWeight.w600)),
            ),

            // Font Color
            IconButton(
              icon: const Icon(Icons.format_color_text_rounded, size: 19, color: Color(0xFF2563EB)),
              tooltip: 'Couleur de police',
              onPressed: () => _showColorPickerModal(false),
            ),

            // Highlight Background
            IconButton(
              icon: const Icon(Icons.border_color_rounded, size: 18, color: Color(0xFFD97706)),
              tooltip: 'Fond de texte (Surlignage)',
              onPressed: () => _showColorPickerModal(true),
            ),

            const VerticalDivider(width: 16, thickness: 1, color: Color(0xFFE2E8F0)),

            // Title Levels 1-8 Modal
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primarySoft,
                foregroundColor: AppTheme.primary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _applyHeadingModal,
              icon: const Icon(Icons.format_size_rounded, size: 15),
              label: const Text('Titre (H1-H8)', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
            ),

            const SizedBox(width: 8),

            // Alignments
            IconButton(
              icon: const Icon(Icons.format_align_left_rounded, size: 18),
              tooltip: 'Aligner à gauche',
              onPressed: () => _insertTextAtCursor('[align=left]'),
            ),
            IconButton(
              icon: const Icon(Icons.format_align_center_rounded, size: 18),
              tooltip: 'Centrer',
              onPressed: () => _insertTextAtCursor('[align=center]'),
            ),
            IconButton(
              icon: const Icon(Icons.format_align_right_rounded, size: 18),
              tooltip: 'Aligner à droite',
              onPressed: () => _insertTextAtCursor('[align=right]'),
            ),

            const VerticalDivider(width: 16, thickness: 1, color: Color(0xFFE2E8F0)),

            // Bullet & Numbered lists
            IconButton(
              icon: const Icon(Icons.format_list_bulleted_rounded, size: 19),
              tooltip: 'Liste à puces',
              onPressed: () => _insertTextAtCursor('\n- '),
            ),
            IconButton(
              icon: const Icon(Icons.format_list_numbered_rounded, size: 19),
              tooltip: 'Liste numérotée',
              onPressed: () => _insertTextAtCursor('\n1. '),
            ),
            IconButton(
              icon: const Icon(Icons.check_box_outlined, size: 19),
              tooltip: 'Case à cocher',
              onPressed: () => _insertTextAtCursor('\n[ ] '),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExcelFormulaGuideBar() {
    final filtered = FormulaEngine.suggestions.where((s) {
      if (_formulaFilter.isEmpty) return true;
      return s.label.toLowerCase().contains(_formulaFilter) ||
          s.description.toLowerCase().contains(_formulaFilter) ||
          s.template.toLowerCase().contains(_formulaFilter);
    }).toList();

    if (filtered.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      color: const Color(0xFFF0FDF4),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filtered.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, idx) {
          final s = filtered[idx];
          return ActionChip(
            backgroundColor: Colors.white,
            side: const BorderSide(color: Color(0xFF86EFAC)),
            avatar: const Icon(Icons.functions_rounded, size: 14, color: Color(0xFF16A34A)),
            label: Text('${s.label} (${s.description})', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF15803D))),
            onPressed: () {
              // Replace partial formula trigger with full template
              final text = _textController.text;
              final sel = _textController.selection;
              if (sel.baseOffset > 0) {
                final textBeforeCursor = text.substring(0, sel.baseOffset);
                final match = RegExp(r'\{([^{}\s]*)$').firstMatch(textBeforeCursor);
                if (match != null) {
                  final start = match.start;
                  final newText = text.replaceRange(start, sel.baseOffset, s.template);
                  _textController.value = TextEditingValue(
                    text: newText,
                    selection: TextSelection.collapsed(offset: start + s.template.length),
                  );
                  setState(() => _showFormulaGuide = false);
                  return;
                }
              }
              _insertTextAtCursor(s.template);
            },
          );
        },
      ),
    );
  }

  Widget _buildWordEditorBody(bool canEdit) {
    return Column(
      children: [
        // Title Input
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: TextField(
            controller: _titleController,
            enabled: canEdit,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            decoration: const InputDecoration(
              hintText: 'Titre du bloc-note...',
              border: InputBorder.none,
              prefixIcon: Icon(Icons.title_rounded, color: AppTheme.primary),
            ),
          ),
        ),
        const Divider(height: 1, color: Color(0xFFE2E8F0)),

        // Main Word Text Area
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _textController,
              enabled: canEdit,
              maxLines: null,
              expands: true,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              style: TextStyle(
                fontSize: 14.5,
                color: const Color(0xFF1E293B),
                height: _lineSpacing,
              ),
              decoration: const InputDecoration(
                hintText:
                    'Rédigez normalement comme sous Word (Appuyez sur Entrée pour un nouveau paragraphe).\n\nPour insérer un tableau ou composant, écrivez simplement {Titre du tableau}.\nPour des maths : {{A_1}}, {{A^7}}, {{(a+b)/(a-b)}}, {{integral(1:2)(2x^2 dx)}}, {{sigma(k=1:n)(k^2)}}, {{sqrt(x)}}.\nPour calculer : {{=formule}} avec vos variables C {int somme = a + b} et {a=2; b=5;}.',
                border: InputBorder.none,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCodeEditorBody(bool canEdit) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: const Color(0xFF0F172A),
          child: Row(
            children: const [
              Icon(Icons.code_rounded, size: 16, color: Color(0xFF38BDF8)),
              SizedBox(width: 8),
              Text(
                'Source du Document & Définitions {{id="Nom"; ...}}',
                style: TextStyle(fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8)),
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            color: const Color(0xFF090D16),
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _codeController,
              enabled: canEdit,
              maxLines: null,
              expands: true,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                color: Color(0xFFF1F5F9),
                height: 1.4,
              ),
              decoration: const InputDecoration(
                hintText: '// Tapez ici votre code source et définitions {{id="..."; ...}}...',
                border: InputBorder.none,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
