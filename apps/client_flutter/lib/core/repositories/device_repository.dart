import 'package:flutter/foundation.dart';
import '../database/local_database.dart';
import '../models/device.dart';

class DeviceRepository extends ChangeNotifier {
  final LocalDatabase _db;
  static const int maxDeviceQuota = 3;

  DeviceRepository(this._db) {
    _db.changes.listen((event) {
      if (event.table == 'devices') {
        notifyListeners();
      }
    });
  }

  // --- CRUD: CREATE (Strict 3-device limit enforcement) ---
  Future<bool> authorizeDevice(Device device) async {
    final activeCount = getActiveDevices().length;
    if (activeCount >= maxDeviceQuota) {
      // Limit strictly reached
      return false;
    }
    await _db.insert('devices', device.id, device.toJson());
    notifyListeners();
    return true;
  }

  // --- CRUD: READ ---
  List<Device> getAllDevices() {
    final list = _db.getAll('devices');
    return list.map((json) => Device.fromJson(json)).toList();
  }

  List<Device> getActiveDevices() {
    return getAllDevices().where((d) => d.status == 'ACTIVE').toList();
  }

  Device? getDeviceById(String id) {
    final data = _db.get('devices', id);
    if (data == null) return null;
    return Device.fromJson(data);
  }

  // --- CRUD: UPDATE / REVOKE ---
  Future<void> revokeDevice(String id) async {
    final device = getDeviceById(id);
    if (device != null) {
      final updated = device.copyWith(
        status: 'REVOKED',
        lastSeenText: 'Session révoquée',
      );
      await _db.update('devices', id, updated.toJson());
      notifyListeners();
    }
  }

  // --- CRUD: DELETE ---
  Future<void> deleteDevice(String id) async {
    await _db.delete('devices', id);
    notifyListeners();
  }
}
