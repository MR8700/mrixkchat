import '../database/local_database.dart';
import '../network/api_client.dart';

/// Directory of verified sovereign users on the MRixk network.
/// ONLY genuine registered identities exist and can be discovered, added as contacts or opened as conversations.
/// Unregistered handles or unknown users are strictly rejected.
class SovereignUser {
  final String id;
  final String name;
  final String handle;
  final String avatarUrl;
  final String statusText;
  final bool isVerified;
  final bool isOnline;

  const SovereignUser({
    required this.id,
    required this.name,
    required this.handle,
    required this.avatarUrl,
    required this.statusText,
    this.isVerified = true,
    this.isOnline = true,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'handle': handle,
    'avatarUrl': avatarUrl,
    'statusText': statusText,
    'isVerified': isVerified,
    'isOnline': isOnline,
  };

  factory SovereignUser.fromJson(Map<String, dynamic> json) => SovereignUser(
    id: json['id'] as String,
    name: json['name'] as String,
    handle: json['handle'] as String,
    avatarUrl: json['avatarUrl'] as String? ?? '',
    statusText: json['statusText'] as String? ?? 'Membre du réseau souverain MRixk',
    isVerified: json['isVerified'] as bool? ?? true,
    isOnline: json['isOnline'] as bool? ?? true,
  );
}

class IdentityDirectoryService {
  /// Genuine verified sovereign users on the network (strictly starts empty in production)
  static final List<SovereignUser> registeredUsers = [];

  /// Explicitly registers or updates a user in the sovereign directory
  static void registerUser(SovereignUser user) {
    final cleanHandle = user.handle.toLowerCase();
    registeredUsers.removeWhere((u) => u.handle.toLowerCase() == cleanHandle || u.id == user.id);
    registeredUsers.add(user);
  }

  /// Synchronizes registered users from genuine local database contacts and user profile
  static void syncFromDatabase(LocalDatabase db) {
    try {
      const legacyHandles = {
        '@mrixk.richard',
        '@amine.t',
        '@aicha.o',
        '@marc.d',
        '@sophie.v',
        '@dr.kabore',
        '@idriss.t',
        '@sarah.c',
        '@toto',
      };
      registeredUsers.removeWhere((u) => legacyHandles.contains(u.handle.toLowerCase()));

      final contacts = db.getAll('contacts');
      for (final c in contacts) {
        final id = (c['id'] ?? '').toString();
        final name = (c['name'] ?? '').toString();
        final handle = (c['handle'] ?? '').toString();
        final formattedHandle = handle.startsWith('@') ? handle : '@$handle';
        if (id.isNotEmpty && handle.isNotEmpty && !legacyHandles.contains(formattedHandle.toLowerCase())) {
          registerUser(SovereignUser(
            id: id,
            name: name.isNotEmpty ? name : handle,
            handle: formattedHandle,
            avatarUrl: (c['avatarUrl'] ?? '').toString(),
            statusText: (c['statusText'] ?? 'Contact certifié').toString(),
            isVerified: c['isVerified'] == true,
            isOnline: c['isOnline'] == true,
          ));
        }
      }

      final users = db.getAll('users');
      for (final u in users) {
        final id = (u['id'] ?? '').toString();
        final name = (u['displayName'] ?? '').toString();
        final handle = (u['handle'] ?? '').toString();
        final formattedHandle = handle.startsWith('@') ? handle : '@$handle';
        if (id.isNotEmpty && handle.isNotEmpty && !legacyHandles.contains(formattedHandle.toLowerCase())) {
          registerUser(SovereignUser(
            id: id,
            name: name.isNotEmpty ? name : handle,
            handle: formattedHandle,
            avatarUrl: (u['avatarUrl'] ?? '').toString(),
            statusText: (u['statusMessage'] ?? 'Disponible').toString(),
            isVerified: true,
            isOnline: true,
          ));
        }
      }
    } catch (_) {}
  }

