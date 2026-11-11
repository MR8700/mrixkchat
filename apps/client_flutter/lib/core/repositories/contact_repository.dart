import 'dart:async';
import 'package:flutter/foundation.dart';
import '../database/local_database.dart';
import '../models/contact.dart';

class ContactRepository extends ChangeNotifier {
  final LocalDatabase _db;
  StreamSubscription? _sub;

  ContactRepository(this._db) {
    _sub = _db.changes.listen((event) {
      if (event.table == 'contacts') {
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  // --- CRUD: CREATE ---
  Future<void> createContact(Contact contact) async {
    await _db.insert('contacts', contact.id, contact.toJson());
    notifyListeners();
  }

  // --- CRUD: READ ---
  List<Contact> getAllContacts() {
    final list = _db.getAll('contacts');
    final contacts = list.map((json) => Contact.fromJson(json)).toList();
    contacts.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return contacts;
  }

  List<Contact> getActiveContacts() {
    return getAllContacts().where((c) => !c.isBlocked).toList();
  }

  List<Contact> getBlockedContacts() {
    return getAllContacts().where((c) => c.isBlocked).toList();
  }

  List<Contact> searchContacts(String query, {bool includeBlocked = false}) {
    final base = includeBlocked ? getAllContacts() : getActiveContacts();
    if (query.trim().isEmpty) return base;
    final lower = query.toLowerCase();
    return base.where((c) {
      return c.name.toLowerCase().contains(lower) ||
          c.handle.toLowerCase().contains(lower) ||
          c.statusText.toLowerCase().contains(lower);
    }).toList();
  }

  Map<String, List<Contact>> getGroupedContacts([String query = '']) {
    final contacts = searchContacts(query);
    final Map<String, List<Contact>> grouped = {};
    for (final c in contacts) {
      final key = c.name.isNotEmpty ? c.name[0].toUpperCase() : 'A';
      grouped.putIfAbsent(key, () => []).add(c);
    }
    return grouped;
  }

  Contact? getContactById(String id) {
    final data = _db.get('contacts', id);
    if (data == null) return null;
    return Contact.fromJson(data);
  }

  // --- CRUD: UPDATE ---
  Future<void> updateContact(Contact contact) async {
    await _db.update('contacts', contact.id, contact.toJson());
    notifyListeners();
  }

  Future<void> toggleFavorite(String id) async {
    final contact = getContactById(id);
    if (contact != null) {
      final updated = contact.copyWith(isFavorite: !contact.isFavorite);
      await updateContact(updated);
    }
  }

  // --- BLOCKING LOGIC ---
  Future<void> blockContact(String id, {String duration = 'Définitif', String? reason}) async {
    final contact = getContactById(id);
    if (contact == null) return;

    final updated = contact.copyWith(
      isBlocked: true,
      blockedUntil: duration,
      blockedAt: DateTime.now(),
      blockedReason: reason ?? 'Suspension de contact bienveillante',
    );
    await updateContact(updated);

    // Also update any matching conversation in the database to blocked
    final allConvs = _db.getAll('conversations');
    for (final json in allConvs) {
      if ((json['title'] as String?)?.toLowerCase() == contact.name.toLowerCase()) {
        final convId = json['id'] as String;
        json['isBlocked'] = true;
        json['blockedMessage'] =
            'Échange suspendu ($duration) : Cette discussion est temporairement inactive afin de préserver la tranquillité de chacun.';
        await _db.update('conversations', convId, json);
      }
    }
  }

  Future<void> unblockContact(String id) async {
    final contact = getContactById(id);
    if (contact == null) return;

    final updated = contact.copyWith(
      isBlocked: false,
      blockedUntil: null,
      blockedAt: null,
      blockedReason: null,
    );
    await updateContact(updated);

    // Unblock matching conversation
    final allConvs = _db.getAll('conversations');
    for (final json in allConvs) {
      if ((json['title'] as String?)?.toLowerCase() == contact.name.toLowerCase()) {
        final convId = json['id'] as String;
        json['isBlocked'] = false;
        json['blockedMessage'] = null;
        await _db.update('conversations', convId, json);
      }
    }
  }

  Future<void> blockMultipleContacts(List<String> ids, {String duration = 'Définitif', String? reason}) async {
    for (final id in ids) {
      await blockContact(id, duration: duration, reason: reason);
    }
  }

  // --- CRUD: DELETE ---
  Future<void> deleteContact(String id) async {
    await _db.delete('contacts', id);
    notifyListeners();
  }

  Future<void> deleteMultipleContacts(List<String> ids) async {
    for (final id in ids) {
      await deleteContact(id);
    }
  }
}
