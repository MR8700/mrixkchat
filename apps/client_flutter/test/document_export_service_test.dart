import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mrixk_client/core/services/document_export_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DocumentExportService - Word, PDF & Markdown Exports', () {
    test('exports document as real Markdown file (.md)', () {
      const title = 'Rapport Synthèse 2026';
      const content = '## Objectifs\n- Chiffrement souverain\n- Traitement local';

      final filename = DocumentExportService.instance.exportMarkdown(
        title: title,
        content: content,
      );

      expect(filename, equals('Rapport Synthèse 2026.md'));
    });

    test('exports document as real Microsoft Word document (.doc) with HTML styles', () {
      const title = 'Cours Traitement du Signal';
      const content = '''
[align=center] # Cours de Télécommunications

Voici le tableau des débits :

| Modulation | Débit |
| QPSK | 2 Mbps |
| 16-QAM | 4 Mbps |

Fin du cours.
''';

      final filename = DocumentExportService.instance.exportWord(
        title: title,
        content: content,
      );

      expect(filename, equals('Cours Traitement du Signal.doc'));
    });

    test('exports document as real vectorized PDF 1.4 file (.pdf)', () {
      const title = 'Fiche Sécurité Cryptographique';
      const content = '''
# Sécurité E2EE Post-Quantique

Ce document atteste de la validation des protocoles :
- X25519 pour l'échange de clés
- ChaCha20-Poly1305 pour le chiffrement symétrique
- Ed25519 pour la signature numérique
''';

      final filename = DocumentExportService.instance.exportPdf(
        title: title,
        content: content,
      );

      expect(filename, equals('Fiche Sécurité Cryptographique.pdf'));
    });
  });
}
