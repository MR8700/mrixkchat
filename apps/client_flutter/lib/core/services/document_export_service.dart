import 'dart:convert';
import 'real_media_service.dart';

/// Service responsible for real document export and local downloading:
/// - Microsoft Word compatible documents (.doc)
/// - Vectorized Portable Document Format (.pdf)
/// - Markdown and raw text documents (.md / .txt)
/// - Native system print / Save-as-PDF spooler
class DocumentExportService {
  static final DocumentExportService instance = DocumentExportService._();
  DocumentExportService._();

  /// Cleans filename of illegal characters
  String _sanitizeFilename(String title, String extension) {
    var safe = title.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    if (safe.isEmpty) safe = 'document_mrixk';
    if (!safe.endsWith('.$extension')) {
      safe = '$safe.$extension';
    }
    return safe;
  }

  /// Exports and downloads the document as a Markdown file (.md)
  String exportMarkdown({
    required String title,
    required String content,
  }) {
    final filename = _sanitizeFilename(title, 'md');
    final header = '# $title\n\n*Document souverain généré par MRixk*\n\n---\n\n';
    final fullDoc = '$header$content';
    final bytes = utf8.encode(fullDoc);

    RealMediaService.instance.downloadFile(
      bytes: bytes,
      filename: filename,
      mimeType: 'text/markdown;charset=utf-8',
    );

    return filename;
  }

  /// Exports and downloads the document as a Microsoft Word-compatible document (.doc)
  String exportWord({
    required String title,
    required String content,
  }) {
    final filename = _sanitizeFilename(title, 'doc');

    // Convert note content to clean HTML for Word
    final htmlContent = _convertMarkdownToWordHtml(content);

    final wordDocumentHtml = '''
<!DOCTYPE html>
<html xmlns:o='urn:schemas-microsoft-com:office:office' xmlns:w='urn:schemas-microsoft-com:office:word' xmlns='http://www.w3.org/TR/REC-html40'>
<head>
  <meta charset="utf-8">
  <title>$title</title>
  <!--[if gte mso 9]>
  <xml>
  <w:WordDocument>
    <w:View>Print</w:View>
    <w:Zoom>100</w:Zoom>
    <w:DoNotOptimizeForBrowser/>
  </w:WordDocument>
  </xml>
  <![endif]-->
  <style>
    @page {
      size: A4;
      margin: 2.5cm 2cm 2.5cm 2cm;
    }
    body {
      font-family: 'Calibri', 'Segoe UI', Arial, sans-serif;
      font-size: 11.5pt;
      color: #0F172A;
      line-height: 1.6;
    }
    h1 {
      font-size: 22pt;
      color: #1E3A8A;
      border-bottom: 2px solid #2563EB;
      padding-bottom: 6px;
      margin-bottom: 16px;
    }
    h2 {
      font-size: 16pt;
      color: #1E40AF;
      margin-top: 22px;
      margin-bottom: 10px;
    }
    h3 {
      font-size: 13pt;
      color: #2563EB;
      margin-top: 16px;
    }
    p {
      margin: 8px 0;
      text-align: justify;
    }
    table {
      border-collapse: collapse;
      width: 100%;
      margin: 18px 0;
      font-size: 10pt;
    }
    th, td {
      border: 1px solid #CBD5E1;
      padding: 9px 12px;
    }
    th {
      background-color: #F1F5F9;
      font-weight: bold;
      color: #0F172A;
      text-align: left;
    }
    tr:nth-child(even) {
      background-color: #F8FAFC;
    }
    blockquote {
      border-left: 4px solid #2563EB;
      padding: 8px 14px;
      margin: 14px 0;
      background-color: #F8FAFC;
      color: #475569;
      font-style: italic;
    }
    .badge {
      display: inline-block;
      padding: 3px 8px;
      background-color: #EEF2FF;
      color: #3730A3;
      border-radius: 4px;
      font-family: 'Consolas', monospace;
      font-size: 9.5pt;
    }
    .footer {
      margin-top: 50px;
      padding-top: 12px;
      border-top: 1px solid #E2E8F0;
      font-size: 9pt;
      color: #94A3B8;
      text-align: center;
    }
  </style>
</head>
<body>
  <h1>$title</h1>
  <p style="font-size: 9.5pt; color: #64748B; margin-bottom: 24px;">
    Document numérique certifié MRixk • Chiffrement souverain de bout en bout • Généré le ${DateTime.now().toLocal().toString().split('.').first}
  </p>
  
  <div class="document-body">
    $htmlContent
  </div>

  <div class="footer">
    MRixk Secure Workspace System — Confidentiel & Souverain
  </div>
</body>
</html>
''';

    final bytes = utf8.encode(wordDocumentHtml);
    RealMediaService.instance.downloadFile(
      bytes: bytes,
      filename: filename,
      mimeType: 'application/msword;charset=utf-8',
    );

    return filename;
  }

