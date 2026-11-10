import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/contact.dart';
import '../../../core/repositories/contact_repository.dart';
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

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  void _validateAndSubmit() {
    final query = _queryController.text.trim();
    if (query.isEmpty) {
      setState(() => _errorMessage = 'Veuillez saisir un identifiant ou nom d\'utilisateur.');
      return;
    }

    final queryLower = query.toLowerCase();
    if (queryLower == 'richard mare' ||
        queryLower == '@richard.m' ||
        queryLower.contains('richard')) {
      setState(() => _errorMessage = 'Vous ne pouvez pas vous ajouter vous-même comme contact.');
      return;
    }

    // Check if user exists in genuine sovereign identity directory
    final verifiedUser = _selectedUser ?? IdentityDirectoryService.findUser(query);
    if (verifiedUser == null) {
      setState(() {
        _errorMessage =
            'Utilisateur introuvable : L\'identifiant « $query » n\'existe pas sur le réseau sécurisé.';
      });
      return;
    }

    // Check if already in contacts
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

    final firstLetter = verifiedUser.name[0].toUpperCase();
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
    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF059669),
        content: Text('${verifiedUser.name} a été ajouté avec succès à vos contacts de confiance.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final searchResults = IdentityDirectoryService.searchUsers(_queryController.text);

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
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
              const SizedBox(height: 12),

              const Text(
                'Recherchez un utilisateur certifié sur le réseau sécurisé par son nom ou son identifiant unique (@handle) :',
                style: TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),

              // Query Input
              TextField(
                controller: _queryController,
                decoration: InputDecoration(
                  labelText: 'Nom ou identifiant (ex: @sophie.valade ou Sophie)',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                  errorText: _errorMessage,
                  suffixIcon: _queryController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            setState(() {
                              _queryController.clear();
                              _selectedUser = null;
                              _errorMessage = null;
                            });
                          },
                        )
                      : null,
                ),
                onChanged: (val) {
                  setState(() {
                    _selectedUser = null;
                    _errorMessage = null;
                  });
                },
              ),
              const SizedBox(height: 12),

              // Live matching list from sovereign directory
              if (searchResults.isNotEmpty) ...[
                const Text(
                  'Utilisateurs certifiés correspondants :',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0043B8)),
                ),
                const SizedBox(height: 6),
                Container(
                  constraints: const BoxConstraints(maxHeight: 180),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: searchResults.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final u = searchResults[index];
                      final isSelected = _selectedUser?.id == u.id;

                      return ListTile(
                        dense: true,
                        leading: AppAvatar(name: u.name, radius: 16, isVerified: true, isClickable: false),
                        title: Text(u.name, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                        subtitle: Text('${u.handle} • ${u.statusText}', style: const TextStyle(fontSize: 10.5)),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle, color: Color(0xFF0043B8), size: 20)
                            : const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
                        onTap: () {
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
