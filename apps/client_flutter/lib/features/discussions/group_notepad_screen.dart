import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/conversation.dart';
import '../../core/models/group_note.dart';
import '../../core/models/message.dart';
import '../../core/repositories/conversation_repository.dart';
import '../../core/repositories/group_note_repository.dart';
import '../../core/repositories/message_repository.dart';
import '../../core/repositories/profile_repository.dart';
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
  late TextEditingController _titleController;
  late GroupNote _currentNote;
  late Map<String, String> _components;
  double _lineSpacing = 1.5;
  double _paragraphSpacing = 14.0;
  bool _hasUnsavedChanges = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    final repo = context.read<GroupNoteRepository>();
    _currentNote = repo.getNote(
      widget.conversation.id,
      groupTitle: widget.conversation.title,
    );
    _textController = TextEditingController(text: _currentNote.content);
    _titleController = TextEditingController(text: _currentNote.title);
    _components = Map<String, String>.from(_currentNote.components);
    _lineSpacing = _currentNote.lineSpacing;
    _paragraphSpacing = _currentNote.paragraphSpacing;

    _textController.addListener(_onTextChanged);
    _titleController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    if (!_hasUnsavedChanges) {
      setState(() => _hasUnsavedChanges = true);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _textController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  bool _canEdit() {
    final myProfile = context.read<ProfileRepository>().getProfile();
    final isAdmin = widget.conversation.isUserAdmin(myProfile.id);

    // If frozen/locked by an admin, only admins can modify or unfreeze
    if (_currentNote.isLocked && !isAdmin) return false;

    // If group permissions reserve editing to admins only
    if (widget.conversation.onlyAdminsCanEditNotes && !isAdmin) {
      return false;
    }

    return true;
  }

  /// Triggers the save workflow with publication options ("À la suite des textos" vs "Garder sur place")
  Future<void> _handleSaveOrClose() async {
    if (!_canEdit()) {
      Navigator.of(context).pop();
      return;
    }

    if (!_hasUnsavedChanges) {
      Navigator.of(context).pop();
      return;
    }

    // Prompt user: "Mettre à la suite des textos" or "Garder sur place"
    await _showSaveChoiceDialog();
  }

  Future<void> _showSaveChoiceDialog() async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: const [
            Icon(Icons.edit_note_rounded, color: AppTheme.primary, size: 26),
            SizedBox(width: 10),
            Text(
              'Enregistrer les modifications',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Le bloc-note a été modifié. Comment souhaitez-vous appliquer cette mise à jour ?',
              style: TextStyle(fontSize: 13.5, color: Color(0xFF334155), height: 1.4),
            ),
            SizedBox(height: 12),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('cancel'),
            child: const Text('Annuler', style: TextStyle(color: Color(0xFF64748B))),
          ),
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
        type: MessageType.text,
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

  void _insertMacro(String macroName) {
    if (!_canEdit()) return;
    final text = _textController.text;
    final selection = _textController.selection;
    final start = selection.start >= 0 ? selection.start : text.length;
    final end = selection.end >= 0 ? selection.end : text.length;

    final token = '\n{{$macroName}}\n';
    final newText = text.replaceRange(start, end, token);
    _textController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + token.length),
    );
  }

  void _openComponentEditor(String name) {
    if (!_canEdit()) return;
    final code = _components[name] ?? '';
    final codeController = TextEditingController(text: code);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 18,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 18,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.code_rounded, color: AppTheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Définition du Composant : {{$name}}',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Définissez ici le code HTML sécurisé, tableau ou formule mathématique associé à cette variable.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            Container(
              height: 180,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: codeController,
                maxLines: null,
                expands: true,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5, color: Color(0xFFE2E8F0)),
                decoration: const InputDecoration(border: InputBorder.none),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    setState(() {
                      _components[name] = codeController.text;
                      _hasUnsavedChanges = true;
                    });
                    Navigator.of(ctx).pop();
                  },
                  child: const Text('Enregistrer le composant'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showNewComponentDialog() {
    if (!_canEdit()) return;
    final nameController = TextEditingController();
    String selectedType = 'tableau';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: const [
              Icon(Icons.add_box_rounded, color: AppTheme.primary),
              SizedBox(width: 8),
              Text('Créer un Nouveau Composant', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Nom du composant (ex: tableau2, calcul_bilan)',
                  hintText: 'mon_composant',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 14),
              const Text('Type de composant :', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: selectedType,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: const [
                  DropdownMenuItem(value: 'tableau', child: Text('Tableau structuré')),
                  DropdownMenuItem(value: 'math', child: Text('Formule mathématique')),
                  DropdownMenuItem(value: 'diagramme', child: Text('Diagramme de flux')),
                  DropdownMenuItem(value: 'graphe', child: Text('Graphique en barres')),
                ],
                onChanged: (val) {
                  if (val != null) setModalState(() => selectedType = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                final rawName = nameController.text.trim();
                if (rawName.isEmpty) return;
                final cleanName = rawName.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');

                String defaultCode = '';
                switch (selectedType) {
                  case 'tableau':
                    defaultCode = '''
<table border="1">
  <thead>
    <tr><th>Paramètre</th><th>Valeur</th><th>Statut</th></tr>
  </thead>
  <tbody>
    <tr><td>Donnée 1</td><td>100</td><td>OK ✅</td></tr>
  </tbody>
</table>''';
                    break;
                  case 'math':
                    defaultCode = '<math>x = \\frac{A}{B}</math>';
                    break;
                  case 'diagramme':
                    defaultCode = '<diagram type="flowchart">\n[Étape 1] -> [Étape 2] -> [Clôture]\n</diagram>';
                    break;
                  case 'graphe':
                    defaultCode = '<graph type="bar" title="Indicateurs">\nPerformance: 95\nFiabilité: 98\n</graph>';
                    break;
                }

                setState(() {
                  _components[cleanName] = defaultCode;
                  _insertMacro(cleanName);
                  _hasUnsavedChanges = true;
                });
                Navigator.of(ctx).pop();
              },
              child: const Text('Insérer dans l\'Éditeur'),
            ),
          ],
        ),
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
              '${widget.conversation.title} • Modifié ${_currentNote.lastModified}',
              style: const TextStyle(fontSize: 11, color: AppTheme.onSurfaceVariant),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          if (isAdmin)
            IconButton(
              icon: Icon(
                _currentNote.isLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
                color: _currentNote.isLocked ? const Color(0xFFE11D48) : AppTheme.secondary,
              ),
              tooltip: _currentNote.isLocked ? 'Défiger le document' : 'Figer en lecture seule',
              onPressed: _toggleLock,
            ),
          IconButton(
            icon: const Icon(Icons.format_line_spacing_rounded, color: AppTheme.primary),
            tooltip: 'Gérer les espacements',
            onPressed: _showSpacingDialog,
          ),
          if (canEdit)
            TextButton.icon(
              onPressed: _handleSaveOrClose,
              icon: const Icon(Icons.save_rounded, size: 18),
              label: const Text('Enregistrer', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.onSurfaceVariant,
          indicatorColor: AppTheme.primary,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.auto_stories_rounded, size: 18), text: 'Document Rendu'),
            Tab(icon: Icon(Icons.edit_note_rounded, size: 18), text: 'Éditeur Word'),
            Tab(icon: Icon(Icons.view_in_ar_rounded, size: 18), text: 'Composants HTML'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Banner when frozen
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
            child: TabBarView(
              controller: _tabController,
              children: [
                // 1. Vue Document Directement Rendue
                _buildLiveDocumentTab(),

                // 2. Éditeur Word sans balises avec macros directement exécutées
                _buildWordEditorTab(canEdit),

                // 3. Gestionnaire des Composants HTML & Variables (tableau1={...})
                _buildComponentsManagerTab(canEdit),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveDocumentTab() {
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
            onEditComponent: _openComponentEditor,
          ),
        ),
      ],
    );
  }

  Widget _buildWordEditorTab(bool canEdit) {
    return Column(
      children: [
        // Title Input
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: TextField(
            controller: _titleController,
            enabled: canEdit,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            decoration: const InputDecoration(
              hintText: 'Titre du document...',
              border: InputBorder.none,
              prefixIcon: Icon(Icons.title_rounded, color: AppTheme.primary),
            ),
          ),
        ),
        const Divider(height: 1, color: Color(0xFFE2E8F0)),

        // Word Action Bar (Sans balises visibles, composants intégrés)
        if (canEdit)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    onPressed: _showNewComponentDialog,
                    icon: const Icon(Icons.add_circle_outline, size: 16),
                    label: const Text('Insérer Composant (Tableau, Maths...)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    tooltip: 'Insérer un composant existant',
                    onSelected: (compName) => _insertMacro(compName),
                    itemBuilder: (ctx) => _components.keys.map((name) {
                      return PopupMenuItem(
                        value: name,
                        child: Row(
                          children: [
                            const Icon(Icons.auto_awesome, size: 15, color: AppTheme.primary),
                            const SizedBox(width: 8),
                            Text('{{$name}}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      );
                    }).toList(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.token_rounded, size: 15, color: Color(0xFF475569)),
                          SizedBox(width: 4),
                          Text('Mes Variables', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                          Icon(Icons.arrow_drop_down, size: 18, color: Color(0xFF475569)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.format_line_spacing_rounded, size: 20, color: Color(0xFF475569)),
                    tooltip: 'Espacements',
                    onPressed: _showSpacingDialog,
                  ),
                ],
              ),
            ),
          ),

        // Text Editor Body
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _textController,
              enabled: canEdit,
              maxLines: null,
              expands: true,
              style: TextStyle(
                fontSize: 14.5,
                color: const Color(0xFF1E293B),
                height: _lineSpacing,
              ),
              decoration: const InputDecoration(
                hintText:
                    'Rédigez votre texte comme sous Word...\nPour insérer un tableau ou une formule, tapez son nom comme {{tableau1}} ou cliquez sur "Insérer Composant".',
                border: InputBorder.none,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildComponentsManagerTab(bool canEdit) {
    return Container(
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.view_in_ar_rounded, color: AppTheme.primary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Variables & Composants HTML Sécurisés',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
              if (canEdit)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _showNewComponentDialog,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Nouveau', style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Chaque variable stocke un bloc de code sécurisé (tableau, calcul mathématique, graphe) pouvant être appelé à tout endroit du texte avec {{nom_variable}}.',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: ListView.separated(
              itemCount: _components.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final entry = _components.entries.elementAt(index);
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.primarySoft,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '{{${entry.key}}}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primary,
                              ),
                            ),
                          ),
                          const Spacer(),
                          if (canEdit) ...[
                            IconButton(
                              icon: const Icon(Icons.copy_rounded, size: 18, color: Color(0xFF64748B)),
                              tooltip: 'Insérer dans le texte',
                              onPressed: () {
                                _insertMacro(entry.key);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('{{${entry.key}}} inséré dans l\'éditeur.')),
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.primary),
                              tooltip: 'Modifier le code HTML',
                              onPressed: () => _openComponentEditor(entry.key),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFEF4444)),
                              tooltip: 'Supprimer',
                              onPressed: () {
                                setState(() {
                                  _components.remove(entry.key);
                                  _hasUnsavedChanges = true;
                                });
                              },
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          entry.value.trim(),
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: Color(0xFF38BDF8),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