  /// Exports and downloads the document as a standard vector PDF file (.pdf)
  String exportPdf({
    required String title,
    required String content,
  }) {
    final filename = _sanitizeFilename(title, 'pdf');
    final pdfBytes = _generatePdf14(title, content);

    RealMediaService.instance.downloadFile(
      bytes: pdfBytes,
      filename: filename,
      mimeType: 'application/pdf',
    );

    return filename;
  }

  /// Triggers the native print dialog
  void printDocument() {
    RealMediaService.instance.printDocument();
  }

  /// Converts Markdown & MRixk tags into HTML formatted for Word
  String _convertMarkdownToWordHtml(String text) {
    final lines = text.split('\n');
    final out = StringBuffer();

    bool inTable = false;

    for (var line in lines) {
      var trimmed = line.trim();

      // Clean alignments
      String alignStyle = '';
      if (trimmed.startsWith('[align=center]')) {
        alignStyle = ' style="text-align: center;"';
        trimmed = trimmed.replaceFirst('[align=center]', '').trim();
      } else if (trimmed.startsWith('[align=right]')) {
        alignStyle = ' style="text-align: right;"';
        trimmed = trimmed.replaceFirst('[align=right]', '').trim();
      } else if (trimmed.startsWith('[align=justify]')) {
        alignStyle = ' style="text-align: justify;"';
        trimmed = trimmed.replaceFirst('[align=justify]', '').trim();
      }

      if (trimmed.isEmpty) {
        if (inTable) {
          out.writeln('</table>');
          inTable = false;
        }
        continue;
      }

      // Skip raw component definition blocks
      if (trimmed.startsWith('{{id=') || trimmed == '}}') {
        continue;
      }

      // Convert headings
      if (trimmed.startsWith('# ')) {
        out.writeln('<h1$alignStyle>${_escapeAndFormat(trimmed.substring(2))}</h1>');
      } else if (trimmed.startsWith('## ')) {
        out.writeln('<h2$alignStyle>${_escapeAndFormat(trimmed.substring(3))}</h2>');
      } else if (trimmed.startsWith('### ')) {
        out.writeln('<h3$alignStyle>${_escapeAndFormat(trimmed.substring(4))}</h3>');
      } else if (trimmed.startsWith('---') || trimmed.startsWith('***')) {
        out.writeln('<hr style="border: none; border-top: 1px solid #CBD5E1; margin: 20px 0;"/>');
      } else if (trimmed.startsWith('|') && trimmed.endsWith('|')) {
        // Markdown table
        if (trimmed.contains('---')) continue; // separator line
        if (!inTable) {
          out.writeln('<table>');
          inTable = true;
        }
        final cells = trimmed.split('|').where((c) => c.isNotEmpty).map((c) => c.trim()).toList();
        out.writeln('<tr>');
        for (final cell in cells) {
          out.writeln('<td>${_escapeAndFormat(cell)}</td>');
        }
        out.writeln('</tr>');
      } else {
        if (inTable) {
          out.writeln('</table>');
          inTable = false;
        }
        out.writeln('<p$alignStyle>${_escapeAndFormat(trimmed)}</p>');
      }
    }

    if (inTable) {
      out.writeln('</table>');
    }

    return out.toString();
  }

