import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../database/database_seed.dart';
import '../database/local_database.dart';
import '../models/user_profile.dart';
import '../services/identity_directory_service.dart';

class ProfileRepository extends ChangeNotifier {
  final LocalDatabase _db;
  StreamSubscription? _sub;
  bool _isDisposed = false;

  ProfileRepository(this._db) {
    _sub = _db.changes.listen((event) {
      if (!_isDisposed && (event.table == 'users' || event.table == 'settings' || event.table == 'all')) {
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _sub?.cancel();
    _sub = null;
    super.dispose();
  }

  /// Whether the user has already configured their identity on this device.
  bool get hasConfiguredIdentity {
    final setting = _db.get('settings', 'identity_configured');
    return setting != null && setting['value'] == true;
  }

  // --- CRUD: READ ---
  UserProfile getProfile() {
    final allUsers = _db.getAll('users');
    if (allUsers.isNotEmpty) {
      final configured = allUsers.firstWhere(
        (u) => (u['displayName'] as String? ?? '').trim().isNotEmpty,
        orElse: () => allUsers.first,
      );
      return UserProfile.fromJson(configured);
    }
    return UserProfile(
      id: 'current_user',
      displayName: '',
      handle: '',
      avatarUrl: '',
      statusMessage: "Disponible sur MRixk",
      isOnline: true,
      deviceQuotaMax: 3,
    );
  }

  static String generateRecoveryCode() {
    final random = Random();
    const chars = '0123456789ABCDEFGHJKLMNPQRSTUVWXYZ';
    String chunk() => List.generate(4, (_) => chars[random.nextInt(chars.length)]).join();
    return 'MRX-${chunk()}-${chunk()}-${chunk()}-${chunk()}';
  }

  // --- CRUD: CREATE INITIAL IDENTITY ---
  Future<UserProfile> saveInitialIdentity({
    required String displayName,
    required String handle,
    String? avatarUrl,
    String? statusMessage,
    String? recoveryCode,
  }) async {
    final cleanHandle = handle.startsWith('@') ? handle : '@$handle';
    final code = recoveryCode ?? generateRecoveryCode();
    final profile = UserProfile(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}',
      displayName: displayName.trim(),
      handle: cleanHandle.trim(),
      avatarUrl: avatarUrl ?? '',
      statusMessage: (statusMessage != null && statusMessage.trim().isNotEmpty)
          ? statusMessage.trim()
          : "Disponible sur MRixk",
      isOnline: true,
      deviceQuotaMax: 3,
      notificationsEnabled: true,
      themeMode: 'Ivoire',
      storageUsed: '0 Mo',
      recoveryCode: code,
    );

    // Save user profile and mark identity as configured
    await _db.insert('users', profile.id, profile.toJson());
    await _db.insert('settings', 'identity_configured', {'value': true});
    IdentityDirectoryService.registerUser(SovereignUser(
      id: profile.id,
      name: profile.displayName,
      handle: profile.handle,
      avatarUrl: profile.avatarUrl,
      statusText: profile.statusMessage,
      isVerified: true,
      isOnline: true,
    ));
    await _db.saveState();
    notifyListeners();
    return profile;
  }

  // --- RESTORE FROM RECOVERY / RECONNECTION CODE ---
  Future<UserProfile?> restoreFromRecoveryCode({
    required String recoveryCode,
    String? preferredName,
    String? preferredHandle,
  }) async {
    final cleanCode = recoveryCode.trim().toUpperCase();
    if (cleanCode.length < 6) return null;

    final allUsers = _db.getAll('users');
    Map<String, dynamic>? matchingUser;

    for (final u in allUsers) {
      final code = (u['recoveryCode'] as String? ?? '').trim().toUpperCase();
      if (code.isNotEmpty && (code == cleanCode || cleanCode.contains(code))) {
        matchingUser = u;
        break;
      }
    }

    UserProfile profile;
    if (matchingUser != null) {
      profile = UserProfile.fromJson(matchingUser).copyWith(isOnline: true);
      await _db.update('users', profile.id, profile.toJson());
    } else {
      // Reconstitute sovereign identity from recovery key on fresh device
      final name = (preferredName != null && preferredName.trim().isNotEmpty)
          ? preferredName.trim()
          : 'Membre MRixk';
      var handle = (preferredHandle != null && preferredHandle.trim().isNotEmpty)
          ? preferredHandle.trim()
          : '@membre.recupere';
      if (!handle.startsWith('@')) handle = '@$handle';

      profile = UserProfile(
        id: 'user_rec_${DateTime.now().millisecondsSinceEpoch}',
        displayName: name,
        handle: handle,
        avatarUrl: '',
        statusMessage: "Session restaurée par code souverain",
        isOnline: true,
        deviceQuotaMax: 3,
        notificationsEnabled: true,
        themeMode: 'Ivoire',
        storageUsed: '0 Mo',
        recoveryCode: cleanCode,
      );
      await _db.insert('users', profile.id, profile.toJson());
    }

    await _db.insert('settings', 'identity_configured', {'value': true});
    await _db.saveState();
    notifyListeners();
    return profile;
  }

  // --- CRUD: UPDATE ---
  Future<void> updateProfile(UserProfile profile) async {
    await _db.update('users', profile.id, profile.toJson());
    IdentityDirectoryService.registerUser(SovereignUser(
      id: profile.id,
      name: profile.displayName,
      handle: profile.handle,
      avatarUrl: profile.avatarUrl,
      statusText: profile.statusMessage,
      isVerified: true,
      isOnline: true,
    ));
    notifyListeners();
  }

  Future<void> updateStatus(String newStatus) async {
    final current = getProfile();
    final updated = current.copyWith(statusMessage: newStatus);
    await updateProfile(updated);
  }

  Future<void> toggleNotifications(bool enabled) async {
    final current = getProfile();
    final updated = current.copyWith(notificationsEnabled: enabled);
    await updateProfile(updated);
  }

  Future<void> setThemeMode(String mode) async {
    final current = getProfile();
    final updated = current.copyWith(themeMode: mode);
    await updateProfile(updated);
  }

  // --- LOGOUT / SWITCH ACCOUNT ---
  Future<void> logout() async {
    await _db.delete('settings', 'identity_configured');
    final allUsers = _db.getAll('users');
    for (final u in allUsers) {
      final updated = Map<String, dynamic>.from(u);
      updated['isOnline'] = false;
      await _db.update('users', u['id'] as String, updated);
    }
    await _db.saveState();
    notifyListeners();
  }

  // --- DELETE ACCOUNT ---
  Future<void> deleteAccount() async {
    await _db.clearAll();
    await seedCleanProductionDatabase(_db);
    await _db.saveState();
    notifyListeners();
  }
}
