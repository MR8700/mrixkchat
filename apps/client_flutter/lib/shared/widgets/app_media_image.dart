import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Sovereign, offline-resilient Media Image widget conforming to Google Stitch design.
/// Displays network photos when available; if offline or SSL fails in sandbox,
/// displays an exquisite, high-fidelity encrypted photocard with geometric aperture,
/// metadata tags, and glowing lens badge.
class AppMediaImage extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final String fallbackTitle;
  final String? fallbackSubtitle;
  final bool showBadge;

  const AppMediaImage({
    super.key,
    this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.fallbackTitle = 'Cliché Haute Définition',
    this.fallbackSubtitle = 'Format original • Protégé',
    this.showBadge = true,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = borderRadius ?? BorderRadius.circular(16);

    Widget content;
    if (imageUrl != null && imageUrl!.startsWith('data:image/')) {
      try {
        final commaIdx = imageUrl!.indexOf(',');
        final base64Str = commaIdx != -1 ? imageUrl!.substring(commaIdx + 1) : imageUrl!;
        final bytes = base64Decode(base64Str);
        content = Image.memory(
          bytes,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (context, error, stackTrace) => _buildOfflinePhotocard(),
        );
      } catch (_) {
        content = _buildOfflinePhotocard();
      }
    } else if (imageUrl != null && (imageUrl!.startsWith('assets/') || imageUrl!.startsWith('images/'))) {
      content = Image.asset(
        imageUrl!,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => _buildOfflinePhotocard(),
      );
    } else if (imageUrl != null && (imageUrl!.startsWith('http://') || imageUrl!.startsWith('https://'))) {
      content = Image.network(
        imageUrl!,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => _buildOfflinePhotocard(),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildLoadingState(loadingProgress);
        },
      );
    } else if (imageUrl != null && imageUrl!.isNotEmpty) {
      content = Image.network(
        imageUrl!.startsWith('/') ? imageUrl! : '/$imageUrl',
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => _buildOfflinePhotocard(),
      );
    } else {
      content = _buildOfflinePhotocard();
    }

    return ClipRRect(
      borderRadius: effectiveRadius,
      child: content,
    );
  }

  Widget _buildLoadingState(ImageChunkEvent loadingProgress) {
    final progress = loadingProgress.expectedTotalBytes != null
        ? loadingProgress.cumulativeBytesLoaded /
            loadingProgress.expectedTotalBytes!
        : null;

    return Container(
      width: width,
      height: height,
      color: const Color(0xFF0F172A),
      child: Center(
        child: SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(
            value: progress,
            strokeWidth: 2.5,
            color: AppTheme.secondary,
          ),
        ),
      ),
    );
  }

  Widget _buildOfflinePhotocard() {
    return Container(
      width: width,
      height: height ?? 200,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF0A1128),
            Color(0xFF101F42),
            Color(0xFF003899),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Geometric aperture rings overlay
          Positioned.fill(
            child: CustomPaint(
              painter: _PhotocardPatternPainter(),
            ),
          ),

          // Central photographic emblem
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0043B8), Color(0xFF20B8A5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF20B8A5).withOpacity(0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.camera_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                fallbackTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13.5,
                  letterSpacing: 0.3,
                ),
                textAlign: TextAlign.center,
              ),
              if (fallbackSubtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  fallbackSubtitle!,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.75),
                    fontSize: 11,
                    letterSpacing: 0.2,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),

          // Top badge: Security & High Definition
          if (showBadge)
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.lock, size: 11, color: AppTheme.secondaryGlow),
                    SizedBox(width: 4),
                    Text(
                      'Qualité HD',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Bottom badge: MRixk Secure
          if (showBadge)
            Positioned(
              bottom: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF0043B8).withOpacity(0.7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Espace Sécurisé',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PhotocardPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final center = Offset(size.width / 2, size.height / 2);
    // Draw subtle concentric circles
    canvas.drawCircle(center, 40, paint);
    canvas.drawCircle(center, 75, paint);
    canvas.drawCircle(center, 120, paint);

    // Subtle diagonal cross lines
    canvas.drawLine(const Offset(0, 0), Offset(size.width, size.height), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(0, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
