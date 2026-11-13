import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/contact.dart';
import '../../core/models/conversation.dart';
import '../../core/repositories/contact_repository.dart';
import '../../core/repositories/conversation_repository.dart';
import '../../core/repositories/device_repository.dart';
import '../../core/repositories/profile_repository.dart';
import '../../core/services/identity_directory_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/responsive/responsive.dart';
import '../../shared/widgets/app_avatar.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../discussions/conversation_detail_screen.dart';
import '../discussions/widgets/call_dialog.dart';
import '../security/security_verification_screen.dart';
import 'widgets/add_contact_dialog.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Multi-selection state
  bool _isSelectionMode = false;
  final Set<String> _selectedContactIds = {};
  bool _showBlockedOnly = false;

  // Draggable FAB position (starts bottom right)
  Offset _fabOffset = const Offset(0, 0);
  bool _fabInitialized = false;

  @override
  void initState() {
    super.initState();
    IdentityDirectoryService.searchUsersOnline('').then((_) {
      if (mounted) setState(() {});
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openAddContact() {
    showAdaptiveModal(
      context: context,
      builder: (ctx) => const AddContactDialog(),
    );
  }

  void _openChatWithContact(Contact contact) {
    if (contact.isBlocked) {
      _showBlockedAlert(contact);
      return;
    }

    final convRepo = context.read<ConversationRepository>();
    final allConvs = convRepo.getAllConversations();
    Conversation? target;

    for (final c in allConvs) {
      if (!c.isGroup &&
          (c.id == 'conv_${contact.id}' ||
           c.title.toLowerCase() == contact.name.toLowerCase() ||
           (contact.handle.isNotEmpty && c.title.toLowerCase() == contact.handle.toLowerCase()))) {
        target = c;
        break;
      }
    }

    if (target == null) {
      final now = DateTime.now();
      final timeStr =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      target = Conversation(
        id: 'conv_${contact.id}',
        title: contact.name,
        peerAvatar: contact.avatarUrl,
        isOnline: contact.isOnline,
        isVerified: contact.isVerified,
        lastMessage: 'Discussion sécurisée initiée',
        lastMessageTime: timeStr,
        unreadCount: 0,
      );
      convRepo.createConversation(target);
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ConversationDetailScreen(conversation: target!),
      ),
    );
  }

  void _callContact(Contact contact, {bool isVideo = false}) {
    if (contact.isBlocked) {
      _showBlockedAlert(contact);
      return;
    }

    final devRepo = context.read<DeviceRepository>();
    final myProfile = context.read<ProfileRepository>().getProfile();
    final nameLower = contact.name.trim().toLowerCase();
    final myNameLower = myProfile.displayName.trim().toLowerCase();
    final isSelf = contact.id == myProfile.id ||
        contact.id == 'contact_self' ||
        (myNameLower.isNotEmpty && nameLower == myNameLower) ||
        nameLower.contains('moi-même');
    final isOwnDevice = devRepo.getAllDevices().any((d) =>
        d.id == contact.id ||
        d.name.trim().toLowerCase() == nameLower);

    if (isSelf || isOwnDevice) {
      _showSelfCallNotAllowedAlert();
      return;
    }

    showResponsiveDialog(
      context: context,
      builder: (ctx) => CallDialog(
        peerName: contact.name,
        peerAvatar: contact.avatarUrl,
        isVideo: isVideo,
        isPeerOnline: contact.isOnline,
      ),
    );
  }

  void _showSelfCallNotAllowedAlert() {
    showResponsiveDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: const [
            Icon(Icons.phone_disabled_rounded, color: Color(0xFF0043B8), size: 28),
            SizedBox(width: 10),
            Text(
              'Appel non autorisé',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text(
          'Vous ne pouvez pas vous appeler vous-même ni appeler l\'un de vos autres appareils synchronisés.\n\n'
          'Vos appareils partagent le même espace sécurisé et vos échanges y sont déjà synchronisés instantanément en temps réel.',
          style: TextStyle(fontSize: 13, height: 1.4, color: AppTheme.onSurfaceVariant),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Compris'),
          ),
        ],
      ),
    );
  }

  void _showBlockedAlert(Contact contact) {
    showResponsiveDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: const [
            Icon(Icons.shield_outlined, color: Color(0xFFD97706)),
            SizedBox(width: 8),
            Text('Contact Suspendu', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Les échanges avec ${contact.name} sont actuellement suspendus (${contact.blockedUntil ?? "Définitif"}). Les appels et messages sont bloqués avec bienveillance pour préserver votre tranquillité mutuelle.',
          style: const TextStyle(fontSize: 13, height: 1.4, color: AppTheme.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Fermer'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await context.read<ContactRepository>().unblockContact(contact.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${contact.name} a été débloqué avec succès.')),
                );
              }
            },
            child: const Text('Débloquer'),
          ),
        ],
      ),
    );
  }

  void _showContactOptionsMenu(Contact contact) {
    showResponsiveSheet(
      isScrollControlled: true,
      useSafeArea: true,
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AppAvatar(name: contact.name, avatarUrl: contact.avatarUrl, radius: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(contact.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        Text(contact.handle, style: const TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),

              if (!contact.isBlocked) ...[
                ListTile(
                  leading: const Icon(Icons.timer_outlined, color: Color(0xFFF59E0B)),
                  title: const Text('Bloquer temporairement (24 heures)'),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    await context.read<ContactRepository>().blockContact(contact.id, duration: '24 heures');
                    _notifyBlocked(contact.name, '24 heures');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.date_range_outlined, color: Color(0xFFF59E0B)),
                  title: const Text('Bloquer temporairement (7 jours)'),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    await context.read<ContactRepository>().blockContact(contact.id, duration: '7 jours');
                    _notifyBlocked(contact.name, '7 jours');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.calendar_month_outlined, color: Color(0xFFD97706)),
                  title: const Text('Bloquer temporairement (30 jours)'),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    await context.read<ContactRepository>().blockContact(contact.id, duration: '30 jours');
                    _notifyBlocked(contact.name, '30 jours');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.block, color: Color(0xFFDC2626)),
                  title: const Text('Bloquer définitivement', style: TextStyle(color: Color(0xFFDC2626))),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    await context.read<ContactRepository>().blockContact(contact.id, duration: 'Définitif');
                    _notifyBlocked(contact.name, 'Définitif');
                  },
                ),
              ] else ...[
                ListTile(
                  leading: const Icon(Icons.lock_open, color: AppTheme.statusGreen),
                  title: const Text('Débloquer le contact avec bienveillance', style: TextStyle(color: AppTheme.statusGreen)),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    await context.read<ContactRepository>().unblockContact(contact.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${contact.name} débloqué.')),
                    );
                  },
                ),
              ],

              ListTile(
                leading: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
                title: const Text('Supprimer des contacts', style: TextStyle(color: Color(0xFFEF4444))),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  _confirmDeleteContacts([contact.id], [contact.name]);
                },
              ),
              ListTile(
                leading: const Icon(Icons.checklist, color: AppTheme.primary),
                title: const Text('Sélectionner plusieurs contacts'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  setState(() {
                    _isSelectionMode = true;
                    _selectedContactIds.add(contact.id);
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _notifyBlocked(String name, String duration) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF1E293B),
        content: Text(
          '$name a été suspendu ($duration). Les statuts, appels et recherches sont désormais inactifs de manière bienveillante.',
          style: const TextStyle(fontSize: 12),
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _confirmDeleteContacts(List<String> ids, List<String> names) {
    showResponsiveDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.delete_forever, color: Color(0xFFEF4444)),
            SizedBox(width: 8),
            Text('Supprimer de la liste ?', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Text(
          ids.length > 1
              ? 'Voulez-vous supprimer ces ${ids.length} contacts de votre carnet d\'adresses souverain ?'
              : 'Voulez-vous supprimer ${names.first} de vos contacts ?',
          style: const TextStyle(fontSize: 13, color: AppTheme.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await context.read<ContactRepository>().deleteMultipleContacts(ids);
              setState(() {
                _selectedContactIds.clear();
                _isSelectionMode = false;
              });
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Contact(s) supprimé(s).')),
                );
              }
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  void _showBatchBlockDialog() {
    String selectedDuration = '24 heures';
    showResponsiveDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
        scrollable: true,
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Bloquer ${_selectedContactIds.length} contact(s)'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Choisissez la durée de suspension bienveillante :',
                style: TextStyle(fontSize: 13, color: AppTheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              ...['24 heures', '7 jours', '30 jours', 'Définitif'].map((d) {
                return RadioListTile<String>(
                  title: Text(d, style: const TextStyle(fontSize: 13)),
                  value: d,
                  groupValue: selectedDuration,
                  activeColor: AppTheme.primary,
                  onChanged: (val) {
                    if (val != null) setModalState(() => selectedDuration = val);
                  },
                );
              }),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD97706), foregroundColor: Colors.white),
              onPressed: () async {
                Navigator.of(ctx).pop();
                await context.read<ContactRepository>().blockMultipleContacts(
                      _selectedContactIds.toList(),
                      duration: selectedDuration,
                    );
                setState(() {
                  _selectedContactIds.clear();
                  _isSelectionMode = false;
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${_selectedContactIds.length} contact(s) bloqué(s) pour $selectedDuration.')),
                  );
                }
              },
              child: const Text('Confirmer le blocage'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final contactRepo = context.watch<ContactRepository>();
    final allContacts = contactRepo.getAllContacts();
    final displayedContacts = _showBlockedOnly
        ? contactRepo.getBlockedContacts()
        : contactRepo.searchContacts(_searchQuery);

    final screenSize = MediaQuery.of(context).size;
    if (!_fabInitialized) {
      _fabOffset = Offset(screenSize.width - 80, screenSize.height - 160);
      _fabInitialized = true;
    }

    return Scaffold(
      backgroundColor: AppTheme.surfaceWarm,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                floating: true,
                pinned: true,
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isSelectionMode
                          ? '${_selectedContactIds.length} sélectionné(s)'
                          : (_showBlockedOnly ? 'Contacts Suspendus' : 'Contacts Réseau'),
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.onSurface,
                      ),
                    ),
                    Text(
                      _showBlockedOnly
                          ? 'Contacts masqués et inactifs'
                          : '${allContacts.length} contacts de confiance synchronisés',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                actions: [
                  // Bouton permanent d'ajout de contact dans l'en-tête (ne disparaît jamais)
                  IconButton(
                    icon: Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: AppTheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person_add_rounded,
                        size: 19,
                        color: Colors.white,
                      ),
                    ),
                    tooltip: 'Ajouter un contact',
                    onPressed: _openAddContact,
                  ),
                  IconButton(
                    icon: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _showBlockedOnly ? const Color(0xFFFEF3C7) : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Icon(
                        Icons.shield_outlined,
                        size: 18,
                        color: _showBlockedOnly ? const Color(0xFFD97706) : AppTheme.onSurfaceVariant,
                      ),
                    ),
                    tooltip: _showBlockedOnly ? 'Voir tous les contacts' : 'Voir les contacts bloqués',
                    onPressed: () => setState(() => _showBlockedOnly = !_showBlockedOnly),
                  ),
                  IconButton(
                    icon: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _isSelectionMode ? AppTheme.primarySoft : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: _isSelectionMode ? AppTheme.primary : const Color(0xFFCBD5E1)),
                      ),
                      child: Icon(
                        Icons.checklist_rounded,
                        size: 18,
                        color: _isSelectionMode ? AppTheme.primary : AppTheme.onSurfaceVariant,
                      ),
                    ),
                    tooltip: _isSelectionMode ? 'Quitter la sélection' : 'Sélectionner des contacts',
                    onPressed: () => setState(() {
                      _isSelectionMode = !_isSelectionMode;
                      if (!_isSelectionMode) _selectedContactIds.clear();
                    }),
                  ),
                  const SizedBox(width: 8),
                ],
              ),

              // Multi-select top banner
              if (_isSelectionMode)
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.primary, width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withOpacity(0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_selectedContactIds.length} contact(s) choisi(s)',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primary),
                        ),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFF59E0B),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              ),
                              icon: const Icon(Icons.block, size: 14),
                              label: const Text('Bloquer...', style: TextStyle(fontSize: 11.5)),
                              onPressed: _selectedContactIds.isEmpty ? null : _showBatchBlockDialog,
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFEF4444),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              ),
                              icon: const Icon(Icons.delete_outline, size: 14),
                              label: const Text('Supprimer', style: TextStyle(fontSize: 11.5)),
                              onPressed: _selectedContactIds.isEmpty
                                  ? null
                                  : () => _confirmDeleteContacts(_selectedContactIds.toList(), []),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

              // Search Bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) {
                        setState(() => _searchQuery = val);
                        if (val.trim().isNotEmpty) {
                          IdentityDirectoryService.searchUsersOnline(val).then((_) {
                            if (mounted) setState(() {});
                          });
                        }
                      },
                      decoration: InputDecoration(
                        hintText: 'Rechercher un contact, @handle, statut...',
                        hintStyle: const TextStyle(fontSize: 13, color: AppTheme.onSurfaceVariant),
                        prefixIcon: const Icon(Icons.search, color: AppTheme.onSurfaceVariant, size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ),
              ),

              // Real-time suggestions from sovereign directory
              if (_searchQuery.trim().isNotEmpty)
                SliverToBoxAdapter(
                  child: _buildRealtimeDirectoryResults(displayedContacts),
                ),

              // Contacts List
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                sliver: displayedContacts.isEmpty
                    ? SliverToBoxAdapter(
                        child: _showBlockedOnly
                            ? const AppEmptyState(
                                icon: Icons.shield_outlined,
                                title: 'Aucun contact suspendu',
                                message:
                                    'Aucun contact n\'est actuellement bloqué ou restreint dans vos paramètres.',
                              )
                            : _searchQuery.isNotEmpty
                                ? AppEmptyState(
                                    icon: Icons.person_search_rounded,
                                    title: 'Aucun contact correspondant',
                                    message:
                                        'Aucun contact de votre carnet ne correspond à "$_searchQuery".',
                                    actionLabel: 'Effacer la recherche',
                                    onAction: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                : AppEmptyState(
                                    icon: Icons.people_outline_rounded,
                                    title: 'Aucun contact enregistré',
                                    message:
                                        'Votre carnet de contacts est vide. Ajoutez vos proches vérifiés pour échanger en toute confidentialité.',
                                    actionLabel: 'Ajouter un contact',
                                    onAction: _openAddContact,
                                  ),
                      )
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final contact = displayedContacts[index];
                            return _buildContactCard(contact);
                          },
                          childCount: displayedContacts.length,
                        ),
                      ),
              ),
              const SliverToBoxAdapter(
                child: SizedBox(height: 90),
              ),
            ],
          ),

          // FLOATING ACTION BUTTON PERMANENT (Toujours visible et accessible au-dessus de la barre)
          Positioned(
            right: 20,
            bottom: 96,
            child: Tooltip(
              message: 'Ajouter un contact souverain',
              child: FloatingActionButton.extended(
                heroTag: 'fab_add_contact_permanent',
                backgroundColor: AppTheme.primary,
                elevation: 6,
                onPressed: _openAddContact,
                icon: const Icon(Icons.person_add_rounded, color: Colors.white, size: 20),
                label: const Text(
                  'Ajouter',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRealtimeDirectoryResults(List<Contact> displayedContacts) {
    final myProfile = context.read<ProfileRepository>().getProfile();
    final myHandleClean = myProfile.handle.toLowerCase().replaceAll('@', '').trim();
    final myNameLower = myProfile.displayName.toLowerCase().trim();
    final myId = myProfile.id.trim();

    final matchingUsers = IdentityDirectoryService.searchUsers(_searchQuery);
    final existingNames = displayedContacts.map((c) => c.name.toLowerCase().trim()).toSet();
    final existingHandles = displayedContacts.map((c) => c.handle.toLowerCase().replaceAll('@', '').trim()).toSet();
    final existingIds = displayedContacts.map((c) => c.id.trim()).toSet();

    final nonAddedUsers = matchingUsers.where((u) {
      final uHandleClean = u.handle.toLowerCase().replaceAll('@', '').trim();
      final uNameLower = u.name.toLowerCase().trim();
      final isSelf = (myId.isNotEmpty && u.id == myId) ||
          (myHandleClean.isNotEmpty && uHandleClean == myHandleClean) ||
          (myNameLower.isNotEmpty && uNameLower == myNameLower);
      if (isSelf) return false;
      if (existingIds.contains(u.id)) return false;
      if (existingHandles.contains(uHandleClean)) return false;
      if (existingNames.contains(uNameLower)) return false;
      return true;
    }).toList();

    if (nonAddedUsers.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
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
                      const Icon(Icons.person_add_alt_1_rounded, size: 14, color: AppTheme.primary),
                ),
                const SizedBox(width: 8),
                Text(
                  'UTILISATEURS DU RÉSEAU MRixk (${nonAddedUsers.length}) — AJOUT RAPIDE',
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
              height: 115,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: nonAddedUsers.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, idx) {
                  final user = nonAddedUsers[idx];
                  return Container(
                    width: 160,
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
                          radius: 16,
                          isOnline: true,
                          showBadge: false,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          user.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.onSurface,
                          ),
                        ),
                        Text(
                          user.handle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppTheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 6),
                        ElevatedButton.icon(
                          onPressed: () => _quickAddContact(user),
                          icon: const Icon(Icons.add, size: 13),
                          label: const Text('Ajouter', style: TextStyle(fontSize: 11)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                            minimumSize: const Size(60, 24),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
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
      ),
    );
  }

  void _quickAddContact(SovereignUser user) {
    final contactRepo = context.read<ContactRepository>();
    final newContact = Contact(
      id: 'contact_${DateTime.now().millisecondsSinceEpoch}',
      name: user.name,
      handle: user.handle,
      avatarUrl: user.avatarUrl,
      statusText: user.statusText,
      category: user.name.isNotEmpty ? user.name[0].toUpperCase() : '#',
      isOnline: true,
      isVerified: true,
    );
    contactRepo.createContact(newContact);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${user.name} a été ajouté(e) à vos contacts.'),
        backgroundColor: const Color(0xFF0043B8),
      ),
    );
  }

  Widget _buildContactCard(Contact contact) {
    final isSelected = _selectedContactIds.contains(contact.id);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onLongPress: () {
        setState(() {
          _isSelectionMode = true;
          _selectedContactIds.add(contact.id);
        });
      },
      onTap: () {
        if (_isSelectionMode) {
          setState(() {
            if (isSelected) {
              _selectedContactIds.remove(contact.id);
              if (_selectedContactIds.isEmpty) _isSelectionMode = false;
            } else {
              _selectedContactIds.add(contact.id);
            }
          });
        } else {
          _openChatWithContact(contact);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: contact.isBlocked ? const Color(0xFFFEF3C7).withOpacity(0.4) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppTheme.primary
                : (contact.isBlocked ? const Color(0xFFFDE68A) : const Color(0xFFCBD5E1)),
            width: isSelected ? 1.8 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            if (_isSelectionMode)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Checkbox(
                  value: isSelected,
                  activeColor: AppTheme.primary,
                  shape: const CircleBorder(),
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _selectedContactIds.add(contact.id);
                      } else {
                        _selectedContactIds.remove(contact.id);
                        if (_selectedContactIds.isEmpty) _isSelectionMode = false;
                      }
                    });
                  },
                ),
              ),

            AppAvatar(
              name: contact.name,
              avatarUrl: contact.avatarUrl,
              radius: 22,
              isOnline: contact.isOnline && !contact.isBlocked,
              isVerified: contact.isVerified,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          contact.name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: contact.isBlocked ? const Color(0xFF92400E) : AppTheme.onSurface,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (contact.isBlocked) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFF59E0B)),
                          ),
                          child: Text(
                            'Suspendu (${contact.blockedUntil ?? "Définitif"})',
                            style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                          ),
                        ),
                      ] else if (contact.isVerified) ...[
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => SecurityVerificationScreen(
                                  peerName: contact.name,
                                  peerAvatar: contact.avatarUrl,
                                  isVerified: contact.isVerified,
                                ),
                              ),
                            );
                          },
                          child: const Icon(Icons.verified, size: 16, color: AppTheme.secondary),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    contact.isBlocked
                        ? 'Contact suspendu avec bienveillance'
                        : '${contact.handle} • ${contact.statusText}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppTheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Action Buttons: Chat, Call & Options "..."
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!contact.isBlocked) ...[
                  IconButton(
                    icon: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceWarm,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: const Icon(Icons.chat_bubble_outline, size: 16, color: AppTheme.primary),
                    ),
                    tooltip: 'Discussion',
                    onPressed: () => _openChatWithContact(contact),
                  ),
                  IconButton(
                    icon: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceWarm,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: const Icon(Icons.call_outlined, size: 16, color: AppTheme.onSurface),
                    ),
                    tooltip: 'Appel sécurisé',
                    onPressed: () => _callContact(contact),
                  ),
                ],
                // Option "..." button
                IconButton(
                  icon: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceWarm,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: const Icon(Icons.more_vert, size: 16, color: AppTheme.onSurfaceVariant),
                  ),
                  tooltip: 'Options du contact (Bloquer, Supprimer)',
                  onPressed: () => _showContactOptionsMenu(contact),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
