enum CallDirection { outgoing, incoming, missed }

class CallLog {
  final String id;
  final String peerName;
  final String peerAvatar;
  final bool isVideo;
  final CallDirection direction;
  final String timestamp;
  final String duration;
  final bool isEncrypted;

  const CallLog({
    required this.id,
    required this.peerName,
    required this.peerAvatar,
    required this.isVideo,
    required this.direction,
    required this.timestamp,
    required this.duration,
    this.isEncrypted = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'peerName': peerName,
        'peerAvatar': peerAvatar,
        'isVideo': isVideo,
        'direction': direction.name,
        'timestamp': timestamp,
        'duration': duration,
        'isEncrypted': isEncrypted,
      };

  factory CallLog.fromJson(Map<String, dynamic> json) => CallLog(
        id: json['id'] as String,
        peerName: json['peerName'] as String,
        peerAvatar: json['peerAvatar'] as String? ?? '',
        isVideo: json['isVideo'] as bool? ?? false,
        direction: CallDirection.values.firstWhere(
          (d) => d.name == json['direction'],
          orElse: () => CallDirection.outgoing,
        ),
        timestamp: json['timestamp'] as String? ?? '',
        duration: json['duration'] as String? ?? '00:00',
        isEncrypted: json['isEncrypted'] as bool? ?? true,
      );
}
