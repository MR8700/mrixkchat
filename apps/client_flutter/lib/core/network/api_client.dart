import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Production-ready, offline-first API Client for the MRixk Go Backend.
class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  String baseUrl = 'https://mrixk-backend.onrender.com/api/v1';
  String? _sessionToken;

  void setSessionToken(String token) {
    _sessionToken = token;
  }

  Map<String, String> _headers({String? contentType = 'application/json'}) {
    final headers = <String, String>{};
    if (contentType != null) {
      headers['Content-Type'] = contentType;
    }
    if (_sessionToken != null) {
      headers['Authorization'] = 'Bearer $_sessionToken';
    }
    return headers;
  }

  /// Checks if backend server is online and healthy.
  Future<bool> checkHealth() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/health')).timeout(const Duration(seconds: 2));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Registers a new sovereign account on the server.
  Future<Map<String, dynamic>?> register({
    required String handle,
    required String password,
    required String displayName,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: _headers(),
        body: jsonEncode({
          'handle': handle,
          'password': password,
          'display_name': displayName,
        }),
      );
      if (res.statusCode == 201) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Authorizes a device and receives a session token.
  Future<String?> authorizeDevice({
    required String handle,
    required String password,
    required String deviceName,
    required String platform,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/devices/authorize'),
        headers: _headers(),
        body: jsonEncode({
          'handle': handle,
          'password': password,
          'device_name': deviceName,
          'platform': platform,
        }),
      );
      if (res.statusCode == 201) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final token = data['session_token'] as String?;
        if (token != null) {
          setSessionToken(token);
        }
        return token;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Sends an encrypted E2EE message envelope to the relay server.
  Future<bool> sendEncryptedMessage({
    required String conversationId,
    required String ciphertext,
    required String idempotencyKey,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/messages'),
        headers: _headers(),
        body: jsonEncode({
          'conversation_id': conversationId,
          'ciphertext': ciphertext,
          'idempotency_key': idempotencyKey,
          'protocol_version': 1,
        }),
      );
      return res.statusCode == 201;
    } catch (_) {
      // Offline: returns false so caller can retain in outbox queue
      return false;
    }
  }

  /// Fetches delta synchronization events from the server since sequence cursor.
  Future<List<dynamic>> fetchSyncEvents({int cursor = 0}) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/sync/events?cursor=$cursor'),
        headers: _headers(),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return (data['events'] as List<dynamic>?) ?? [];
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Uploads an encrypted media blob to the relay server.
  Future<String?> uploadMedia({
    required String mediaId,
    required List<int> bytes,
    required String mimeType,
    required String sha256Hash,
  }) async {
    try {
      final headers = _headers(contentType: mimeType);
      headers['X-Media-ID'] = mediaId;
      headers['X-Media-SHA256'] = sha256Hash;

      final res = await http.post(
        Uri.parse('$baseUrl/media/upload'),
        headers: headers,
        body: bytes,
      );
      if (res.statusCode == 201) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return data['id'] as String?;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Downloads an encrypted media blob from the relay server.
  Future<List<int>?> downloadMedia(String mediaId) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/media/$mediaId'),
        headers: _headers(contentType: null),
      );
      if (res.statusCode == 200) {
        return res.bodyBytes;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Sends a WebRTC call offer to peer through the server.
  Future<bool> sendCallOffer({
    required String callId,
    required String calleeId,
    required String type,
    required String sdpOffer,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/calls/offer'),
        headers: _headers(),
        body: jsonEncode({
          'call_id': callId,
          'callee_id': calleeId,
          'type': type,
          'sdp_offer': sdpOffer,
        }),
      );
      return res.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  /// Queries the local assistant AI via the server engine.
  Future<String?> queryAI(String prompt) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/ai/query'),
        headers: _headers(),
        body: jsonEncode({'prompt': prompt}),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return data['answer'] as String?;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
