// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'storage_interface.dart';

class PlatformStorageImpl implements PlatformStorage {
  static const String _dbKey = 'mrixk_db_snapshot';
  static const String _lockKey = 'mrixk_active_instance_lock';
  static const String _channelName = 'mrixk_instance_channel';

  late final String instanceId;
  Timer? _heartbeatTimer;
  html.BroadcastChannel? _channel;
  final StreamController<InstanceLockEvent> _lockEventController =
      StreamController<InstanceLockEvent>.broadcast();

  PlatformStorageImpl() {
    instanceId =
        'inst_${DateTime.now().millisecondsSinceEpoch}_${(DateTime.now().microsecond % 10000)}';
    _initChannel();
  }

  void _initChannel() {
    try {
      _channel = html.BroadcastChannel(_channelName);
      _channel?.onMessage.listen((event) {
        if (event.data != null) {
          try {
            final raw = event.data.toString();
            final data = jsonDecode(raw) as Map<String, dynamic>;
            if (data['type'] == 'takeover' && data['sender'] != instanceId) {
              _heartbeatTimer?.cancel();
              _lockEventController.add(InstanceLockEvent.lostLock);
            }
          } catch (_) {}
        }
      });
    } catch (_) {}

    try {
      html.window.addEventListener('storage', (event) {
        final se = event as html.StorageEvent;
        if (se.key == _lockKey && se.newValue != null) {
          try {
            final data = jsonDecode(se.newValue!) as Map<String, dynamic>;
            if (data['instanceId'] != instanceId) {
              _heartbeatTimer?.cancel();
              _lockEventController.add(InstanceLockEvent.lostLock);
            }
          } catch (_) {}
        }
      });
    } catch (_) {}

    try {
      html.window.addEventListener('beforeunload', (_) {
        releaseLock();
      });
    } catch (_) {}
  }

  @override
  Stream<InstanceLockEvent> get lockEvents => _lockEventController.stream;

  @override
  Future<bool> save(String content) async {
    try {
      html.window.localStorage[_dbKey] = content;
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String?> load() async {
    try {
      final val = html.window.localStorage[_dbKey];
      return (val != null && val.trim().isNotEmpty) ? val : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> clear() async {
    try {
      html.window.localStorage.remove(_dbKey);
    } catch (_) {}
  }

  @override
  Future<bool> acquireLock({bool forceTakeover = false}) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final currentLockStr = html.window.localStorage[_lockKey];

      if (!forceTakeover && currentLockStr != null && currentLockStr.isNotEmpty) {
        try {
          final currentLock = jsonDecode(currentLockStr) as Map<String, dynamic>;
          final lastBeat = currentLock['timestamp'] as int? ?? 0;
          final holder = currentLock['instanceId'] as String? ?? '';

          // If locked by another instance and heartbeat is within last 4 seconds
          if (holder != instanceId && (now - lastBeat) < 4000) {
            return false;
          }
        } catch (_) {}
      }

      // Claim lock
      final lockData = jsonEncode({
        'instanceId': instanceId,
        'timestamp': now,
      });
      html.window.localStorage[_lockKey] = lockData;

      if (forceTakeover) {
        try {
          _channel?.postMessage(jsonEncode({
            'type': 'takeover',
            'sender': instanceId,
          }));
        } catch (_) {}
      }

      _startHeartbeat();
      _lockEventController.add(InstanceLockEvent.acquiredLock);
      return true;
    } catch (_) {
      return true;
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      try {
        final now = DateTime.now().millisecondsSinceEpoch;
        html.window.localStorage[_lockKey] = jsonEncode({
          'instanceId': instanceId,
          'timestamp': now,
        });
      } catch (_) {}
    });
  }

  @override
  Future<void> releaseLock() async {
    _heartbeatTimer?.cancel();
    try {
      final currentLockStr = html.window.localStorage[_lockKey];
      if (currentLockStr != null) {
        final currentLock = jsonDecode(currentLockStr) as Map<String, dynamic>;
        if (currentLock['instanceId'] == instanceId) {
          html.window.localStorage.remove(_lockKey);
        }
      }
    } catch (_) {}
  }
}
