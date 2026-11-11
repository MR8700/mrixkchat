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

  @override
  State<GroupNotepadScreen> createState() => _GroupNotepadScreenState();
}

class _GroupNotepadScreenState extends State<GroupNotepadScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late TextEditingController _textController;
  late TextEditingController _titleController;
  late GroupNote _currentNote;
  bool _isSaving = false;

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

    // If locked by admin, only admins can unlock or edit
    if (_currentNote.isLocked) return false;

    // If group permissions restrict notes to admins only
    if (widget.conversation.onlyAdminsCanEditNotes && !isAdmin) {
      return false;
    }

    return true;
  }

  Future<void> _saveNote({bool showFeedback = true}) async {
    setState(() => _isSaving = true);
    final myProfile = context.read<ProfileRepository>().getProfile();
    final now = DateTime.now();
    final timeStr =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')} à ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final updated = _currentNote.copyWith(
      title: _titleController.text.trim().isNotEmpty
          ? _titleController.text.trim()
          : 'Bloc-Note : ${widget.conversation.title}',
      content: _textController.text,
      lastModified: timeStr,
      lastModifiedBy: myProfile.displayName.isNotEmpty
          ? myProfile.displayName
          : 'Richard MARE',
    );

    await context.read<GroupNoteRepository>().saveNote(updated);
    if (!mounted) return;
    setState(() {
      _currentNote = updated;
      _isSaving = false;
    });

    if (showFeedback) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Document et formules enregistrés avec succès.'),
          backgroundColor: AppTheme.secondary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _insertFormatting(String prefix, String suffix, [String defaultText = '']) {
    if (!_canEdit()) return;
    final text = _textController.text;
    final selection = _textController.selection;
    final start = selection.start >= 0 ? selection.start : text.length;
    final end = selection.end >= 0 ? selection.end : text.length;

    final selectedText =
        start < end ? text.substring(start, end) : defaultText;
    final replacement = '$prefix$selectedText$suffix';

    final newText = text.replaceRange(start, end, replacement);
    _textController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + replacement.length),
    );
  }

  void _showMathFormulaPicker() {
    if (!_canEdit()) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.functions_rounded, color: AppTheme.primary, size: 22),
                SizedBox(width: 8),
                Text(
                  'Insérer une Formule Mathématique',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.calculate_outlined, color: AppTheme.secondary),
              title: const Text('Équation quadratique'),
              subtitle: const Text('x = (-b ± √(b² - 4ac)) / 2a'),
              onTap: () {
                _insertFormatting('\n<math>\nx = \\frac{-b \\pm \\sqrt{b^2 - 4ac}}{2a}\n</math>\n', '');
                Navigator.of(ctx).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.timeline_rounded, color: AppTheme.primary),
              title: const Text('Intégrale de Gauss'),
              subtitle: const Text('∫_{-∞}^{+∞} e^{-x²} dx = √π'),
              onTap: () {
                _insertFormatting('\n<math>\n\\int_{-\\infty}^{+\\infty} e^{-x^2} dx = \\sqrt{\\pi}\n</math>\n', '');
                Navigator.of(ctx).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.exposure_plus_1_rounded, color: Color(0xFF0D9488)),
              title: const Text('Somme discrète (Série)'),
              subtitle: const Text('∑_{k=1}^n k = n(n+1)/2'),
              onTap: () {
                _insertFormatting('\n<math>\n\\sum_{k=1}^{n} k = \\frac{n(n+1)}{2}\n</math>\n', '');
                Navigator.of(ctx).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.horizontal_rule_rounded, color: Color(0xFF8B5CF6)),
              title: const Text('Fraction personnalisée'),
              subtitle: const Text('\\frac{Numérateur}{Dénominateur}'),
              onTap: () {
                _insertFormatting('\n<math>\n\\frac{A}{B}\n</math>\n', '');
                Navigator.of(ctx).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _insertTableTemplate() {
    if (!_canEdit()) return;
    const template = '''
<table border="1">
  <thead>
    <tr>
      <th>Composant</th>
      <th>Détail</th>
      <th>Validation</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>Sécurité E2EE</td>
      <td>Clés souveraines</td>
      <td>Vérifié 🛡️</td>
    </tr>
    <tr>
      <td>Stockage Local</td>
      <td>Chiffrement SQLite</td>
      <td>Actif ✅</td>
    </tr>
  </tbody>
</table>
''';
    _insertFormatting('\n$template\n', '');
  }

  void _insertFlowchartTemplate() {
    if (!_canEdit()) return;
    const template = '''
<diagram type="flowchart">
[1. Étape Initiale] -> [2. Traitement Chiffré] -> [3. Validation Admin] -> [4. Clôture]
</diagram>
''';
    _insertFormatting('\n$template\n', '');
  }

  void _insertGraphTemplate() {
    if (!_canEdit()) return;
    const template = '''
<graph type="bar" title="Métriques du Projet (%)">
Confidentialité E2EE: 100
Vitesse de transfert: 92
Stabilité Réseau: 95
</graph>
''';
    _insertFormatting('\n$template\n', '');
  }

  void _shareNoteInGroup() {
    final myProfile = context.read<ProfileRepository>().getProfile();
    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final shareText =
        '📝 [Bloc-Note du Groupe] "${_titleController.text.trim()}" a été mis à jour par ${myProfile.displayName.isNotEmpty ? myProfile.displayName : 'Moi'}.\nOuvrez le bloc-note pour consulter les formules mathématiques et diagrammes.';

    final msg = Message(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      conversationId: widget.conversation.id,
      senderId: myProfile.id,
      senderName: myProfile.displayName.isNotEmpty ? myProfile.displayName : 'Moi',
      senderAvatar: myProfile.avatarUrl,
      type: MessageType.text,
      content: shareText,
      time: timeStr,
      isOutgoing: true,
      isRead: true,
    );

    context.read<MessageRepository>().sendMessage(msg);
    context.read<ConversationRepository>().updateLastMessage(
          conversationId: widget.conversation.id,
          message: '📝 Bloc-Note partagé dans le groupe',
          time: timeStr,
        );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Lien du Bloc-Note partagé dans la discussion du groupe.'),
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
        const SnackBar(
          content: Text('Seuls les administrateurs peuvent verrouiller ce document.'),
        ),
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
              ? 'Document verrouillé en lecture seule pour les membres.'
              : 'Document déverrouillé : modifications autorisées.',
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
          icon: const Icon(Icons.arrow_back, color: AppTheme.onSurface),
          onPressed: () {
            _saveNote(showFeedback: false);
            Navigator.of(context).pop();
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bloc-Note de Groupe',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.onSurface,
              ),
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
              tooltip: _currentNote.isLocked
                  ? 'Déverrouiller le bloc-note'
                  : 'Verrouiller en lecture seule',
              onPressed: _toggleLock,
            ),
          IconButton(
            icon: const Icon(Icons.share_outlined, color: AppTheme.primary),
            tooltip: 'Partager dans la discussion',
            onPressed: _shareNoteInGroup,
          ),
          if (canEdit)
            IconButton(
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle_rounded, color: AppTheme.primary),
              tooltip: 'Enregistrer',
              onPressed: () => _saveNote(),
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
            Tab(icon: Icon(Icons.auto_stories_rounded, size: 18), text: 'Document'),
            Tab(icon: Icon(Icons.edit_note_rounded, size: 18), text: 'Éditeur Word'),
            Tab(icon: Icon(Icons.code_rounded, size: 18), text: 'Code HTML'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Moderation & Read-only Banner
          if (!canEdit)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFFFEF3C7),
              child: Row(
                children: [
                  const Icon(Icons.lock_rounded, size: 18, color: Color(0xFFB45309)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _currentNote.isLocked
                          ? 'Document verrouillé par un administrateur (${_currentNote.lastModifiedBy}). Lecture seule.'
                          : 'Seuls les administrateurs sont autorisés à modifier ce bloc-note.',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF92400E),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // 1. Rendu Document Haute Fidélité
                _buildPreviewTab(),

                // 2. Éditeur Word léger
                _buildWordEditorTab(canEdit),

                // 3. Code HTML Sécurisé
                _buildHtmlCodeTab(canEdit),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewTab() {
    return Column(
      children: [
        // Document Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _titleController.text.isNotEmpty
                    ? _titleController.text
                    : 'Bloc-Note Collaboratif',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.verified_user_outlined, size: 14, color: AppTheme.secondary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Dernière synchronisation par ${_currentNote.lastModifiedBy} • ${_currentNote.lastModified}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: GroupNoteRenderer(content: _textController.text),
        ),
      ],
    );
  }

  Widget _buildWordEditorTab(bool canEdit) {
    return Column(
      children: [
        // Title Input
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
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

        // Word-style Toolbar
        if (canEdit) _buildWordToolbar(),

        // Editor Body
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _textController,
              enabled: canEdit,
              maxLines: null,
              expands: true,
              style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B), height: 1.5),
              decoration: const InputDecoration(
                hintText: 'Rédigez ici vos notes, formules de maths, tableaux ou diagrammes...',
                border: InputBorder.none,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWordToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _toolbarButton(icon: Icons.format_bold_rounded, tooltip: 'Gras', onTap: () => _insertFormatting('<b>', '</b>', 'texte en gras')),
            _toolbarButton(icon: Icons.format_italic_rounded, tooltip: 'Italique', onTap: () => _insertFormatting('<i>', '</i>', 'texte en italique')),
            _toolbarButton(icon: Icons.format_underlined_rounded, tooltip: 'Souligné', onTap: () => _insertFormatting('<u>', '</u>', 'texte souligné')),
            _toolbarButton(icon: Icons.format_strikethrough_rounded, tooltip: 'Barré', onTap: () => _insertFormatting('<s>', '</s>', 'texte barré')),
            const VerticalDivider(width: 16),
            _toolbarButton(label: 'H1', tooltip: 'Titre 1', onTap: () => _insertFormatting('\n<h1>', '</h1>\n', 'Grand Titre')),
            _toolbarButton(label: 'H2', tooltip: 'Titre 2', onTap: () => _insertFormatting('\n<h2>', '</h2>\n', 'Sous-Titre')),
            _toolbarButton(label: 'H3', tooltip: 'Titre 3', onTap: () => _insertFormatting('\n<h3>', '</h3>\n', 'Titre de Section')),
            const VerticalDivider(width: 16),
            _toolbarButton(icon: Icons.format_list_bulleted_rounded, tooltip: 'Liste à puces', onTap: () => _insertFormatting('\n<ul>\n  <li>', '</li>\n</ul>\n', 'Élément')),
            _toolbarButton(icon: Icons.format_quote_rounded, tooltip: 'Citation', onTap: () => _insertFormatting('\n<blockquote>', '</blockquote>\n', 'Citation')),
            _toolbarButton(icon: Icons.highlight_rounded, tooltip: 'Surlignage', onTap: () => _insertFormatting('<mark>', '</mark>', 'texte surligné')),
            _toolbarButton(icon: Icons.code_rounded, tooltip: 'Code', onTap: () => _insertFormatting('<code>', '</code>', 'code source')),
            const VerticalDivider(width: 16),
            // Specialized Math, Table, Diagram, Graph Buttons
            _actionPill(
              icon: Icons.functions_rounded,
              label: 'Maths',
              color: AppTheme.primary,
              onTap: _showMathFormulaPicker,
            ),
            const SizedBox(width: 6),
            _actionPill(
              icon: Icons.table_chart_rounded,
              label: 'Tableau',
              color: const Color(0xFF0D9488),
              onTap: _insertTableTemplate,
            ),
            const SizedBox(width: 6),
            _actionPill(
              icon: Icons.account_tree_rounded,
              label: 'Diagramme',
              color: const Color(0xFF8B5CF6),
              onTap: _insertFlowchartTemplate,
            ),
            const SizedBox(width: 6),
            _actionPill(
              icon: Icons.bar_chart_rounded,
              label: 'Graphe',
              color: AppTheme.secondary,
              onTap: _insertGraphTemplate,
            ),
          ],
        ),
      ),
    );
  }

  Widget _toolbarButton({
    IconData? icon,
    String? label,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: icon != null
              ? Icon(icon, size: 19, color: const Color(0xFF334155))
              : Text(
                  label ?? '',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF334155),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _actionPill({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHtmlCodeTab(bool canEdit) {
    return Container(
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.security_rounded, size: 16, color: Color(0xFF38BDF8)),
              SizedBox(width: 6),
              Text(
                'Source HTML Sécurisé • Scripts neutralisés',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF38BDF8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TextField(
              controller: _textController,
              enabled: canEdit,
              maxLines: null,
              expands: true,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                color: Color(0xFFE2E8F0),
                height: 1.4,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Code source HTML sécurisé...',
                hintStyle: TextStyle(color: Color(0xFF64748B)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
