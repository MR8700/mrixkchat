import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mrixk_client/core/database/local_database.dart';
import 'package:mrixk_client/core/network/api_client.dart';
import 'package:mrixk_client/core/network/websocket_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocalDatabase File Persistence Suite', () {
    test('Persists database to disk and restores it faithfully', () async {
      final tempDir = await Directory.systemTemp.createTemp('mrixk_db_test_');
      final dbFile = File('${tempDir.path}/test_db.json');

      try {
        final db = LocalDatabase();
        await db.initialize();

        // Insert test record
        await db.insert('contacts', 'c-persist-1', {
          'id': 'c-persist-1',
          'name': 'Sovereign Contact',
          'publicKey': 'pubkey-abc-123',
          'isVerified': true,
        });

        // Persist to file
        final saved = await db.persistToFile(dbFile.path);
        expect(saved, isTrue);
        expect(await dbFile.exists(), isTrue);

        // Export and verify JSON content
        final content = await dbFile.readAsString();
        expect(content.contains('Sovereign Contact'), isTrue);

        // Clear in-memory and reload from file
        await db.delete('contacts', 'c-persist-1');
        expect(db.getAll('contacts'), isEmpty);

        final loaded = await db.loadFromFile(dbFile.path);
        expect(loaded, isTrue);

        final restored = db.getAll('contacts');
        expect(restored.length, 1);
        expect(restored.first['name'], 'Sovereign Contact');
      } finally {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      }
    });
  });

  group('Network & Protocol Clients Suite', () {
    test('ApiClient handles offline fallback gracefully without throwing', () async {
      final client = ApiClient();
      client.baseUrl = 'http://127.0.0.1:59999/api/v1'; // Unbound test port
      client.setSessionToken('test-token-jwt');

      // Attempt to send encrypted message when backend is unreachable
      final res = await client.sendEncryptedMessage(
        conversationId: 'conv-test-1',
        ciphertext: 'base64-cipher',
        idempotencyKey: 'idemp-12345',
      );

      // Should return false (safe offline fallback retaining in local outbox)
      expect(res, isFalse);
    });

    test('WebSocketClient maintains connection state and listeners', () {
      final wsClient = WebSocketClient();
      wsClient.wsUrl = 'ws://127.0.0.1:59999/api/v1/ws';
      expect(wsClient.isConnected, isFalse);

      var eventReceived = false;
      final sub = wsClient.events.listen((event) {
        eventReceived = true;
      });

      // Disconnect safely when never connected
      wsClient.disconnect();
      expect(wsClient.isConnected, isFalse);
      expect(eventReceived, isFalse);

      sub.cancel();
    });
  });
}
