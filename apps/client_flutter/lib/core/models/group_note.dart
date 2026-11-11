class GroupNote {
  final String id;
  final String conversationId;
  final String title;
  final String content;
  final Map<String, String> components;
  final double lineSpacing;
  final double paragraphSpacing;
  final String lastModified;
  final String lastModifiedBy;
  final bool isLocked;

  const GroupNote({
    required this.id,
    required this.conversationId,
    required this.title,
    required this.content,
    this.components = const {},
    this.lineSpacing = 1.5,
    this.paragraphSpacing = 12.0,
    required this.lastModified,
    required this.lastModifiedBy,
    this.isLocked = false,
  });

  GroupNote copyWith({
    String? id,
    String? conversationId,
    String? title,
    String? content,
    Map<String, String>? components,
    double? lineSpacing,
    double? paragraphSpacing,
    String? lastModified,
    String? lastModifiedBy,
    bool? isLocked,
  }) {
    return GroupNote(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      title: title ?? this.title,
      content: content ?? this.content,
      components: components ?? this.components,
      lineSpacing: lineSpacing ?? this.lineSpacing,
      paragraphSpacing: paragraphSpacing ?? this.paragraphSpacing,
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
    'components': components,
    'lineSpacing': lineSpacing,
    'paragraphSpacing': paragraphSpacing,
    'lastModified': lastModified,
    'lastModifiedBy': lastModifiedBy,
    'isLocked': isLocked,
  };

  factory GroupNote.fromJson(Map<String, dynamic> json) => GroupNote(
    id: json['id'] as String,
    conversationId: json['conversationId'] as String,
    title: json['title'] as String? ?? 'Bloc-note du groupe',
    content: json['content'] as String? ?? '',
    components: (json['components'] as Map<String, dynamic>?)?.map(
          (k, v) => MapEntry(k, v.toString()),
        ) ??
        const {},
    lineSpacing: (json['lineSpacing'] as num?)?.toDouble() ?? 1.5,
    paragraphSpacing: (json['paragraphSpacing'] as num?)?.toDouble() ?? 12.0,
    lastModified: json['lastModified'] as String? ?? 'Aujourd\'hui',
    lastModifiedBy: json['lastModifiedBy'] as String? ?? 'Admin',
    isLocked: json['isLocked'] as bool? ?? false,
  );
}