  /// Strictly finds a verified user by handle or name from registered users ONLY.
  /// Never fabricates or synthesizes a user. Returns null if not registered.
  static SovereignUser? findUser(String query) {
    final clean = query.trim();
    if (clean.isEmpty) return null;

    final cleanLower = clean.toLowerCase();
    final cleanHandle = cleanLower.startsWith('@') ? cleanLower : '@$cleanLower';
    final queryHandleWithoutAt = cleanLower.startsWith('@') ? cleanLower.substring(1) : cleanLower;

    for (final user in registeredUsers) {
      final userHandleLower = user.handle.toLowerCase();
      final userHandleWithoutAt = userHandleLower.startsWith('@') ? userHandleLower.substring(1) : userHandleLower;
      final userNameLower = user.name.toLowerCase();

      if (userHandleLower == cleanHandle ||
          userHandleWithoutAt == queryHandleWithoutAt ||
          userNameLower == cleanLower ||
          userNameLower.contains(cleanLower)) {
        return user;
      }
    }

    return null;
  }

  /// Strictly searches users matching a query from registered users ONLY.
  /// Never fabricates or inserts unregistered handles into results.
  static List<SovereignUser> searchUsers(String query) {
    final clean = query.trim();
    if (clean.isEmpty) return registeredUsers;

    final cleanLower = clean.toLowerCase();
    final cleanHandle = cleanLower.startsWith('@') ? cleanLower : '@$cleanLower';
    final queryHandleWithoutAt = cleanLower.startsWith('@') ? cleanLower.substring(1) : cleanLower;

    final results = <SovereignUser>[];

    for (final u in registeredUsers) {
      final uHandleLower = u.handle.toLowerCase();
      final uHandleWithoutAt = uHandleLower.startsWith('@') ? uHandleLower.substring(1) : uHandleLower;
      final uNameLower = u.name.toLowerCase();

      if (uNameLower.contains(cleanLower) ||
          uHandleLower.contains(cleanLower) ||
          uHandleLower.contains(cleanHandle) ||
          uHandleWithoutAt.contains(queryHandleWithoutAt)) {
        results.add(u);
      }
    }

    return results;
  }

  /// Discovers users online from the backend server in real-time.
  /// Automatically registers discovered verified users into the directory.
  static Future<List<SovereignUser>> searchUsersOnline(String query) async {
    try {
      final remoteUsers = await ApiClient().searchUsers(query);
      for (final u in remoteUsers) {
        final id = (u['id'] ?? '').toString();
        final name = (u['display_name'] ?? '').toString();
        final handle = (u['handle'] ?? '').toString();
        final avatar = (u['avatar_ref'] ?? u['avatar_url'] ?? '').toString();
        final status = (u['status_message'] ?? 'Membre du réseau souverain').toString();
        if (id.isNotEmpty && handle.isNotEmpty) {
          registerUser(SovereignUser(
            id: id,
            name: name.isNotEmpty ? name : handle,
            handle: handle.startsWith('@') ? handle : '@$handle',
            avatarUrl: avatar,
            statusText: status,
            isVerified: true,
            isOnline: true,
          ));
        }
      }
    } catch (_) {}
    return searchUsers(query);
  }

  /// Verifies a user against the backend server online before contact addition.
  static Future<SovereignUser?> verifyUserOnline(String query) async {
    // 1. Check local directory first
    final local = findUser(query);
    if (local != null) return local;

    // 2. Query online server
    try {
      final res = await ApiClient().verifyContact(query);
      if (res != null && res['valid'] == true && res['user'] != null) {
        final u = res['user'] as Map<String, dynamic>;
        final user = SovereignUser(
          id: (u['id'] ?? '').toString(),
          name: (u['display_name'] ?? '').toString(),
          handle: (u['handle'] ?? '').toString(),
          avatarUrl: (u['avatar_ref'] ?? u['avatar_url'] ?? '').toString(),
          statusText: (u['status_message'] ?? 'Membre du réseau souverain').toString(),
          isVerified: true,
          isOnline: true,
        );
        registerUser(user);
        return user;
      }
    } catch (_) {}

    return null;
  }
}
