class GroupNote {
  final String id;
  final String conversationId;
  final String title;
  final String content;
  final String lastModified;
  final String lastModifiedBy;
  final bool isLocked;

  const GroupNote({
    required this.id,
    required this.conversationId,
    required this.title,
    required this.content,
    required this.lastModified,
    required this.lastModifiedBy,
    this.isLocked = false,
  });

  GroupNote copyWith({
    String? id,
    String? conversationId,
    String? title,
    String? content,
    String? lastModified,
    String? lastModifiedBy,
    bool? isLocked,
  }) {
    return GroupNote(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      title: title ?? this.title,
      content: content ?? this.content,
      lastModified: lastModified ?? this.lastModified,
      lastModifiedBy: lastModifiedBy ?? this.lastModifiedBy,
      isLocked: isLocked ?? this.isLocked,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'conversationId': conversationId,
    'title': title,
    'content': content,
    'lastModified': lastModified,
    'lastModifiedBy': lastModifiedBy,
    'isLocked': isLocked,
  };

  factory GroupNote.fromJson(Map<String, dynamic> json) => GroupNote(
    id: json['id'] as String,
    conversationId: json['conversationId'] as String,
    title: json['title'] as String? ?? 'Bloc-note du groupe',
    content: json['content'] as String? ?? '',
    lastModified: json['lastModified'] as String? ?? 'Aujourd\'hui',
    lastModifiedBy: json['lastModifiedBy'] as String? ?? 'Admin',
    isLocked: json['isLocked'] as bool? ?? false,
  );
}
