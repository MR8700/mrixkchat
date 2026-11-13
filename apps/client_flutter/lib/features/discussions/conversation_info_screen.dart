import 'package:flutter/material.dart';
import '../../shared/responsive/responsive.dart';
import 'package:provider/provider.dart';
import '../../core/models/conversation.dart';
import '../../core/repositories/contact_repository.dart';
import '../../core/repositories/conversation_repository.dart';
import '../../core/repositories/device_repository.dart';
import '../../core/repositories/profile_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_avatar.dart';
import '../media_vault/media_vault_screen.dart';
import '../security/security_verification_screen.dart';
import 'group_notepad_screen.dart';

class ConversationInfoScreen extends StatefulWidget {
  final Conversation conversation;

  const ConversationInfoScreen({
    super.key,
    required this.conversation,
  });

  @override
  State<ConversationInfoScreen> createState() => _ConversationInfoScreenState();
}

class _ConversationInfoScreenState extends State<ConversationInfoScreen> {
  late Conversation _conv;
  bool _isMuted = false;
  String _ephemeralTimer = 'Désactivé';

  @override
  void initState() {
    super.initState();
    _conv = widget.conversation;
    if (_conv.isGroup && _conv.groupMembers.isEmpty) {
      final myProfile = context.read<ProfileRepository>().getProfile();
      int myDevCount = 1;
      try {
        final devRepo = context.read<DeviceRepository>();
        final devs = devRepo.getActiveDevices();
        if (devs.isNotEmpty) myDevCount = devs.length;
      } catch (_) {}

      final creator = GroupMember(
        id: myProfile.id,
        name: myProfile.displayName.isNotEmpty ? '${myProfile.displayName} (Moi)' : 'Moi',
        handle: myProfile.handle,
        avatarUrl: myProfile.avatarUrl,
        role: 'creator',
        connectedDevicesCount: myDevCount,
      );
      _conv = _conv.copyWith(
        groupMembers: [creator],
        groupMembersCount: 1,
      );
    }
  }

  bool _isCurrentUserAdmin() {
    final myProfile = context.read<ProfileRepository>().getProfile();
    return _conv.isUserAdmin(myProfile.id);
  }

  Future<void> _updateConversation(Conversation updated) async {
    setState(() => _conv = updated);
    await context.read<ConversationRepository>().updateConversation(updated);
  }

