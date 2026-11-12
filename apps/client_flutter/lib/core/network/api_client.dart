import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Production-ready, offline-first API Client for the MRixk Go Backend.
class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  static const String prodRemoteUrl = 'https://mrixk-backend.onrender.com/api/v1';
  static const String localFallbackUrl = 'http://localhost:8080/api/v1';
  String baseUrl = prodRemoteUrl;
  String? _sessionToken;

  void setSessionToken(String token) {
    _sessionToken = token;
  }

  /// Automatically resolves the active backend server (local or production).
  /// Strictly online-first as required: prioritizes the production backend.
  Future<String> getActiveBaseUrl() async {
    if (kIsWeb) {
      // In web browser: if served over HTTPS or on GitHub Pages / remote domain,
      // Mixed Content rules strictly forbid connecting to insecure http://localhost.
      if (Uri.base.scheme == 'https' || !Uri.base.host.contains('localhost')) {
        baseUrl = prodRemoteUrl;
        return baseUrl;
      }
    }

    // 1. Online-first: prioritize the remote production server
    try {
      final res = await http.get(Uri.parse('$prodRemoteUrl/health')).timeout(const Duration(milliseconds: 2000));
      if (res.statusCode == 200) {
        baseUrl = prodRemoteUrl;
        return baseUrl;
      }
    } catch (_) {}

    // 2. Fallback to local server if offline or running in local dev without internet
    try {
      final res = await http.get(Uri.parse('$localFallbackUrl/health')).timeout(const Duration(milliseconds: 600));
      if (res.statusCode == 200) {
        baseUrl = localFallbackUrl;
        return baseUrl;
      }
    } catch (_) {}

    return baseUrl;
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
      final targetUrl = await getActiveBaseUrl();
      final res = await http.get(Uri.parse('$targetUrl/health')).timeout(const Duration(seconds: 2));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Registers a new sovereign account on the server online FIRST.
  Future<Map<String, dynamic>?> register({
    required String handle,
    required String displayName,
    String? recoveryCode,
    String? avatarUrl,
    String? statusMessage,
    String? password,
  }) async {
    final targetUrl = await getActiveBaseUrl();
    try {
      final res = await http.post(
        Uri.parse('$targetUrl/auth/register'),
        headers: _headers(),
        body: jsonEncode({
          'handle': handle,
          'display_name': displayName,
          if (recoveryCode != null && recoveryCode.isNotEmpty) 'recovery_code': recoveryCode,
          if (avatarUrl != null && avatarUrl.isNotEmpty) 'avatar_url': avatarUrl,
          if (statusMessage != null && statusMessage.isNotEmpty) 'status_message': statusMessage,
          if (password != null && password.isNotEmpty) 'password': password,
        }),
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 201 || res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      } else if (res.statusCode == 409) {
        throw Exception('Cet identifiant unique est déjà enregistré sur le serveur.');
      } else {
        try {
          final err = jsonDecode(res.body) as Map<String, dynamic>;
          throw Exception(err['error'] ?? 'Échec de l\'enregistrement sur le serveur.');
        } catch (e) {
          if (e is Exception) rethrow;
          throw Exception('Erreur serveur lors de l\'enregistrement (${res.statusCode}).');
        }
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Impossible de contacter le serveur en ligne : $e');
    }
  }

  /// Recovers an existing account by recovery code from the server online FIRST.
  Future<Map<String, dynamic>?> recover({
    required String recoveryCode,
    String? preferredName,
    String? preferredHandle,
  }) async {
    final cleanCode = recoveryCode.trim().toUpperCase();
    final targetUrl = await getActiveBaseUrl();
    final serversToTry = [
      targetUrl,
      if (targetUrl != prodRemoteUrl) prodRemoteUrl,
      if (targetUrl != localFallbackUrl && !kIsWeb) localFallbackUrl,
    ];

    Exception? lastException;
    for (final server in serversToTry) {
      try {
        final res = await http.post(
          Uri.parse('$server/auth/recover'),
          headers: _headers(),
          body: jsonEncode({
            'recovery_code': cleanCode,
            if (preferredName != null && preferredName.isNotEmpty) 'preferred_name': preferredName.trim(),
            if (preferredHandle != null && preferredHandle.isNotEmpty) 'preferred_handle': preferredHandle.trim(),
          }),
        ).timeout(const Duration(seconds: 6));

        if (res.statusCode == 200) {
          return jsonDecode(res.body) as Map<String, dynamic>;
        }
      } catch (e) {
        if (e is Exception) lastException = e;
      }
    }

    if (lastException != null) throw lastException;
    throw Exception('Identifiant ou code de secours introuvable sur le serveur.');
  }

  /// Synchronizes profile updates to the server.
  /// Note: The sovereign handle (@handle) is strictly immutable and cannot be changed.
  Future<bool> updateProfile({
    required String userId,
    String? displayName,
    String? avatarUrl,
    String? statusMessage,
  }) async {
    final targetUrl = await getActiveBaseUrl();
    try {
      final res = await http.put(
        Uri.parse('$targetUrl/users/$userId'),
        headers: _headers(),
        body: jsonEncode({
          if (displayName != null) 'display_name': displayName,
          if (avatarUrl != null) 'avatar_url': avatarUrl,
          if (statusMessage != null) 'status_message': statusMessage,
        }),
      ).timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Searches genuine registered users on the server.
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    final targetUrl = await getActiveBaseUrl();
    try {
      final encoded = Uri.encodeComponent(query.trim());
      final res = await http.get(
        Uri.parse('$targetUrl/users/search?q=$encoded'),
        headers: _headers(),
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final list = data['users'] as List<dynamic>?;
        if (list != null) {
          return list.map((item) => Map<String, dynamic>.from(item as Map)).toList();
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Verifies if an identifier (user_id or @handle) exists on the server.
  Future<Map<String, dynamic>?> verifyContact(String identifier) async {
    final targetUrl = await getActiveBaseUrl();
    try {
      final res = await http.post(
        Uri.parse('$targetUrl/contacts/verify'),
        headers: _headers(),
        body: jsonEncode({'identifier': identifier.trim()}),
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Looks up a user by ID or handle from the server.
  Future<Map<String, dynamic>?> getUser(String idOrHandle) async {
    final targetUrl = await getActiveBaseUrl();
    try {
      final encoded = Uri.encodeComponent(idOrHandle.trim());
      final res = await http.get(
        Uri.parse('$targetUrl/users/$encoded'),
        headers: _headers(),
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return data['user'] as Map<String, dynamic>?;
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
