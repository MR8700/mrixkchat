class UserProfile {
  final String id;
  final String displayName;
  final String handle;
  final String avatarUrl;
  final String statusMessage;
  final bool isOnline;
  final int deviceQuotaMax;
  final bool notificationsEnabled;
  final String themeMode; // 'Ivoire', 'Nuit'
  final String storageUsed;
  final String? recoveryCode;

  UserProfile({
    required this.id,
    required this.displayName,
    required this.handle,
    required this.avatarUrl,
    required this.statusMessage,
    this.isOnline = true,
    this.deviceQuotaMax = 3,
    this.notificationsEnabled = true,
    this.themeMode = 'Ivoire',
    this.storageUsed = '1.2 Go',
    this.recoveryCode,
  });

  UserProfile copyWith({
    String? id,
    String? displayName,
    String? handle,
    String? avatarUrl,
    String? statusMessage,
    bool? isOnline,
    int? deviceQuotaMax,
    bool? notificationsEnabled,
    String? themeMode,
    String? storageUsed,
    String? recoveryCode,
  }) {
    return UserProfile(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      handle: handle ?? this.handle,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      statusMessage: statusMessage ?? this.statusMessage,
      isOnline: isOnline ?? this.isOnline,
      deviceQuotaMax: deviceQuotaMax ?? this.deviceQuotaMax,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      themeMode: themeMode ?? this.themeMode,
      storageUsed: storageUsed ?? this.storageUsed,
      recoveryCode: recoveryCode ?? this.recoveryCode,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'displayName': displayName,
    'handle': handle,
    'avatarUrl': avatarUrl,
    'statusMessage': statusMessage,
    'isOnline': isOnline,
    'deviceQuotaMax': deviceQuotaMax,
    'notificationsEnabled': notificationsEnabled,
    'themeMode': themeMode,
    'storageUsed': storageUsed,
    'recoveryCode': recoveryCode,
  };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    id: json['id'] as String,
    displayName: json['displayName'] as String,
    handle: json['handle'] as String,
    avatarUrl: json['avatarUrl'] as String,
    statusMessage: json['statusMessage'] as String,
    isOnline: json['isOnline'] as bool? ?? true,
    deviceQuotaMax: json['deviceQuotaMax'] as int? ?? 3,
    notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
    themeMode: json['themeMode'] as String? ?? 'Ivoire',
    storageUsed: json['storageUsed'] as String? ?? '1.2 Go',
    recoveryCode: json['recoveryCode'] as String?,
  );
}
