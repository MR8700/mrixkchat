import 'package:flutter/material.dart';

/// Specialized Rich Text Controller for MRixk DWS (Word Workspace).
///
/// In Word mode:
/// - Typography and styles are rendered visually directly (bold, italic, underline,
///   strikethrough, font face, font color, font highlight background, headings, lists).
/// - Markup tags (like `**`, `*`, `<u>`, `<font>`, `[align=...]`, `#`) are visually suppressed.
/// - In accordance with MRixk specifications, declarations `{...}` and evaluations `{{...}}`
///   REMAIN RAW (visible characters) with a distinctive highlighted background pill,
///   making them immediately identifiable while editing.
/// - Character length parity is strictly preserved across all TextSpans so cursor
///   position and text selection stay 100% accurate.
class WordRichTextController extends TextEditingController {
  WordRichTextController({super.text});

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final rawText = text;
    if (rawText.isEmpty) {
      return TextSpan(text: '', style: style);
    }

    final baseStyle = style ??
        const TextStyle(
          fontSize: 14.5,
          color: Color(0xFF1E293B),
          height: 1.5,
        );

    final n = rawText.length;
    final charStyles = List.generate(n, (_) => _CharStyle());

    // 1. Double Braces {{...}} (Calculations, formulas, math expressions, components)
    // Remain raw with soft indigo highlight
    final doubleBracesReg = RegExp(r'\{\{[\s\S]*?\}\}');
    for (final match in doubleBracesReg.allMatches(rawText)) {
      for (int i = match.start; i < match.end; i++) {
        charStyles[i].isDoubleBrace = true;
      }
    }

    // 2. Single Braces {...} (C declarations, variable assignments)
    // Remain raw with soft amber highlight (only if not inside double braces)
    final singleBracesReg = RegExp(r'\{[^{}\n]+?\}');
    for (final match in singleBracesReg.allMatches(rawText)) {
      bool isInsideDouble = false;
      for (int i = match.start; i < match.end; i++) {
        if (charStyles[i].isDoubleBrace) {
          isInsideDouble = true;
          break;
        }
      }
      if (!isInsideDouble) {
        for (int i = match.start; i < match.end; i++) {
          charStyles[i].isSingleBrace = true;
        }
      }
    }

    // 3. Alignment tags [align=(left|center|right|justify)]
    final alignReg = RegExp(r'\[align=(?:left|center|right|justify)\]', caseSensitive: false);
    for (final match in alignReg.allMatches(rawText)) {
      _applyTagHiding(charStyles, match.start, match.end);
    }

    // 4. Headings # Titre, ## Titre ... (multiline)
    final headingReg = RegExp(r'^(#{1,6})\s+(.*)$', multiLine: true);
    for (final match in headingReg.allMatches(rawText)) {
      final hashes = match.group(1)!;
      final level = hashes.length;
      final hashEnd = match.start + level + 1; // hashes plus space
      _applyTagHiding(charStyles, match.start, hashEnd);

      final contentStart = hashEnd;
      final contentEnd = match.end;
      final double fontSize = switch (level) {
        1 => 22.0,
        2 => 19.0,
        3 => 17.5,
        4 => 16.0,
        _ => 15.0,
      };
      for (int i = contentStart; i < contentEnd; i++) {
        if (!charStyles[i].isDoubleBrace && !charStyles[i].isSingleBrace) {
          charStyles[i].isBold = true;
          charStyles[i].fontSize = fontSize;
        }
      }
    }

    // 5. Underline <u>...</u>
    final underlineReg = RegExp(r'<u>([\s\S]*?)</u>', caseSensitive: false);
    for (final match in underlineReg.allMatches(rawText)) {
      _applyTagHiding(charStyles, match.start, match.start + 3); // <u>
      _applyFormatting(charStyles, match.start + 3, match.end - 4, (s) => s.isUnderline = true);
      _applyTagHiding(charStyles, match.end - 4, match.end); // </u>
    }

    // 6. Strikethrough <s>...</s> and ~~...~~
    final sTagReg = RegExp(r'<s>([\s\S]*?)</s>', caseSensitive: false);
    for (final match in sTagReg.allMatches(rawText)) {
      _applyTagHiding(charStyles, match.start, match.start + 3);
      _applyFormatting(charStyles, match.start + 3, match.end - 4, (s) => s.isStrikethrough = true);
      _applyTagHiding(charStyles, match.end - 4, match.end);
    }
    final strikeTildeReg = RegExp(r'~~([\s\S]*?)~~');
    for (final match in strikeTildeReg.allMatches(rawText)) {
      _applyTagHiding(charStyles, match.start, match.start + 2);
      _applyFormatting(charStyles, match.start + 2, match.end - 2, (s) => s.isStrikethrough = true);
      _applyTagHiding(charStyles, match.end - 2, match.end);
    }

