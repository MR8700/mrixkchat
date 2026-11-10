class Conversation {
  final String id;
  final String title;
  final String peerAvatar;
  final bool isGroup;
  final int groupMembersCount;
  final bool isOnline;
  final bool isVerified;
  final String lastMessage;
  final String lastMessageTime;
  final int unreadCount;
  final bool hasVoiceNote;
  final String? voiceNoteDuration;
  final bool hasDocument;
  final String? tagText;
  final bool isFavorite;
  final bool isPinned;
  final bool isArchived;
  final bool isBlocked;
  final String? blockedMessage;

  Conversation({
    required this.id,
    required this.title,
    required this.peerAvatar,
    this.isGroup = false,
    this.groupMembersCount = 1,
    this.isOnline = false,
    this.isVerified = false,
    required this.lastMessage,
    required this.lastMessageTime,
    this.unreadCount = 0,
    this.hasVoiceNote = false,
    this.voiceNoteDuration,
    this.hasDocument = false,
    this.tagText,
    this.isFavorite = false,
    this.isPinned = false,
    this.isArchived = false,
    this.isBlocked = false,
    this.blockedMessage,
  });

  Conversation copyWith({
    String? id,
    String? title,
    String? peerAvatar,
    bool? isGroup,
    int? groupMembersCount,
    bool? isOnline,
    bool? isVerified,
    String? lastMessage,
    String? lastMessageTime,
    int? unreadCount,
    bool? hasVoiceNote,
    String? voiceNoteDuration,
    bool? hasDocument,
    String? tagText,
    bool? isFavorite,
    bool? isPinned,
    bool? isArchived,
    bool? isBlocked,
    String? blockedMessage,
  }) {
    return Conversation(
      id: id ?? this.id,
      title: title ?? this.title,
      peerAvatar: peerAvatar ?? this.peerAvatar,
      isGroup: isGroup ?? this.isGroup,
      groupMembersCount: groupMembersCount ?? this.groupMembersCount,
      isOnline: isOnline ?? this.isOnline,
      isVerified: isVerified ?? this.isVerified,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      unreadCount: unreadCount ?? this.unreadCount,
      hasVoiceNote: hasVoiceNote ?? this.hasVoiceNote,
      voiceNoteDuration: voiceNoteDuration ?? this.voiceNoteDuration,
      hasDocument: hasDocument ?? this.hasDocument,
      tagText: tagText ?? this.tagText,
      isFavorite: isFavorite ?? this.isFavorite,
      isPinned: isPinned ?? this.isPinned,
      isArchived: isArchived ?? this.isArchived,
      isBlocked: isBlocked ?? this.isBlocked,
      blockedMessage: blockedMessage ?? this.blockedMessage,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'peerAvatar': peerAvatar,
    'isGroup': isGroup,
    'groupMembersCount': groupMembersCount,
    'isOnline': isOnline,
    'isVerified': isVerified,
    'lastMessage': lastMessage,
    'lastMessageTime': lastMessageTime,
    'unreadCount': unreadCount,
    'hasVoiceNote': hasVoiceNote,
    'voiceNoteDuration': voiceNoteDuration,
    'hasDocument': hasDocument,
    'tagText': tagText,
    'isFavorite': isFavorite,
    'isPinned': isPinned,
    'isArchived': isArchived,
    'isBlocked': isBlocked,
    'blockedMessage': blockedMessage,
  };

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
    id: json['id'] as String,
    title: json['title'] as String,
    peerAvatar: json['peerAvatar'] as String,
    isGroup: json['isGroup'] as bool? ?? false,
    groupMembersCount: json['groupMembersCount'] as int? ?? 1,
    isOnline: json['isOnline'] as bool? ?? false,
    isVerified: json['isVerified'] as bool? ?? false,
    lastMessage: json['lastMessage'] as String,
    lastMessageTime: json['lastMessageTime'] as String,
    unreadCount: json['unreadCount'] as int? ?? 0,
    hasVoiceNote: json['hasVoiceNote'] as bool? ?? false,
    voiceNoteDuration: json['voiceNoteDuration'] as String?,
    hasDocument: json['hasDocument'] as bool? ?? false,
    tagText: json['tagText'] as String?,
    isFavorite: json['isFavorite'] as bool? ?? false,
    isPinned: json['isPinned'] as bool? ?? false,
    isArchived: json['isArchived'] as bool? ?? false,
    isBlocked: json['isBlocked'] as bool? ?? false,
    blockedMessage: json['blockedMessage'] as String?,
  );
}
