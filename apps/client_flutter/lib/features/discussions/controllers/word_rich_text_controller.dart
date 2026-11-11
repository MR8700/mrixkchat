import 'package:flutter/material.dart';

/// Clean-Buffer & Span-Attribution Engine for MRixk DWS (Specialized Integrated Word Space).
///
/// Design Guarantees:
/// 1. True WYSIWYG Editing: The text buffer contains ONLY clean, visible characters.
///    Zero markup tags (`**`, `*`, `<u>`, `<font>`, `[align=...]`) exist in the text string while editing.
/// 2. 1:1 Character Parity: 1 visual glyph on screen equals exactly 1 character in the text buffer.
///    - Selection drag and double-click NEVER miss or truncate the last letters of a word.
///    - Backspacing NEVER exposes raw asterisks or broken HTML tags.
/// 3. Declarations `{...}` and Evaluations `{{...}}` remain natively raw in the text,
///    rendered with their respective distinctive warm amber and soft indigo badges.
/// 4. Bi-directional Serialization:
///    - `loadMarkdown(markdown)` parses standard Markdown / HTML into clean text and style spans.
///    - `toMarkdown()` serializes clean text and style spans back to standard Markdown / HTML for Code mode & storage.
class WordRichTextController extends TextEditingController {
  final List<WordCharStyle> _charStyles = [];
  final Map<int, String> _lineAlignments = {}; // line index -> alignment ('center', 'right', 'justify', 'left')
  final Map<int, int> _lineHeadings = {}; // line index -> heading level (1 to 8)
  WordCharStyle? _pendingStyle;

  WordRichTextController({String? text}) {
    if (text != null && text.isNotEmpty) {
      loadMarkdown(text);
    }
  }

  WordRichTextController.fromMarkdown(String markdown) {
    loadMarkdown(markdown);
  }

  List<WordCharStyle> get charStyles => List.unmodifiable(_charStyles);

  /// Loads Markdown content into clean text and extracts all formatting spans.
  void loadMarkdown(String markdown) {
    _charStyles.clear();
    _lineAlignments.clear();
    _lineHeadings.clear();
    _pendingStyle = null;

    if (markdown.isEmpty) {
      super.value = TextEditingValue.empty;
      return;
    }

    final rawLines = markdown.split('\n');
    final cleanLines = <String>[];

    for (int lineIdx = 0; lineIdx < rawLines.length; lineIdx++) {
      var line = rawLines[lineIdx];

      // 1. Heading (#, ##, ...)
      final headingMatch = RegExp(r'^(#{1,8})\s+(.*)$').firstMatch(line);
      int headingLevel = 0;
      if (headingMatch != null) {
        headingLevel = headingMatch.group(1)!.length;
        line = headingMatch.group(2)!;
        _lineHeadings[lineIdx] = headingLevel;
      }

      // 2. Alignment [align=...]
      final alignMatch = RegExp(r'\[align=(left|center|right|justify)\]\s*', caseSensitive: false).firstMatch(line);
      if (alignMatch != null) {
        _lineAlignments[lineIdx] = alignMatch.group(1)!.toLowerCase();
        line = line.replaceFirst(alignMatch.group(0)!, '');
      }

      // 3. Parse inline formatting into clean text + styles
      final parsed = _parseInlineMarkdown(line, headingLevel: headingLevel);
      cleanLines.add(parsed.cleanText);
      _charStyles.addAll(parsed.styles);

      // Append newline style if not last line
      if (lineIdx < rawLines.length - 1) {
        _charStyles.add(WordCharStyle());
      }
    }

    final fullCleanText = cleanLines.join('\n');
    super.value = TextEditingValue(
      text: fullCleanText,
      selection: TextSelection.collapsed(offset: fullCleanText.length),
    );
  }

