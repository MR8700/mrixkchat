import 'package:flutter/material.dart';
import '../../shared/responsive/responsive.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/models/user_profile.dart';
import '../../core/repositories/device_repository.dart';
import '../../core/repositories/profile_repository.dart';
import '../../core/services/real_media_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_avatar.dart';
import '../media_vault/media_vault_screen.dart';
import '../onboarding/splash_screen.dart';
import '../security/security_verification_screen.dart';
import 'widgets/device_manager_dialog.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _showAvatarOptions(BuildContext context, void Function(String newAvatarUrl) onAvatarSelected) {
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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.photo_camera_rounded, color: Color(0xFF0043B8), size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Photo de profil',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.camera_alt_rounded, color: Color(0xFF0043B8)),
                ),
                title: const Text('Appareil photo / Prendre une photo',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Prendre une photo instantanée avec la caméra'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final photo = await RealMediaService.instance.captureCameraPhoto();
                  if (photo != null && photo.isNotEmpty) {
                    onAvatarSelected(photo);
                  }
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.photo_library_rounded, color: Color(0xFF16A34A)),
                ),
                title: const Text('Choisir depuis l\'appareil',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Sélectionner une image dans vos documents'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final photo = await RealMediaService.instance.pickMediaFile(isVideo: false);
                  if (photo != null && photo.isNotEmpty) {
                    onAvatarSelected(photo);
                  }
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.delete_outline, color: Colors.redAccent),
                ),
                title: const Text('Supprimer la photo actuelle',
                    style: TextStyle(fontWeight: FontWeight.w600, color: Colors.redAccent)),
                subtitle: const Text('Utiliser les initiales de votre pseudonyme'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  onAvatarSelected('');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showChangeAvatarModal(BuildContext context, UserProfile profile) {
    _showAvatarOptions(context, (newAvatar) async {
      await context
          .read<ProfileRepository>()
          .updateProfile(profile.copyWith(avatarUrl: newAvatar));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo de profil mise à jour avec succès'),
            backgroundColor: Color(0xFF0043B8),
          ),
        );
      }
    });
  }

  void _openEditProfileDialog(BuildContext context, UserProfile profile) {
    final nameController = TextEditingController(text: profile.displayName);
    final handleController = TextEditingController(
      text: profile.handle.startsWith('@') ? profile.handle.substring(1) : profile.handle,
    );
    final statusController = TextEditingController(text: profile.statusMessage);
    String selectedAvatarUrl = profile.avatarUrl;

    showResponsiveDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
        scrollable: true,
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primarySoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.manage_accounts_outlined,
                        color: AppTheme.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Modifier mes informations',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 440,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 8),
                      // Avatar with edit badge
                      GestureDetector(
                        onTap: () {
                          _showAvatarOptions(context, (newAvatar) {
                            setDialogState(() {
                              selectedAvatarUrl = newAvatar;
                            });
                          });
                        },
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            AppAvatar(
                              name: nameController.text.isNotEmpty
                                  ? nameController.text
                                  : profile.displayName,
                              avatarUrl: selectedAvatarUrl,
                              radius: 42,
                              isOnline: true,
                            ),
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppTheme.primary,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(Icons.camera_alt,
                                  color: Colors.white, size: 14),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextButton.icon(
                        onPressed: () {
                          _showAvatarOptions(context, (newAvatar) {
                            setDialogState(() {
                              selectedAvatarUrl = newAvatar;
                            });
                          });
                        },
                        icon: const Icon(Icons.photo_camera,
                            size: 16, color: AppTheme.primary),
                        label: const Text(
                          'Changer la photo',
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primary),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Name / Pseudo
                      TextField(
                        controller: nameController,
                        onChanged: (_) => setDialogState(() {}),
                        decoration: InputDecoration(
                          labelText: 'Nom ou Pseudonyme',
                          hintText: 'Ex: Richard M.',
                          prefixIcon: const Icon(Icons.person_outline, size: 20),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14)),
                          filled: true,
                          fillColor: AppTheme.surfaceWarm,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Sovereign handle (STRICTLY READ-ONLY / IMMUTABLE)
                      TextField(
                        controller: handleController,
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: 'Identifiant souverain (Non modifiable)',
                          prefixText: '@',
                          prefixIcon:
                              const Icon(Icons.lock_outline_rounded, size: 20, color: Color(0xFF64748B)),
                          helperText: 'L\'identifiant souverain avec @ est unique et non modifiable.',
                          helperStyle: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14)),
                          filled: true,
                          fillColor: const Color(0xFFF1F5F9),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Status message
                      TextField(
                        controller: statusController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: 'Statut / Pensée',
                          hintText: 'Ex: Disponible sur MRixk',
                          prefixIcon:
                              const Icon(Icons.chat_bubble_outline, size: 20),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14)),
                          filled: true,
                          fillColor: AppTheme.surfaceWarm,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: const Text('Annuler',
                      style: TextStyle(color: AppTheme.onSurfaceVariant)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    final trimmedName = nameController.text.trim();
                    final trimmedStatus = statusController.text.trim();

                    final updated = profile.copyWith(
                      displayName: trimmedName.isNotEmpty
                          ? trimmedName
                          : profile.displayName,
                      handle: profile.handle,
                      statusMessage: trimmedStatus.isNotEmpty
                          ? trimmedStatus
                          : profile.statusMessage,
                      avatarUrl: selectedAvatarUrl,
                    );

                    await context.read<ProfileRepository>().updateProfile(updated);
                    Navigator.of(dialogCtx).pop();

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Informations personnelles mises à jour avec succès'),
                          backgroundColor: Color(0xFF0043B8),
                          duration: Duration(seconds: 3),
                        ),
                      );
                    }
                  },
                  child: const Text('Enregistrer',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmLogout(BuildContext context) {
    showResponsiveDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        scrollable: true,
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.logout, color: Color(0xFFDC2626), size: 22),
            SizedBox(width: 10),
            Text(
              'Déconnexion',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text(
          'Voulez-vous vous déconnecter de votre compte MRixk ?\n\n'
          'Votre session locale sera fermée. Vous pourrez vous reconnecter ou configurer un autre compte sur cet appareil.',
          style: TextStyle(fontSize: 13.5, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Annuler',
                style: TextStyle(color: AppTheme.onSurfaceVariant)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.of(dialogCtx).pop();
              await context.read<ProfileRepository>().logout();
              if (context.mounted) {
                Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const SplashScreen()),
                  (route) => false,
                );
              }
            },
            child: const Text('Se déconnecter',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAccount(BuildContext context) {
    showResponsiveDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        scrollable: true,
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded,
                color: Color(0xFFDC2626), size: 24),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Supprimer définitivement mon compte',
                style: TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFDC2626),
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.security_update_warning_rounded,
                      color: Color(0xFFDC2626), size: 24),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Action irréversible et destructrice',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF991B1B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Toutes vos conversations locales, messages chiffrés, contacts, médias et vos clés souveraines Ed25519 stockées sur cet appareil seront définitivement effacées.\n\n'
              'Êtes-vous absolument sûr de vouloir supprimer définitivement votre compte ?',
              style: TextStyle(
                  fontSize: 13, height: 1.5, color: AppTheme.onSurface),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Annuler',
                style: TextStyle(color: AppTheme.onSurfaceVariant)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.of(dialogCtx).pop();
              final messenger = ScaffoldMessenger.of(context);
              try {
                await context.read<ProfileRepository>().deleteAccount();
              } catch (e) {
                // Server did not confirm: keep local data, tell the user.
                messenger.showSnackBar(SnackBar(
                  backgroundColor: const Color(0xFFDC2626),
                  content: Text('Suppression impossible : ${e.toString().replaceAll('Exception: ', '')}'),
                ));
                return;
              }
              if (context.mounted) {
                Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const SplashScreen()),
                  (route) => false,
                );
                messenger.showSnackBar(const SnackBar(
                  content: Text('Compte supprimé. Votre @identifiant reste réservé 24 h.'),
                ));
              }
            },
            child: const Text('Supprimer définitivement',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _editStatusDialog(BuildContext context) {
    final profileRepo = context.read<ProfileRepository>();
    final currentStatus = profileRepo.getProfile().statusMessage;
    final controller = TextEditingController(text: currentStatus);

    showResponsiveDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Modifier votre statut',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Votre pensée ou statut',
            border: OutlineInputBorder(),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              profileRepo.updateStatus(controller.text.trim());
              Navigator.of(ctx).pop();
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  void _openDeviceManager(BuildContext context) {
    showResponsiveDialog(
      context: context,
      builder: (ctx) => const DeviceManagerDialog(),
    );
  }

  void _showRecoveryCodeDialog(BuildContext context, String code) {
    final effectiveCode = code.isNotEmpty ? code : 'MRX-7F89-A2B4-9C10-E5D3';
    showResponsiveDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.vpn_key_rounded, color: AppTheme.primary),
            SizedBox(width: 8),
            Text(
              'Code de récupération',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Conservez ce code en lieu sûr. Il vous permet de reconnecter votre identité souveraine et restaurer vos clés cryptographiques sur n\'importe quel appareil sans mot de passe ni serveur central.',
              style: TextStyle(fontSize: 12.5, color: AppTheme.onSurfaceVariant, height: 1.4),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      effectiveCode,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppTheme.primary,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 20, color: AppTheme.primary),
                    tooltip: 'Copier le code',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: effectiveCode));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Code de secours copié dans le presse-papier'),
                          backgroundColor: Color(0xFF0043B8),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileRepo = context.watch<ProfileRepository>();
    final profile = profileRepo.getProfile();
    final devRepo = context.watch<DeviceRepository>();
    final activeDevices = devRepo.getActiveDevices();

    return Scaffold(
      backgroundColor: AppTheme.surfaceWarm,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 90, top: 12),
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Mon Espace',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: AppTheme.onSurface,
                      ),
                    ),
                    Text(
                      'Identité & sécurité souveraine',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.secondaryLight,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.shield_outlined, size: 14, color: AppTheme.secondary),
                      SizedBox(width: 4),
                      Text(
                        '100% Souverain',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // User Identity Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFDFE4ED)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF111C2C).withOpacity(0.04),
                    blurRadius: 14,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => _showChangeAvatarModal(context, profile),
                        child: Stack(
                          children: [
                            AppAvatar(
                              name: profile.displayName,
                              avatarUrl: profile.avatarUrl,
                              radius: 34,
                              isOnline: true,
                              isVerified: true,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0043B8),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                  size: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              profile.displayName,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.onSurface,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          const Icon(Icons.verified, size: 16, color: AppTheme.secondary),
                                        ],
                                      ),
                                      Text(
                                        profile.handle,
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          color: AppTheme.primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(10),
                                    onTap: () => _openEditProfileDialog(context, profile),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primarySoft,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: const Color(0xFFDBEAFE)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: const [
                                          Icon(Icons.edit_outlined, size: 15, color: AppTheme.primary),
                                          SizedBox(width: 4),
                                          Text(
                                            'Modifier',
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            GestureDetector(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => SecurityVerificationScreen(
                                      peerName: profile.displayName,
                                      peerAvatar: profile.avatarUrl,
                                      isVerified: true,
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFECFDF5),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(Icons.qr_code, size: 12, color: Color(0xFF047857)),
                                    SizedBox(width: 4),
                                    Text(
                                      'Compte vérifié Ed25519 (Voir)',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF047857),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Status box (clickable to edit!)
                  GestureDetector(
                    onTap: () => _editStatusDialog(context),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceWarm,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFDFE4ED)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              profile.statusMessage,
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: AppTheme.onSurface,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                          const Icon(Icons.edit, size: 16, color: AppTheme.primary),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Mes Appareils de Confiance Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFDFE4ED)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.devices, size: 20, color: AppTheme.primary),
                          SizedBox(width: 8),
                          Text(
                            'Mes Appareils de Confiance',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primarySoft,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${activeDevices.length} / 3 maximum',
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Display list of active devices
                  ...activeDevices.map((dev) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceWarm,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFDFE4ED)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              dev.iconType == 'laptop'
                                  ? Icons.laptop_mac
                                  : (dev.iconType == 'tablet'
                                      ? Icons.tablet_mac
                                      : Icons.phone_android),
                              size: 20,
                              color: AppTheme.primary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  dev.name,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.onSurface,
                                  ),
                                ),
                                Text(
                                  dev.lastSeenText,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (dev.isCurrentDevice)
                            const Icon(Icons.verified_user, size: 18, color: AppTheme.secondary)
                          else
                            const Icon(Icons.lock, size: 16, color: Colors.grey),
                        ],
                      ),
                    );
                  }),

                  const SizedBox(height: 8),
                  // Manage security button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.surfaceWarm,
                        foregroundColor: AppTheme.primary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Color(0xFFDFE4ED)),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onPressed: () => _openDeviceManager(context),
                      icon: const Icon(Icons.shield, size: 16),
                      label: const Text(
                        'Gérer la sécurité de mes appareils',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Preferences Title
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                'PRÉFÉRENCES D\'ESPACE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: AppTheme.onSurfaceVariant,
                ),
              ),
            ),

            // 1. Numéro de sécurité & Empreintes Ed25519
            _settingsCard(
              icon: Icons.qr_code_scanner,
              iconColor: const Color(0xFF059669),
              title: 'Numéro de sécurité & Empreinte QR',
              subtitle: 'Clés Ed25519 vérifiées de bout en bout',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (ctx) => SecurityVerificationScreen(
                      peerName: profile.displayName,
                      peerAvatar: profile.avatarUrl,
                      isVerified: true,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),

            // 2. Confidentialité & Protection
            _settingsCard(
              icon: Icons.privacy_tip_outlined,
              iconColor: AppTheme.primary,
              title: 'Confidentialité & Protection',
              subtitle: 'Qui peut voir mes moments et mon statut',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Audience des moments : Contacts uniquement')),
                );
              },
            ),
            const SizedBox(height: 8),

            // 2. Notifications & Sons
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFDFE4ED)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppTheme.secondaryLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.notifications_active, color: AppTheme.secondary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Notifications & Sons',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.onSurface,
                          ),
                        ),
                        Text(
                          'Restez averti avec douceur',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: profile.notificationsEnabled,
                    activeColor: AppTheme.secondary,
                    onChanged: (val) {
                      profileRepo.toggleNotifications(val);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // 3. Apparence & Thème
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFDFE4ED)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppTheme.primarySoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.palette_outlined, color: AppTheme.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Apparence & Thème',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.onSurface,
                          ),
                        ),
                        Text(
                          'Ivoire Luminous actuel, option Nuit douce',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      final newMode = profile.themeMode == 'Ivoire' ? 'Nuit' : 'Ivoire';
                      profileRepo.setThemeMode(newMode);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceWarm,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFDFE4ED)),
                      ),
                      child: Text(
                        profile.themeMode,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // 4. Espace de stockage & Documents
            _settingsCard(
              icon: Icons.folder_special_outlined,
              iconColor: const Color(0xFF2B4A93),
              title: 'Espace de stockage & Documents',
              subtitle: '${profile.storageUsed} • Coffre et Médias déchiffrés',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (ctx) => const MediaVaultScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),

            // 5. Code de récupération & Sauvegarde souveraine
            _settingsCard(
              icon: Icons.vpn_key_rounded,
              iconColor: const Color(0xFFD97706),
              title: 'Code de récupération souverain',
              subtitle: 'Afficher et copier votre clé de secours pour reconnexion',
              onTap: () => _showRecoveryCodeDialog(context, profile.recoveryCode ?? ''),
            ),
            const SizedBox(height: 16),

            // Logout / Switch account button
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFDC2626),
                side: const BorderSide(color: Color(0xFFFCA5A5)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => _confirmLogout(context),
              icon: const Icon(Icons.logout, size: 18),
              label: const Text(
                'Déconnexion / Changer de compte',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
            const SizedBox(height: 10),

            // Delete Account button
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF991B1B),
                backgroundColor: const Color(0xFFFEF2F2),
                side: const BorderSide(color: Color(0xFFF87171)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => _confirmDeleteAccount(context),
              icon: const Icon(Icons.delete_forever_rounded, size: 18, color: Color(0xFFDC2626)),
              label: const Text(
                'Supprimer définitivement mon compte',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _settingsCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFDFE4ED)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.onSurface,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
