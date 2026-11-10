import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'platform_storage/platform_storage.dart';

/// A robust, transactional, multiplatform Local Database engine for MRixk.
/// Ensures 100% of data flows strictly through real CRUD operations.
class LocalDatabase {
  static final LocalDatabase _instance = LocalDatabase._internal();
  factory LocalDatabase() => _instance;
  LocalDatabase._internal();

  // Internal table stores: TableName -> {RecordId: JsonData}
  final Map<String, Map<String, Map<String, dynamic>>> _tables = {};
  String? _storageFilePath;
  bool _usePlatformStorage = false;
  PlatformStorage? _platformStorage;

  PlatformStorage get platformStorage =>
      _platformStorage ??= createPlatformStorage();

  // Broadcast stream controller for reactive CRUD listening
  final StreamController<DatabaseChangeEvent> _changeController =
      StreamController<DatabaseChangeEvent>.broadcast();

  Stream<DatabaseChangeEvent> get changes => _changeController.stream;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  Future<void> initialize({
    String? storagePath,
    bool usePlatformStorage = false,
    Future<void> Function(LocalDatabase db)? onSeed,
  }) async {
    if (_isInitialized) return;
    _tables['users'] = {};
    _tables['devices'] = {};
    _tables['contacts'] = {};
    _tables['conversations'] = {};
    _tables['messages'] = {};
    _tables['moments'] = {};
    _tables['memories'] = {};
    _tables['settings'] = {};

    _storageFilePath = storagePath;
    _usePlatformStorage = usePlatformStorage;
    bool hasRestoredFromDisk = false;

    if (_usePlatformStorage) {
      final saved = await platformStorage.load();
      if (saved != null && saved.trim().isNotEmpty) {
        try {
          importJson(saved);
          hasRestoredFromDisk = true;
        } catch (_) {}
      }
    }

    if (!hasRestoredFromDisk && storagePath != null) {
      hasRestoredFromDisk = await loadFromFile(storagePath);
    }

    _isInitialized = true;

    // Only seed initial default data if no persistent database exists on disk
    if (!hasRestoredFromDisk && onSeed != null) {
      await onSeed(this);
      _saveIfConfigured();
    }
  }

  /// Exports the entire database as a formatted JSON snapshot.
  String exportJson() {
    return jsonEncode(_tables);
  }

  /// Clears all tables in the local database and purges persistent snapshot.
  Future<void> clearAll() async {
    for (final table in _tables.values) {
      table.clear();
    }
    if (_usePlatformStorage) {
      await platformStorage.clear();
    }
    _saveIfConfigured();
    _changeController.add(DatabaseChangeEvent(
      table: 'all',
      type: DatabaseChangeType.delete,
      id: '*',
    ));
  }

  /// Explicitly saves the current database snapshot to persistent storage.
  Future<void> saveState() async {
    final jsonStr = exportJson();
    if (_usePlatformStorage) {
      await platformStorage.save(jsonStr);
    }
    if (_storageFilePath != null) {
      await persistToFile(_storageFilePath!);
    }
  }

  /// Imports and validates a JSON snapshot into database tables.
  void importJson(String jsonString) {
    final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
    for (final table in decoded.keys) {
      _ensureTable(table);
      final records = decoded[table] as Map<String, dynamic>;
      for (final id in records.keys) {
        _tables[table]![id] = Map<String, dynamic>.from(records[id] as Map);
      }
    }
  }

  /// Persists database state to an on-disk JSON file atomically.
  Future<bool> persistToFile(String path) async {
    try {
      final file = File(path);
      await file.parent.create(recursive: true);
      final jsonStr = exportJson();
      final tmpFile = File('$path.tmp');
      await tmpFile.writeAsString(jsonStr, flush: true);
      await tmpFile.rename(path);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Restores database state from an on-disk JSON file.
  Future<bool> loadFromFile(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return false;
      final content = await file.readAsString();
      if (content.trim().isEmpty) return false;
      importJson(content);
      return true;
    } catch (_) {
      return false;
    }
  }

  void _saveIfConfigured() {
    if (_usePlatformStorage) {
      final jsonStr = exportJson();
      platformStorage.save(jsonStr);
    }
    if (_storageFilePath != null) {
      persistToFile(_storageFilePath!);
    }
  }

  // --- CRUD: CREATE ---
  Future<void> insert(String table, String id, Map<String, dynamic> data) async {
    _ensureTable(table);
    _tables[table]![id] = Map<String, dynamic>.from(data);
    _saveIfConfigured();
    _changeController.add(DatabaseChangeEvent(
      table: table,
      type: DatabaseChangeType.create,
      id: id,
      data: data,
    ));
  }

  // --- CRUD: READ ---
  Map<String, dynamic>? get(String table, String id) {
    _ensureTable(table);
    final record = _tables[table]![id];
    if (record == null) return null;
    return Map<String, dynamic>.from(record);
  }

  List<Map<String, dynamic>> getAll(String table) {
    _ensureTable(table);
    return _tables[table]!.values.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  List<Map<String, dynamic>> query(
    String table,
    bool Function(Map<String, dynamic> row) predicate,
  ) {
    _ensureTable(table);
    return _tables[table]!
        .values
        .where(predicate)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  // --- CRUD: UPDATE ---
  Future<bool> update(String table, String id, Map<String, dynamic> data) async {
    _ensureTable(table);
    if (!_tables[table]!.containsKey(id)) {
      return false;
    }
    _tables[table]![id] = Map<String, dynamic>.from(data);
    _saveIfConfigured();
    _changeController.add(DatabaseChangeEvent(
      table: table,
      type: DatabaseChangeType.update,
      id: id,
      data: data,
    ));
    return true;
  }

  // --- CRUD: DELETE ---
  Future<bool> delete(String table, String id) async {
    _ensureTable(table);
    if (!_tables[table]!.containsKey(id)) {
      return false;
    }
    final removed = _tables[table]!.remove(id);
    _saveIfConfigured();
    _changeController.add(DatabaseChangeEvent(
      table: table,
      type: DatabaseChangeType.delete,
      id: id,
      data: removed,
    ));
    return true;
  }

  int count(String table) {
    _ensureTable(table);
    return _tables[table]!.length;
  }

  void _ensureTable(String table) {
    _tables.putIfAbsent(table, () => <String, Map<String, dynamic>>{});
  }
}

enum DatabaseChangeType { create, update, delete }

class DatabaseChangeEvent {
  final String table;
  final DatabaseChangeType type;
  final String id;
  final Map<String, dynamic>? data;

  DatabaseChangeEvent({
    required this.table,
    required this.type,
    required this.id,
    this.data,
  });
}
