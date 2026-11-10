class MemoryItem {
  final String id;
  final String title;
  final String detail;
  final String category;
  final double confidence;
  final bool isActive;
  final String createdAt;

  MemoryItem({
    required this.id,
    required this.title,
    required this.detail,
    required this.category,
    this.confidence = 0.95,
    this.isActive = true,
    required this.createdAt,
  });

  MemoryItem copyWith({
    String? id,
    String? title,
    String? detail,
    String? category,
    double? confidence,
    bool? isActive,
    String? createdAt,
  }) {
    return MemoryItem(
      id: id ?? this.id,
      title: title ?? this.title,
      detail: detail ?? this.detail,
      category: category ?? this.category,
      confidence: confidence ?? this.confidence,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'detail': detail,
    'category': category,
    'confidence': confidence,
    'isActive': isActive,
    'createdAt': createdAt,
  };

  factory MemoryItem.fromJson(Map<String, dynamic> json) => MemoryItem(
    id: json['id'] as String,
    title: json['title'] as String,
    detail: json['detail'] as String,
    category: json['category'] as String,
    confidence: (json['confidence'] as num?)?.toDouble() ?? 0.95,
    isActive: json['isActive'] as bool? ?? true,
    createdAt: json['createdAt'] as String,
  );
}
