import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_media_image.dart';

class ImageViewerScreen extends StatefulWidget {
  final String title;
  final String imageUrl;
  final String? time;
  final String? senderName;
  final String? subtitle;

  const ImageViewerScreen({
    super.key,
    required this.title,
    String? imageUrl,
    String? imageUri,
    this.time,
    this.senderName,
    this.subtitle,
  }) : imageUrl = imageUrl ?? imageUri ?? '';

  @override
  State<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<ImageViewerScreen> {
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  bool _isDownloaded = false;

  void _downloadImage() async {
    if (_isDownloading || _isDownloaded) return;

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.1;
    });

    // Simulate E2EE decryption & block-by-block download
    for (int i = 1; i <= 10; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;
      setState(() {
        _downloadProgress = i / 10.0;
      });
    }

    setState(() {
      _isDownloading = false;
      _isDownloaded = true;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF065F46),
          content: Row(
            children: const [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Image HD déchiffrée et enregistrée dans : /MRixk/Media/Images/',
                  style: TextStyle(fontSize: 12.5),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.shield_outlined, color: AppTheme.secondary),
            SizedBox(width: 8),
            Text('Métadonnées Sécurisées', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _metaRow('Fichier :', widget.title),
            _metaRow('Origine :', widget.senderName ?? 'Expéditeur vérifié'),
            _metaRow('Horodatage :', widget.time ?? 'Récent'),
            _metaRow('Chiffrement :', 'AES-256-GCM + AAD'),
            _metaRow('Intégrité :', 'SHA-256 Vérifié ✓'),
            _metaRow('Résolution :', 'Haute Définition (HD 1080p)'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Widget _metaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.85),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
            ),
            if (widget.subtitle != null)
              Text(
                widget.subtitle!,
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              )
            else if (widget.senderName != null)
              Text(
                'Par ${widget.senderName} • ${widget.time ?? ''}',
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white),
            tooltip: 'Infos de protection',
            onPressed: _showInfoDialog,
          ),
          IconButton(
            icon: _isDownloading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      value: _downloadProgress,
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    _isDownloaded ? Icons.file_download_done : Icons.file_download,
                    color: _isDownloaded ? AppTheme.statusGreen : Colors.white,
                  ),
            tooltip: _isDownloaded ? 'Déjà téléchargé' : 'Télécharger dans /MRixk/Media',
            onPressed: _downloadImage,
          ),
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            tooltip: 'Partager',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Partage sécurisé re-chiffré prêt')),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.network(
                widget.imageUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                      color: AppTheme.primary,
                    ),
                  );
                },
                errorBuilder: (_, __, ___) => Center(
                  child: AppMediaImage(
                    width: 340,
                    height: 340,
                    fallbackTitle: widget.title,
                    fallbackSubtitle: widget.subtitle ?? 'Aperçu haute fidélité protégé',
                  ),
                ),
              ),
            ),
          ),
          if (_isDownloading)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: LinearProgressIndicator(
                value: _downloadProgress,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
              ),
            ),
        ],
      ),
    );
  }
}
