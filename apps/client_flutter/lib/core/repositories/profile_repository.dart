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

    Exception? onlineError;

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
          displayName: (u['display_name'] ?? preferredName ?? '').toString(),
          handle: (u['handle'] ?? preferredHandle ?? '').toString(),
          avatarUrl: (u['avatar_ref'] ?? u['avatar_url'] ?? '').toString(),
          statusMessage: (u['status_message'] ?? 'Disponible').toString(),
          isOnline: true,
          deviceQuotaMax: 3,
          notificationsEnabled: true,
          themeMode: 'Ivoire',
          storageUsed: '0 Mo',
          recoveryCode: cleanCode,
        );

        if (profile.displayName.isNotEmpty && profile.handle.isNotEmpty) {
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
      }
    } catch (e) {
      if (e is Exception) onlineError = e;
    }

    // 2. Local fallback if previously stored on this exact terminal
    final keyRecord = _db.get('recovery_keys', cleanCode);
    if (keyRecord != null) {
      final name = (keyRecord['displayName'] ?? '').toString();
      final handle = (keyRecord['handle'] ?? '').toString();
      final avatar = (keyRecord['avatarUrl'] ?? '').toString();
      final status = (keyRecord['statusMessage'] ?? 'Disponible').toString();

      if (name.isNotEmpty && handle.isNotEmpty && handle != '@utilisateur') {
        final profile = UserProfile(
          id: (keyRecord['id'] ?? 'usr_rec_${DateTime.now().millisecondsSinceEpoch}').toString(),
          displayName: name,
          handle: handle,
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
    }

    // 3. Check users table
    final allUsers = _db.getAll('users');
    for (final u in allUsers) {
      final code = (u['recoveryCode'] as String? ?? '').trim().toUpperCase();
      if (code.isNotEmpty && (code == cleanCode || cleanCode.contains(code))) {
        final profile = UserProfile.fromJson(u).copyWith(isOnline: true);
        if (profile.handle != '@utilisateur') {
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
    }

    // STRICTLY NEVER invent dummy '@utilisateur' or 'Utilisateur'!
    if (onlineError != null) throw onlineError;
    throw Exception('Code de secours introuvable sur le serveur ($cleanCode).');
  }

  // --- CRUD: UPDATE (Handle is strictly immutable) ---
  Future<void> updateProfile(UserProfile profile) async {
    final current = getProfile();
    // Enforce that the sovereign handle with @ can NEVER be modified!
    final safeProfile = profile.copyWith(handle: current.handle);
    await _db.update('users', safeProfile.id, safeProfile.toJson());
    IdentityDirectoryService.registerUser(SovereignUser(
      id: safeProfile.id,
      name: safeProfile.displayName,
      handle: safeProfile.handle,
      avatarUrl: safeProfile.avatarUrl,
      statusText: safeProfile.statusMessage,
      isVerified: true,
      isOnline: true,
    ));

    // Synchronize to the backend server so all devices of this user are identical
    ApiClient().updateProfile(
      userId: safeProfile.id,
      displayName: safeProfile.displayName,
      avatarUrl: safeProfile.avatarUrl,
      statusMessage: safeProfile.statusMessage,
    );

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
