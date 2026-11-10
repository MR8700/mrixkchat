import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Exquisite, high-definition sovereign Avatar widget conforming to Google Stitch design.
/// 100% resilient offline: if network image fails or is unreachable, renders a luminous
/// gradient background tailored to the user's name with crisp bold initials and verified badge.
class AppAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String name;
  final double radius;
  final bool isOnline;
  final bool isVerified;
  final bool showBadge;
  final bool isClickable;
  final VoidCallback? onTap;

  const AppAvatar({
    super.key,
    required this.name,
    this.avatarUrl,
    this.radius = 20,
    this.isOnline = false,
    this.isVerified = false,
    this.showBadge = true,
    this.isClickable = true,
    this.onTap,
  });

  String get _initials {
    final clean = name.trim();
    if (clean.isEmpty) return 'M';
    final parts = clean.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return clean.substring(0, clean.length >= 2 ? 2 : 1).toUpperCase();
  }

  List<Color> _getGradientForName(String str) {
    final hash = str.codeUnits.fold(0, (acc, c) => acc + c);
    final palettes = [
      [const Color(0xFF0043B8), const Color(0xFF245BDB)], // Sapphire / Electric Azure
      [const Color(0xFF006B5F), const Color(0xFF20B8A5)], // Deep Mineral Turquoise / Mint
      [const Color(0xFF6366F1), const Color(0xFF8B5CF6)], // Indigo / Violet
      [const Color(0xFFE11D48), const Color(0xFFFB7185)], // Rose / Coral
      [const Color(0xFFD97706), const Color(0xFFFBBF24)], // Amber / Gold
      [const Color(0xFF059669), const Color(0xFF34D399)], // Emerald / Jade
    ];
    return palettes[hash % palettes.length];
  }

  @override
  Widget build(BuildContext context) {
    final gradient = _getGradientForName(name);

    final avatarWidget = Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: radius * 2,
          height: radius * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: gradient.first.withOpacity(0.25),
                blurRadius: radius > 24 ? 12 : 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipOval(
            child: (avatarUrl != null &&
                    avatarUrl!.isNotEmpty &&
                    !avatarUrl!.startsWith('http'))
                ? Image.asset(
                    avatarUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildInitials(),
                  )
                : (avatarUrl != null && avatarUrl!.startsWith('http'))
                    ? Image.network(
                        avatarUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildInitials(),
                        loadingBuilder: (_, child, progress) {
                          if (progress == null) return child;
                          return _buildInitials();
                        },
                      )
                    : _buildInitials(),
          ),
        ),
        if (isOnline && showBadge)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: radius * 0.44,
              height: radius * 0.44,
              decoration: BoxDecoration(
                color: AppTheme.statusGreen,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: radius > 20 ? 2 : 1.5),
              ),
            ),
          ),
        if (isVerified && showBadge)
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(1.5),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: AppTheme.secondary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check,
                  size: radius * 0.35,
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );

    if (!isClickable) return avatarWidget;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap ?? () => _showEnlargedAvatarDialog(context),
        child: avatarWidget,
      ),
    );
  }

  void _showEnlargedAvatarDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.75),
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with close button
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                    onPressed: () => Navigator.of(ctx).pop(),
                    tooltip: 'Fermer',
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Enlarged Avatar Card
              Container(
                width: 320,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: const Color(0xFF334155), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppAvatar(
                      name: name,
                      avatarUrl: avatarUrl,
                      radius: 90,
                      isOnline: isOnline,
                      isVerified: isVerified,
                      isClickable: false,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: isOnline
                            ? const Color(0xFF059669).withOpacity(0.2)
                            : Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isOnline
                              ? const Color(0xFF10B981)
                              : Colors.white.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: isOnline ? const Color(0xFF10B981) : Colors.grey,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              isOnline ? 'En ligne • Profil vérifié' : 'Hors ligne • Protégé',
                              style: TextStyle(
                                fontSize: 12,
                                color: isOnline ? const Color(0xFF34D399) : Colors.white70,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInitials() {
    return Center(
      child: Text(
        _initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: radius * 0.76,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
      ),
    );
  }
}

/// Official MRixk Sovereign Emblem Logo conforming to Stitch specifications.
/// The name "M • R • I • X • K" is rendered circularly around the sovereign diamond icon.
class MRixkLogo extends StatelessWidget {
  final double size;
  const MRixkLogo({super.key, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFF003799), Color(0xFF1E40AF), Color(0xFF0043B8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0043B8).withOpacity(0.35),
            blurRadius: size * 0.25,
            offset: Offset(0, size * 0.08),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Circular Text: M • R • I • X • K
          CustomPaint(
            size: Size(size, size),
            painter: _CircularTextPainter(
              text: '• M • R • I • X • K ',
              radius: size * 0.38,
              fontSize: (size * 0.12).clamp(5.0, 14.0),
            ),
          ),
          // Inner sovereign badge ring
          Container(
            width: size * 0.52,
            height: size * 0.52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF0A1530).withOpacity(0.85),
              border: Border.all(color: const Color(0xFF20B8A5).withOpacity(0.5), width: 1),
            ),
          ),
          // Sovereign Diamond Lattice
          Transform.rotate(
            angle: 0.785398, // 45 degrees
            child: Container(
              width: size * 0.26,
              height: size * 0.26,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 1.8),
                borderRadius: BorderRadius.circular(size * 0.04),
              ),
            ),
          ),
          // Central core node
          Container(
            width: size * 0.12,
            height: size * 0.12,
            decoration: const BoxDecoration(
              color: Color(0xFF20B8A5), // Mint Green Sovereign node
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

class _CircularTextPainter extends CustomPainter {
  final String text;
  final double radius;
  final double fontSize;

  _CircularTextPainter({
    required this.text,
    required this.radius,
    required this.fontSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final count = text.length;
    final angleStep = (2 * 3.141592653589793) / count;

    for (int i = 0; i < count; i++) {
      final char = text[i];
      // Angle starting at top (-pi / 2)
      final angle = -1.5707963267948966 + (i * angleStep);

      final textSpan = TextSpan(
        text: char,
        style: TextStyle(
          color: char == '•' ? const Color(0xFF20B8A5) : Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          fontFamily: 'monospace',
          letterSpacing: 0,
        ),
      );

      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(angle);
      canvas.translate(0, -radius);
      textPainter.paint(
        canvas,
        Offset(-textPainter.width / 2, -textPainter.height / 2),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _CircularTextPainter oldDelegate) =>
      oldDelegate.text != text || oldDelegate.radius != radius;
}
