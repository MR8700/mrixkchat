import 'package:flutter/material.dart';
import '../../core/models/conversation.dart';
import '../../core/theme/app_theme.dart';

class SecurityVerificationScreen extends StatefulWidget {
  final Conversation? conversation;
  final String peerName;
  final String peerAvatar;
  final bool isVerified;

  const SecurityVerificationScreen({
    super.key,
    this.conversation,
    this.peerName = 'Contact',
    this.peerAvatar = '',
    this.isVerified = false,
  });

  @override
  State<SecurityVerificationScreen> createState() => _SecurityVerificationScreenState();
}

class _SecurityVerificationScreenState extends State<SecurityVerificationScreen> {
  late bool _isManuallyVerified;

  String get _effectivePeerName => widget.conversation?.title ?? widget.peerName;

  @override
  void initState() {
    super.initState();
    _isManuallyVerified = widget.conversation?.isVerified ?? widget.isVerified;
  }

  final String _safetyNumber =
      '38492 10482 95821 02948\n'
      '57391 84920 19485 72940\n'
      '48291 04829 19485 82910';

  @override
  Widget build(BuildContext context) {
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
          'Numéro de sécurité',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.onSurface),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // QR Code container
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFDFE4ED)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF111C2C).withOpacity(0.04),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const Icon(Icons.qr_code_2, size: 160, color: Color(0xFF1E293B)),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.lock, size: 22, color: AppTheme.primary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('Empreinte QR', style: TextStyle(fontSize: 11, color: AppTheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Text(
                    _safetyNumber,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      height: 1.6,
                      color: AppTheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Instructions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_user, color: Color(0xFF059669), size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Pour vérifier le chiffrement de bout en bout avec $_effectivePeerName, comparez ce numéro avec son appareil ou scannez le code QR.',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF065F46), height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Verification Switch
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFDFE4ED)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Marquer ce contact comme vérifié',
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Clé Ed25519 validée physiquement',
                          style: TextStyle(fontSize: 11, color: AppTheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isManuallyVerified,
                    activeColor: AppTheme.statusGreen,
                    onChanged: (val) {
                      setState(() => _isManuallyVerified = val);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(val ? 'Contact marqué comme vérifié' : 'Vérification désactivée'),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
