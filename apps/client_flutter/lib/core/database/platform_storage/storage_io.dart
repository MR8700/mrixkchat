import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'storage_interface.dart';

class PlatformStorageImpl implements PlatformStorage {
  late final String instanceId;
  late final String _dbPath;
  late final String _lockPath;
  Timer? _heartbeatTimer;
  final StreamController<InstanceLockEvent> _lockEventController =
      StreamController<InstanceLockEvent>.broadcast();

  PlatformStorageImpl() {
    instanceId = 'io_${Platform.operatingSystem}_$pid';
    final home = Platform.environment['HOME'] ?? Directory.systemTemp.path;
    final dir = Directory('$home/.mrixk');
    if (!dir.existsSync()) {
      try {
        dir.createSync(recursive: true);
      } catch (_) {}
    }
    _dbPath = '${dir.path}/mrixk_database.json';
    _lockPath = '${dir.path}/mrixk_instance.lock';
  }

  @override
  Stream<InstanceLockEvent> get lockEvents => _lockEventController.stream;

  @override
  Future<bool> save(String content) async {
    try {
      final file = File(_dbPath);
      final tmp = File('$_dbPath.tmp');
      await tmp.writeAsString(content, flush: true);
      await tmp.rename(_dbPath);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String?> load() async {
    try {
      final file = File(_dbPath);
      if (await file.exists()) {
        final s = await file.readAsString();
        return s.trim().isNotEmpty ? s : null;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> clear() async {
    try {
      final file = File(_dbPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  @override
  Future<bool> acquireLock({bool forceTakeover = false}) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final lockFile = File(_lockPath);

      if (!forceTakeover && await lockFile.exists()) {
        try {
          final content = await lockFile.readAsString();
          if (content.trim().isNotEmpty) {
            final data = jsonDecode(content) as Map<String, dynamic>;
            final lastBeat = data['timestamp'] as int? ?? 0;
            final holder = data['instanceId'] as String? ?? '';
            if (holder != instanceId && (now - lastBeat) < 5000) {
              return false; // Active lock held by another process
            }
          }
        } catch (_) {}
      }

      await lockFile.writeAsString(
        jsonEncode({
          'instanceId': instanceId,
          'timestamp': now,
        }),
        flush: true,
      );

      _startHeartbeat();
      _lockEventController.add(InstanceLockEvent.acquiredLock);
      return true;
    } catch (_) {
      return true;
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      try {
        final lockFile = File(_lockPath);
        if (await lockFile.exists()) {
          final content = await lockFile.readAsString();
          final data = jsonDecode(content) as Map<String, dynamic>;
          if (data['instanceId'] != instanceId) {
            _lockEventController.add(InstanceLockEvent.lostLock);
            _heartbeatTimer?.cancel();
            return;
          }
        }
        await lockFile.writeAsString(
          jsonEncode({
            'instanceId': instanceId,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          }),
          flush: true,
        );
      } catch (_) {}
    });
  }

  @override
  Future<void> releaseLock() async {
    _heartbeatTimer?.cancel();
    try {
      final lockFile = File(_lockPath);
      if (await lockFile.exists()) {
        final content = await lockFile.readAsString();
        final data = jsonDecode(content) as Map<String, dynamic>;
        if (data['instanceId'] == instanceId) {
          await lockFile.delete();
        }
      }
    } catch (_) {}
  }
}
