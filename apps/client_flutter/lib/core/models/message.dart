enum MessageType {
  text,
  voice,
  document,
  image,
  video,
}

class Message {
  final String id;
  final String conversationId;
  final String senderId;
  final String senderName;
  final String senderAvatar;
  final MessageType type;
  final String content;
  final String time;
  final bool isOutgoing;
  final bool isRead;
  final bool isVerifiedSignature;
  
  // Voice note attributes
  final String? voiceDuration;
  final String? voiceTranscription;
  final List<double>? waveform;

  // Video attributes
  final String? videoUri;
  final String? videoDuration;

  // Document attributes
  final String? fileName;
  final String? fileSize;
  final String? fileType;

  // Visual/Image attributes
  final String? imageUri;

  // Status & Edit flags
  final bool isEdited;
  final bool isViewOnce;
  final bool isViewOnceOpened;

  // Deletion attributes
  final bool isDeletedForEveryone;
  final String? deletionReason;
  final String? deletedByName;

  // Reply / Quote attributes
  final String? replyToMessageId;
  final String? replyToText;
  final String? replyToSender;

  // Forwarded flag
  final bool isForwarded;

  // Reactions: emoji -> count (e.g. {'👍': 1, '✨': 1})
  final Map<String, int> reactions;

  Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    required this.senderAvatar,
    required this.type,
    required this.content,
    required this.time,
    this.isOutgoing = false,
    this.isRead = true,
    this.isVerifiedSignature = true,
    this.voiceDuration,
    this.voiceTranscription,
    this.waveform,
    this.videoUri,
    this.videoDuration,
    this.fileName,
    this.fileSize,
    this.fileType,
    this.imageUri,
    this.isEdited = false,
    this.isViewOnce = false,
    this.isViewOnceOpened = false,
    this.isDeletedForEveryone = false,
    this.deletionReason,
    this.deletedByName,
    this.replyToMessageId,
    this.replyToText,
    this.replyToSender,
    this.isForwarded = false,
    Map<String, int>? reactions,
  }) : reactions = reactions ?? {};

  Message copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? senderName,
    String? senderAvatar,
    MessageType? type,
    String? content,
    String? time,
    bool? isOutgoing,
    bool? isRead,
    bool? isVerifiedSignature,
    String? voiceDuration,
    String? voiceTranscription,
    List<double>? waveform,
    String? videoUri,
    String? videoDuration,
    String? fileName,
    String? fileSize,
    String? fileType,
    String? imageUri,
    bool? isEdited,
    bool? isViewOnce,
    bool? isViewOnceOpened,
    bool? isDeletedForEveryone,
    String? deletionReason,
    String? deletedByName,
    String? replyToMessageId,
    String? replyToText,
    String? replyToSender,
    bool? isForwarded,
    Map<String, int>? reactions,
  }) {
    return Message(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderAvatar: senderAvatar ?? this.senderAvatar,
      type: type ?? this.type,
      content: content ?? this.content,
      time: time ?? this.time,
      isOutgoing: isOutgoing ?? this.isOutgoing,
      isRead: isRead ?? this.isRead,
      isVerifiedSignature: isVerifiedSignature ?? this.isVerifiedSignature,
      voiceDuration: voiceDuration ?? this.voiceDuration,
      voiceTranscription: voiceTranscription ?? this.voiceTranscription,
      waveform: waveform ?? this.waveform,
      videoUri: videoUri ?? this.videoUri,
      videoDuration: videoDuration ?? this.videoDuration,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      fileType: fileType ?? this.fileType,
      imageUri: imageUri ?? this.imageUri,
      isEdited: isEdited ?? this.isEdited,
      isViewOnce: isViewOnce ?? this.isViewOnce,
      isViewOnceOpened: isViewOnceOpened ?? this.isViewOnceOpened,
      isDeletedForEveryone: isDeletedForEveryone ?? this.isDeletedForEveryone,
      deletionReason: deletionReason ?? this.deletionReason,
      deletedByName: deletedByName ?? this.deletedByName,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      replyToText: replyToText ?? this.replyToText,
      replyToSender: replyToSender ?? this.replyToSender,
      isForwarded: isForwarded ?? this.isForwarded,
      reactions: reactions ?? Map<String, int>.from(this.reactions),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'conversationId': conversationId,
    'senderId': senderId,
    'senderName': senderName,
    'senderAvatar': senderAvatar,
    'type': type.name,
    'content': content,
    'time': time,
    'isOutgoing': isOutgoing,
    'isRead': isRead,
    'isVerifiedSignature': isVerifiedSignature,
    'voiceDuration': voiceDuration,
    'voiceTranscription': voiceTranscription,
    'waveform': waveform,
    'videoUri': videoUri,
    'videoDuration': videoDuration,
    'fileName': fileName,
    'fileSize': fileSize,
    'fileType': fileType,
    'imageUri': imageUri,
    'isEdited': isEdited,
    'isViewOnce': isViewOnce,
    'isViewOnceOpened': isViewOnceOpened,
    'isDeletedForEveryone': isDeletedForEveryone,
    'deletionReason': deletionReason,
    'deletedByName': deletedByName,
    'replyToMessageId': replyToMessageId,
    'replyToText': replyToText,
    'replyToSender': replyToSender,
    'isForwarded': isForwarded,
    'reactions': reactions,
  };

  factory Message.fromJson(Map<String, dynamic> json) => Message(
    id: json['id'] as String,
    conversationId: json['conversationId'] as String,
    senderId: json['senderId'] as String,
    senderName: json['senderName'] as String,
    senderAvatar: json['senderAvatar'] as String,
    type: MessageType.values.firstWhere(
      (e) => e.name == json['type'],
      orElse: () => MessageType.text,
    ),
    content: json['content'] as String,
    time: json['time'] as String,
    isOutgoing: json['isOutgoing'] as bool? ?? false,
    isRead: json['isRead'] as bool? ?? true,
    isVerifiedSignature: json['isVerifiedSignature'] as bool? ?? true,
    voiceDuration: json['voiceDuration'] as String?,
    voiceTranscription: json['voiceTranscription'] as String?,
    waveform: (json['waveform'] as List<dynamic>?)?.map((e) => (e as num).toDouble()).toList(),
    videoUri: json['videoUri'] as String?,
    videoDuration: json['videoDuration'] as String?,
    fileName: json['fileName'] as String?,
    fileSize: json['fileSize'] as String?,
    fileType: json['fileType'] as String?,
    imageUri: json['imageUri'] as String?,
    isEdited: json['isEdited'] as bool? ?? false,
    isViewOnce: json['isViewOnce'] as bool? ?? false,
    isViewOnceOpened: json['isViewOnceOpened'] as bool? ?? false,
    isDeletedForEveryone: json['isDeletedForEveryone'] as bool? ?? false,
    deletionReason: json['deletionReason'] as String?,
    deletedByName: json['deletedByName'] as String?,
    replyToMessageId: json['replyToMessageId'] as String?,
    replyToText: json['replyToText'] as String?,
    replyToSender: json['replyToSender'] as String?,
    isForwarded: json['isForwarded'] as bool? ?? false,
    reactions: (json['reactions'] as Map<String, dynamic>?)?.map(
      (k, v) => MapEntry(k, v as int),
    ),
  );
}
