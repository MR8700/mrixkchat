class Device {
  final String id;
  final String name;
  final String platform;
  final String status; // 'ACTIVE', 'REVOKED'
  final String lastSeenText;
  final bool isCurrentDevice;
  final String iconType; // 'phone', 'laptop', 'tablet'
  final String pairingCode;

  Device({
    required this.id,
    required this.name,
    required this.platform,
    required this.status,
    required this.lastSeenText,
    this.isCurrentDevice = false,
    this.iconType = 'phone',
    this.pairingCode = 'MRX-SEC-8F2B-914A',
  });

  Device copyWith({
    String? id,
    String? name,
    String? platform,
    String? status,
    String? lastSeenText,
    bool? isCurrentDevice,
    String? iconType,
    String? pairingCode,
  }) {
    return Device(
      id: id ?? this.id,
      name: name ?? this.name,
      platform: platform ?? this.platform,
      status: status ?? this.status,
      lastSeenText: lastSeenText ?? this.lastSeenText,
      isCurrentDevice: isCurrentDevice ?? this.isCurrentDevice,
      iconType: iconType ?? this.iconType,
      pairingCode: pairingCode ?? this.pairingCode,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'platform': platform,
    'status': status,
    'lastSeenText': lastSeenText,
    'isCurrentDevice': isCurrentDevice,
    'iconType': iconType,
    'pairingCode': pairingCode,
  };

  factory Device.fromJson(Map<String, dynamic> json) => Device(
    id: json['id'] as String,
    name: json['name'] as String,
    platform: json['platform'] as String,
    status: json['status'] as String? ?? 'ACTIVE',
    lastSeenText: json['lastSeenText'] as String,
    isCurrentDevice: json['isCurrentDevice'] as bool? ?? false,
    iconType: json['iconType'] as String? ?? 'phone',
    pairingCode: json['pairingCode'] as String? ?? 'MRX-SEC-8F2B-914A',
  );
}
