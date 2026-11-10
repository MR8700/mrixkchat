import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/repositories/profile_repository.dart';
import '../../core/services/identity_directory_service.dart';
import '../../core/services/real_media_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_avatar.dart';
import '../../shared/widgets/responsive_scaffold.dart';

class IdentitySetupScreen extends StatefulWidget {
  const IdentitySetupScreen({super.key});

  @override
  State<IdentitySetupScreen> createState() => _IdentitySetupScreenState();
}

class _IdentitySetupScreenState extends State<IdentitySetupScreen> {
  bool _isRecoveryMode = false;

  // Create mode controllers
  final _nameController = TextEditingController();
  final _handleController = TextEditingController();
  final _statusController = TextEditingController(text: 'Disponible sur MRixk');

  // Recovery mode controllers
  final _recoveryCodeController = TextEditingController();
  final _recoveryNameController = TextEditingController();

  String? _avatarUrl;
  bool _isHandleCustomized = false;
  String? _errorMessage;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _handleController.dispose();
    _statusController.dispose();
    _recoveryCodeController.dispose();
    _recoveryNameController.dispose();
    super.dispose();
  }

  void _onNameChanged(String val) {
    if (!_isHandleCustomized) {
      final clean = val.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '.');
      setState(() {
        _handleController.text = clean.isNotEmpty ? '@$clean' : '';
      });
    }
  }

  Future<void> _pickAvatar() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Photo de profil',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: AppTheme.primary),
                title: const Text('Appareil photo / Prendre une photo'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final photo = await RealMediaService.instance.captureCameraPhoto();
                  if (photo != null && photo.isNotEmpty && mounted) {
                    setState(() => _avatarUrl = photo);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: Color(0xFF10B981)),
                title: const Text('Choisir depuis l\'appareil'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final photo = await RealMediaService.instance.pickMediaFile(isVideo: false);
                  if (photo != null && photo.isNotEmpty && mounted) {
                    setState(() => _avatarUrl = photo);
                  }
                },
              ),
              if (_avatarUrl != null)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  title: const Text('Supprimer la photo actuelle'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    setState(() => _avatarUrl = null);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitIdentity() async {
    final name = _nameController.text.trim();
    var handle = _handleController.text.trim();

    if (name.isEmpty) {
      setState(() => _errorMessage = 'Veuillez saisir votre nom ou pseudo.');
      return;
    }

    if (handle.isEmpty) {
      final clean = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '.');
      handle = '@$clean';
    }

    if (!handle.startsWith('@')) {
      handle = '@$handle';
    }

    // Check handle collision against directory
    final existingUser = IdentityDirectoryService.findUser(handle);
    if (existingUser != null) {
      setState(() => _errorMessage = 'Cet identifiant est déjà utilisé. Veuillez en choisir un autre.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final profileRepo = context.read<ProfileRepository>();
    final profile = await profileRepo.saveInitialIdentity(
      displayName: name,
      handle: handle,
      avatarUrl: _avatarUrl,
      statusMessage: _statusController.text.trim(),
    );

    if (mounted) {
      if (profile.recoveryCode != null && profile.recoveryCode!.isNotEmpty) {
        await _showCreatedRecoveryCodeDialog(context, profile.recoveryCode!);
      }
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ResponsiveScaffold()),
        );
      }
    }
  }

  Future<void> _showCreatedRecoveryCodeDialog(BuildContext context, String code) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: const [
            Icon(Icons.key_rounded, color: AppTheme.primary, size: 24),
            SizedBox(width: 10),
            Text('Votre code de secours', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Conservez précieusement ce code unique. Il vous permettra de vous reconnecter sur n\'importe quel autre terminal en toute souveraineté.',
              style: TextStyle(fontSize: 13, height: 1.4, color: AppTheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: SelectableText(
                code,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                  letterSpacing: 1.2,
                  color: AppTheme.primary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: code));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Code copié dans le presse-papier')),
                  );
                },
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text('Copier le code'),
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
            child: const Text('J\'ai noté mon code'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitRecovery() async {
    final code = _recoveryCodeController.text.trim();
    if (code.isEmpty) {
      setState(() => _errorMessage = 'Veuillez saisir votre code de récupération ou de reconnexion.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final profileRepo = context.read<ProfileRepository>();
    final profile = await profileRepo.restoreFromRecoveryCode(
      recoveryCode: code,
      preferredName: _recoveryNameController.text.trim(),
    );

    if (profile != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Identité souveraine restaurée : ${profile.displayName}'),
          backgroundColor: AppTheme.primary,
        ),
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ResponsiveScaffold()),
      );
    } else if (mounted) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Code invalide. Veuillez vérifier le format (ex: MRX-XXXX-XXXX...)';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // App Emblem
                  const MRixkLogo(size: 76),
                  const SizedBox(height: 18),

                  // Mode Switcher (Créer / Récupérer)
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.all(3.5),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() {
                              _isRecoveryMode = false;
                              _errorMessage = null;
                            }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: !_isRecoveryMode ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(11),
                                boxShadow: !_isRecoveryMode
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.06),
                                          blurRadius: 4,
                                          offset: const Offset(0, 1),
                                        )
                                      ]
                                    : null,
                              ),
                              child: Center(
                                child: Text(
                                  'Créer une identité',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: !_isRecoveryMode ? AppTheme.primary : AppTheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() {
                              _isRecoveryMode = true;
                              _errorMessage = null;
                            }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: _isRecoveryMode ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(11),
                                boxShadow: _isRecoveryMode
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.06),
                                          blurRadius: 4,
                                          offset: const Offset(0, 1),
                                        )
                                      ]
                                    : null,
                              ),
                              child: Center(
                                child: Text(
                                  'Code de secours',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: _isRecoveryMode ? AppTheme.primary : AppTheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  if (!_isRecoveryMode) ...[
                    // --- CREATION MODE ---
                    const Text(
                      'Créez votre identité',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.onSurface,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Définissez votre nom et identifiant unique pour échanger en toute souveraineté sur MRixk.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppTheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 22),

                    // Avatar selector
                    GestureDetector(
                      onTap: _pickAvatar,
                      child: Stack(
                        children: [
                          AppAvatar(
                            name: _nameController.text.isNotEmpty ? _nameController.text : 'M',
                            avatarUrl: _avatarUrl,
                            radius: 44,
                            showBadge: false,
                            isClickable: false,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: AppTheme.primary,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.18),
                                    blurRadius: 5,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                size: 15,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextButton(
                      onPressed: _pickAvatar,
                      child: Text(
                        _avatarUrl != null ? 'Modifier la photo' : 'Ajouter une photo',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Creation Form Fields Card
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
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
                          const Text(
                            'Votre nom ou pseudo *',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.onSurface),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _nameController,
                            onChanged: _onNameChanged,
                            decoration: InputDecoration(
                              hintText: 'Ex: Alex, Sam, Camille...',
                              prefixIcon: const Icon(Icons.person_outline, size: 20),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          const Text(
                            'Identifiant unique *',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.onSurface),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _handleController,
                            onChanged: (val) => _isHandleCustomized = true,
                            decoration: InputDecoration(
                              hintText: '@votre.identifiant',
                              prefixIcon: const Icon(Icons.alternate_email, size: 18),
                              helperText: 'Permet à vos proches de vous contacter directement.',
                              helperStyle: const TextStyle(fontSize: 11),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          const Text(
                            'Statut personnel',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.onSurface),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _statusController,
                            decoration: InputDecoration(
                              hintText: 'Ex: Disponible sur MRixk',
                              prefixIcon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                              ),
                            ),
                          ),

                          if (_errorMessage != null) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(Icons.error_outline, color: Colors.redAccent, size: 16),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Privacy Shield
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.shield_outlined, color: Color(0xFF047857), size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Vos clés souveraines sont générées et stockées uniquement sur cet appareil.',
                              style: TextStyle(fontSize: 11.5, color: Color(0xFF065F46)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submitIdentity,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Text(
                                    'Commencer sur MRixk',
                                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
                                  ),
                                  SizedBox(width: 8),
                                  Icon(Icons.arrow_forward_rounded, size: 18),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextButton.icon(
                      onPressed: () => setState(() {
                        _isRecoveryMode = true;
                        _errorMessage = null;
                      }),
                      icon: const Icon(Icons.key_rounded, size: 16),
                      label: const Text(
                        'Déjà un compte ? Saisir un code de récupération',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ] else ...[
                    // --- RECOVERY / RECONNECTION MODE ---
                    const Text(
                      'Reconnexion au compte',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.onSurface,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Saisissez votre code de secours ou de reconnexion pour restaurer votre identité et vos clés sur cet appareil.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppTheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 22),

                    // Recovery Form Card
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
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
                          const Text(
                            'Code de récupération ou de reconnexion *',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.onSurface),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _recoveryCodeController,
                            textCapitalization: TextCapitalization.characters,
                            decoration: InputDecoration(
                              hintText: 'Ex: MRX-8F2A-3D9C-47E1-B05F',
                              prefixIcon: const Icon(Icons.vpn_key_rounded, size: 20),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.paste_rounded, size: 20),
                                tooltip: 'Coller depuis le presse-papier',
                                onPressed: () async {
                                  final data = await Clipboard.getData('text/plain');
                                  if (data != null && data.text != null) {
                                    _recoveryCodeController.text = data.text!.trim().toUpperCase();
                                  }
                                },
                              ),
                              helperText: 'Format: MRX-XXXX-XXXX... ou phrase de récupération.',
                              helperStyle: const TextStyle(fontSize: 11),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          const Text(
                            'Nom ou identifiant (facultatif)',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.onSurface),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _recoveryNameController,
                            decoration: InputDecoration(
                              hintText: 'Ex: Alex ou @alex.pro',
                              prefixIcon: const Icon(Icons.person_outline, size: 20),
                              helperText: 'Permet de personnaliser l\'affichage sur ce terminal.',
                              helperStyle: const TextStyle(fontSize: 11),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                              ),
                            ),
                          ),

                          if (_errorMessage != null) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(Icons.error_outline, color: Colors.redAccent, size: 16),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Security Guarantee
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.lock_outline, color: AppTheme.primary, size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Votre clé souveraine sera restaurée et chiffrée uniquement sur cet appareil.',
                              style: TextStyle(fontSize: 11.5, color: Color(0xFF1E3A8A)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Restore Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _submitRecovery,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: _isLoading
                            ? const SizedBox.shrink()
                            : const Icon(Icons.login_rounded, size: 18),
                        label: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text(
                                'Restaurer mon compte & Se connecter',
                                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextButton.icon(
                      onPressed: () => setState(() {
                        _isRecoveryMode = false;
                        _errorMessage = null;
                      }),
                      icon: const Icon(Icons.arrow_back_rounded, size: 16),
                      label: const Text(
                        'Retour : Créer une nouvelle identité',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
