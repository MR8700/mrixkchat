import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../database/database_seed.dart';
import '../database/local_database.dart';
import '../models/user_profile.dart';
import '../network/api_client.dart';
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

  // --- CRUD: CREATE INITIAL IDENTITY (ONLINE FIRST) ---
  Future<UserProfile> saveInitialIdentity({
    required String displayName,
    required String handle,
    String? avatarUrl,
    String? statusMessage,
    String? recoveryCode,
  }) async {
    final cleanHandle = handle.startsWith('@') ? handle : '@$handle';
    final code = recoveryCode ?? generateRecoveryCode();
    final cleanName = displayName.trim();
    final cleanStatus = (statusMessage != null && statusMessage.trim().isNotEmpty)
        ? statusMessage.trim()
        : "Disponible sur MRixk";

    // 1. ONLINE-FIRST: Register on backend server before saving locally
    String serverUserId = 'usr_${DateTime.now().millisecondsSinceEpoch}';
    String officialHandle = cleanHandle.trim();
    String officialCode = code;

    try {
      final res = await ApiClient().register(
        handle: officialHandle,
        displayName: cleanName,
        recoveryCode: officialCode,
        avatarUrl: avatarUrl,
        statusMessage: cleanStatus,
      );
      if (res != null && res['user'] != null) {
        final u = res['user'] as Map<String, dynamic>;
        serverUserId = (u['id'] ?? serverUserId).toString();
        officialHandle = (u['handle'] ?? officialHandle).toString();
        officialCode = (u['recovery_code'] ?? officialCode).toString();
      }
    } catch (e) {
      rethrow;
    }

    final profile = UserProfile(
      id: serverUserId,
      displayName: cleanName,
      handle: officialHandle,
      avatarUrl: avatarUrl ?? '',
      statusMessage: cleanStatus,
      isOnline: true,
      deviceQuotaMax: 3,
      notificationsEnabled: true,
      themeMode: 'Ivoire',
      storageUsed: '0 Mo',
      recoveryCode: officialCode,
    );

    // 2. Persist locally only AFTER online server confirmation
    await _db.insert('users', profile.id, profile.toJson());
    await _db.insert('settings', 'identity_configured', {'value': true});
    await _db.insert('recovery_keys', officialCode, {
      'id': profile.id,
      'displayName': profile.displayName,
      'handle': profile.handle,
      'avatarUrl': profile.avatarUrl,
      'statusMessage': profile.statusMessage,
      'recoveryCode': officialCode,
    });
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

  // --- RESTORE FROM RECOVERY / RECONNECTION CODE (ONLINE FIRST) ---
  Future<UserProfile?> restoreFromRecoveryCode({
    required String recoveryCode,
    String? preferredName,
    String? preferredHandle,
  }) async {
    final cleanCode = recoveryCode.trim().toUpperCase();
    if (cleanCode.length < 6) return null;

    // 1. ONLINE-FIRST: Verify against backend server online
    try {
      final res = await ApiClient().recover(
        recoveryCode: cleanCode,
        preferredName: preferredName,
        preferredHandle: preferredHandle,
      );
      if (res != null && res['user'] != null) {
        final u = res['user'] as Map<String, dynamic>;
        final profile = UserProfile(
          id: (u['id'] ?? 'usr_${DateTime.now().millisecondsSinceEpoch}').toString(),
          displayName: (u['display_name'] ?? preferredName ?? 'Utilisateur').toString(),
          handle: (u['handle'] ?? preferredHandle ?? '@utilisateur').toString(),
          avatarUrl: (u['avatar_ref'] ?? u['avatar_url'] ?? '').toString(),
          statusMessage: (u['status_message'] ?? 'Session restaurée par code souverain').toString(),
          isOnline: true,
          deviceQuotaMax: 3,
          notificationsEnabled: true,
          themeMode: 'Ivoire',
          storageUsed: '0 Mo',
          recoveryCode: cleanCode,
        );

        await _db.insert('users', profile.id, profile.toJson());
        await _db.insert('settings', 'identity_configured', {'value': true});
        await _db.insert('recovery_keys', cleanCode, {
          'id': profile.id,
          'displayName': profile.displayName,
          'handle': profile.handle,
          'avatarUrl': profile.avatarUrl,
          'statusMessage': profile.statusMessage,
          'recoveryCode': cleanCode,
        });
        await _db.saveState();
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
        return profile;
      }
    } catch (_) {}

    // 2. Check local recovery_keys table
    final keyRecord = _db.get('recovery_keys', cleanCode);
    if (keyRecord != null) {
      final name = (keyRecord['displayName'] ?? '').toString();
      final handle = (keyRecord['handle'] ?? '').toString();
      final avatar = (keyRecord['avatarUrl'] ?? '').toString();
      final status = (keyRecord['statusMessage'] ?? 'Disponible sur MRixk').toString();

      final profile = UserProfile(
        id: (keyRecord['id'] ?? 'user_rec_${DateTime.now().millisecondsSinceEpoch}').toString(),
        displayName: name.isNotEmpty ? name : (preferredName?.trim().isNotEmpty == true ? preferredName!.trim() : 'Utilisateur'),
        handle: handle.isNotEmpty ? handle : (preferredHandle?.trim().isNotEmpty == true ? preferredHandle!.trim() : '@utilisateur'),
        avatarUrl: avatar,
        statusMessage: status,
        isOnline: true,
        deviceQuotaMax: 3,
        notificationsEnabled: true,
        themeMode: 'Ivoire',
        storageUsed: '0 Mo',
        recoveryCode: cleanCode,
      );
      await _db.insert('users', profile.id, profile.toJson());
      await _db.insert('settings', 'identity_configured', {'value': true});
      await _db.saveState();
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
      return profile;
    }

    // 3. Check users table
    final allUsers = _db.getAll('users');
    for (final u in allUsers) {
      final code = (u['recoveryCode'] as String? ?? '').trim().toUpperCase();
      if (code.isNotEmpty && (code == cleanCode || cleanCode.contains(code))) {
        final profile = UserProfile.fromJson(u).copyWith(isOnline: true);
        await _db.update('users', profile.id, profile.toJson());
        await _db.insert('settings', 'identity_configured', {'value': true});
        await _db.saveState();
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
        return profile;
      }
    }

    // 4. Fallback from input parameters if online and local both unavailable
    String name = (preferredName ?? '').trim();
    String handle = (preferredHandle ?? '').trim();

    if (name.isNotEmpty && handle.isEmpty) {
      if (name.startsWith('@')) {
        handle = name;
        final raw = name.substring(1);
        name = raw.contains('.')
            ? raw.split('.').map((p) => p.isNotEmpty ? '${p[0].toUpperCase()}${p.substring(1)}' : '').join(' ')
            : (raw.isNotEmpty ? '${raw[0].toUpperCase()}${raw.substring(1)}' : 'Membre');
      } else {
        handle = '@${name.toLowerCase().replaceAll(' ', '.')}';
      }
    } else if (handle.isNotEmpty && name.isEmpty) {
      final raw = handle.startsWith('@') ? handle.substring(1) : handle;
      name = raw.contains('.')
          ? raw.split('.').map((p) => p.isNotEmpty ? '${p[0].toUpperCase()}${p.substring(1)}' : '').join(' ')
          : (raw.isNotEmpty ? '${raw[0].toUpperCase()}${raw.substring(1)}' : 'Membre');
    }

    if (handle.isEmpty && name.isEmpty) {
      return null;
    }

    if (!handle.startsWith('@')) handle = '@$handle';

    final profile = UserProfile(
      id: 'usr_rec_${DateTime.now().millisecondsSinceEpoch}',
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
    await _db.insert('recovery_keys', cleanCode, {
      'id': profile.id,
      'displayName': profile.displayName,
      'handle': profile.handle,
      'avatarUrl': profile.avatarUrl,
      'statusMessage': profile.statusMessage,
      'recoveryCode': cleanCode,
    });
    await _db.insert('settings', 'identity_configured', {'value': true});
    await _db.saveState();
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
