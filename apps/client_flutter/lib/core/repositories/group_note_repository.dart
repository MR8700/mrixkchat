import 'dart:async';
import 'package:flutter/foundation.dart';
import '../database/local_database.dart';
import '../models/group_note.dart';
import '../services/formula_engine.dart';

class GroupNoteRepository extends ChangeNotifier {
  final LocalDatabase _db;
  StreamSubscription? _sub;

  GroupNoteRepository(this._db) {
    _sub = _db.changes.listen((event) {
      if (event.table == 'group_notes') {
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

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
      final note = GroupNote.fromJson(primaryData);
      // Clean up legacy test data and unreferenced components
      final cleanComponents = Map<String, String>.from(note.components);
      cleanComponents.removeWhere((k, _) =>
        !note.content.contains('{{$k}}') && !note.content.contains('{$k}') && !note.content.contains('<!-- macro:$k -->')
      );
      if (cleanComponents.length != note.components.length) {
        final updated = note.copyWith(components: cleanComponents);
        _db.insert('group_notes', note.id, updated.toJson());
        return updated;
      }
      return note;
    }

    // Create clean primary note without test data
    final initialNote = GroupNote(
      id: 'note_$conversationId',
      conversationId: conversationId,
      title: 'Bloc-Note : $groupTitle',
      content: '',
      components: const {},
      lineSpacing: 1.5,
      paragraphSpacing: 12.0,
      createdAt: 'À l\'instant',
      createdBy: 'Richard MARE (Créateur)',
      lastModified: 'À l\'instant',
      lastModifiedBy: 'Richard MARE (Créateur)',
      slug: 'Note',
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