    // 7. Font tags <font face="..." color="..." bg="...">...</font>
    final fontReg = RegExp(r'<font\s+([^>]*?)>([\s\S]*?)</font>', caseSensitive: false);
    for (final match in fontReg.allMatches(rawText)) {
      final attrs = match.group(1) ?? '';
      final openTagEnd = match.start + 6 + attrs.length + 1; // <font ...>
      final closeTagStart = match.end - 7; // </font>

      _applyTagHiding(charStyles, match.start, openTagEnd);

      Color? fontColor;
      Color? bgColor;
      String? fontFamily;

      final colorMatch = RegExp(r'color=["\x27]([^"\x27]+)["\x27]', caseSensitive: false).firstMatch(attrs);
      if (colorMatch != null) fontColor = _parseColor(colorMatch.group(1));

      final bgMatch = RegExp(r'bg=["\x27]([^"\x27]+)["\x27]', caseSensitive: false).firstMatch(attrs);
      if (bgMatch != null) bgColor = _parseColor(bgMatch.group(1));

      final faceMatch = RegExp(r'face=["\x27]([^"\x27]+)["\x27]', caseSensitive: false).firstMatch(attrs);
      if (faceMatch != null) fontFamily = faceMatch.group(1);

      _applyFormatting(charStyles, openTagEnd, closeTagStart, (s) {
        if (fontColor != null) s.fontColor = fontColor;
        if (bgColor != null) s.bgColor = bgColor;
        if (fontFamily != null) s.fontFamily = fontFamily;
      });

      _applyTagHiding(charStyles, closeTagStart, match.end);
    }

    // 8. Mark highlight tags <mark(?: color="...")?>...</mark>
    final markReg = RegExp(r'<mark(?:\s+color=["\x27]([^"\x27]+)["\x27"])?>([\s\S]*?)</mark>', caseSensitive: false);
    for (final match in markReg.allMatches(rawText)) {
      final colorStr = match.group(1);
      final highlightColor = _parseColor(colorStr) ?? const Color(0xFFFEF08A);
      final fullMatchStr = match.group(0)!;
      final openTagLen = fullMatchStr.indexOf('>') + 1;
      final openTagEnd = match.start + openTagLen;
      final closeTagStart = match.end - 7;

      _applyTagHiding(charStyles, match.start, openTagEnd);
      _applyFormatting(charStyles, openTagEnd, closeTagStart, (s) => s.bgColor = highlightColor);
      _applyTagHiding(charStyles, closeTagStart, match.end);
    }

    // 9. Bold **...**
    final boldReg = RegExp(r'\*\*(.+?)\*\*');
    for (final match in boldReg.allMatches(rawText)) {
      _applyTagHiding(charStyles, match.start, match.start + 2); // **
      _applyFormatting(charStyles, match.start + 2, match.end - 2, (s) => s.isBold = true);
      _applyTagHiding(charStyles, match.end - 2, match.end); // **
    }

    // 10. Italic *...* (avoiding ** collisions)
    final italicReg = RegExp(r'(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)');
    for (final match in italicReg.allMatches(rawText)) {
      _applyTagHiding(charStyles, match.start, match.start + 1); // *
      _applyFormatting(charStyles, match.start + 1, match.end - 1, (s) => s.isItalic = true);
      _applyTagHiding(charStyles, match.end - 1, match.end); // *
    }

    // 11. Inline code `...`
    final codeReg = RegExp(r'`([^`\n]+)`');
    for (final match in codeReg.allMatches(rawText)) {
      _applyTagHiding(charStyles, match.start, match.start + 1);
      _applyFormatting(charStyles, match.start + 1, match.end - 1, (s) => s.isCode = true);
      _applyTagHiding(charStyles, match.end - 1, match.end);
    }

    // 12. Bullet list markers at beginning of lines (- , * , + )
    final bulletReg = RegExp(r'^(\s*[-*+]\s+)', multiLine: true);
    for (final match in bulletReg.allMatches(rawText)) {
      for (int i = match.start; i < match.end; i++) {
        if (!charStyles[i].isHidden && !charStyles[i].isDoubleBrace && !charStyles[i].isSingleBrace) {
          charStyles[i].isBullet = true;
        }
      }
    }

    // 13. Build final contiguous TextSpans guaranteeing exact character length parity
    final spans = <TextSpan>[];
    int runStart = 0;
    while (runStart < n) {
      int runEnd = runStart + 1;
      final currentStyle = charStyles[runStart];
      while (runEnd < n && charStyles[runEnd].isSameAs(currentStyle)) {
        runEnd++;
      }
      final chunk = rawText.substring(runStart, runEnd);
      spans.add(TextSpan(text: chunk, style: currentStyle.toTextStyle(baseStyle)));
      runStart = runEnd;
    }