  /// Serializes the clean text, style spans, headings, and alignments to standard Markdown.
  String toMarkdown() {
    final cleanText = text;
    if (cleanText.isEmpty) return '';

    final lines = cleanText.split('\n');
    final outLines = <String>[];
    int charOffset = 0;

    for (int lineIdx = 0; lineIdx < lines.length; lineIdx++) {
      final line = lines[lineIdx];
      final lineLen = line.length;

      // 1. Heading prefix
      final headingLevel = _lineHeadings[lineIdx] ?? 0;
      final headingPrefix = headingLevel > 0 ? '${"#" * headingLevel} ' : '';

      // 2. Alignment prefix
      final align = _lineAlignments[lineIdx];
      final alignPrefix = (align != null && align != 'left') ? '[align=$align] ' : '';

      // 3. Serialize line characters
      final lineStyles = <WordCharStyle>[];
      for (int i = 0; i < lineLen; i++) {
        final idx = charOffset + i;
        if (idx < _charStyles.length) {
          lineStyles.add(_charStyles[idx]);
        } else {
          lineStyles.add(WordCharStyle());
        }
      }

      final lineMarkdown = _serializeLineToMarkdown(line, lineStyles, isHeading: headingLevel > 0);
      outLines.add('$alignPrefix$headingPrefix$lineMarkdown');

      charOffset += lineLen + 1; // account for '\n'
    }

    return outLines.join('\n');
  }

  @override
  set value(TextEditingValue newValue) {
    final oldText = text;
    final newText = newValue.text;

    if (oldText != newText) {
      _synchronizeCharStylesOnTextDelta(oldText, newText);
    }

    super.value = newValue;
  }

  void _synchronizeCharStylesOnTextDelta(String oldText, String newText) {
    if (newText.isEmpty) {
      _charStyles.clear();
      _lineHeadings.clear();
      _lineAlignments.clear();
      return;
    }

    // 1. Common prefix
    int prefixLen = 0;
    final minLen = oldText.length < newText.length ? oldText.length : newText.length;
    while (prefixLen < minLen && oldText.codeUnitAt(prefixLen) == newText.codeUnitAt(prefixLen)) {
      prefixLen++;
    }

    // 2. Common suffix
    int suffixLen = 0;
    while (suffixLen < (minLen - prefixLen) &&
        oldText.codeUnitAt(oldText.length - 1 - suffixLen) ==
            newText.codeUnitAt(newText.length - 1 - suffixLen)) {
      suffixLen++;
    }

    final oldDelStart = prefixLen;
    final oldDelEnd = oldText.length - suffixLen;
    final newInsStart = prefixLen;
    final newInsEnd = newText.length - suffixLen;

    // Remove deleted styles
    if (oldDelEnd > oldDelStart && oldDelStart < _charStyles.length) {
      final safeEnd = oldDelEnd.clamp(0, _charStyles.length);
      _charStyles.removeRange(oldDelStart, safeEnd);
    }

    // Inherit style for newly inserted characters
    WordCharStyle inherited;
    if (_pendingStyle != null) {
      inherited = _pendingStyle!.clone();
      _pendingStyle = null;
    } else if (prefixLen > 0 && prefixLen <= _charStyles.length) {
      inherited = _charStyles[prefixLen - 1].clone();
    } else if (_charStyles.isNotEmpty) {
      inherited = _charStyles[0].clone();
    } else {
      inherited = WordCharStyle();
    }

    // Insert new styles
    final addedCount = newInsEnd - newInsStart;
    if (addedCount > 0) {
      final safeInsertPos = newInsStart.clamp(0, _charStyles.length);
      for (int i = 0; i < addedCount; i++) {
        _charStyles.insert(safeInsertPos + i, inherited.clone());
      }
    }

    // Guarantee exact length parity at all times
    while (_charStyles.length < newText.length) {
      _charStyles.add(WordCharStyle());
    }
    if (_charStyles.length > newText.length) {
      _charStyles.removeRange(newText.length, _charStyles.length);
    }
  }

  // --- Specialized Toolbar Actions ---

  void toggleBoldSelection() {
    final sel = selection;
    if (!sel.isValid) return;

    if (sel.isCollapsed) {
      _pendingStyle = (_pendingStyle ?? (_charStyles.isNotEmpty && sel.start > 0 ? _charStyles[sel.start - 1].clone() : WordCharStyle()));
      _pendingStyle!.isBold = !_pendingStyle!.isBold;
      notifyListeners();
      return;
    }

    final start = sel.start.clamp(0, _charStyles.length);
    final end = sel.end.clamp(0, _charStyles.length);
    if (start >= end) return;

    bool allBold = true;
    for (int i = start; i < end; i++) {
      if (!_charStyles[i].isBold) {
        allBold = false;
        break;
      }
    }

    final newBold = !allBold;
    for (int i = start; i < end; i++) {
      _charStyles[i].isBold = newBold;
    }
    notifyListeners();
  }

