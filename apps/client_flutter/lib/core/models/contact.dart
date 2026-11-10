class Contact {
  final String id;
  final String name;
  final String handle;
  final String avatarUrl;
  final String statusText;
  final bool isOnline;
  final bool isVerified;
  final bool isFavorite;
  final bool isBlocked;
  final String? blockedUntil; // '24 heures', '7 jours', '30 jours', 'Définitif'
  final DateTime? blockedAt;
  final String? blockedReason;
  final String category; // 'A', 'D', 'S', etc.

  Contact({
    required this.id,
    required this.name,
    required this.handle,
    required this.avatarUrl,
    required this.statusText,
    this.isOnline = false,
    this.isVerified = false,
    this.isFavorite = false,
    this.isBlocked = false,
    this.blockedUntil,
    this.blockedAt,
    this.blockedReason,
    required this.category,
  });

  Contact copyWith({
    String? id,
    String? name,
    String? handle,
    String? avatarUrl,
    String? statusText,
    bool? isOnline,
    bool? isVerified,
    bool? isFavorite,
    bool? isBlocked,
    String? blockedUntil,
    DateTime? blockedAt,
    String? blockedReason,
    String? category,
  }) {
    return Contact(
      id: id ?? this.id,
      name: name ?? this.name,
      handle: handle ?? this.handle,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      statusText: statusText ?? this.statusText,
      isOnline: isOnline ?? this.isOnline,
      isVerified: isVerified ?? this.isVerified,
      isFavorite: isFavorite ?? this.isFavorite,
      isBlocked: isBlocked ?? this.isBlocked,
      blockedUntil: blockedUntil ?? this.blockedUntil,
      blockedAt: blockedAt ?? this.blockedAt,
      blockedReason: blockedReason ?? this.blockedReason,
      category: category ?? this.category,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'handle': handle,
    'avatarUrl': avatarUrl,
    'statusText': statusText,
    'isOnline': isOnline,
    'isVerified': isVerified,
    'isFavorite': isFavorite,
    'isBlocked': isBlocked,
    'blockedUntil': blockedUntil,
    'blockedAt': blockedAt?.toIso8601String(),
    'blockedReason': blockedReason,
    'category': category,
  };

  factory Contact.fromJson(Map<String, dynamic> json) => Contact(
    id: json['id'] as String,
    name: json['name'] as String,
    handle: json['handle'] as String,
    avatarUrl: json['avatarUrl'] as String? ?? '',
    statusText: json['statusText'] as String? ?? '',
    isOnline: json['isOnline'] as bool? ?? false,
    isVerified: json['isVerified'] as bool? ?? false,
    isFavorite: json['isFavorite'] as bool? ?? false,
    isBlocked: json['isBlocked'] as bool? ?? false,
    blockedUntil: json['blockedUntil'] as String?,
    blockedAt: json['blockedAt'] != null ? DateTime.tryParse(json['blockedAt'] as String) : null,
    blockedReason: json['blockedReason'] as String?,
    category: json['category'] as String? ?? 'A',
  );
}
