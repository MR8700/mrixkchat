import 'package:flutter/material.dart';
import '../../core/models/conversation.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_avatar.dart';
import '../media_vault/media_vault_screen.dart';
import '../security/security_verification_screen.dart';

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
  bool _isMuted = false;
  String _ephemeralTimer = 'Désactivé';

  @override
  Widget build(BuildContext context) {
    final conv = widget.conversation;

    return Scaffold(
      backgroundColor: AppTheme.surfaceWarm,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Détails de la conversation',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.onSurface),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: AppTheme.primary),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Partage de contact sécurisé : ${conv.title}')),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFDFE4ED)),
            ),
            child: Column(
              children: [
                AppAvatar(
                  name: conv.title,
                  avatarUrl: conv.peerAvatar,
                  radius: 42,
                  isVerified: conv.isVerified,
                  isOnline: conv.isOnline,
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      conv.title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.onSurface),
                    ),
                    if (conv.isVerified) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.verified, size: 18, color: AppTheme.secondary),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  conv.isGroup ? '${conv.groupMembersCount} membres sécurisés' : '@${conv.title.toLowerCase().replaceAll(' ', '.')}',
                  style: const TextStyle(fontSize: 13, color: AppTheme.primary, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
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
                      const Text(
                        'Session Sécurisée Établie',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Shared Media & Documents Shortcut
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
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
                    builder: (ctx) => MediaVaultScreen(conversation: conv),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),

          // Security & Safety Numbers Section
          Container(
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
                const Text(
                  'Les messages et appels échangés avec ce contact sont protégés par échange de clés X25519 et signés Ed25519.',
                  style: TextStyle(fontSize: 11.5, color: AppTheme.onSurfaceVariant, height: 1.4),
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
                          builder: (ctx) => SecurityVerificationScreen(conversation: conv),
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
          ),
          const SizedBox(height: 14),

          // Options & Settings
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFDFE4ED)),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Mode silencieux', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  subtitle: const Text('Couper les notifications pour ce contact', style: TextStyle(fontSize: 11)),
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
                    showModalBottomSheet(
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
                  leading: const Icon(Icons.delete_sweep, color: Color(0xFFEF4444)),
                  title: const Text('Effacer le contenu de la discussion', style: TextStyle(fontSize: 13, color: Color(0xFFEF4444))),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Historique local effacé')),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
