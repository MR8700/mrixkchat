import 'dart:async';

enum InstanceLockEvent {
  acquiredLock,
  lostLock,
}

abstract class PlatformStorage {
  Stream<InstanceLockEvent> get lockEvents;
  Future<bool> save(String content);
  Future<String?> load();
  Future<void> clear();
  Future<bool> acquireLock({bool forceTakeover = false});
  Future<void> releaseLock();
}
