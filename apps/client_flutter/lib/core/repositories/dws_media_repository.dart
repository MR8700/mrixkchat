import 'package:flutter/foundation.dart';
import '../database/local_database.dart';
import '../models/dws_media.dart';

/// Repository managing sovereign multimedia assets within the MRixk DWS environment.
/// Ensures E2EE preservation, zero server decryption, and cross-document referencing.
class DwsMediaRepository extends ChangeNotifier {
  final LocalDatabase _db;

  DwsMediaRepository(this._db) {
    _seedInitialMediaIfEmpty();
  }

  void _seedInitialMediaIfEmpty() {
    final existing = _db.getAll('dws_media');
    if (existing.isNotEmpty) return;

    final initialAssets = [
      DwsMedia(
        id: 'media://group/asset_schema_reseau',
        conversationId: 'conv_group_1',
        slug: 'schema_reseau',
        type: DwsMediaType.image,
        source: '/imagetest.png',
        fileName: 'schema_reseau.png',
        fileSize: '840 Ko',
        mimeType: 'image/png',
        widthPercent: 80.0,
        align: 'center',
        caption: 'Architecture générale du réseau et topologie de routage.',
        alt: 'Schéma détaillé des passerelles et commutateurs sécurisés.',
        figureNumber: 1,
        role: DwsMediaRole.figure,
        createdAt: '11 novembre 2026 à 10:35',
        createdBy: 'Membre du groupe',
      ),
      DwsMedia(
        id: 'media://group/asset_experience_mp4',
        conversationId: 'conv_group_1',
        slug: 'experience',
        type: DwsMediaType.video,
        source: 'https://sample-videos.com/video321/mp4/720/big_buck_bunny_720p_1mb.mp4',
        fileName: 'experience.mp4',
        fileSize: '4.8 Mo',
        duration: '04:32',
        mimeType: 'video/mp4',
        widthPercent: 100.0,
        align: 'center',
        caption: 'Démonstration de configuration d\'un routeur sécurisé.',
        alt: 'Capture vidéo de manipulation d\'équipements réseau.',
        figureNumber: 2,
        role: DwsMediaRole.demo,
        createdAt: '11 novembre 2026 à 10:48',
        createdBy: 'Membre du groupe',
      ),
      DwsMedia(
        id: 'media://group/asset_explication_mp3',
        conversationId: 'conv_group_1',
        slug: 'explication',
        type: DwsMediaType.audio,
        source: '/audio_sample.wav',
        fileName: 'explication.mp3',
        fileSize: '1.2 Mo',
        duration: '02:15',
        mimeType: 'audio/mp3',
        widthPercent: 100.0,
        align: 'center',
        caption: 'Explication audio de la formule de Gauss et primitives de chiffrement.',
        alt: 'Enregistrement vocal des notes de synthèse.',
        figureNumber: 3,
        role: DwsMediaRole.explanation,
        createdAt: '11 novembre 2026 à 11:00',
        createdBy: 'Richard MARE',
      ),
    ];

    for (final asset in initialAssets) {
      _db.insert('dws_media', asset.id, asset.toJson());
    }
  }

  /// Returns all media assets associated with a group conversation
  List<DwsMedia> getMediaForGroup(String conversationId) {
    final all = _db.getAll('dws_media');
    final result = <DwsMedia>[];
    for (final raw in all) {
      try {
        final media = DwsMedia.fromJson(raw);
        if (media.conversationId == conversationId || media.conversationId.isEmpty) {
          result.add(media);
        }
      } catch (_) {}
    }
    return result;
  }

  /// Returns a media asset by its slug within a group (e.g. 'schema_reseau')
  DwsMedia? getMediaBySlug(String conversationId, String slug) {
    final list = getMediaForGroup(conversationId);
    final target = slug.toLowerCase().trim();
    for (final m in list) {
      if (m.slug.toLowerCase().trim() == target || m.fileName.toLowerCase().contains(target)) {
        return m;
      }
    }
    return null;
  }

  /// Returns a media asset by its canonical URI (e.g. 'media://group/asset_8f29a1')
  DwsMedia? getMediaById(String id) {
    final raw = _db.get('dws_media', id);
    if (raw != null) {
      return DwsMedia.fromJson(raw);
    }
    return null;
  }

  /// Returns a map of all available media in the group indexed by slug and ID
  Map<String, DwsMedia> getAllGroupMediaRegistry(String conversationId) {
    final map = <String, DwsMedia>{};
    for (final media in getMediaForGroup(conversationId)) {
      map[media.slug] = media;
      map[media.id] = media;
      if (media.fileName.isNotEmpty) {
        map[media.fileName] = media;
      }
    }
    return map;
  }

  /// Registers or updates a media asset in the sovereign group vault
  Future<void> registerMedia(DwsMedia media) async {
    await _db.insert('dws_media', media.id, media.toJson());
    notifyListeners();
  }

  /// Deletes a media asset
  Future<void> deleteMedia(String id) async {
    await _db.delete('dws_media', id);
    notifyListeners();
  }

  // === Sovereign Local AI Utilities (100% on-device, no unencrypted data to server) ===

  /// Generates a contextual caption using on-device heuristics
  String generateAutoCaption(DwsMedia media) {
    switch (media.type) {
      case DwsMediaType.image:
        return 'Figure technique : ${media.slug.replaceAll('_', ' ')} illustrant l\'architecture validée.';
      case DwsMediaType.video:
        return 'Séquence vidéo : ${media.slug.replaceAll('_', ' ')} (${media.duration.isNotEmpty ? media.duration : "04:30"}).';
      case DwsMediaType.audio:
        return 'Enregistrement vocal de synthèse : ${media.slug.replaceAll('_', ' ')}.';
      case DwsMediaType.pdf:
        return 'Annexe documentaire certifiée : ${media.fileName}.';
    }
  }

  /// Simulates local on-device OCR text extraction
  String extractTextOcr(DwsMedia media) {
    return '[OCR Local MRixk] Données extraites de "${media.fileName}":\n'
        '• Nœuds d\'infrastructure : Passerelle A1, Routeur B2, Commutateur C3\n'
        '• Débit mesuré : 10 Gbps / Sécurisation Post-Quantique Kyber-1024';
  }

  /// Simulates local on-device audio/video transcription
  String transcribeAudio(DwsMedia media) {
    return '[Transcription Locale] "Voici l\'analyse complète des paramètres réseaux et des protocoles de chiffrement de bout en bout présentés lors de cette séance."';
  }

  /// Generates descriptive accessibility alternative text
  String generateAltText(DwsMedia media) {
    return 'Représentation visuelle de type ${media.roleDisplayName} pour "${media.slug}".';
  }
}
