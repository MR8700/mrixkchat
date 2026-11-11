enum DwsMediaType {
  image,
  video,
  audio,
  pdf,
}

enum DwsMediaRole {
  figure, // Scientific or technical figure
  photo, // Authentic photography
  illustration, // Graphical diagram or illustration
  demo, // Practical video demonstration
  lecture, // Conference or lecture
  explanation, // Audio explanation
  annex, // Attached documentary annex
}

/// Represents a first-class media component within the MRixk Document Workspace System (DWS).
class DwsMedia {
  final String id; // Unique URI e.g. media://group/asset_8f29a1
  final String conversationId;
  final String slug; // Short reference e.g. schema_reseau, experience
  final DwsMediaType type;
  final String source; // URL, asset path, data URI or blob
  final String fileName;
  final String fileSize;
  final String duration; // e.g. '04:32' for video or '01:45' for audio
  final String mimeType;
  final double widthPercent; // 0 to 100%
  final String align; // 'center', 'left', 'right'
  final String wrap; // 'square', 'inline', 'break'
  final String caption;
  final String alt;
  final int? figureNumber;
  final DwsMediaRole role;
  final String createdAt;
  final String createdBy;

  const DwsMedia({
    required this.id,
    required this.conversationId,
    required this.slug,
    required this.type,
    required this.source,
    this.fileName = '',
    this.fileSize = '',
    this.duration = '',
    this.mimeType = '',
    this.widthPercent = 80.0,
    this.align = 'center',
    this.wrap = 'break',
    this.caption = '',
    this.alt = '',
    this.figureNumber,
    this.role = DwsMediaRole.figure,
    this.createdAt = '',
    this.createdBy = '',
  });

  DwsMedia copyWith({
    String? id,
    String? conversationId,
    String? slug,
    DwsMediaType? type,
    String? source,
    String? fileName,
    String? fileSize,
    String? duration,
    String? mimeType,
    double? widthPercent,
    String? align,
    String? wrap,
    String? caption,
    String? alt,
    int? figureNumber,
    DwsMediaRole? role,
    String? createdAt,
    String? createdBy,
  }) {
    return DwsMedia(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      slug: slug ?? this.slug,
      type: type ?? this.type,
      source: source ?? this.source,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      duration: duration ?? this.duration,
      mimeType: mimeType ?? this.mimeType,
      widthPercent: widthPercent ?? this.widthPercent,
      align: align ?? this.align,
      wrap: wrap ?? this.wrap,
      caption: caption ?? this.caption,
      alt: alt ?? this.alt,
      figureNumber: figureNumber ?? this.figureNumber,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversationId': conversationId,
      'slug': slug,
      'type': type.name,
      'source': source,
      'fileName': fileName,
      'fileSize': fileSize,
      'duration': duration,
      'mimeType': mimeType,
      'widthPercent': widthPercent,
      'align': align,
      'wrap': wrap,
      'caption': caption,
      'alt': alt,
      'figureNumber': figureNumber,
      'role': role.name,
      'createdAt': createdAt,
      'createdBy': createdBy,
    };
  }

  factory DwsMedia.fromJson(Map<String, dynamic> json) {
    return DwsMedia(
      id: json['id'] as String? ?? 'media_${DateTime.now().millisecondsSinceEpoch}',
      conversationId: json['conversationId'] as String? ?? '',
      slug: json['slug'] as String? ?? 'media',
      type: DwsMediaType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => DwsMediaType.image,
      ),
      source: json['source'] as String? ?? '',
      fileName: json['fileName'] as String? ?? '',
      fileSize: json['fileSize'] as String? ?? '',
      duration: json['duration'] as String? ?? '',
      mimeType: json['mimeType'] as String? ?? '',
      widthPercent: (json['widthPercent'] as num?)?.toDouble() ?? 80.0,
      align: json['align'] as String? ?? 'center',
      wrap: json['wrap'] as String? ?? 'break',
      caption: json['caption'] as String? ?? '',
      alt: json['alt'] as String? ?? '',
      figureNumber: json['figureNumber'] as int?,
      role: DwsMediaRole.values.firstWhere(
        (e) => e.name == json['role'],
        orElse: () => DwsMediaRole.figure,
      ),
      createdAt: json['createdAt'] as String? ?? '',
      createdBy: json['createdBy'] as String? ?? '',
    );
  }

  String get roleDisplayName {
    switch (role) {
      case DwsMediaRole.figure:
        return 'Figure scientifique';
      case DwsMediaRole.photo:
        return 'Photographie';
      case DwsMediaRole.illustration:
        return 'Illustration';
      case DwsMediaRole.demo:
        return 'Démonstration pratique';
      case DwsMediaRole.lecture:
        return 'Conférence';
      case DwsMediaRole.explanation:
        return 'Explication audio';
      case DwsMediaRole.annex:
        return 'Annexe documentaire';
    }
  }
}
