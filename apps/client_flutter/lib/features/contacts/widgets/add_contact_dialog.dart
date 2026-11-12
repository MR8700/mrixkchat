import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/contact.dart';
import '../../../core/repositories/contact_repository.dart';
import '../../../core/repositories/profile_repository.dart';
import '../../../core/services/identity_directory_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_avatar.dart';

class AddContactDialog extends StatefulWidget {
  const AddContactDialog({super.key});

  @override
  State<AddContactDialog> createState() => _AddContactDialogState();
}

class _AddContactDialogState extends State<AddContactDialog> {
  final TextEditingController _queryController = TextEditingController();
  SovereignUser? _selectedUser;
  String? _errorMessage;
  bool _isSearchingOnline = false;

  @override
  void initState() {
    super.initState();
    _triggerOnlineSearch('');
  }

  void _triggerOnlineSearch(String q) {
    setState(() => _isSearchingOnline = true);
    IdentityDirectoryService.searchUsersOnline(q).then((_) {
      if (mounted) setState(() => _isSearchingOnline = false);
    }).catchError((_) {
      if (mounted) setState(() => _isSearchingOnline = false);
    });
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _validateAndSubmit() async {
    final query = _queryController.text.trim();
    if (query.isEmpty) {
      setState(() => _errorMessage = 'Veuillez saisir un identifiant ou nom d\'utilisateur.');
      return;
    }

    final myProfile = context.read<ProfileRepository>().getProfile();
    final queryLower = query.toLowerCase().trim();
    final myHandleClean = myProfile.handle.toLowerCase().replaceAll('@', '').trim();
    final queryClean = queryLower.replaceAll('@', '');
    if ((myProfile.displayName.isNotEmpty && queryLower == myProfile.displayName.toLowerCase().trim()) ||
        (myHandleClean.isNotEmpty && queryClean == myHandleClean)) {
      setState(() => _errorMessage = 'Vous ne pouvez pas vous ajouter vous-même comme contact.');
      return;
    }

    setState(() => _isSearchingOnline = true);

    // Verify against the online backend server first
    final verifiedUser = _selectedUser ?? await IdentityDirectoryService.verifyUserOnline(query);
    if (mounted) setState(() => _isSearchingOnline = false);

    if (verifiedUser == null) {
      if (mounted) {
        setState(() {
          _errorMessage =
              'Utilisateur introuvable : L\'identifiant « $query » n\'existe pas sur le serveur en ligne.';
        });
      }
      return;
    }

    // Check if already in contacts
    final existing = context.read<ContactRepository>().getAllContacts();
    if (existing.any((c) =>
        c.id == verifiedUser.id ||
        c.name.toLowerCase() == verifiedUser.name.toLowerCase() ||
        c.handle.toLowerCase() == verifiedUser.handle.toLowerCase())) {
      if (mounted) {
        setState(() {
          _errorMessage = '${verifiedUser.name} est déjà présent dans vos contacts.';
        });
      }
      return;
    }

    final firstLetter = verifiedUser.name.isNotEmpty ? verifiedUser.name[0].toUpperCase() : 'U';
    final newContact = Contact(
      id: verifiedUser.id,
      name: verifiedUser.name,
      handle: verifiedUser.handle,
      avatarUrl: verifiedUser.avatarUrl,
      statusText: verifiedUser.statusText,
      isVerified: true,
      category: firstLetter,
    );

    context.read<ContactRepository>().createContact(newContact);
    if (mounted) {
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF059669),
          content: Text('${verifiedUser.name} (${verifiedUser.handle}) a été vérifié sur le serveur et ajouté à vos contacts.'),
        ),
      );
    }
  }

  void _addContactDirectly(SovereignUser verifiedUser) {
    final existing = context.read<ContactRepository>().getAllContacts();
    if (existing.any((c) =>
        c.id == verifiedUser.id ||
        c.name.toLowerCase() == verifiedUser.name.toLowerCase() ||
        c.handle.toLowerCase() == verifiedUser.handle.toLowerCase())) {
      setState(() {
        _errorMessage = '${verifiedUser.name} est déjà présent dans vos contacts.';
      });
      return;
    }

    final firstLetter = verifiedUser.name.isNotEmpty ? verifiedUser.name[0].toUpperCase() : 'U';
    final newContact = Contact(
      id: verifiedUser.id,
      name: verifiedUser.name,
      handle: verifiedUser.handle,
      avatarUrl: verifiedUser.avatarUrl,
      statusText: verifiedUser.statusText,
      isVerified: true,
      category: firstLetter,
    );

    context.read<ContactRepository>().createContact(newContact);
    if (mounted) {
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF059669),
          content: Text('${verifiedUser.name} (${verifiedUser.handle}) a été vérifié sur le serveur et ajouté à vos contacts.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final myProfile = context.read<ProfileRepository>().getProfile();
    final myId = myProfile.id.trim();
    final myHandleClean = myProfile.handle.toLowerCase().replaceAll('@', '').trim();
    final myNameLower = myProfile.displayName.toLowerCase().trim();

    final existingContacts = context.read<ContactRepository>().getAllContacts();
    final existingIds = existingContacts.map((c) => c.id).toSet();
    final existingHandles = existingContacts.map((c) => c.handle.toLowerCase().replaceAll('@', '').trim()).toSet();
    final existingNames = existingContacts.map((c) => c.name.toLowerCase().trim()).toSet();

    final allResults = IdentityDirectoryService.searchUsers(_queryController.text);

    // Strictly exclude the current user from any search or directory results
    final nonSelfResults = allResults.where((u) {
      final uHandleClean = u.handle.toLowerCase().replaceAll('@', '').trim();
      final uNameLower = u.name.toLowerCase().trim();
      final isSelf = (myId.isNotEmpty && u.id == myId) ||
          (myHandleClean.isNotEmpty && uHandleClean == myHandleClean) ||
          (myNameLower.isNotEmpty && uNameLower == myNameLower);
      return !isSelf;
    }).toList();

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.person_add_rounded, color: Color(0xFF0043B8), size: 22),
                      SizedBox(width: 8),
                      Text(
                        'Ajouter un contact',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              const Text(
                'Recherchez un utilisateur certifié sur le réseau sécurisé par son nom ou son identifiant unique (@handle) :',
                style: TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),

              // Query Input
              TextField(
                controller: _queryController,
                decoration: InputDecoration(
                  labelText: 'Nom ou identifiant (ex: @alice ou Alice)',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                  errorText: _errorMessage,
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isSearchingOnline)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      if (_queryController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            setState(() {
                              _queryController.clear();
                              _selectedUser = null;
                              _errorMessage = null;
                            });
                            _triggerOnlineSearch('');
                          },
                        ),
                    ],
                  ),
                ),
                onChanged: (val) {
                  setState(() {
                    _selectedUser = null;
                    _errorMessage = null;
                  });
                  _triggerOnlineSearch(val);
                },
              ),
              const SizedBox(height: 14),

              // Section Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _queryController.text.trim().isEmpty
                        ? 'Membres inscrits sur le réseau (${nonSelfResults.length}) :'
                        : 'Utilisateurs certifiés correspondants (${nonSelfResults.length}) :',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0043B8)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, size: 16, color: Color(0xFF0043B8)),
                    tooltip: 'Rafraîchir les utilisateurs en ligne',
                    onPressed: () => _triggerOnlineSearch(_queryController.text),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // Results or Empty State
              if (nonSelfResults.isEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        _isSearchingOnline ? Icons.cloud_sync_rounded : Icons.person_search_outlined,
                        size: 36,
                        color: const Color(0xFF94A3B8),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _isSearchingOnline
                            ? 'Recherche sur le serveur en ligne...'
                            : (_queryController.text.trim().isEmpty
                                ? 'Aucun autre utilisateur inscrit sur le réseau pour le moment.'
                                : 'Aucun utilisateur certifié ne correspond à « ${_queryController.text.trim()} ».'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isSearchingOnline
                            ? 'Vérification du répertoire réseau en cours'
                            : (_queryController.text.trim().isEmpty
                                ? 'Dès qu\'un utilisateur crée un compte sur le réseau, il apparaîtra ici automatiquement.'
                                : 'Vérifiez l\'orthographe du pseudonyme ou du @handle.'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                      ),
                      if (!_isSearchingOnline) ...[
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: const Text('Actualiser la liste en ligne', style: TextStyle(fontSize: 12)),
                          onPressed: () => _triggerOnlineSearch(_queryController.text),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ] else ...[
                Container(
                  constraints: const BoxConstraints(maxHeight: 220),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: nonSelfResults.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final u = nonSelfResults[index];
                      final isSelected = _selectedUser?.id == u.id;
                      final uHandleClean = u.handle.toLowerCase().replaceAll('@', '').trim();
                      final isAlreadyContact = existingIds.contains(u.id) ||
                          existingHandles.contains(uHandleClean) ||
                          existingNames.contains(u.name.toLowerCase().trim());

                      return ListTile(
                        dense: true,
                        leading: AppAvatar(name: u.name, radius: 17, isVerified: true, isClickable: false),
                        title: Row(
                          children: [
                            Flexible(
                              child: Text(
                                u.name,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isAlreadyContact) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE2E8F0),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Déjà contact',
                                  style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                                ),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Text(
                          '${u.handle} • ${u.statusText}',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: isAlreadyContact
                            ? const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF059669), size: 20)
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF0043B8), size: 20),
                                    tooltip: 'Ajouter aux contacts',
                                    onPressed: () => _addContactDirectly(u),
                                  ),
                                  if (isSelected)
                                    const Icon(Icons.check_circle, color: Color(0xFF0043B8), size: 20)
                                  else
                                    const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
                                ],
                              ),
                        onTap: () {
                          if (isAlreadyContact) {
                            setState(() {
                              _errorMessage = '${u.name} est déjà présent dans vos contacts.';
                            });
                            return;
                          }
                          setState(() {
                            _selectedUser = u;
                            _queryController.text = u.handle;
                            _errorMessage = null;
                          });
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Annuler', style: TextStyle(color: AppTheme.onSurfaceVariant)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0043B8),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _validateAndSubmit,
                    child: const Text('Ajouter'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