  String _escapeAndFormat(String input) {
    var res = input
        .replaceAll('&', '&amp;')
        .replaceAll('<font color="', '<span style="color:')
        .replaceAll('</font>', '</span>')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');

    // Re-allow span tags from font
    res = res.replaceAll('&lt;span style="color:', '<span style="color:').replaceAll('&lt;/span&gt;', '</span>');

    // Bold
    res = res.replaceAllMapped(RegExp(r'\*\*([^*]+)\*\*'), (m) => '<strong>${m.group(1)}</strong>');
    // Italic
    res = res.replaceAllMapped(RegExp(r'(?<!\*)\*([^*]+)\*(?!\*)'), (m) => '<em>${m.group(1)}</em>');
    // Code
    res = res.replaceAllMapped(RegExp(r'`([^`]+)`'), (m) => '<span class="badge">${m.group(1)}</span>');

    return res;
  }

  /// Pure Dart PDF 1.4 Vector Document Generator
  List<int> _generatePdf14(String title, String content) {
    final pdf = StringBuffer();
    final offsets = <int>[];

    void write(String str) {
      pdf.write(str);
    }

    int currentOffset() => utf8.encode(pdf.toString()).length;

    write('%PDF-1.4\n');
    write('%âãÏÓ\n'); // Binary marker for PDF viewers

    // 1 0 obj: Catalog
    offsets.add(currentOffset());
    write('1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n');

    // 2 0 obj: Pages
    offsets.add(currentOffset());
    write('2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n');

    // 3 0 obj: Page (A4: 595.28 x 841.89 points)
    offsets.add(currentOffset());
    write('3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595.28 841.89] /Resources << /Font << /F1 4 0 R /F2 5 0 R >> >> /Contents 6 0 R >>\nendobj\n');

    // 4 0 obj: Helvetica Font (Normal)
    offsets.add(currentOffset());
    write('4 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>\nendobj\n');

    // 5 0 obj: Helvetica-Bold Font
    offsets.add(currentOffset());
    write('5 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold /Encoding /WinAnsiEncoding >>\nendobj\n');

    // Prepare PDF stream contents
    final streamContent = StringBuffer();
    double y = 790.0;
    const double leftMargin = 50.0;
    const double pageWidth = 595.28;

    // Header bar
    streamContent.writeln('0.15 0.35 0.75 rg'); // Blue color
    streamContent.writeln('$leftMargin ${y - 4} ${pageWidth - leftMargin * 2} 2.5 re f');
    streamContent.writeln('0 0 0 rg');

    // Title
    y -= 25.0;
    streamContent.writeln('BT');
    streamContent.writeln('/F2 18 Tf');
    streamContent.writeln('$leftMargin $y Td');
    streamContent.writeln('(${_pdfEscape(title)}) Tj');
    streamContent.writeln('ET');

    // Subtitle
    y -= 16.0;
    streamContent.writeln('BT');
    streamContent.writeln('0.4 0.45 0.55 rg');
    streamContent.writeln('/F1 9 Tf');
    streamContent.writeln('$leftMargin $y Td');
    streamContent.writeln('(Document souverain certifie MRixk - E2EE) Tj');
    streamContent.writeln('0 0 0 rg');
    streamContent.writeln('ET');

    y -= 20.0;

    // Render lines of text
    final rawLines = content.split('\n');
    for (var rawLine in rawLines) {
      if (y < 60.0) break; // Limit single page for now or advance

      var line = rawLine.trim();
      line = line.replaceAll(RegExp(r'\[align=[^\]]+\]'), '').trim();
      line = line.replaceAll(RegExp(r'<[^>]*>'), '');

      if (line.isEmpty) {
        y -= 10.0;
        continue;
      }

      if (line.startsWith('{{id=') || line == '}}') continue;

      if (line.startsWith('# ')) {
        y -= 10.0;
        streamContent.writeln('BT');
        streamContent.writeln('0.1 0.25 0.65 rg');
        streamContent.writeln('/F2 14 Tf');
        streamContent.writeln('$leftMargin $y Td');
        streamContent.writeln('(${_pdfEscape(line.substring(2))}) Tj');
        streamContent.writeln('0 0 0 rg');
        streamContent.writeln('ET');
        y -= 16.0;
      } else if (line.startsWith('## ')) {
        y -= 8.0;
        streamContent.writeln('BT');
        streamContent.writeln('0.15 0.3 0.6 rg');
        streamContent.writeln('/F2 12 Tf');
        streamContent.writeln('$leftMargin $y Td');
        streamContent.writeln('(${_pdfEscape(line.substring(3))}) Tj');
        streamContent.writeln('0 0 0 rg');
        streamContent.writeln('ET');
        y -= 14.0;
      } else {
        // Normal text line wrapped
        final wrapped = _wrapText(line, 80);
        for (final wLine in wrapped) {
          if (y < 60.0) break;
          streamContent.writeln('BT');
          streamContent.writeln('0.1 0.1 0.15 rg');
          streamContent.writeln('/F1 10 Tf');
          streamContent.writeln('$leftMargin $y Td');
          streamContent.writeln('(${_pdfEscape(wLine)}) Tj');
          streamContent.writeln('ET');
          y -= 13.5;
        }
      }
    }

    // Footer
    streamContent.writeln('0.6 0.65 0.7 rg');
    streamContent.writeln('$leftMargin 40 ${pageWidth - leftMargin * 2} 0.5 re f');
    streamContent.writeln('BT');
    streamContent.writeln('/F1 8 Tf');
    streamContent.writeln('$leftMargin 28 Td');
    streamContent.writeln('(MRixk Sovereign Workspace - Generateur Vectoriel PDF Certifie) Tj');
    streamContent.writeln('ET');

    final streamBytes = utf8.encode(streamContent.toString());

    // 6 0 obj: Stream
    offsets.add(currentOffset());
    write('6 0 obj\n<< /Length ${streamBytes.length} >>\nstream\n');
    write(streamContent.toString());
    write('\nendstream\nendobj\n');

    // XREF Table
    final startXref = currentOffset();
    write('xref\n0 7\n');
    write('0000000000 65535 f \n');
    for (final offset in offsets) {
      write('${offset.toString().padLeft(10, '0')} 00000 n \n');
    }

    // Trailer
    write('trailer\n<< /Size 7 /Root 1 0 R >>\nstartxref\n$startXref\n%%EOF\n');

    return utf8.encode(pdf.toString());
  }