  void _showEditGroupDialog() {
    final titleController = TextEditingController(text: _conv.title);
    final descController = TextEditingController(text: _conv.description ?? '');

    showResponsiveDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.edit_note_rounded, color: AppTheme.primary),
            SizedBox(width: 8),
            Text('Modifier les infos du groupe', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: InputDecoration(
                labelText: 'Nom du groupe',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Description / Sujet du groupe',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
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
              final newTitle = titleController.text.trim();
              if (newTitle.isNotEmpty) {
                final updated = _conv.copyWith(
                  title: newTitle,
                  description: descController.text.trim(),
                );
                _updateConversation(updated);
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Informations du groupe mises à jour.')),
                );
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  void _showAddMemberDialog() {
    final contacts = context.read<ContactRepository>().getAllContacts();
    final existingUserIds = _conv.groupMembers.map((m) => m.userId).toSet();
    final availableContacts = contacts.where((c) => !existingUserIds.contains(c.id)).toList();

    showResponsiveSheet(
      isScrollControlled: true,
      useSafeArea: true,
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
                Icon(Icons.person_add_rounded, color: AppTheme.primary),
                SizedBox(width: 8),
                Text(
                  'Ajouter un participant au groupe',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (availableContacts.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'Tous vos contacts sont déjà membres de ce groupe.',
                    style: TextStyle(color: Color(0xFF64748B)),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: availableContacts.length,
                  itemBuilder: (context, index) {
                    final contact = availableContacts[index];
                    return ListTile(
                      leading: AppAvatar(
                        name: contact.name,
                        avatarUrl: contact.avatarUrl,
                        radius: 20,
                        isOnline: contact.isOnline,
                      ),
                      title: Text(contact.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(contact.handle),
                      trailing: IconButton(
                        icon: const Icon(Icons.add_circle, color: AppTheme.primary),
                        onPressed: () {
                          // Rule: UNIQUE (group_id, user_id) - Prevent duplicate additions
                          final currentIds = _conv.groupMembers.map((m) => m.userId).toSet();
                          if (currentIds.contains(contact.id)) {
                            Navigator.of(ctx).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('${contact.name} est déjà membre de ce groupe.')),
                            );
                            return;
                          }

                          final newMember = GroupMember(
                            id: contact.id, // user_id is the sole identity reference
                            name: contact.name,
                            handle: contact.handle,
                            avatarUrl: contact.avatarUrl,
                            role: 'member',
                            connectedDevicesCount: 1,
                          );
                          final updatedMembers = List<GroupMember>.from(_conv.groupMembers)..add(newMember);
                          final updated = _conv.copyWith(
                            groupMembers: updatedMembers,
                            groupMembersCount: updatedMembers.length,
                          );
                          _updateConversation(updated);
                          Navigator.of(ctx).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('${contact.name} a été ajouté au groupe.')),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _moderateMember(GroupMember member, String action) {
    final updatedMembers = _conv.groupMembers.map((m) {
      if (m.id == member.id) {
        if (action == 'promote') return m.copyWith(role: 'admin');
        if (action == 'demote') return m.copyWith(role: 'member');
        if (action == 'toggle_mute') return m.copyWith(isMuted: !m.isMuted);
      }
      return m;
    }).toList();

    if (action == 'remove') {
      updatedMembers.removeWhere((m) => m.id == member.id);
    }

    final updated = _conv.copyWith(
      groupMembers: updatedMembers,
      groupMembersCount: updatedMembers.length,
    );
    _updateConversation(updated);

    String feedback = '';
    switch (action) {
      case 'promote':
        feedback = '${member.name} est désormais administrateur.';
        break;
      case 'demote':
        feedback = '${member.name} est désormais membre simple.';
        break;
      case 'toggle_mute':
        feedback = member.isMuted
            ? '${member.name} peut à nouveau parler.'
            : '${member.name} a été mis en sourdine.';
        break;
      case 'remove':
        feedback = '${member.name} a été retiré du groupe.';
        break;
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(feedback)));
  }

  @override
  Widget build(BuildContext context) {
    // Keep updated from repository if changed elsewhere
    final repoConv = context.watch<ConversationRepository>().getConversationById(_conv.id);
    if (repoConv != null) {
      _conv = repoConv;
    }

    final isAdmin = _isCurrentUserAdmin();

    return Scaffold(
      backgroundColor: AppTheme.surfaceWarm,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _conv.isGroup ? 'Infos du groupe' : 'Détails de la conversation',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.onSurface),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: AppTheme.primary),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Partage sécurisé : ${_conv.title}')),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // 1. Header Card
          _buildHeaderCard(isAdmin),
          const SizedBox(height: 14),

          // 2. Bloc-Note Collaboratif Hero Card (for Groups)
          if (_conv.isGroup) ...[
            _buildBlocNoteHeroCard(),
            const SizedBox(height: 14),
          ],

          // 3. Shared Media Shortcut
          _buildMediaShortcut(),
          const SizedBox(height: 14),

          // 4. Admin Permissions & Group Controls (for Groups)
          if (_conv.isGroup) ...[
            _buildAdminPermissionsCard(isAdmin),
            const SizedBox(height: 14),
            _buildMembersListCard(isAdmin),
            const SizedBox(height: 14),
          ],

          // 5. Cryptography & Security Card
          _buildSecurityCard(),
          const SizedBox(height: 14),

          // 6. Options & Danger Zone
          _buildOptionsCard(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(bool isAdmin) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFDFE4ED)),
      ),
      child: Column(
        children: [
          AppAvatar(
            name: _conv.title,
            avatarUrl: _conv.peerAvatar,
            radius: 42,
            isVerified: _conv.isVerified,
            isOnline: _conv.isOnline,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  _conv.title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.onSurface),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_conv.isVerified) ...[
                const SizedBox(width: 6),
                const Icon(Icons.verified, size: 18, color: AppTheme.secondary),
              ],
              if (_conv.isGroup && (isAdmin || !_conv.onlyAdminsCanEditGroupInfo)) ...[
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.edit, size: 18, color: AppTheme.primary),
                  onPressed: _showEditGroupDialog,
                  tooltip: 'Modifier les infos',
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _conv.isGroup
                ? '${_conv.totalUserAccountsCount} ${_conv.totalUserAccountsCount <= 1 ? "membre sécurisé" : "membres sécurisés"}'
                : '@${_conv.title.toLowerCase().replaceAll(' ', '.')}',
            style: const TextStyle(fontSize: 13, color: AppTheme.primary, fontWeight: FontWeight.w600),
          ),
          if (_conv.isGroup && _conv.description != null && _conv.description!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Text(
                _conv.description!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569), height: 1.4),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppTheme.statusGreen,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _conv.isGroup ? 'Groupe Chiffré de Bout en Bout' : 'Session Sécurisée Établie',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlocNoteHeroCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0043B8), Color(0xFF002A7A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x200043B8),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (ctx) => GroupNotepadScreen(conversation: _conv),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.edit_note_rounded, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Bloc-Note Collaboratif',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0D9488),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'NOUVEAU',
                              style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Traitement de texte Word léger, formules mathématiques, graphes & diagrammes sécurisés.',
                        style: TextStyle(fontSize: 11.5, color: Color(0xFFDFE4ED), height: 1.3),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.white70),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAdminPermissionsCard(bool isAdmin) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFDFE4ED)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.admin_panel_settings_rounded, color: AppTheme.primary, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Permissions Administrateur du Groupe',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (!isAdmin)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('Consultation', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                  ),
              ],
            ),
          ),
          SwitchListTile(
            title: const Text('Envoi de messages restreint', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            subtitle: Text(
              _conv.onlyAdminsCanSendMessages
                  ? 'Seuls les administrateurs peuvent envoyer des messages'
                  : 'Tous les membres peuvent envoyer des messages',
              style: const TextStyle(fontSize: 11, color: AppTheme.onSurfaceVariant),
            ),
            value: _conv.onlyAdminsCanSendMessages,
            activeColor: AppTheme.primary,
            onChanged: isAdmin
                ? (val) => _updateConversation(_conv.copyWith(onlyAdminsCanSendMessages: val))
                : null,
          ),
          const Divider(height: 1),
          SwitchListTile(
            title: const Text('Modification des infos du groupe', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            subtitle: Text(
              _conv.onlyAdminsCanEditGroupInfo
                  ? 'Seuls les administrateurs peuvent modifier le nom et le sujet'
                  : 'Tous les membres peuvent modifier les infos',
              style: const TextStyle(fontSize: 11, color: AppTheme.onSurfaceVariant),
            ),
            value: _conv.onlyAdminsCanEditGroupInfo,
            activeColor: AppTheme.primary,
            onChanged: isAdmin
                ? (val) => _updateConversation(_conv.copyWith(onlyAdminsCanEditGroupInfo: val))
                : null,
          ),
          const Divider(height: 1),
          SwitchListTile(
            title: const Text('Ajout de nouveaux participants', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            subtitle: Text(
              _conv.onlyAdminsCanAddMembers
                  ? 'Seuls les administrateurs peuvent ajouter des contacts'
                  : 'Tous les participants peuvent ajouter des contacts',
              style: const TextStyle(fontSize: 11, color: AppTheme.onSurfaceVariant),
            ),
            value: _conv.onlyAdminsCanAddMembers,
            activeColor: AppTheme.primary,
            onChanged: isAdmin
                ? (val) => _updateConversation(_conv.copyWith(onlyAdminsCanAddMembers: val))
                : null,
          ),
          const Divider(height: 1),
          SwitchListTile(
            title: const Text('Édition du Bloc-note collaboratif', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            subtitle: Text(
              _conv.onlyAdminsCanEditNotes
                  ? 'Seuls les administrateurs peuvent écrire dans le bloc-note'
                  : 'Tous les membres peuvent éditer le bloc-note',
              style: const TextStyle(fontSize: 11, color: AppTheme.onSurfaceVariant),
            ),
            value: _conv.onlyAdminsCanEditNotes,
            activeColor: AppTheme.primary,
            onChanged: isAdmin
                ? (val) => _updateConversation(_conv.copyWith(onlyAdminsCanEditNotes: val))
                : null,
          ),
        ],
      ),
    ),
  );
  }

  Widget _buildMembersListCard(bool isAdmin) {
    final myProfile = context.read<ProfileRepository>().getProfile();
    final members = _conv.groupMembers.isNotEmpty
        ? _conv.groupMembers
        : [
            GroupMember(
              id: myProfile.id,
              name: myProfile.displayName.isNotEmpty ? '${myProfile.displayName} (Moi)' : 'Moi',
              handle: myProfile.handle,
              avatarUrl: myProfile.avatarUrl,
              role: 'creator',
              connectedDevicesCount: 1,
            ),
          ];
    final totalAccounts = members.length;
    final totalDevices = members.fold<int>(0, (sum, m) => sum + m.connectedDevicesCount);
    final canAdd = isAdmin || !_conv.onlyAdminsCanAddMembers;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFDFE4ED)),
        ),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.people_outline_rounded, color: AppTheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Membres du groupe ($totalAccounts)',
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (canAdd)
                  TextButton.icon(
                    onPressed: _showAddMemberDialog,
                    icon: const Icon(Icons.person_add_alt_1, size: 16),
                    label: const Text('Ajouter', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: members.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final member = members[index];
              return ListTile(
                leading: AppAvatar(
                  name: member.name,
                  avatarUrl: member.avatarUrl,
                  radius: 20,
                ),
                title: Row(
                  children: [
                    Flexible(
                      child: Text(
                        member.name,
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    _buildRoleBadge(member.role),
                    if (member.isMuted) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.volume_off, size: 14, color: Color(0xFFE11D48)),
                    ],
                  ],
                ),
                subtitle: Text(
                  '${member.roleLabel} · ${member.deviceCountLabel}',
                  style: const TextStyle(fontSize: 11, color: AppTheme.onSurfaceVariant),
                ),
                trailing: isAdmin && !member.isCreator
                    ? PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, size: 18, color: Colors.grey),
                        onSelected: (action) => _moderateMember(member, action),
                        itemBuilder: (ctx) => [
                          if (member.role != 'admin')
                            const PopupMenuItem(
                              value: 'promote',
                              child: ListTile(
                                leading: Icon(Icons.shield_outlined, color: AppTheme.primary, size: 18),
                                title: Text('Désigner comme admin', style: TextStyle(fontSize: 12.5)),
                                dense: true,
                              ),
                            )
                          else
                            const PopupMenuItem(
                              value: 'demote',
                              child: ListTile(
                                leading: Icon(Icons.remove_moderator_outlined, color: Color(0xFFD97706), size: 18),
                                title: Text('Retirer des admins', style: TextStyle(fontSize: 12.5)),
                                dense: true,
                              ),
                            ),
                          PopupMenuItem(
                            value: 'toggle_mute',
                            child: ListTile(
                              leading: Icon(
                                member.isMuted ? Icons.volume_up_outlined : Icons.volume_off_outlined,
                                color: const Color(0xFF64748B),
                                size: 18,
                              ),
                              title: Text(
                                member.isMuted ? 'Rétablir la parole' : 'Mettre en sourdine',
                                style: const TextStyle(fontSize: 12.5),
                              ),
                              dense: true,
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'remove',
                            child: ListTile(
                              leading: Icon(Icons.person_remove_outlined, color: Color(0xFFEF4444), size: 18),
                              title: Text('Retirer du groupe', style: TextStyle(fontSize: 12.5, color: Color(0xFFEF4444))),
                              dense: true,
                            ),
                          ),
                        ],
                      )
                    : null,
              );
            },
          ),
          const Divider(height: 1),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(18),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Total des comptes membres',
                              style: TextStyle(fontSize: 10.5, color: AppTheme.onSurfaceVariant),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$totalAccounts',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primary),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Total des appareils',
                              style: TextStyle(fontSize: 10.5, color: AppTheme.onSurfaceVariant),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$totalDevices',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 14, color: Color(0xFF64748B)),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Un utilisateur = une identité unique (user_id). Les appareils autorisés sont rattachés au compte et ne constituent jamais des membres distincts.',
                        style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B), height: 1.3),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  }

  Widget _buildRoleBadge(String role) {
    if (role == 'creator') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF3C7),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: const Text('👑 Créateur', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF92400E))),
      );
    }
    if (role == 'admin') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFBFDBFE)),
        ),
        child: const Text('⭐ Admin', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primary)),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text('Membre', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
    );
  }

  Widget _buildMediaShortcut() {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFDFE4ED)),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppTheme.primarySoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.perm_media_outlined, color: AppTheme.primary, size: 20),
          ),
          title: const Text(
            'Médias, fichiers et liens',
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
          ),
          subtitle: const Text(
            'Photos, vidéos, PDF, notes vocales',
            style: TextStyle(fontSize: 11, color: AppTheme.onSurfaceVariant),
          ),
          trailing: const Icon(Icons.chevron_right, color: Colors.grey),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (ctx) => MediaVaultScreen(conversation: _conv),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSecurityCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDFE4ED)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.lock_clock_outlined, color: AppTheme.secondary, size: 20),
              SizedBox(width: 8),
              Text(
                'Chiffrement et Empreinte de Sécurité',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _conv.isGroup
                ? 'Les échanges au sein de ce groupe sont protégés par le protocole de chiffrement multipartite X25519 avec rotation des clés de session.'
                : 'Les messages et appels échangés avec ce contact sont protégés par échange de clés X25519 et signés Ed25519.',
            style: const TextStyle(fontSize: 11.5, color: AppTheme.onSurfaceVariant, height: 1.4),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFDFE4ED)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (ctx) => SecurityVerificationScreen(conversation: _conv),
                  ),
                );
              },
              icon: const Icon(Icons.qr_code, size: 18, color: AppTheme.primary),
              label: const Text(
                'Vérifier le code de sécurité',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppTheme.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionsCard() {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFDFE4ED)),
        ),
        child: Column(
          children: [
            SwitchListTile(
              title: const Text('Mode silencieux', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              subtitle: const Text('Couper les notifications pour ce groupe', style: TextStyle(fontSize: 11)),
              value: _isMuted,
              activeColor: AppTheme.primary,
              onChanged: (val) => setState(() => _isMuted = val),
            ),
            const Divider(height: 1),
            ListTile(
              title: const Text('Messages éphémères', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              subtitle: Text('Délai actuel : $_ephemeralTimer', style: const TextStyle(fontSize: 11, color: AppTheme.onSurfaceVariant)),
              trailing: const Icon(Icons.timer_outlined, color: AppTheme.primary),
              onTap: () {
                showResponsiveSheet(
                  isScrollControlled: true,
                  useSafeArea: true,
                  context: context,
                  builder: (ctx) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: ['Désactivé', '24 heures', '7 jours', '30 jours'].map((timer) {
                      return ListTile(
                        title: Text(timer),
                        trailing: _ephemeralTimer == timer ? const Icon(Icons.check, color: AppTheme.primary) : null,
                        onTap: () {
                          setState(() => _ephemeralTimer = timer);
                          Navigator.of(ctx).pop();
                        },
                      );
                    }).toList(),
                  ),
                );
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(_conv.isGroup ? Icons.exit_to_app_rounded : Icons.delete_sweep, color: const Color(0xFFEF4444)),
              title: Text(
                _conv.isGroup ? 'Quitter le groupe' : 'Effacer le contenu de la discussion',
                style: const TextStyle(fontSize: 13, color: Color(0xFFEF4444), fontWeight: FontWeight.bold),
              ),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(_conv.isGroup ? 'Vous avez quitté le groupe' : 'Historique local effacé'),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
