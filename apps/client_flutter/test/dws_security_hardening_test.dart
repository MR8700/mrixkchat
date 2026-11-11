import 'package:flutter_test/flutter_test.dart';
import 'package:mrixk_client/core/services/formula_engine.dart';
import 'package:mrixk_client/features/discussions/widgets/group_note_renderer.dart';

void main() {
  group('MRixk Security Hardening & Zero-Trust Threat Mitigation', () {
    test('Anti-DoS : Rejet des expressions à profondeur excessive (limite 32 niveaux)', () {
      // Create deeply nested expression with 60 levels: (((((... 5 ...)))))
      final nested = '('*60 + '5' + ')'*60;
      final result = FormulaEngine.evaluateExpression(nested, {});
      expect(result, isNull);
    });

    test('Anti-DoS : Rejet des expressions saturées de tokens (> 512 tokens)', () {
      // Build expression with 600 additions: 1 + 1 + 1 + ...
      final massive = List.generate(600, (_) => '1').join(' + ');
      final result = FormulaEngine.evaluateExpression(massive, {});
      expect(result, isNull);
    });

    test('Zero-Code-Execution : Blocage strict des mots-clés d\'évasion et d\'exécution système', () {
      const maliciousPayloads = [
        'eval("malicious")',
        'system("rm -rf /")',
        'exec("whoami")',
        'execute("cat /etc/passwd")',
        'window.location',
        'document.cookie',
        'fetch("https://attacker.com")',
        'readFile("/keys/private.pem")',
        'require("child_process")',
        'constructor.constructor("alert(1)")',
        '__proto__.polluted = true',
      ];

      for (final payload in maliciousPayloads) {
        final result = FormulaEngine.evaluateExpression(payload, {});
        expect(result, isNull, reason: 'Payload "$payload" must be rejected');
      }
    });

    test('XSS & SVG Sanitization : Neutralisation totale des scripts, objets et gestionnaires d\'événements', () {
      const dirtyHtml = '''
<div>
  <h1>Titre Inoffensif</h1>
  <script>alert("XSS Script");</script>
  <iframe src="javascript:alert('XSS Frame')"></iframe>
  <object data="malicious.swf"></object>
  <embed src="exploit.pdf">
  <applet code="Malicious.class"></applet>
  <style>body { display: none; }</style>
  <meta http-equiv="refresh" content="0;url=http://attacker.com">
  <link rel="stylesheet" href="http://attacker.com/evil.css">
  <svg onload="alert('XSS SVG')">
    <foreignObject>
      <body xmlns="http://www.w3.org/1999/xhtml"><script>alert(1)</script></body>
    </foreignObject>
    <a xlink:href="javascript:alert('XSS Link')"><text>Click</text></a>
  </svg>
  <img src="valid.png" onerror="alert('XSS Img')" onclick="fetch('http://leak.com')"/>
  <a href="javascript:void(0)">Lien</a>
  <a href="vbscript:msgbox('hack')">VB</a>
</div>
''';

      final cleanHtml = sanitizeHtml(dirtyHtml);

      expect(cleanHtml.contains('<script'), isFalse);
      expect(cleanHtml.contains('<iframe'), isFalse);
      expect(cleanHtml.contains('<object'), isFalse);
      expect(cleanHtml.contains('<embed'), isFalse);
      expect(cleanHtml.contains('<applet'), isFalse);
      expect(cleanHtml.contains('<style'), isFalse);
      expect(cleanHtml.contains('<meta'), isFalse);
      expect(cleanHtml.contains('<link'), isFalse);
      expect(cleanHtml.contains('<foreignObject'), isFalse);
      expect(cleanHtml.contains('onload='), isFalse);
      expect(cleanHtml.contains('onerror='), isFalse);
      expect(cleanHtml.contains('onclick='), isFalse);
      expect(cleanHtml.contains('javascript:'), isFalse);
      expect(cleanHtml.contains('vbscript:'), isFalse);
      expect(cleanHtml.contains('xlink:href'), isFalse);
      // Valid text remains intact
      expect(cleanHtml.contains('Titre Inoffensif'), isTrue);
    });

    test('Anti-Sondage & Timing Neutral : Erreur uniforme sur l\'opérateur .? sans fuite d\'existence', () {
      final externalDocs = {
        'SecretDoc': {'private_val': 42.0},
      };

      // Querying non-existent doc vs querying non-existent variable in existing doc
      final res1 = FormulaEngine.evaluateCalculatorMacro('Inconnu.?val', {}, externalDocs: externalDocs);
      final res2 = FormulaEngine.evaluateCalculatorMacro('SecretDoc.?autre', {}, externalDocs: externalDocs);

      // Both must start with the standard uniform warning badge
      expect(res1.startsWith('⚠️ Variable introuvable'), isTrue);
      expect(res2.startsWith('⚠️ Variable introuvable'), isTrue);
    });

    test('Détection des dépendances cycliques interdocuments', () {
      final externalDocs = {
        'DocA': {'valA': 10.0},
        'DocB': {'valB': 20.0},
      };
      final graph = <String, Set<String>>{
        'DocA': {'DocB'},
        'DocB': {'DocA'}, // cycle DocA -> DocB -> DocA
      };

      // In evaluateExpression, CircularDependencyException is rethrown
      expect(
        () => FormulaEngine.evaluateExpression(
          'DocB.valB',
          {},
          externalDocs: externalDocs,
          currentDoc: 'DocA',
          graph: graph,
        ),
        throwsA(isA<CircularDependencyException>()),
      );

      // In evaluateCalculatorMacro, it returns an explicit warning
      final macroRes = FormulaEngine.evaluateCalculatorMacro(
        'DocB.valB',
        {},
        externalDocs: externalDocs,
        currentDoc: 'DocA',
        graph: graph,
      );
      expect(macroRes.startsWith('⚠️ Dépendance circulaire détectée'), isTrue);
    });
  });
}
