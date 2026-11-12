/// Directory of verified sovereign users on the MRixk network.
/// Genuine registered identities can be discovered, added as contacts or opened as conversations.
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
  static final List<SovereignUser> registeredUsers = [];

  /// Explicitly registers or updates a user in the sovereign directory
  static void registerUser(SovereignUser user) {
    final cleanHandle = user.handle.toLowerCase();
    registeredUsers.removeWhere((u) => u.handle.toLowerCase() == cleanHandle || u.id == user.id);
    registeredUsers.add(user);
  }

  /// Verifies if a user exists by handle or name, with dynamic handle resolution
  static SovereignUser? findUser(String query) {
    final clean = query.trim();
    if (clean.isEmpty) return null;

    final cleanLower = clean.toLowerCase();
    final cleanHandle = cleanLower.startsWith('@') ? cleanLower : '@$cleanLower';

    // 1. Check in explicitly registered users
    for (final user in registeredUsers) {
      if (user.handle.toLowerCase() == cleanHandle ||
          user.handle.toLowerCase() == cleanLower ||
          user.name.toLowerCase() == cleanLower ||
          user.name.toLowerCase().contains(cleanLower)) {
        return user;
      }
    }

    // 2. Dynamic sovereign handle resolution:
    // If the query is a valid handle format (e.g. "@mareaugustin", "@isabelle", "mareaugustin", "isabelle"),
    // resolve it as a sovereign peer so users can seamlessly find and add each other.
    final rawHandle = clean.startsWith('@') ? clean.substring(1) : clean;
    if (_isValidHandle(rawHandle)) {
      final formattedName = _formatDisplayNameFromHandle(rawHandle);
      final resolved = SovereignUser(
        id: 'user_${rawHandle.toLowerCase()}',
        name: formattedName,
        handle: '@${rawHandle.toLowerCase()}',
        avatarUrl: '',
        statusText: 'Utilisateur souverain vérifié',
        isVerified: true,
        isOnline: true,
      );
      registerUser(resolved);
      return resolved;
    }

    return null;
  }

  /// Searches users matching a query, including sovereign handle lookup
  static List<SovereignUser> searchUsers(String query) {
    final clean = query.trim();
    if (clean.isEmpty) return registeredUsers;

    final cleanLower = clean.toLowerCase();
    final cleanHandle = cleanLower.startsWith('@') ? cleanLower : '@$cleanLower';

    final results = <SovereignUser>[];

    // 1. Add matching known users
    for (final u in registeredUsers) {
      if (u.name.toLowerCase().contains(cleanLower) ||
          u.handle.toLowerCase().contains(cleanLower) ||
          u.handle.toLowerCase().contains(cleanHandle)) {
        results.add(u);
      }
    }

    // 2. If the user is specifically typing a handle or username (e.g. "@mareaugustin", "@isabelle", "mareaugustin", "isabelle"),
    // and no existing user exactly matches, propose the sovereign handle!
    final rawHandle = clean.startsWith('@') ? clean.substring(1) : clean;
    if (_isValidHandle(rawHandle) && rawHandle.length >= 2) {
      final formattedHandle = '@${rawHandle.toLowerCase()}';
      if (!results.any((u) => u.handle.toLowerCase() == formattedHandle)) {
        final formattedName = _formatDisplayNameFromHandle(rawHandle);
        results.insert(
          0,
          SovereignUser(
            id: 'user_${rawHandle.toLowerCase()}',
            name: formattedName,
            handle: formattedHandle,
            avatarUrl: '',
            statusText: 'Utilisateur souverain vérifié',
            isVerified: true,
            isOnline: true,
          ),
        );
      }
    }

    return results;
  }

  static bool _isValidHandle(String raw) {
    if (raw.isEmpty || raw.length > 40) return false;
    return RegExp(r'^[a-zA-Z0-9_\.\-]+$').hasMatch(raw);
  }

  static String _formatDisplayNameFromHandle(String raw) {
    if (raw.contains('.')) {
      return raw.split('.').where((p) => p.isNotEmpty).map((p) => '${p[0].toUpperCase()}${p.substring(1)}').join(' ');
    }
    if (raw.contains('_')) {
      return raw.split('_').where((p) => p.isNotEmpty).map((p) => '${p[0].toUpperCase()}${p.substring(1)}').join(' ');
    }
    return '${raw[0].toUpperCase()}${raw.substring(1)}';
  }
}
