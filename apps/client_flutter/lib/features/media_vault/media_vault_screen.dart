import 'package:flutter/material.dart';
import '../../core/models/conversation.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../viewers/document_viewer_screen.dart';
import '../viewers/image_viewer_screen.dart';
import '../viewers/video_player_screen.dart';
import '../discussions/widgets/audio_player_widget.dart';

class MediaVaultScreen extends StatefulWidget {
  final Conversation? conversation;

  const MediaVaultScreen({
    super.key,
    this.conversation,
  });

  @override
  State<MediaVaultScreen> createState() => _MediaVaultScreenState();
}

class _MediaVaultScreenState extends State<MediaVaultScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<Map<String, String>> _photosAndVideos = [];
  final List<Map<String, String>> _documents = [];
  final List<Map<String, String>> _audios = [];
  final List<Map<String, String>> _vaultItems = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.conversation != null
        ? 'Médias de ${widget.conversation!.title}'
        : 'Dossier Médias & Coffre';

    return Scaffold(
      backgroundColor: AppTheme.surfaceWarm,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.onSurface),
            ),
            const Text(
              'Stockage local chiffré • Zéro fuite cloud',
              style: TextStyle(fontSize: 11, color: AppTheme.onSurfaceVariant),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.onSurfaceVariant,
          indicatorColor: AppTheme.primary,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Médias (Photos/Vidéos)'),
            Tab(text: 'Documents (PDF/DOC)'),
            Tab(text: 'Audios'),
            Tab(text: 'Coffre-fort Personnel'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMediaTab(),
          _buildDocumentsTab(),
          _buildAudiosTab(),
          _buildVaultTab(),
        ],
      ),
    );
  }

  Widget _buildMediaTab() {
    if (_photosAndVideos.isEmpty) {
      return const AppEmptyState(
        icon: Icons.photo_library_outlined,
        title: 'Aucune photo ni vidéo',
        message: 'Les photos et vidéos partagées dans vos conversations apparaîtront ici.',
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _photosAndVideos.length,
      itemBuilder: (context, idx) {
        final item = _photosAndVideos[idx];
        final isVideo = item['type'] == 'video';

        return GestureDetector(
          onTap: () {
            if (isVideo) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (ctx) => VideoPlayerScreen(
                    title: item['title']!,
                    duration: item['duration'] ?? '1:45',
                    senderName: item['sender'],
                  ),
                ),
              );
            } else {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (ctx) => ImageViewerScreen(
                    title: item['title']!,
                    imageUrl: item['url']!,
                    time: item['date'],
                    senderName: item['sender'],
                  ),
                ),
              );
            }
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (!isVideo && item['url']!.isNotEmpty)
                  Image.network(
                    item['url']!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.grey.shade300,
                      child: const Icon(Icons.image, color: Colors.grey),
                    ),
                  )
                else
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        isVideo ? Icons.play_circle_fill : Icons.image,
                        color: Colors.white70,
                        size: 36,
                      ),
                    ),
                  ),

                // Video duration badge or HD badge
                Positioned(
                  bottom: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isVideo) ...[
                          const Icon(Icons.play_arrow, color: Colors.white, size: 10),
                          const SizedBox(width: 2),
                          Text(
                            item['duration'] ?? '1:00',
                            style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                          ),
                        ] else ...[
                          const Text(
                            'HD',
                            style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDocumentsTab() {
    if (_documents.isEmpty) {
      return const AppEmptyState(
        icon: Icons.folder_open_rounded,
        title: 'Aucun document partagé',
        message: 'Les documents PDF, contrats et fichiers échangés apparaîtront ici.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _documents.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, idx) {
        final doc = _documents[idx];
        final isPdf = doc['type'] == 'PDF';
        final isDocx = doc['type'] == 'DOCX';

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFDFE4ED)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF111C2C).withOpacity(0.02),
                blurRadius: 8,
              ),
            ],
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => _openDoc(doc),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isPdf
                        ? const Color(0xFFFEF2F2)
                        : (isDocx ? const Color(0xFFEFF6FF) : const Color(0xFFECFDF5)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      doc['type']!,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: isPdf
                            ? const Color(0xFFDC2626)
                            : (isDocx ? const Color(0xFF2563EB) : const Color(0xFF059669)),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => _openDoc(doc),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doc['title']!,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${doc['size']} • ${doc['date']}',
                        style: const TextStyle(fontSize: 11, color: AppTheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.file_download, color: AppTheme.primary, size: 22),
                tooltip: 'Télécharger',
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${doc['title']} téléchargé dans /MRixk/Documents/'),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _openDoc(Map<String, String> doc) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => DocumentViewerScreen(
          fileName: doc['title']!,
          fileSize: doc['size']!,
          fileType: doc['type']!,
          senderName: doc['sender'],
        ),
      ),
    );
  }

  Widget _buildAudiosTab() {
    if (_audios.isEmpty) {
      return const AppEmptyState(
        icon: Icons.graphic_eq_rounded,
        title: 'Aucun fichier audio',
        message: 'Les notes vocales et fichiers audio partagés apparaîtront ici.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _audios.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, idx) {
        final audio = _audios[idx];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFDFE4ED)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    audio['title']!,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  Text(
                    audio['date']!,
                    style: const TextStyle(fontSize: 11, color: AppTheme.onSurfaceVariant),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              AudioPlayerWidget(duration: audio['duration'] ?? '0:42'),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVaultTab() {
    if (_vaultItems.isEmpty) {
      return const AppEmptyState(
        icon: Icons.lock_outline_rounded,
        title: 'Coffre-fort vide',
        message: 'Aucun élément hautement sécurisé n\'est stocké pour le moment.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _vaultItems.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, idx) {
        final item = _vaultItems[idx];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFDFE4ED)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.secondaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.shield, color: AppTheme.secondary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['title']!,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${item['size']} • ${item['status']}',
                      style: const TextStyle(fontSize: 11, color: AppTheme.secondary),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.lock_open, color: AppTheme.primary, size: 20),
                tooltip: 'Déverrouiller avec clé',
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Déverrouillage local sécurisé : ${item['title']}'),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