  String _pdfEscape(String text) {
    return text
        .replaceAll('\\', '\\\\')
        .replaceAll('(', '\\(')
        .replaceAll(')', '\\)')
        .replaceAll('\r', '')
        .replaceAll('\n', ' ')
        // Convert French accents to standard ASCII for WinAnsiEncoding Helvetica
        .replaceAll('é', 'e')
        .replaceAll('è', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('à', 'a')
        .replaceAll('â', 'a')
        .replaceAll('î', 'i')
        .replaceAll('ï', 'i')
        .replaceAll('ô', 'o')
        .replaceAll('ù', 'u')
        .replaceAll('û', 'u')
        .replaceAll('ç', 'c')
        .replaceAll('É', 'E')
        .replaceAll('È', 'E')
        .replaceAll('À', 'A')
        .replaceAll('Ç', 'C')
        .replaceAll('’', '\'')
        .replaceAll('–', '-')
        .replaceAll('—', '-');
  }

  List<String> _wrapText(String text, int maxChars) {
    if (text.length <= maxChars) return [text];
    final words = text.split(' ');
    final lines = <String>[];
    var currentLine = '';

    for (final word in words) {
      if ((currentLine + (currentLine.isEmpty ? '' : ' ') + word).length <= maxChars) {
        currentLine += (currentLine.isEmpty ? '' : ' ') + word;
      } else {
        if (currentLine.isNotEmpty) lines.add(currentLine);
        currentLine = word;
      }
    }
    if (currentLine.isNotEmpty) lines.add(currentLine);
    return lines;
  }
}
