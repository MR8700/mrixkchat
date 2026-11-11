import 'package:flutter/material.dart';

class TitleConfig {
  final int level; // 1 to 8
  final Color color;
  final String fontFamily;
  final TextAlign alignment;
  final bool isNumbered;

  const TitleConfig({
    this.level = 1,
    this.color = const Color(0xFF0F172A),
    this.fontFamily = 'Inter',
    this.alignment = TextAlign.left,
    this.isNumbered = false,
  });

  TitleConfig copyWith({
    int? level,
    Color? color,
    String? fontFamily,
    TextAlign? alignment,
    bool? isNumbered,
  }) {
    return TitleConfig(
      level: level ?? this.level,
      color: color ?? this.color,
      fontFamily: fontFamily ?? this.fontFamily,
      alignment: alignment ?? this.alignment,
      isNumbered: isNumbered ?? this.isNumbered,
    );
  }

  double get fontSize {
    switch (level) {
      case 1:
        return 22.0;
      case 2:
        return 19.0;
      case 3:
        return 17.0;
      case 4:
        return 15.5;
      case 5:
        return 14.5;
      case 6:
        return 13.5;
      case 7:
        return 12.5;
      case 8:
        return 11.5;
      default:
        return 16.0;
    }
  }

  FontWeight get fontWeight {
    if (level <= 2) return FontWeight.bold;
    if (level <= 4) return FontWeight.w700;
    if (level <= 6) return FontWeight.w600;
    return FontWeight.w500;
  }
}
