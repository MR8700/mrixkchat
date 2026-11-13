import 'dart:async';
import 'package:flutter/material.dart';
import '../../shared/responsive/responsive.dart';
import 'package:provider/provider.dart';
import '../../core/models/conversation.dart';
import '../../core/models/message.dart';
import '../../core/models/moment.dart';
import '../../core/repositories/contact_repository.dart';
import '../../core/repositories/conversation_repository.dart';
import '../../core/repositories/device_repository.dart';
import '../../core/repositories/message_repository.dart';
import '../../core/repositories/moment_repository.dart';
import '../../core/repositories/profile_repository.dart';
import '../../core/services/identity_directory_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_avatar.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../calls/call_history_screen.dart';
import '../media_vault/media_vault_screen.dart';
import '../moments/widgets/add_moment_dialog.dart';
import '../moments/widgets/moment_story_viewer_dialog.dart';
import '../profile/widgets/device_manager_dialog.dart';
import 'conversation_detail_screen.dart';
import 'message_requests_screen.dart';
import 'widgets/audio_player_widget.dart';
import 'widgets/call_dialog.dart';

class DiscussionsScreen extends StatefulWidget {
  final ValueChanged<int>? onNavigateTab;
  final ValueChanged<Conversation>? onSelectConversationDesktop;

  const DiscussionsScreen({
    super.key,
    this.onNavigateTab,
    this.onSelectConversationDesktop,
  });

  @override
  State<DiscussionsScreen> createState() => _DiscussionsScreenState();
}

class _DiscussionsScreenState extends State<DiscussionsScreen> {
  String _selectedFilter = 'Tous';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  Timer? _directorySearchDebounce;
  int _directorySearchVersion = 0;
  bool _searchingDirectory = false;
  List<SovereignUser> _onlineSearchResults = const [];

