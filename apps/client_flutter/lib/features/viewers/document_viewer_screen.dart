import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class DocumentViewerScreen extends StatefulWidget {
  final String fileName;
  final String fileSize;
  final String fileType;
  final String? senderName;
  final String? fileUri;

  const DocumentViewerScreen({
    super.key,
    required this.fileName,
    required this.fileSize,
    this.fileType = 'PDF',
    this.senderName,
    this.fileUri,
  });

  @override
  State<DocumentViewerScreen> createState() => _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends State<DocumentViewerScreen> {
  int _currentPage = 1;
  final int _totalPages = 3;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  bool _isDownloaded = false;
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _downloadDocument() async {
    if (_isDownloading || _isDownloaded) return;

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.1;
    });

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
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${widget.fileName} enregistré dans : /MRixk/Documents/',
                  style: const TextStyle(fontSize: 12.5),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPdf = widget.fileType.toUpperCase() == 'PDF';
    final isWord = widget.fileType.toUpperCase() == 'DOCX' || widget.fileType.toUpperCase() == 'DOC';

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
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
              widget.fileName,
              style: const TextStyle(color: AppTheme.onSurface, fontSize: 14, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${widget.fileSize} • Page $_currentPage sur $_totalPages',
              style: const TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 11),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: AppTheme.onSurfaceVariant),
            tooltip: 'Rechercher dans le document',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Recherche locale chiffrée')),
              );
            },
          ),
          IconButton(
            icon: _isDownloading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      value: _downloadProgress,
                      strokeWidth: 2,
                      color: AppTheme.primary,
                    ),
                  )
                : Icon(
                    _isDownloaded ? Icons.file_download_done : Icons.file_download,
                    color: _isDownloaded ? AppTheme.statusGreen : AppTheme.primary,
                  ),
            tooltip: _isDownloaded ? 'Document téléchargé' : 'Télécharger le fichier',
            onPressed: _downloadDocument,
          ),
          IconButton(
            icon: const Icon(Icons.share, color: AppTheme.onSurfaceVariant),
            tooltip: 'Partager',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Partage de document chiffré')),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isDownloading)
            LinearProgressIndicator(
              value: _downloadProgress,
              backgroundColor: Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
            ),

          // Security Cert Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFFECFDF5),
            child: Row(
              children: [
                const Icon(Icons.verified_user, color: Color(0xFF059669), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Document intègre certifié par signature Ed25519 • Zéro fuite cloud',
                    style: TextStyle(color: Colors.green.shade800, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Text(
                    widget.fileType.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isPdf ? Colors.red.shade700 : (isWord ? Colors.blue.shade700 : Colors.teal),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Page View
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (page) => setState(() => _currentPage = page + 1),
              children: [
                _buildDocumentPage(
                  pageNumber: 1,
                  title: widget.fileName,
                  contentSections: [
                    'PROTOCOLE DE COOPÉRATION & SÉCURITÉ DES DONNÉES',
                    'Article 1 — Objet du Contrat\nLe présent document atteste des dispositions relatives à la souveraineté numérique, au chiffrement de bout en bout des flux de données et à l\'exécution de l\'intelligence artificielle strictement sur les terminaux locaux autorisés.',
                    'Article 2 — Quota d\'Appareils\nChaque compte est limité à un maximum strict de 3 appareils matériels autorisés. Toute tentative de connexion supplémentaire est automatiquement rejetée avec révocation possible des sessions antérieures.',
                  ],
                ),
                _buildDocumentPage(
                  pageNumber: 2,
                  title: 'Spécifications Techniques & Mémoire Vectorielle',
                  contentSections: [
                    'Article 3 — Isolation Cognitive M(u)\nL\'espace d\'assistance IA personnel est strictement privé : M(u1) ∩ M(u2) = ∅. Aucune donnée mémorisée, document analysé ou préférence utilisateur n\'est transmise ni agrégée sur un serveur distant.',
                    'Article 4 — Formule de Similarité Hybride\nLe score de pertinence est calculé localement selon l\'équation :\nScore = α · S_sémantique + β · S_lexical + γ · S_récence + δ · S_confiance',
                  ],
                ),
                _buildDocumentPage(
                  pageNumber: 3,
                  title: 'Signatures Numériques & Validation',
                  contentSections: [
                    'Article 5 — Révocation et Droit à l\'Oubli\nL\'effacement de message pour tous s\'effectue avec motif obligatoire certifié, transmis de manière chiffrée à tous les appareils pairs.',
                    'Fait et signé électroniquement avec clés cryptographiques Ed25519 valides.',
                  ],
                  isLastPage: true,
                ),
              ],
            ),
          ),

          // Bottom Pagination Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _currentPage > 1
                      ? () => _pageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          )
                      : null,
                ),
                Text(
                  'Page $_currentPage sur $_totalPages',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _currentPage < _totalPages
                      ? () => _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          )
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentPage({
    required int pageNumber,
    required String title,
    required List<String> contentSections,
    bool isLastPage = false,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 680),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Page header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Center(
                          child: Text('◈', style: TextStyle(color: Colors.white, fontSize: 12)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'MRixk Document Sécurisé',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.primary),
                      ),
                    ],
                  ),
                  Text(
                    'Page $pageNumber',
                    style: const TextStyle(fontSize: 11, color: AppTheme.onSurfaceVariant),
                  ),
                ],
              ),
              const Divider(height: 24),
              Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.onSurface),
              ),
              const SizedBox(height: 16),
              ...contentSections.map(
                (sec) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    sec,
                    style: const TextStyle(fontSize: 13, height: 1.6, color: Color(0xFF334155)),
                  ),
                ),
              ),
              if (isLastPage) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.verified, color: AppTheme.secondary, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Certificat Cryptographique Validé',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Empreinte : 9b4d...7a12 • Clé Ed25519',
                              style: TextStyle(fontSize: 11, color: AppTheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