  void toggleItalicSelection() {
    final sel = selection;
    if (!sel.isValid) return;

    if (sel.isCollapsed) {
      _pendingStyle = (_pendingStyle ?? (_charStyles.isNotEmpty && sel.start > 0 ? _charStyles[sel.start - 1].clone() : WordCharStyle()));
      _pendingStyle!.isItalic = !_pendingStyle!.isItalic;
      notifyListeners();
      return;
    }

    final start = sel.start.clamp(0, _charStyles.length);
    final end = sel.end.clamp(0, _charStyles.length);
    if (start >= end) return;

    bool allItalic = true;
    for (int i = start; i < end; i++) {
      if (!_charStyles[i].isItalic) {
        allItalic = false;
        break;
      }
    }

    final newItalic = !allItalic;
    for (int i = start; i < end; i++) {
      _charStyles[i].isItalic = newItalic;
    }
    notifyListeners();
  }

  void toggleUnderlineSelection() {
    final sel = selection;
    if (!sel.isValid) return;

    if (sel.isCollapsed) {
      _pendingStyle = (_pendingStyle ?? (_charStyles.isNotEmpty && sel.start > 0 ? _charStyles[sel.start - 1].clone() : WordCharStyle()));
      _pendingStyle!.isUnderline = !_pendingStyle!.isUnderline;
      notifyListeners();
      return;
    }

    final start = sel.start.clamp(0, _charStyles.length);
    final end = sel.end.clamp(0, _charStyles.length);
    if (start >= end) return;

    bool allUnderline = true;
    for (int i = start; i < end; i++) {
      if (!_charStyles[i].isUnderline) {
        allUnderline = false;
        break;
      }
    }

    final newUnderline = !allUnderline;
    for (int i = start; i < end; i++) {
      _charStyles[i].isUnderline = newUnderline;
    }
    notifyListeners();
  }

  void setFontColorSelection(Color color) {
    final sel = selection;
    if (!sel.isValid) return;

    if (sel.isCollapsed) {
      _pendingStyle = (_pendingStyle ?? (_charStyles.isNotEmpty && sel.start > 0 ? _charStyles[sel.start - 1].clone() : WordCharStyle()));
      _pendingStyle!.fontColor = color;
      notifyListeners();
      return;
    }

    final start = sel.start.clamp(0, _charStyles.length);
    final end = sel.end.clamp(0, _charStyles.length);
    for (int i = start; i < end; i++) {
      _charStyles[i].fontColor = color;
    }
    notifyListeners();
  }

  void setFontFamilySelection(String fontFamily) {
    final sel = selection;
    if (!sel.isValid) return;

    if (sel.isCollapsed) {
      _pendingStyle = (_pendingStyle ?? (_charStyles.isNotEmpty && sel.start > 0 ? _charStyles[sel.start - 1].clone() : WordCharStyle()));
      _pendingStyle!.fontFamily = fontFamily;
      notifyListeners();
      return;
    }

    final start = sel.start.clamp(0, _charStyles.length);
    final end = sel.end.clamp(0, _charStyles.length);
    for (int i = start; i < end; i++) {
      _charStyles[i].fontFamily = fontFamily;
    }
    notifyListeners();
  }

  void setHighlightSelection(Color color) {
    final sel = selection;
    if (!sel.isValid) return;

    if (sel.isCollapsed) {
      _pendingStyle = (_pendingStyle ?? (_charStyles.isNotEmpty && sel.start > 0 ? _charStyles[sel.start - 1].clone() : WordCharStyle()));
      _pendingStyle!.bgColor = color;
      notifyListeners();
      return;
    }

    final start = sel.start.clamp(0, _charStyles.length);
    final end = sel.end.clamp(0, _charStyles.length);
    for (int i = start; i < end; i++) {
      _charStyles[i].bgColor = color;
    }
    notifyListeners();
  }

