import 'dart:async';
import 'package:flutter/foundation.dart';
import '../database/local_database.dart';
import '../models/call_log.dart';

class CallHistoryRepository extends ChangeNotifier {
  final LocalDatabase _db;
  StreamSubscription? _sub;

  CallHistoryRepository(this._db) {
    _sub = _db.changes.listen((event) {
      if (event.table == 'call_logs') {
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
  Future<void> addCallLog(CallLog log) async {
    await _db.insert('call_logs', log.id, log.toJson());
    notifyListeners();
  }

  // --- CRUD: READ ---
  List<CallLog> getAllLogs() {
    final list = _db.getAll('call_logs');
    final logs = list.map((json) => CallLog.fromJson(json)).toList();
    // Return sorted newest first
    return logs.reversed.toList();
  }

  List<CallLog> getMissedLogs() {
    return getAllLogs().where((l) => l.direction == CallDirection.missed).toList();
  }

  List<CallLog> getVideoLogs() {
    return getAllLogs().where((l) => l.isVideo).toList();
  }

  // --- CRUD: DELETE ---
  Future<void> deleteLog(String id) async {
    await _db.delete('call_logs', id);
    notifyListeners();
  }

  Future<void> clearAll() async {
    final all = _db.getAll('call_logs');
    for (final item in all) {
      final id = item['id'] as String?;
      if (id != null) {
        await _db.delete('call_logs', id);
      }
    }
    notifyListeners();
  }
}
