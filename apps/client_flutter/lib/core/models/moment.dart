enum MomentType {
  image,
  video,
  voice,
  quote,
}

class MomentComment {
  final String id;
  final String authorName;
  final String authorAvatar;
  final String text;
  final String timeAgo;
  final int likes;
  final bool userLiked;

  MomentComment({
    required this.id,
    required this.authorName,
    required this.authorAvatar,
    required this.text,
    required this.timeAgo,
    this.likes = 0,
    this.userLiked = false,
  });

  MomentComment copyWith({
    String? id,
    String? authorName,
    String? authorAvatar,
    String? text,
    String? timeAgo,
    int? likes,
    bool? userLiked,
  }) {
    return MomentComment(
      id: id ?? this.id,
      authorName: authorName ?? this.authorName,
      authorAvatar: authorAvatar ?? this.authorAvatar,
      text: text ?? this.text,
      timeAgo: timeAgo ?? this.timeAgo,
      likes: likes ?? this.likes,
      userLiked: userLiked ?? this.userLiked,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'authorName': authorName,
    'authorAvatar': authorAvatar,
    'text': text,
    'timeAgo': timeAgo,
    'likes': likes,
    'userLiked': userLiked,
  };

  factory MomentComment.fromJson(Map<String, dynamic> json) => MomentComment(
    id: json['id'] as String,
    authorName: json['authorName'] as String,
    authorAvatar: json['authorAvatar'] as String? ?? '',
    text: json['text'] as String,
    timeAgo: json['timeAgo'] as String? ?? 'À l\'instant',
    likes: json['likes'] as int? ?? 0,
    userLiked: json['userLiked'] as bool? ?? false,
  );
}

class Moment {
  final String id;
  final String authorId;
  final String authorName;
  final String authorAvatar;
  final String? authorBadge; // 'verified', 'Conseil', 'stars'
  final MomentType type;
  final String timeAgo;
  final String caption;
  final String? mediaUrl;
  final String? location;
  final String? voiceTitle;
  final String? voiceDuration;
  final int heartCount;
  final int moodCount;
  final int celebrationCount;
  final int commentCount;
  final bool userLiked;
  final String? userReaction;
  final List<MomentComment> comments;

  Moment({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.authorAvatar,
    this.authorBadge,
    required this.type,
    required this.timeAgo,
    required this.caption,
    this.mediaUrl,
    this.location,
    this.voiceTitle,
    this.voiceDuration,
    this.heartCount = 0,
    this.moodCount = 0,
    this.celebrationCount = 0,
    this.commentCount = 0,
    this.userLiked = false,
    this.userReaction,
    List<MomentComment>? comments,
  }) : comments = comments ?? [];

  Moment copyWith({
    String? id,
    String? authorId,
    String? authorName,
    String? authorAvatar,
    String? authorBadge,
    MomentType? type,
    String? timeAgo,
    String? caption,
    String? mediaUrl,
    String? location,
    String? voiceTitle,
    String? voiceDuration,
    int? heartCount,
    int? moodCount,
    int? celebrationCount,
    int? commentCount,
    bool? userLiked,
    String? userReaction,
    List<MomentComment>? comments,
  }) {
    return Moment(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorAvatar: authorAvatar ?? this.authorAvatar,
      authorBadge: authorBadge ?? this.authorBadge,
      type: type ?? this.type,
      timeAgo: timeAgo ?? this.timeAgo,
      caption: caption ?? this.caption,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      location: location ?? this.location,
      voiceTitle: voiceTitle ?? this.voiceTitle,
      voiceDuration: voiceDuration ?? this.voiceDuration,
      heartCount: heartCount ?? this.heartCount,
      moodCount: moodCount ?? this.moodCount,
      celebrationCount: celebrationCount ?? this.celebrationCount,
      commentCount: commentCount ?? this.commentCount,
      userLiked: userLiked ?? this.userLiked,
      userReaction: userReaction ?? this.userReaction,
      comments: comments ?? this.comments,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'authorId': authorId,
    'authorName': authorName,
    'authorAvatar': authorAvatar,
    'authorBadge': authorBadge,
    'type': type.name,
    'timeAgo': timeAgo,
    'caption': caption,
    'mediaUrl': mediaUrl,
    'location': location,
    'voiceTitle': voiceTitle,
    'voiceDuration': voiceDuration,
    'heartCount': heartCount,
    'moodCount': moodCount,
    'celebrationCount': celebrationCount,
    'commentCount': commentCount,
    'userLiked': userLiked,
    'userReaction': userReaction,
    'comments': comments.map((c) => c.toJson()).toList(),
  };

  factory Moment.fromJson(Map<String, dynamic> json) => Moment(
    id: json['id'] as String,
    authorId: json['authorId'] as String,
    authorName: json['authorName'] as String,
    authorAvatar: json['authorAvatar'] as String,
    authorBadge: json['authorBadge'] as String?,
    type: MomentType.values.firstWhere(
      (e) => e.name == json['type'],
      orElse: () => MomentType.image,
    ),
    timeAgo: json['timeAgo'] as String,
    caption: json['caption'] as String,
    mediaUrl: json['mediaUrl'] as String?,
    location: json['location'] as String?,
    voiceTitle: json['voiceTitle'] as String?,
    voiceDuration: json['voiceDuration'] as String?,
    heartCount: json['heartCount'] as int? ?? 0,
    moodCount: json['moodCount'] as int? ?? 0,
    celebrationCount: json['celebrationCount'] as int? ?? 0,
    commentCount: json['commentCount'] as int? ?? 0,
    userLiked: json['userLiked'] as bool? ?? false,
    userReaction: json['userReaction'] as String?,
    comments: (json['comments'] as List<dynamic>?)
            ?.map((c) => MomentComment.fromJson(c as Map<String, dynamic>))
            .toList() ??
        [],
  );
}