  void setHeadingLevelForSelection(int level) {
    final sel = selection;
    final cursor = sel.isValid ? sel.start : 0;
    final rawText = text;

    int lineStart = rawText.lastIndexOf('\n', cursor > 0 ? cursor - 1 : 0);
    lineStart = lineStart == -1 ? 0 : lineStart + 1;

    int lineEnd = rawText.indexOf('\n', cursor);
    lineEnd = lineEnd == -1 ? rawText.length : lineEnd;

    // Find line index
    final lineIndex = '\n'.allMatches(rawText.substring(0, lineStart)).length;

    if (level == 0) {
      _lineHeadings.remove(lineIndex);
    } else {
      _lineHeadings[lineIndex] = level;
    }

    final double? fontSize = switch (level) {
      1 => 22.0,
      2 => 19.0,
      3 => 17.5,
      4 => 16.0,
      > 4 => 15.0,
      _ => null,
    };
    final bool isBold = level > 0;

    for (int i = lineStart; i < lineEnd; i++) {
      if (i < _charStyles.length) {
        _charStyles[i].fontSize = fontSize;
        _charStyles[i].isBold = isBold;
      }
    }
    notifyListeners();
  }

  void setAlignmentForSelection(String align) {
    final sel = selection;
    final cursor = sel.isValid ? sel.start : 0;
    final rawText = text;

    int lineStart = rawText.lastIndexOf('\n', cursor > 0 ? cursor - 1 : 0);
    lineStart = lineStart == -1 ? 0 : lineStart + 1;

    final lineIndex = '\n'.allMatches(rawText.substring(0, lineStart)).length;

    if (align == 'left') {
      _lineAlignments.remove(lineIndex);
    } else {
      _lineAlignments[lineIndex] = align;
    }
    notifyListeners();
  }

  String? getAlignmentAtCursor() {
    final sel = selection;
    final cursor = sel.isValid ? sel.start : 0;
    final rawText = text;
    int lineStart = rawText.lastIndexOf('\n', cursor > 0 ? cursor - 1 : 0);
    lineStart = lineStart == -1 ? 0 : lineStart + 1;
    final lineIndex = '\n'.allMatches(rawText.substring(0, lineStart)).length;
    return _lineAlignments[lineIndex];
  }