    return TextSpan(children: spans, style: baseStyle);
  }

  void _applyTagHiding(List<_CharStyle> charStyles, int start, int end) {
    for (int i = start; i < end; i++) {
      // Do not hide braces
      if (!charStyles[i].isDoubleBrace && !charStyles[i].isSingleBrace) {
        charStyles[i].isHidden = true;
      }
    }
  }

  void _applyFormatting(List<_CharStyle> charStyles, int start, int end, void Function(_CharStyle) format) {
    for (int i = start; i < end; i++) {
      if (!charStyles[i].isHidden && !charStyles[i].isDoubleBrace && !charStyles[i].isSingleBrace) {
        format(charStyles[i]);
      }
    }
  }

  static Color? _parseColor(String? colorStr) {
    if (colorStr == null || colorStr.isEmpty) return null;
    var hex = colorStr.trim();
    if (hex.startsWith('#')) hex = hex.substring(1);
    if (hex.length == 6) hex = 'FF$hex';
    final val = int.tryParse(hex, radix: 16);
    if (val != null) return Color(val);
    switch (colorStr.toLowerCase()) {
      case 'red':
        return const Color(0xFFDC2626);
      case 'green':
        return const Color(0xFF16A34A);
      case 'blue':
        return const Color(0xFF2563EB);
      case 'amber':
      case 'orange':
        return const Color(0xFFD97706);
      case 'purple':
        return const Color(0xFF9333EA);
      case 'teal':
        return const Color(0xFF0D9488);
      default:
        return null;
    }
  }
}

class _CharStyle {
  bool isHidden = false;
  bool isBold = false;
  bool isItalic = false;
  bool isUnderline = false;
  bool isStrikethrough = false;
  bool isDoubleBrace = false;
  bool isSingleBrace = false;
  bool isBullet = false;
  bool isCode = false;
  Color? fontColor;
  Color? bgColor;
  String? fontFamily;
  double? fontSize;

  bool isSameAs(_CharStyle o) {
    return isHidden == o.isHidden &&
        isBold == o.isBold &&
        isItalic == o.isItalic &&
        isUnderline == o.isUnderline &&
        isStrikethrough == o.isStrikethrough &&
        isDoubleBrace == o.isDoubleBrace &&
        isSingleBrace == o.isSingleBrace &&
        isBullet == o.isBullet &&
        isCode == o.isCode &&
        fontColor == o.fontColor &&
        bgColor == o.bgColor &&
        fontFamily == o.fontFamily &&
        fontSize == o.fontSize;
  }

  TextStyle toTextStyle(TextStyle base) {
    if (isHidden) {
      // Zero visual presence for markup tags
      return const TextStyle(
        fontSize: 0.001,
        color: Colors.transparent,
        letterSpacing: -1.0,
      );
    }

    if (isDoubleBrace) {
      // {{...}} remains raw with distinctive soft indigo background badge
      return base.copyWith(
        backgroundColor: const Color(0xFFEEF2FF), // soft indigo
        color: const Color(0xFF3730A3), // deep indigo
        fontFamily: 'monospace',
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
      );
    }

    if (isSingleBrace) {
      // {...} remains raw with distinctive warm amber background badge
      return base.copyWith(
        backgroundColor: const Color(0xFFFEF3C7), // soft amber
        color: const Color(0xFF92400E), // deep amber
        fontFamily: 'monospace',
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
      );
    }

    if (isBullet) {
      return base.copyWith(
        color: const Color(0xFF0284C7),
        fontWeight: FontWeight.bold,
      );
    }

    if (isCode) {
      return base.copyWith(
        fontFamily: 'monospace',
        backgroundColor: const Color(0xFFF1F5F9),
        color: const Color(0xFF0F172A),
      );
    }

    TextStyle s = base;
    if (fontColor != null) s = s.copyWith(color: fontColor);
    if (bgColor != null) s = s.copyWith(backgroundColor: bgColor);
    if (fontFamily != null) s = s.copyWith(fontFamily: fontFamily);
    if (fontSize != null) s = s.copyWith(fontSize: fontSize);

    if (isBold && isItalic) {
      s = s.copyWith(fontWeight: FontWeight.bold, fontStyle: FontStyle.italic);
    } else if (isBold) {
      s = s.copyWith(fontWeight: FontWeight.bold);
    } else if (isItalic) {
      s = s.copyWith(fontStyle: FontStyle.italic);
    }

    if (isUnderline && isStrikethrough) {
      s = s.copyWith(
        decoration: TextDecoration.combine([TextDecoration.underline, TextDecoration.lineThrough]),
        decorationColor: s.color,
      );
    } else if (isUnderline) {
      s = s.copyWith(
        decoration: TextDecoration.underline,
        decorationColor: s.color,
      );
    } else if (isStrikethrough) {
      s = s.copyWith(decoration: TextDecoration.lineThrough);
    }

    return s;
  }
}
