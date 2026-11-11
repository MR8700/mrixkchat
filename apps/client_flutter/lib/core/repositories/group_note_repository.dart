import 'package:flutter/foundation.dart';
import '../database/local_database.dart';
import '../models/group_note.dart';
import '../services/formula_engine.dart';

class GroupNoteRepository extends ChangeNotifier {
  final LocalDatabase _db;

  GroupNoteRepository(this._db) {
    _db.changes.listen((event) {
      if (event.table == 'group_notes') {
        notifyListeners();
      }
    });
  }

  /// Default predefined components/macros mapping: name -> HTML/Math/Diagram code
  static const Map<String, String> defaultSeedComponents = {
    'tableau1': '''
<table border="1">
  <thead>
    <tr>
      <th>Module</th>
      <th>Responsable</th>
      <th>Protocole</th>
      <th>Statut</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>Chiffrement de bout en bout</td>
      <td>Marc Delaunay</td>
      <td>X25519 + ChaCha20</td>
      <td>Validé ✅</td>
    </tr>
    <tr>
      <td>Base locale souveraine</td>
      <td>Richard MARE</td>
      <td>Stockage Chiffré</td>
      <td>Opérationnel 🚀</td>
    </tr>
    <tr>
      <td>Bloc-note & Formules</td>
      <td>Sophie Valade</td>
      <td>HTML Sécurisé</td>
      <td>Actif ✨</td>
    </tr>
    <tr>
      <td>Vérification d'empreinte</td>
      <td>Dr. Sarah Connor</td>
      <td>Ed25519 Multi-device</td>
      <td>Certifié 🛡️</td>
    </tr>
  </tbody>
</table>
''',
    'formule1': r'''
<math>
x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}
</math>
''',
    'integrale1': r'''
<math>
\int_{-\infty}^{+\infty} e^{-x^2} dx = \sqrt{\pi}
</math>
''',
    'somme1': r'''
<math>
\sum_{k=1}^{n} k = \frac{n(n+1)}{2}
</math>
''',
    'diagramme1': '''
<diagram type="flowchart">
[1. Saisie Locale] -> [2. Signature Ed25519] -> [3. Chiffrement X25519] -> [4. Distribution Souveraine]
</diagram>
''',
    'graphe1': '''
<graph type="bar" title="Indicateurs de Sécurité & Résilience (%)">
Souveraineté des données: 100
Résistance Cryptographique: 98
Disponibilité Hors-ligne: 95
Vitesse d'Exécution: 92
</graph>
''',
  };

  /// Default seed note text: clean, elegant text with macro component calls {{name}}
  static const String defaultSeedContent = '''
# Spécifications & Architecture Souveraine MRixk

Bienvenue dans le Bloc-Note Collaboratif du groupe. Cet espace réunit les notes d'équipe, calculs mathématiques certifiés et diagrammes de flux sécurisés.

---

## 1. Fondements Mathématiques & Cryptographiques
Les échanges s'appuient sur des primitives asymétriques à haute résistance :

{{formule1}}

{{integrale1}}

{{somme1}}

---

## 2. Matrice d'Audit des Modules
Tableau récapitulatif des composants validés par l'équipe :

{{tableau1}}

---

## 3. Flux de Traitement des Données
Organigramme du cycle de vie d'un message confidentiel :

{{diagramme1}}

---

## 4. Indicateurs Clés de Performance
Métriques de fiabilité et de vitesse constatées :

{{graphe1}}
''';

  /// Retrieves the note for a given group conversation.
  /// If [documentId] or [documentSlug] is provided, searches for that specific document.
  /// Defaults to primary group note for backwards compatibility.
  GroupNote getNote(
    String conversationId, {
    String? documentId,
    String? documentSlug,
    String groupTitle = 'Groupe',
  }) {
    // If querying by specific documentId
    if (documentId != null) {
      final docData = _db.get('group_notes', documentId);
      if (docData != null) return GroupNote.fromJson(docData);
    }

    // If querying by slug (e.g. Maths, Physique)
    if (documentSlug != null) {
      final all = getNotesForGroup(conversationId);
      for (final n in all) {
        if (n.slug.toLowerCase() == documentSlug.toLowerCase() ||
            n.title.toLowerCase() == documentSlug.toLowerCase() ||
            n.effectiveSlug.toLowerCase() == documentSlug.toLowerCase()) {
          return n;
        }
      }
    }

    // Default primary note lookup
    final primaryData = _db.get('group_notes', 'note_$conversationId') ?? _db.get('group_notes', conversationId);
    if (primaryData != null) {
      return GroupNote.fromJson(primaryData);
    }

    // Create and seed primary note
    final initialNote = GroupNote(
      id: 'note_$conversationId',
      conversationId: conversationId,
      title: 'Bloc-Note : $groupTitle',
      content: defaultSeedContent,
      components: defaultSeedComponents,
      lineSpacing: 1.5,
      paragraphSpacing: 12.0,
      createdAt: '11 novembre 2026 à 10:35',
      createdBy: 'Richard MARE (Créateur)',
      lastModified: 'Aujourd\'hui à 10:48',
      lastModifiedBy: 'Richard MARE (Créateur)',
      slug: 'Maths',
      isLocked: false,
    );

    _db.insert('group_notes', 'note_$conversationId', initialNote.toJson());
    _db.insert('group_notes', conversationId, initialNote.toJson());
    return initialNote;
  }

