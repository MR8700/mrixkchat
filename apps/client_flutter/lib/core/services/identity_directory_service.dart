/// Directory of verified sovereign users on the MRixk network.
/// Only genuinely registered identities can be added as contacts or new conversations.
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
    this.isOnline = false,
  });
}

class IdentityDirectoryService {
  static final List<SovereignUser> registeredUsers = [];

  /// Verifies if a user exists by handle or name
  static SovereignUser? findUser(String query) {
    final clean = query.trim().toLowerCase();
    if (clean.isEmpty) return null;

    final cleanHandle = clean.startsWith('@') ? clean : '@$clean';

    for (final user in registeredUsers) {
      if (user.handle.toLowerCase() == cleanHandle ||
          user.handle.toLowerCase() == clean ||
          user.name.toLowerCase() == clean ||
          user.name.toLowerCase().contains(clean)) {
        return user;
      }
    }
    return null;
  }

  /// Searches users matching a query
  static List<SovereignUser> searchUsers(String query) {
    final clean = query.trim().toLowerCase();
    if (clean.isEmpty) return registeredUsers;

    final cleanHandle = clean.startsWith('@') ? clean : '@$clean';
    return registeredUsers.where((u) {
      return u.name.toLowerCase().contains(clean) ||
          u.handle.toLowerCase().contains(clean) ||
          u.handle.toLowerCase().contains(cleanHandle);
    }).toList();
  }
}
