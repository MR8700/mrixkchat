import 'package:flutter/foundation.dart';
import '../database/local_database.dart';
import '../models/group_note.dart';

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
  /// If none exists, initializes it with a rich default note and macro components.
  GroupNote getNote(String conversationId, {String groupTitle = 'Groupe'}) {
    final data = _db.get('group_notes', conversationId);
    if (data != null) {
      return GroupNote.fromJson(data);
    }

    final initialNote = GroupNote(
      id: 'note_$conversationId',
      conversationId: conversationId,
      title: 'Bloc-Note : $groupTitle',
      content: defaultSeedContent,
      components: defaultSeedComponents,
      lineSpacing: 1.5,
      paragraphSpacing: 12.0,
      lastModified: 'Aujourd\'hui à 10:30',
      lastModifiedBy: 'Richard MARE (Créateur)',
      isLocked: false,
    );

    _db.insert('group_notes', conversationId, initialNote.toJson());
    return initialNote;
  }

  /// Saves or updates the note
  Future<void> saveNote(GroupNote note) async {
    await _db.insert('group_notes', note.conversationId, note.toJson());
    notifyListeners();
  }

  /// Toggles or sets the lock state of the note
  Future<void> setLock(String conversationId, bool isLocked, String modifiedBy) async {
    final note = getNote(conversationId);
    final updated = note.copyWith(
      isLocked: isLocked,
      lastModified: 'À l\'instant',
      lastModifiedBy: modifiedBy,
    );
    await saveNote(updated);
  }
}