  @override
  void dispose() {
    _directorySearchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _searchOnlineDirectory(String query) {
    _directorySearchDebounce?.cancel();
    final version = ++_directorySearchVersion;
    if (query.trim().isEmpty) {
      setState(() {
        _onlineSearchResults = const [];
        _searchingDirectory = false;
      });
      return;
    }
    setState(() => _searchingDirectory = true);
    _directorySearchDebounce =
        Timer(const Duration(milliseconds: 350), () async {
      final results = await IdentityDirectoryService.searchUsersOnline(query);
      if (!mounted || version != _directorySearchVersion) return;
      setState(() {
        _onlineSearchResults = results;
        _searchingDirectory = false;
      });
    });
  }

  void _showNewConversationDialog() {
    final titleController = TextEditingController();
    final messageController = TextEditingController();
    bool isGroup = false;
    String? dialogError;

    showResponsiveDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
        scrollable: true,
            backgroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: const [
                Icon(Icons.chat_bubble_outline, color: AppTheme.primary),
                SizedBox(width: 8),
                Text(
                  'Nouvelle discussion',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: isGroup
                          ? 'Nom du groupe'
                          : 'Nom ou @identifiant du contact',
                      hintText: isGroup
                          ? 'Ex: Équipe Projet'
                          : 'Ex: @handle ou Prénom',
                      border: const OutlineInputBorder(),
                      errorText: dialogError,
                    ),
                    onChanged: (_) {
                      if (dialogError != null) {
                        setModalState(() => dialogError = null);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: messageController,
                    decoration: const InputDecoration(
                      labelText: 'Premier message protégé',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Checkbox(
                        value: isGroup,
                        activeColor: AppTheme.primary,
                        onChanged: (val) {
                          setModalState(() {
                            isGroup = val ?? false;
                            dialogError = null;
                          });
                        },
                      ),
                      const Text('Créer un groupe sécurisé'),
                    ],
                  ),
                ],
              ),
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
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  final title = titleController.text.trim();
                  if (title.isEmpty) return;

                  final myProfile =
                      context.read<ProfileRepository>().getProfile();

                  if (!isGroup) {
                    final titleLower = title.toLowerCase();
                    final myNameLower =
                        myProfile.displayName.trim().toLowerCase();
                    final myHandleLower = myProfile.handle.trim().toLowerCase();

                    if ((myNameLower.isNotEmpty && titleLower == myNameLower) ||
                        (myHandleLower.isNotEmpty &&
                            titleLower == myHandleLower) ||
                        titleLower.contains('moi-même')) {
                      setModalState(() {
                        dialogError =
                            'Une discussion « Note à moi-même » existe déjà.';
                      });
                      return;
                    }

                    // Check if exists in Identity Directory or Contact Repository
                    final inDirectory =
                        IdentityDirectoryService.findUser(title);
                    final contacts =
                        context.read<ContactRepository>().getAllContacts();
                    final inContacts = contacts.any((c) =>
                        c.name.toLowerCase() == titleLower ||
                        c.handle.toLowerCase() == titleLower ||
                        c.name.toLowerCase().contains(titleLower));

                    if (inDirectory == null && !inContacts) {
                      setModalState(() {
                        dialogError =
                            'Utilisateur introuvable sur le réseau sécurisé.';
                      });
                      return;
                    }
                  }

                  final now = DateTime.now();
                  final timeStr =
                      '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
                  final firstMsg = messageController.text.trim();

                  int myDeviceCount = 1;
                  try {
                    final devRepo = context.read<DeviceRepository>();
                    final devs = devRepo.getActiveDevices();
                    if (devs.isNotEmpty) myDeviceCount = devs.length;
                  } catch (_) {}

                  final creatorMember = GroupMember(
                    id: myProfile.id,
                    name: myProfile.displayName.isNotEmpty
                        ? '${myProfile.displayName} (Moi)'
                        : 'Moi',
                    handle: myProfile.handle,
                    avatarUrl: myProfile.avatarUrl,
                    role: 'creator',
                    connectedDevicesCount: myDeviceCount,
                  );

                  String? peerUserId;
                  if (!isGroup) {
                    peerUserId = IdentityDirectoryService.findUser(title)?.id;
                    for (final contact
                        in context.read<ContactRepository>().getAllContacts()) {
                      if (contact.name.toLowerCase() == title.toLowerCase() ||
                          contact.handle.toLowerCase() == title.toLowerCase()) {
                        peerUserId = contact.id;
                        break;
                      }
                    }
                  }

                  final newConv = Conversation(
                    id: 'conv_${DateTime.now().millisecondsSinceEpoch}',
                    peerUserId: peerUserId,
                    title: title,
                    peerAvatar: '',
                    isGroup: isGroup,
                    groupMembersCount: 1,
                    groupMembers: isGroup ? [creatorMember] : const [],
                    lastMessage:
                        firstMsg.isNotEmpty ? firstMsg : 'Discussion créée',
                    lastMessageTime: timeStr,
                    unreadCount: 0,
                    tagText: isGroup ? 'Groupe sécurisé' : 'Privé',
                  );
                  context
                      .read<ConversationRepository>()
                      .createConversation(newConv);

                  if (firstMsg.isNotEmpty) {
                    final msg = Message(
                      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
                      conversationId: newConv.id,
                      senderId: myProfile.id,
                      senderName: myProfile.displayName.isNotEmpty
                          ? myProfile.displayName
                          : 'Moi',
                      senderAvatar: myProfile.avatarUrl,
                      type: MessageType.text,
                      content: firstMsg,
                      time: timeStr,
                      isOutgoing: true,
                    );
                    context.read<MessageRepository>().sendMessage(msg);
                  }

                  Navigator.of(ctx).pop();

                  if (widget.onSelectConversationDesktop != null) {
                    widget.onSelectConversationDesktop!(newConv);
                  } else {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            ConversationDetailScreen(conversation: newConv),
                      ),
                    );
                  }
                },
                child: const Text('Créer'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showDiscussionOptionsMenu() {
    showResponsiveSheet(
      isScrollControlled: true,
      useSafeArea: true,
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.tune, color: AppTheme.primary, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Options des Discussions',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.onSurface),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ListTile(
                leading: const Icon(Icons.mark_email_unread_outlined,
                    color: AppTheme.primary),
                title: const Text('Demandes de message'),
                trailing: Badge(
                  label: Text(
                      '${context.read<MessageRepository>().getPendingMessageRequests().length}'),
                  isLabelVisible: context
                      .read<MessageRepository>()
                      .getPendingMessageRequests()
                      .isNotEmpty,
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const MessageRequestsScreen()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.mark_chat_read_outlined,
                    color: AppTheme.primary),
                title: const Text('Tout marquer comme lu'),
                onTap: () {
                  final convRepo = context.read<ConversationRepository>();
                  for (final c in convRepo.getAllConversations()) {
                    convRepo.markAsRead(c.id);
                  }
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content:
                            Text('Toutes les discussions marquées comme lues')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.devices, color: AppTheme.secondary),
                title: const Text('Appareils synchronisés (3 max)'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  showResponsiveDialog(
                    context: context,
                    builder: (_) => const DeviceManagerDialog(),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.phone_in_talk_outlined,
                    color: AppTheme.primary),
                title: const Text('Historique des appels sécurisés'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const CallHistoryScreen()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.folder_special_outlined,
                    color: AppTheme.primary),
                title: const Text('Ouvrir le Coffre Médias'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const MediaVaultScreen()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final convRepo = context.watch<ConversationRepository>();
    final profile = context.watch<ProfileRepository>().getProfile();
    final conversations = convRepo.getFilteredConversations(
      filter: _selectedFilter,
      searchQuery: _searchQuery,
    );

    final allConversations = convRepo.getAllConversations();
    final nonArchived = allConversations.where((c) => !c.isArchived).toList();
    final totalCount = nonArchived.length;
    final unreadCount = nonArchived.where((c) => c.unreadCount > 0).length;
    final groupCount = nonArchived.where((c) => c.isGroup).length;
    final archivedCount = allConversations.where((c) => c.isArchived).length;

    return Scaffold(
      backgroundColor: AppTheme.surfaceWarm,
      body: SafeArea(
        child: Stack(
          children: [
            CustomScrollView(
              slivers: [
                // 1. Header
                SliverToBoxAdapter(
                  child: _buildHeader(profile),
                ),

                // 2. Status Moments Bar
                SliverToBoxAdapter(
                  child: _buildMomentsBar(),
                ),

                // 4. Search and Filter Chips
                SliverToBoxAdapter(
                  child: _buildSearchAndFilters(
                      totalCount, unreadCount, groupCount, archivedCount),
                ),

                // 5. Conversations Cards List or Coherent Empty State
                if (conversations.isEmpty)
                  SliverToBoxAdapter(
                    child: _searchQuery.isNotEmpty
                        ? AppEmptyState(
                            icon: Icons.search_off_rounded,
                            title: 'Aucune discussion trouvée',
                            message:
                                'Aucun échange existant ne correspond à "$_searchQuery". Vous pouvez contacter directement l\'un des utilisateurs ci-dessus ou lancer un nouvel échange.',
                            actionLabel: 'Effacer la recherche',
                            onAction: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : AppEmptyState(
                            icon: _selectedFilter == 'Archivés'
                                ? Icons.archive_outlined
                                : _selectedFilter == 'Non lus'
                                    ? Icons.mark_chat_read_outlined
                                    : _selectedFilter == 'Groupes'
                                        ? Icons.group_outlined
                                        : _selectedFilter == 'Favoris'
                                            ? Icons.star_border_rounded
                                            : Icons.chat_bubble_outline_rounded,
                            title: _selectedFilter == 'Archivés'
                                ? 'Aucune discussion archivée'
                                : _selectedFilter == 'Non lus'
                                    ? 'Aucun message non lu'
                                    : _selectedFilter == 'Groupes'
                                        ? 'Aucun groupe de discussion'
                                        : _selectedFilter == 'Favoris'
                                            ? 'Aucune discussion favorite'
                                            : 'Aucune discussion',
                            message: _selectedFilter == 'Tous'
                                ? 'Vos conversations privées et sécurisées apparaîtront ici.'
                                : (_selectedFilter == 'Archivés'
                                    ? 'Vos discussions archivées apparaîtront ici. Vous pouvez archiver une discussion en glissant vers la droite.'
                                    : 'Aucune conversation dans la catégorie "$_selectedFilter".'),
                            actionLabel: _selectedFilter == 'Archivés'
                                ? 'Retour aux discussions'
                                : (_selectedFilter == 'Tous'
                                    ? 'Nouvelle discussion'
                                    : 'Afficher tout'),
                            onAction: _selectedFilter == 'Archivés'
                                ? () => setState(() => _selectedFilter = 'Tous')
                                : (_selectedFilter == 'Tous'
                                    ? _showNewConversationDialog
                                    : () => setState(
                                        () => _selectedFilter = 'Tous')),
                          ),
                  )
                else ...[
                  if (_selectedFilter == 'Archivés')
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.archive_outlined,
                                  color: Color(0xFF1D4ED8), size: 20),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'Discussions archivées • Masquées de la liste principale',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1E40AF),
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () =>
                                    setState(() => _selectedFilter = 'Tous'),
                                child: const Text('Fermer',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1D4ED8))),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  SliverPadding(
                    padding: const EdgeInsets.only(
                        left: 16, right: 16, bottom: 100, top: 8),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final conv = conversations[index];
                          return _buildConversationCard(conv);
                        },
                        childCount: conversations.length,
                      ),
                    ),
                  ),
                ],
              ],
            ),

            // Floating Action Button with soft glow aura
            Positioned(
              bottom: 84,
              right: 18,
              child: GestureDetector(
                onTap: _showNewConversationDialog,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0043B8), Color(0xFF245BDB)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withOpacity(0.4),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                      BoxShadow(
                        color: AppTheme.secondaryGlow.withOpacity(0.3),
                        blurRadius: 16,
                      ),
                    ],
                    border: Border.all(
                        color: Colors.white.withOpacity(0.4), width: 1.5),
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 28),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(dynamic profile) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo & Title
          Row(
            children: [
              const MRixkLogo(size: 40),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Text(
                        'MRixk',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: AppTheme.onSurface,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 5,
                              height: 5,
                              decoration: const BoxDecoration(
                                color: AppTheme.statusGreen,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'En ligne',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF047857),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Text(
                    'Messagerie privée & sécurisée',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Actions: Calls, Media Vault, Tune & Profile
          Row(
            children: [
              IconButton(
                icon: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFDFE4ED)),
                  ),
                  child: const Icon(Icons.phone_outlined,
                      size: 18, color: AppTheme.primary),
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const CallHistoryScreen(),
                    ),
                  );
                },
                tooltip: 'Historique des appels',
              ),
              const SizedBox(width: 6),
              IconButton(
                icon: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFDFE4ED)),
                  ),
                  child: const Icon(Icons.folder_special_outlined,
                      size: 18, color: AppTheme.primary),
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const MediaVaultScreen(),
                    ),
                  );
                },
                tooltip: 'Dossier Médias & Coffre-fort',
              ),
              const SizedBox(width: 6),
              IconButton(
                icon: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Center(
                          child: Icon(Icons.tune,
                              size: 18, color: AppTheme.primary)),
                      if (context
                          .watch<MessageRepository>()
                          .getPendingMessageRequests()
                          .isNotEmpty)
                        Positioned(
                          right: 1,
                          top: 1,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                                color: Color(0xFFDC2626),
                                shape: BoxShape.circle),
                          ),
                        ),
                    ],
                  ),
                ),
                onPressed: _showDiscussionOptionsMenu,
                tooltip: 'Options des discussions',
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () {
                  if (widget.onNavigateTab != null) {
                    widget.onNavigateTab!(4); // Navigate to Profil
                  }
                },
                child: AppAvatar(
                  name: profile.displayName,
                  avatarUrl: profile.avatarUrl,
                  radius: 20,
                  isOnline: profile.isOnline,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showMomentStory(BuildContext context, List<Moment> moments,
      {int initialIndex = 0}) {
    if (moments.isEmpty) return;
    showDialog(
      context: context,
      useSafeArea: false,
      barrierColor: Colors.black.withOpacity(0.92),
      builder: (ctx) => MomentStoryViewerDialog(
        moments: moments,
        initialIndex: initialIndex,
      ),
    );
  }

  Widget _buildMomentsBar() {
    final moments = context.watch<MomentRepository>().getAllMoments();
    final profile = context.watch<ProfileRepository>().getProfile();

    // Check if the current user has any moment published
    final myMoments = moments
        .where((m) =>
      m.authorId == profile.id ||
            (profile.displayName.isNotEmpty &&
                m.authorName.toLowerCase() ==
                    profile.displayName.toLowerCase()))
        .toList();

    // Filter contacts' moments
    final otherMoments = moments
        .where((m) =>
      !myMoments.contains(m) &&
      m.authorId != profile.id &&
            (profile.displayName.isEmpty ||
                m.authorName.toLowerCase() !=
                    profile.displayName.toLowerCase()))
        .toList();

    // Group contact moments by author key to play their stories sequentially
    final Map<String, List<Moment>> contactMomentsGrouped = {};
    for (final m in otherMoments) {
      final key = m.authorId.isNotEmpty ? m.authorId : m.authorName;
      contactMomentsGrouped.putIfAbsent(key, () => []).add(m);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'MOMENTS DU JOUR',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: AppTheme.onSurfaceVariant,
                ),
              ),
              GestureDetector(
                onTap: () {
                  if (widget.onNavigateTab != null) widget.onNavigateTab!(1);
                },
                child: const Text(
                  'Voir tout',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 86,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              // Mon statut (+ Ajouter)
              _buildAddMomentItem(myMoments),
              for (final group in contactMomentsGrouped.values) ...[
                const SizedBox(width: 12),
                _buildContactMomentGroupItem(group),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAddMomentItem(List<Moment> myMoments) {
    final profile = context.watch<ProfileRepository>().getProfile();
    final hasMoment = myMoments.isNotEmpty;

    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            GestureDetector(
              onTap: () {
                if (hasMoment) {
                  _showMomentStory(context, myMoments, initialIndex: 0);
                } else {
                  showResponsiveDialog(
                    context: context,
                    builder: (ctx) => const AddMomentDialog(),
                  );
                }
              },
              child: Container(
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: hasMoment
                      ? const LinearGradient(
                          colors: [
                            AppTheme.primary,
                            Color(0xFF245BDB),
                            AppTheme.secondaryGlow
                          ],
                          begin: Alignment.bottomLeft,
                          end: Alignment.topRight,
                        )
                      : null,
                  border: hasMoment
                      ? null
                      : Border.all(color: const Color(0xFFDFE4ED), width: 1.5),
                ),
                child: AppAvatar(
                  name: profile.displayName.isNotEmpty
                      ? profile.displayName
                      : 'Moi',
                  avatarUrl: profile.avatarUrl,
                  radius: 23,
                  isClickable: false,
                  showBadge: false,
                ),
              ),
            ),
            Positioned(
              bottom: -1,
              right: -1,
              child: GestureDetector(
                onTap: () {
                  showResponsiveDialog(
                    context: context,
                    builder: (ctx) => const AddMomentDialog(),
                  );
                },
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 13),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          hasMoment ? 'Mon statut' : 'Ajouter',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppTheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildContactMomentGroupItem(List<Moment> momentsGroup) {
    if (momentsGroup.isEmpty) return const SizedBox.shrink();
    final firstMoment = momentsGroup.first;
    final count = momentsGroup.length;
    return GestureDetector(
      onTap: () => _showMomentStory(context, momentsGroup, initialIndex: 0),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(2.5),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primary,
                      Color(0xFF245BDB),
                      AppTheme.secondaryGlow
                    ],
                    begin: Alignment.bottomLeft,
                    end: Alignment.topRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: AppAvatar(
                  name: firstMoment.authorName,
                  avatarUrl: firstMoment.authorAvatar,
                  radius: 23,
                  isClickable: false,
                  showBadge: false,
                ),
              ),
              if (count > 1)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppTheme.secondary,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Text(
                      '$count',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 58,
            child: Text(
              firstMoment.authorName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppTheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters(
      int total, int unread, int groups, int archived) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFDFE4ED)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF111C2C).withOpacity(0.02),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.search, size: 20, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      setState(() => _searchQuery = val);
                      _searchOnlineDirectory(val);
                    },
                    decoration: const InputDecoration(
                      hintText: 'Rechercher un message, un proche...',
                      hintStyle: TextStyle(fontSize: 13, color: Colors.grey),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                      _searchOnlineDirectory('');
                    },
                    child:
                        const Icon(Icons.close, size: 18, color: Colors.grey),
                  ),
                const SizedBox(width: 6),
                const Icon(Icons.mic, size: 20, color: Colors.grey),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Filter pills
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterPill('Tous', count: total),
                const SizedBox(width: 8),
                _filterPill('Non lus', count: unread, hasPulse: true),
                const SizedBox(width: 8),
                _filterPill('Groupes', count: groups),
                const SizedBox(width: 8),
                _filterPill('Favoris', isStar: true),
                const SizedBox(width: 8),
                _filterPill('Archivés', count: archived),
              ],
            ),
          ),
          if (_searchQuery.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildRealtimeUserSearchResults(),
          ],
        ],
      ),
    );
  }

  Widget _buildRealtimeUserSearchResults() {
    final matchingUsers = _onlineSearchResults;
    if (matchingUsers.isEmpty) {
      final error = IdentityDirectoryService.lastOnlineError.value;
      if (!_searchingDirectory && error == null) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text('Aucun utilisateur trouvé sur le serveur.',
              style: TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant)),
        );
      }
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            if (_searchingDirectory)
              const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
            else
              const Icon(Icons.cloud_off_rounded,
                  size: 18, color: Color(0xFFB91C1C)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _searchingDirectory
                    ? 'Recherche sur le serveur…'
                    : 'Impossible de vérifier le réseau. Réessayez lorsque le serveur sera disponible.',
                style: TextStyle(
                    fontSize: 12,
                    color: _searchingDirectory
                        ? AppTheme.onSurfaceVariant
                        : const Color(0xFF991B1B)),
              ),
            ),
            if (!_searchingDirectory)
              TextButton(
                  onPressed: () => _searchOnlineDirectory(_searchQuery),
                  child: const Text('Réessayer')),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child:
                    const Icon(Icons.bolt, size: 14, color: AppTheme.primary),
              ),
              const SizedBox(width: 8),
              Text(
                'UTILISATEURS TROUVÉS (${matchingUsers.length}) — ACTIONS INSTANTANÉES',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: matchingUsers.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, idx) {
                final user = matchingUsers[idx];
                return _buildQuickUserCard(user);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickUserCard(SovereignUser user) {
    return Container(
      width: 155,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AppAvatar(
            name: user.name,
            avatarUrl: user.avatarUrl,
            radius: 18,
            isOnline: true,
            showBadge: false,
          ),
          const SizedBox(height: 4),
          Text(
            user.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppTheme.onSurface,
            ),
          ),
          Text(
            user.handle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10.5,
              color: AppTheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _quickActionButton(
                icon: Icons.chat_bubble_outline_rounded,
                tooltip: 'Discuter avec ${user.name}',
                color: AppTheme.primary,
                onTap: () => _openOrCreateConversationWithUser(user),
              ),
              const SizedBox(width: 8),
              _quickActionButton(
                icon: Icons.call_outlined,
                tooltip: 'Appel vocal avec ${user.name}',
                color: const Color(0xFF10B981),
                onTap: () => _startCallWithUser(user, isVideo: false),
              ),
              const SizedBox(width: 8),
              _quickActionButton(
                icon: Icons.videocam_outlined,
                tooltip: 'Appel vidéo avec ${user.name}',
                color: const Color(0xFF6366F1),
                onTap: () => _startCallWithUser(user, isVideo: true),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _quickActionButton({
    required IconData icon,
    required String tooltip,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 14, color: color),
        ),
      ),
    );
  }

  void _openOrCreateConversationWithUser(SovereignUser user) {
    final convRepo = context.read<ConversationRepository>();
    Conversation? existingConv;
    for (final c in convRepo.getAllConversations()) {
      if (c.title.toLowerCase().contains(user.name.toLowerCase()) ||
          c.title.toLowerCase().contains(user.handle.toLowerCase())) {
        existingConv = c;
        break;
      }
    }

    if (existingConv != null) {
      if (widget.onSelectConversationDesktop != null) {
        widget.onSelectConversationDesktop!(existingConv);
      } else {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (ctx) =>
                ConversationDetailScreen(conversation: existingConv!),
          ),
        );
      }
    } else {
      final now = DateTime.now();
      final timeStr =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      final newConv = Conversation(
        id: 'conv_${DateTime.now().millisecondsSinceEpoch}',
        peerUserId: user.id,
        title: user.name,
        peerAvatar: user.avatarUrl,
        isGroup: false,
        groupMembersCount: 1,
        lastMessage: 'Discussion démarrée',
        lastMessageTime: timeStr,
        unreadCount: 0,
        tagText: 'Privé',
      );
      convRepo.createConversation(newConv);
      if (widget.onSelectConversationDesktop != null) {
        widget.onSelectConversationDesktop!(newConv);
      } else {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (ctx) => ConversationDetailScreen(conversation: newConv),
          ),
        );
      }
    }
  }

  void _startCallWithUser(SovereignUser user, {required bool isVideo}) {
    showResponsiveDialog(
      context: context,
      builder: (ctx) => CallDialog(
        peerName: user.name,
        peerAvatar: user.avatarUrl,
        isVideo: isVideo,
        isPeerOnline: user.isOnline,
      ),
    );
  }

  Widget _filterPill(
    String label, {
    int? count,
    bool hasPulse = false,
    bool isStar = false,
  }) {
    final isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border:
              isSelected ? null : Border.all(color: const Color(0xFFDFE4ED)),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primary.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasPulse && !isSelected) ...[
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppTheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
            ],
            if (isStar) ...[
              const Icon(Icons.star, size: 13, color: Color(0xFFF59E0B)),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : AppTheme.onSurfaceVariant,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withOpacity(0.2)
                      : AppTheme.primarySoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : AppTheme.primary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConversationCard(Conversation conv) {
    return Dismissible(
      key: ValueKey('conv_${conv.id}'),
      direction: DismissDirection.horizontal,
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: conv.isArchived
              ? const Color(0xFF3B82F6)
              : const Color(0xFF10B981),
          borderRadius: BorderRadius.circular(18),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          children: [
            Icon(
              conv.isArchived
                  ? Icons.unarchive_outlined
                  : Icons.archive_outlined,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              conv.isArchived ? 'Désarchiver' : 'Archiver',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13.5,
              ),
            ),
          ],
        ),
      ),
      secondaryBackground: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444),
          borderRadius: BorderRadius.circular(18),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: const [
            Text(
              'Supprimer',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13.5,
              ),
            ),
            SizedBox(width: 8),
            Icon(Icons.delete_outline, color: Colors.white, size: 24),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Swipe right: Archive / Unarchive
          await context.read<ConversationRepository>().toggleArchive(conv.id);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  conv.isArchived
                      ? 'Discussion désarchivée'
                      : 'Discussion archivée',
                ),
                action: SnackBarAction(
                  label: 'Annuler',
                  textColor: Colors.amber,
                  onPressed: () {
                    context
                        .read<ConversationRepository>()
                        .toggleArchive(conv.id);
                  },
                ),
                duration: const Duration(seconds: 3),
              ),
            );
          }
          return true;
        } else {
          // Swipe left: Delete with confirmation
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
        scrollable: true,
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: const [
                  Icon(Icons.delete_forever, color: Color(0xFFEF4444)),
                  SizedBox(width: 8),
                  Text('Supprimer la discussion ?',
                      style: TextStyle(fontSize: 16)),
                ],
              ),
              content: Text(
                'Êtes-vous sûr de vouloir effacer l\'historique avec ${conv.title} sur cet appareil ?',
                style: const TextStyle(
                    fontSize: 13.5, color: AppTheme.onSurfaceVariant),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Conserver'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Supprimer'),
                ),
              ],
            ),
          );
          if (confirmed == true && mounted) {
            await context
                .read<ConversationRepository>()
                .deleteConversation(conv.id);
            return true;
          }
          return false;
        }
      },
      child: GestureDetector(
      onTap: () {
        if (widget.onSelectConversationDesktop != null) {
          widget.onSelectConversationDesktop!(conv);
        } else {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (ctx) => ConversationDetailScreen(conversation: conv),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            Stack(
              children: [
                if (conv.isGroup)
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [
                            AppTheme.primarySoft,
                            AppTheme.secondaryLight
                          ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFDBEAFE)),
                    ),
                      child: const Icon(Icons.groups,
                          color: AppTheme.primary, size: 24),
                  )
                else if (conv.title.contains('Coffre'))
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFDBEAFE)),
                    ),
                      child: const Icon(Icons.shield,
                          color: AppTheme.primary, size: 24),
                  )
                else
                  AppAvatar(
                    name: conv.title,
                    avatarUrl: conv.peerAvatar,
                    radius: 24,
                    isOnline: conv.isOnline,
                  ),
                if (conv.isGroup)
                  Positioned(
                    bottom: -2,
                    right: -2,
                    child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${conv.totalUserAccountsCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            conv.title,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.onSurface,
                            ),
                          ),
                          if (conv.isVerified) ...[
                            const SizedBox(width: 4),
                            Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Vérifié',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF059669),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        conv.lastMessageTime,
                        style: TextStyle(
                          fontSize: 11.5,
                            fontWeight: conv.unreadCount > 0
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: conv.unreadCount > 0
                                ? AppTheme.primary
                                : AppTheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Mini Audio Player snippet if hasVoiceNote
                  if (conv.hasVoiceNote) ...[
                    AudioPlayerWidget(
                      duration: conv.voiceNoteDuration ?? '0:42',
                      isCompact: true,
                    ),
                    const SizedBox(height: 4),
                  ],

                  // Document icon preview if hasDocument
                  if (conv.hasDocument) ...[
                    Row(
                      children: const [
                          Icon(Icons.description,
                              size: 16, color: AppTheme.primary),
                        SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Document partagé : Contrat de partenariat signé',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],

                  // Message text snippet & Unread badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          conv.lastMessage,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: conv.unreadCount > 0
                                ? AppTheme.onSurface
                                : AppTheme.onSurfaceVariant,
                              fontWeight: conv.unreadCount > 0
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (conv.unreadCount > 0)
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: AppTheme.primary,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primary.withOpacity(0.3),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              '${conv.unreadCount}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),

                  // Tag row (e.g. "Connexion sécurisée", "Projet équipe", "Mémoire protégée")
                  if (conv.tagText != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: const [
                              Icon(Icons.lock,
                                  size: 12, color: Color(0xFF059669)),
                            SizedBox(width: 3),
                            Text(
                              'Connexion sécurisée',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF059669),
                              ),
                            ),
                          ],
                        ),
                        Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: AppTheme.primarySoft,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            conv.tagText!,
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}