  /// Returns all active documents belonging to this group conversation
  List<GroupNote> getNotesForGroup(String conversationId) {
    final all = _db.getAll('group_notes');
    final result = <GroupNote>[];
    final seenIds = <String>{};

    for (final raw in all) {
      try {
        final note = GroupNote.fromJson(raw);
        if (note.conversationId == conversationId && !seenIds.contains(note.id)) {
          seenIds.add(note.id);
          result.add(note);
        }
      } catch (_) {}
    }

    if (result.isEmpty) {
      result.add(getNote(conversationId));
    }

    return result;
  }

  /// Creates a new named document in the group
  Future<GroupNote> createDocument(
    String conversationId, {
    required String title,
    String? slug,
    required String createdBy,
  }) async {
    final docId = 'doc_${DateTime.now().millisecondsSinceEpoch}';
    final effectiveSlug = slug?.isNotEmpty == true
        ? slug!
        : title.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');

    final newDoc = GroupNote(
      id: docId,
      conversationId: conversationId,
      title: title,
      content: '',
      components: {},
      createdAt: '11 novembre 2026 à 10:35',
      createdBy: createdBy,
      lastModified: 'À l\'instant',
      lastModifiedBy: createdBy,
      slug: effectiveSlug,
      isLocked: false,
    );

    await saveNote(newDoc);
    return newDoc;
  }

  /// Saves or updates a note and notifies listeners
  Future<void> saveNote(GroupNote note) async {
    await _db.insert('group_notes', note.id, note.toJson());
    // Also keep primary key synced if it's the primary note
    if (note.id == 'note_${note.conversationId}') {
      await _db.insert('group_notes', note.conversationId, note.toJson());
    }
    notifyListeners();
  }

  /// Renames a document
  Future<void> renameNote(String conversationId, String noteId, String newTitle) async {
    final note = getNote(conversationId, documentId: noteId);
    final updated = note.copyWith(
      title: newTitle,
      lastModified: 'À l\'instant',
    );
    await saveNote(updated);
  }

  /// Deletes a document with audit trace
  Future<void> deleteNote(String conversationId, String noteId, {required String deletedBy}) async {
    await _db.delete('group_notes', noteId);
    if (noteId == 'note_$conversationId') {
      await _db.delete('group_notes', conversationId);
    }
    notifyListeners();
  }

  /// Toggles or sets the lock state of the note
  Future<void> setLock(String conversationId, bool isLocked, String modifiedBy, {String? documentId}) async {
    final note = getNote(conversationId, documentId: documentId);
    final updated = note.copyWith(
      isLocked: isLocked,
      lastModified: 'À l\'instant',
      lastModifiedBy: modifiedBy,
    );
    await saveNote(updated);
  }

  /// Extracts all variables across all documents of the group
  /// e.g. mapping "Maths" -> { "a": 2.0, "b": 5.0, "somme": 7.0 }
  /// and "Physique" -> { "resultat": 14.0 }
  Map<String, Map<String, double>> getAllGroupVariables(String conversationId) {
    final notes = getNotesForGroup(conversationId);
    final groupVars = <String, Map<String, double>>{};

    for (final doc in notes) {
      final docVars = FormulaEngine.extractAndComputeVariables(doc.content);
      // Index by slug and by sanitized title
      if (doc.slug.isNotEmpty) {
        groupVars[doc.slug] = docVars;
      }
      groupVars[doc.title] = docVars;
      final cleanTitle = doc.title.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '');
      if (cleanTitle.isNotEmpty) {
        groupVars[cleanTitle] = docVars;
      }
    }

    return groupVars;
  }
}
