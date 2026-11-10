import 'dart:async';
import 'storage_interface.dart';

class PlatformStorageImpl implements PlatformStorage {
  final StreamController<InstanceLockEvent> _lockEventController =
      StreamController<InstanceLockEvent>.broadcast();

  @override
  Stream<InstanceLockEvent> get lockEvents => _lockEventController.stream;

  @override
  Future<bool> save(String content) async => true;

  @override
  Future<String?> load() async => null;

  @override
  Future<void> clear() async {}

  @override
  Future<bool> acquireLock({bool forceTakeover = false}) async => true;

  @override
  Future<void> releaseLock() async {}
}
