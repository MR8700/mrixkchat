class GroupMember {
  final String id;
  final String name;
  final String handle;
  final String avatarUrl;
  final String role; // 'creator', 'admin', 'member'
  final bool isMuted;

  const GroupMember({
    required this.id,
    required this.name,
    this.handle = '',
    this.avatarUrl = '',
    this.role = 'member',
    this.isMuted = false,
  });

  bool get isCreator => role == 'creator';
  bool get isAdmin => role == 'admin' || role == 'creator';

  GroupMember copyWith({
    String? id,
    String? name,
    String? handle,
    String? avatarUrl,
    String? role,
    bool? isMuted,
  }) {
    return GroupMember(
      id: id ?? this.id,
      name: name ?? this.name,
      handle: handle ?? this.handle,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
      isMuted: isMuted ?? this.isMuted,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'handle': handle,
    'avatarUrl': avatarUrl,
    'role': role,
    'isMuted': isMuted,
  };

  factory GroupMember.fromJson(Map<String, dynamic> json) => GroupMember(
    id: json['id'] as String,
    name: json['name'] as String,
    handle: json['handle'] as String? ?? '',
    avatarUrl: json['avatarUrl'] as String? ?? '',
    role: json['role'] as String? ?? 'member',
    isMuted: json['isMuted'] as bool? ?? false,
  );
}

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

  // Group parameters & permissions
  final String? description;
  final bool onlyAdminsCanSendMessages;
  final bool onlyAdminsCanEditGroupInfo;
  final bool onlyAdminsCanAddMembers;
  final bool onlyAdminsCanEditNotes;
  final List<GroupMember> groupMembers;

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
    this.description,
    this.onlyAdminsCanSendMessages = false,
    this.onlyAdminsCanEditGroupInfo = false,
    this.onlyAdminsCanAddMembers = false,
    this.onlyAdminsCanEditNotes = false,
    this.groupMembers = const [],
  });

  bool isUserAdmin(String userId) {
    if (!isGroup) return false;
    final member = groupMembers.firstWhere(
      (m) => m.id == userId,
      orElse: () => const GroupMember(id: '', name: '', role: 'member'),
    );
    if (member.id.isNotEmpty) {
      return member.isAdmin;
    }
    // Default fallback: if current user is richard, treat as admin
    if (userId == 'user_richard' || userId.isEmpty) return true;
    return false;
  }

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
    String? description,
    bool? onlyAdminsCanSendMessages,
    bool? onlyAdminsCanEditGroupInfo,
    bool? onlyAdminsCanAddMembers,
    bool? onlyAdminsCanEditNotes,
    List<GroupMember>? groupMembers,
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
      description: description ?? this.description,
      onlyAdminsCanSendMessages: onlyAdminsCanSendMessages ?? this.onlyAdminsCanSendMessages,
      onlyAdminsCanEditGroupInfo: onlyAdminsCanEditGroupInfo ?? this.onlyAdminsCanEditGroupInfo,
      onlyAdminsCanAddMembers: onlyAdminsCanAddMembers ?? this.onlyAdminsCanAddMembers,
      onlyAdminsCanEditNotes: onlyAdminsCanEditNotes ?? this.onlyAdminsCanEditNotes,
      groupMembers: groupMembers ?? this.groupMembers,
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
    'description': description,
    'onlyAdminsCanSendMessages': onlyAdminsCanSendMessages,
    'onlyAdminsCanEditGroupInfo': onlyAdminsCanEditGroupInfo,
    'onlyAdminsCanAddMembers': onlyAdminsCanAddMembers,
    'onlyAdminsCanEditNotes': onlyAdminsCanEditNotes,
    'groupMembers': groupMembers.map((m) => m.toJson()).toList(),
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
    description: json['description'] as String?,
    onlyAdminsCanSendMessages: json['onlyAdminsCanSendMessages'] as bool? ?? false,
    onlyAdminsCanEditGroupInfo: json['onlyAdminsCanEditGroupInfo'] as bool? ?? false,
    onlyAdminsCanAddMembers: json['onlyAdminsCanAddMembers'] as bool? ?? false,
    onlyAdminsCanEditNotes: json['onlyAdminsCanEditNotes'] as bool? ?? false,
    groupMembers: (json['groupMembers'] as List<dynamic>?)
            ?.map((m) => GroupMember.fromJson(m as Map<String, dynamic>))
            .toList() ??
        const [],
  );
}