  void toggleBulletListForSelection() {
    final sel = selection;
    final cursor = sel.isValid ? sel.start : 0;
    final rawText = text;

    int lineStart = rawText.lastIndexOf('\n', cursor > 0 ? cursor - 1 : 0);
    lineStart = lineStart == -1 ? 0 : lineStart + 1;

    int lineEnd = rawText.indexOf('\n', cursor);
    lineEnd = lineEnd == -1 ? rawText.length : lineEnd;

    final currentLine = rawText.substring(lineStart, lineEnd);
    if (currentLine.startsWith('- ')) {
      final newText = rawText.replaceRange(lineStart, lineStart + 2, '');
      value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: (cursor - 2).clamp(0, newText.length)),
      );
    } else {
      final newText = rawText.replaceRange(lineStart, lineStart, '- ');
      value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: (cursor + 2).clamp(0, newText.length)),
      );
    }
  }

  // --- Rendering TextSpans with 100% Visual Alignment ---

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

    // Detect braces ranges for high-priority badge highlights
    final isDoubleBrace = List.filled(n, false);
    for (final match in RegExp(r'\{\{[\s\S]*?\}\}').allMatches(rawText)) {
      for (int i = match.start; i < match.end; i++) {
        isDoubleBrace[i] = true;
      }
    }

    final isSingleBrace = List.filled(n, false);
    for (final match in RegExp(r'\{[^{}\n]+?\}').allMatches(rawText)) {
      bool insideDouble = false;
      for (int i = match.start; i < match.end; i++) {
        if (isDoubleBrace[i]) {
          insideDouble = true;
          break;
        }
      }
      if (!insideDouble) {
        for (int i = match.start; i < match.end; i++) {
          isSingleBrace[i] = true;
        }
      }
    }

    final spans = <TextSpan>[];
    int runStart = 0;

    while (runStart < n) {
      int runEnd = runStart + 1;

      final startInDouble = isDoubleBrace[runStart];
      final startInSingle = isSingleBrace[runStart];
      final startStyle = (runStart < _charStyles.length) ? _charStyles[runStart] : WordCharStyle();

      while (runEnd < n) {
        if (isDoubleBrace[runEnd] != startInDouble || isSingleBrace[runEnd] != startInSingle) {
          break;
        }
        final curStyle = (runEnd < _charStyles.length) ? _charStyles[runEnd] : WordCharStyle();
        if (!curStyle.isSameAs(startStyle)) {
          break;
        }
        runEnd++;
      }

      final chunk = rawText.substring(runStart, runEnd);

      TextStyle spanStyle;
      if (startInDouble) {
        // Double braces {{...}} remain raw with distinctive soft indigo background
        spanStyle = baseStyle.copyWith(
          backgroundColor: const Color(0xFFEEF2FF),
          color: const Color(0xFF3730A3),
          fontFamily: 'monospace',
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        );
      } else if (startInSingle) {
        // Single braces {...} remain raw with distinctive warm amber background
        spanStyle = baseStyle.copyWith(
          backgroundColor: const Color(0xFFFEF3C7),
          color: const Color(0xFF92400E),
          fontFamily: 'monospace',
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        );
      } else {
        spanStyle = startStyle.toTextStyle(baseStyle);
      }

      spans.add(TextSpan(text: chunk, style: spanStyle));
      runStart = runEnd;
    }

    return TextSpan(children: spans, style: baseStyle);
  }

  // --- Parser & Serializer Helpers ---

  static ({String cleanText, List<WordCharStyle> styles}) _parseInlineMarkdown(String raw, {int headingLevel = 0}) {
    final double? defaultFontSize = switch (headingLevel) {
      1 => 22.0,
      2 => 19.0,
      3 => 17.5,
      4 => 16.0,
      > 4 => 15.0,
      _ => null,
    };
    final bool defaultBold = headingLevel > 0;

    final sb = StringBuffer();
    final styles = <WordCharStyle>[];

    final tagRegex = RegExp(
      r'(\{\{[\s\S]*?\}\}|\{[^{}\n]+?\}|' // 1: braces preserved verbatim
      r'\*\*\*|\*\*|\*|' // 2: bold / italic markers
      r'</?(?:u|s|mark|font|b|i)[^>]*>|' // 3: HTML tags
      r'~~|`' // 4: strike / code
      r')',
      caseSensitive: false,
    );

    bool isBold = defaultBold;
    bool isItalic = false;
    bool isUnderline = false;
    bool isStrikethrough = false;
    Color? fontColor;
    Color? bgColor;
    String? fontFamily;

    int lastIndex = 0;

    void addPlainText(String plain) {
      for (int i = 0; i < plain.length; i++) {
        sb.write(plain[i]);
        styles.add(WordCharStyle(
          isBold: isBold,
          isItalic: isItalic,
          isUnderline: isUnderline,
          isStrikethrough: isStrikethrough,
          fontColor: fontColor,
          bgColor: bgColor,
          fontFamily: fontFamily,
          fontSize: defaultFontSize,
        ));
      }
    }

    for (final match in tagRegex.allMatches(raw)) {
      if (match.start > lastIndex) {
        addPlainText(raw.substring(lastIndex, match.start));
      }

      final token = match.group(0)!;
      lastIndex = match.end;

      if (token.startsWith('{') && token.endsWith('}')) {
        addPlainText(token);
        continue;
      }

      if (token == '***') {
        isBold = !isBold;
        isItalic = !isItalic;
      } else if (token == '**') {
        isBold = !isBold;
      } else if (token == '*') {
        isItalic = !isItalic;
      } else if (token.toLowerCase() == '<u>') {
        isUnderline = true;
      } else if (token.toLowerCase() == '</u>') {
        isUnderline = false;
      } else if (token.toLowerCase() == '<s>' || token == '~~') {
        isStrikethrough = true;
      } else if (token.toLowerCase() == '</s>') {
        isStrikethrough = false;
      } else if (token.toLowerCase().startsWith('<mark')) {
        final colMatch = RegExp(r'color=["\x27]([^"\x27]+)["\x27]').firstMatch(token);
        bgColor = _parseColor(colMatch?.group(1)) ?? const Color(0xFFFEF08A);
      } else if (token.toLowerCase() == '</mark>') {
        bgColor = null;
      } else if (token.toLowerCase().startsWith('<font')) {
        final colMatch = RegExp(r'color=["\x27]([^"\x27]+)["\x27]').firstMatch(token);
        if (colMatch != null) fontColor = _parseColor(colMatch.group(1));
        final faceMatch = RegExp(r'face=["\x27]([^"\x27]+)["\x27]').firstMatch(token);
        if (faceMatch != null) fontFamily = faceMatch.group(1);
      } else if (token.toLowerCase() == '</font>') {
        fontColor = null;
        fontFamily = null;
      } else {
        addPlainText(token);
      }
    }

    if (lastIndex < raw.length) {
      addPlainText(raw.substring(lastIndex));
    }

    return (cleanText: sb.toString(), styles: styles);
  }

  static String _serializeLineToMarkdown(String text, List<WordCharStyle> styles, {bool isHeading = false}) {
    if (text.isEmpty) return '';

    final sb = StringBuffer();
    final n = text.length;
    int runStart = 0;

    while (runStart < n) {
      int runEnd = runStart + 1;
      final startStyle = (runStart < styles.length) ? styles[runStart] : WordCharStyle();

      while (runEnd < n) {
        final curStyle = (runEnd < styles.length) ? styles[runEnd] : WordCharStyle();
        if (!curStyle.isSameAs(startStyle)) break;
        runEnd++;
      }

      var chunk = text.substring(runStart, runEnd);

      // Apply formatting if chunk is not purely white spaces
      if (chunk.trim().isNotEmpty) {
        if (startStyle.isBold && startStyle.isItalic && !isHeading) {
          chunk = '***$chunk***';
        } else if (startStyle.isBold && !isHeading) {
          chunk = '**$chunk**';
        } else if (startStyle.isItalic) {
          chunk = '*$chunk*';
        }

        if (startStyle.isUnderline) {
          chunk = '<u>$chunk</u>';
        }

        if (startStyle.isStrikethrough) {
          chunk = '~~$chunk~~';
        }

        if (startStyle.bgColor != null) {
          final hex = '#${startStyle.bgColor!.value.toRadixString(16).padLeft(8, '0').substring(2)}';
          chunk = '<mark color="$hex">$chunk</mark>';
        }

        if (startStyle.fontColor != null || startStyle.fontFamily != null) {
          final colorAttr = startStyle.fontColor != null
              ? 'color="#${startStyle.fontColor!.value.toRadixString(16).padLeft(8, '0').substring(2)}"'
              : '';
          final faceAttr = startStyle.fontFamily != null ? 'face="${startStyle.fontFamily}"' : '';
          final attrs = '$colorAttr $faceAttr'.trim();
          chunk = '<font $attrs>$chunk</font>';
        }
      }

      sb.write(chunk);
      runStart = runEnd;
    }

    return sb.toString();
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

/// Style attributes of a single character in the clean WYSIWYG text.
class WordCharStyle {
  bool isBold;
  bool isItalic;
  bool isUnderline;
  bool isStrikethrough;
  Color? fontColor;
  Color? bgColor;
  String? fontFamily;
  double? fontSize;

  WordCharStyle({
    this.isBold = false,
    this.isItalic = false,
    this.isUnderline = false,
    this.isStrikethrough = false,
    this.fontColor,
    this.bgColor,
    this.fontFamily,
    this.fontSize,
  });

  WordCharStyle clone() {
    return WordCharStyle(
      isBold: isBold,
      isItalic: isItalic,
      isUnderline: isUnderline,
      isStrikethrough: isStrikethrough,
      fontColor: fontColor,
      bgColor: bgColor,
      fontFamily: fontFamily,
      fontSize: fontSize,
    );
  }

  bool isSameAs(WordCharStyle o) {
    return isBold == o.isBold &&
        isItalic == o.isItalic &&
        isUnderline == o.isUnderline &&
        isStrikethrough == o.isStrikethrough &&
        fontColor == o.fontColor &&
        bgColor == o.bgColor &&
        fontFamily == o.fontFamily &&
        fontSize == o.fontSize;
  }

  TextStyle toTextStyle(TextStyle base) {
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
