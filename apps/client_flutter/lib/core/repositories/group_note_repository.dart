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

  /// Default seed note with rich Word formatting, Math formulas, Tables, Flowchart and Bar Graph
  static const String defaultSeedContent = '''
<h1>Spécifications & Architecture Souveraine MRixk</h1>
<p>Bienvenue dans le <b>Bloc-Note Collaboratif</b> du groupe. Cet espace réunit les notes d'équipe, calculs mathématiques certifiés et diagrammes de flux sécurisés.</p>

<hr/>

<h2>1. Fondements Mathématiques & Cryptographiques</h2>
<p>Les échanges s'appuient sur des primitives asymétriques à haute résistance :</p>

<math>
x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}
</math>

<math>
\int_{-\infty}^{+\infty} e^{-x^2} dx = \sqrt{\pi}
</math>

<math>
\sum_{k=1}^{n} k = \frac{n(n+1)}{2}
</math>

<hr/>

<h2>2. Matrice d'Audit des Modules</h2>
<p>Tableau récapitulatif des composants validés par l'équipe :</p>

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

<hr/>

<h2>3. Flux de Traitement des Données</h2>
<p>Organigramme du cycle de vie d'un message confidentiel :</p>

<diagram type="flowchart">
[1. Saisie Locale] -> [2. Signature Ed25519] -> [3. Chiffrement X25519] -> [4. Distribution Souveraine]
</diagram>

<hr/>

<h2>4. Indicateurs Clés de Performance</h2>
<p>Métriques de fiabilité et de vitesse constatées :</p>

<graph type="bar" title="Indicateurs de Sécurité & Résilience (%)">
Souveraineté des données: 100
Résistance Cryptographique: 98
Disponibilité Hors-ligne: 95
Vitesse d'Exécution: 92
</graph>
''';

  /// Retrieves the note for a given group conversation.
  /// If none exists, initializes it with a rich default note.
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
      lastModified: 'Aujourd\'hui à 10:30',
      lastModifiedBy: 'Richard MARE (Créateur)',
      isLocked: false,
    );

    // Save synchronously in db
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
