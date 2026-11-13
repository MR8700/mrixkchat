import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/message_request.dart';

/// Production-ready, offline-first API Client for the MRixk Go Backend.
class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  static const String prodRemoteUrl =
      'https://mrixk-backend.onrender.com/api/v1';
  String baseUrl = prodRemoteUrl;
  String? _sessionToken;

  void setSessionToken(String token) {
    _sessionToken = token;
  }

  /// Optional override at build time: --dart-define=API_URL=https://host/api/v1
  static const String _envUrl = String.fromEnvironment('API_URL');

  bool _warmed = false;

  /// Resolves the single source-of-truth backend.
  /// Local development servers must be selected explicitly with --dart-define=API_URL=...
  Future<String> getActiveBaseUrl() async {
    if (_envUrl.isNotEmpty) {
      baseUrl = _envUrl;
      return baseUrl;
    }
    baseUrl = prodRemoteUrl;
    return baseUrl;
  }

  /// Wakes up the (free-tier) server in the background; cold starts can take up to ~60s.
  Future<bool> warmUp() async {
    final target = await getActiveBaseUrl();
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final res = await http
            .get(Uri.parse('$target/health'))
            .timeout(const Duration(seconds: 40));
        if (res.statusCode == 200) {
          _warmed = true;
          return true;
        }
      } catch (_) {}
    }
    return false;
  }

  /// GET/POST with retry and a generous first-request timeout (cold start aware).
  Future<http.Response> _send(
    Future<http.Response> Function(String base) request, {
    int retries = 2,
  }) async {
    final base = await getActiveBaseUrl();
    final timeout = Duration(seconds: _warmed ? 12 : 45);
    Object? lastError;
    for (var attempt = 0; attempt <= retries; attempt++) {
      try {
        final res = await request(base).timeout(timeout);
        if (res.statusCode >= 500 && attempt < retries) {
          await Future.delayed(Duration(milliseconds: 600 * (attempt + 1)));
          continue;
        }
        _warmed = true;
        return res;
      } catch (e) {
        lastError = e;
        await Future.delayed(Duration(milliseconds: 600 * (attempt + 1)));
      }
    }
    throw ApiUnavailableException('Serveur injoignable ($lastError)');
  }

  Map<String, String> _headers(
      {String? contentType = 'application/json', String? recoveryCode}) {
    final headers = <String, String>{};
    if (contentType != null) {
      headers['Content-Type'] = contentType;
    }
    if (_sessionToken != null) {
      headers['Authorization'] = 'Bearer $_sessionToken';
    }
    if (recoveryCode != null && recoveryCode.isNotEmpty) {
      headers['X-MRixk-Recovery-Code'] = recoveryCode;
    }
    return headers;
  }

  /// Checks if backend server is online and healthy.
  Future<bool> checkHealth() async {
    try {
      final res = await _send((base) => http.get(Uri.parse('$base/health')),
          retries: 1);
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
      final res = await http
          .post(
        Uri.parse('$targetUrl/auth/register'),
        headers: _headers(),
        body: jsonEncode({
          'handle': handle,
          'display_name': displayName,
              if (recoveryCode != null && recoveryCode.isNotEmpty)
                'recovery_code': recoveryCode,
              if (avatarUrl != null && avatarUrl.isNotEmpty)
                'avatar_url': avatarUrl,
              if (statusMessage != null && statusMessage.isNotEmpty)
                'status_message': statusMessage,
          if (password != null && password.isNotEmpty) 'password': password,
        }),
          )
          .timeout(const Duration(seconds: 65));

      if (res.statusCode == 201 || res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      } else if (res.statusCode == 409) {
        throw Exception(
            'Cet identifiant unique est déjà enregistré sur le serveur.');
      } else {
        try {
          final err = jsonDecode(res.body) as Map<String, dynamic>;
          throw Exception(
              err['error'] ?? 'Échec de l\'enregistrement sur le serveur.');
        } catch (e) {
          if (e is Exception) rethrow;
          throw Exception(
              'Erreur serveur lors de l\'enregistrement (${res.statusCode}).');
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
    final res = await _send((base) => http.post(
      Uri.parse('$base/auth/recover'),
      headers: _headers(),
      body: jsonEncode({
        'recovery_code': cleanCode,
            if (preferredName != null && preferredName.isNotEmpty)
              'preferred_name': preferredName.trim(),
            if (preferredHandle != null && preferredHandle.isNotEmpty)
              'preferred_handle': preferredHandle.trim(),
      }),
    ));
    if (res.statusCode == 200)
      return jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 404)
      throw Exception(
          'Identifiant ou code de secours introuvable sur le serveur.');
    throw ApiUnavailableException(
        'Récupération impossible (${res.statusCode})');
  }

  /// Synchronizes profile updates to the server.
  /// Note: The sovereign handle (@handle) is strictly immutable and cannot be changed.
  Future<bool> updateProfile({
    required String userId,
    String? displayName,
    String? avatarUrl,
    String? statusMessage,
    String? recoveryCode,
  }) async {
    final targetUrl = await getActiveBaseUrl();
    try {
      final res = await http
          .put(
        Uri.parse('$targetUrl/users/$userId'),
        headers: _headers(recoveryCode: recoveryCode),
        body: jsonEncode({
          if (displayName != null) 'display_name': displayName,
          if (avatarUrl != null) 'avatar_url': avatarUrl,
          if (statusMessage != null) 'status_message': statusMessage,
        }),
          )
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Searches genuine registered users on the server.
  /// Throws [ApiUnavailableException] when the server cannot be reached (never a silent empty list).
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    final encoded = Uri.encodeComponent(query.trim());
    final res = await _send((base) => http.get(
          Uri.parse('$base/users/search?q=$encoded'),
          headers: _headers(),
        ));
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final list = data['users'] as List<dynamic>?;
      if (list != null) {
        return list
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
      }
      return [];
    }
    throw ApiUnavailableException(
        'Réponse serveur inattendue (${res.statusCode})');
  }

  /// Permanently deletes the account on the server (owner proven by recovery code).
  /// Returns true when the account is deleted (or already gone).
  Future<bool> deleteAccount(
      {required String userId, required String recoveryCode}) async {
    final res = await _send((base) => http.delete(
          Uri.parse('$base/users/$userId'),
          headers: _headers(recoveryCode: recoveryCode.trim().toUpperCase()),
        ));
    if (res.statusCode == 200) return true;
    if (res.statusCode == 404)
      return true; // unknown to the server: nothing left to delete
    if (res.statusCode == 403) {
      throw Exception('Suppression refusée : code de récupération invalide.');
    }
    throw ApiUnavailableException('Suppression impossible (${res.statusCode})');
  }

  /// Re-registers the same local identity when a server reset erased it.
  Future<Map<String, dynamic>> restoreAccount({
    required String userId,
    required String handle,
    required String displayName,
    required String recoveryCode,
    String? avatarUrl,
    String? statusMessage,
  }) async {
    final res = await _send((base) => http.post(
      Uri.parse('$base/auth/restore'),
      headers: _headers(),
      body: jsonEncode({
        'user_id': userId,
        'handle': handle,
        'display_name': displayName,
        'recovery_code': recoveryCode,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
        if (statusMessage != null) 'status_message': statusMessage,
      }),
    ));
    if (res.statusCode == 201)
      return jsonDecode(res.body) as Map<String, dynamic>;
    final message = _responseError(res.body) ??
        'Restauration impossible (${res.statusCode})';
    throw Exception(message);
  }

  String? _responseError(String body) {
    try {
      final data = jsonDecode(body) as Map<String, dynamic>;
      return data['error']?.toString();
    } catch (_) {
      return null;
    }
  }

  /// Reconciles known accounts with the server: which still exist, which were deleted.
  /// Returns null when the server is unreachable (callers must not change local state then).
  Future<UsersStatus?> usersStatus(List<String> ids) async {
    if (ids.isEmpty) return UsersStatus(active: {}, deleted: {});
    try {
      final res = await _send(
        (base) => http.post(
          Uri.parse('$base/users/status'),
          headers: _headers(),
          body: jsonEncode({'ids': ids}),
        ),
        retries: 1,
      );
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final active = <String, Map<String, dynamic>>{};
      for (final u in (data['active'] as List? ?? [])) {
        final m = Map<String, dynamic>.from(u as Map);
        active[(m['id'] ?? '').toString()] = m;
      }
      final deleted = <String, Map<String, dynamic>>{};
      for (final u in (data['deleted'] as List? ?? [])) {
        final m = Map<String, dynamic>.from(u as Map);
        deleted[(m['user_id'] ?? '').toString()] = m;
      }
      final missing =
          (data['missing'] as List? ?? []).map((id) => id.toString()).toSet();
      return UsersStatus(active: active, deleted: deleted, missing: missing);
    } on ApiUnavailableException {
      return null;
    }
  }

  /// Verifies if an identifier (user_id or @handle) exists on the server.
  Future<Map<String, dynamic>?> verifyContact(String identifier) async {
    final res = await _send((base) => http.post(
      Uri.parse('$base/contacts/verify'),
      headers: _headers(),
      body: jsonEncode({'identifier': identifier.trim()}),
    ));
    if (res.statusCode == 200)
      return jsonDecode(res.body) as Map<String, dynamic>;
    throw ApiUnavailableException(
        'Vérification impossible (${res.statusCode})');
  }

  /// Looks up a user by ID or handle from the server.
  Future<Map<String, dynamic>?> getUser(String idOrHandle) async {
    final encoded = Uri.encodeComponent(idOrHandle.trim());
    final res = await _send((base) =>
        http.get(Uri.parse('$base/users/$encoded'), headers: _headers()));
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return data['user'] as Map<String, dynamic>?;
    }
    if (res.statusCode == 404 || res.statusCode == 410) return null;
    throw ApiUnavailableException('Recherche impossible (${res.statusCode})');
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

  /// Delivers a first-contact message to the recipient's request inbox.
  Future<bool> sendMessageRequest({
    required String senderId,
    required String recipientId,
    required String messageId,
    required String conversationId,
    required String content,
    required String recoveryCode,
    String messageType = 'text',
  }) async {
    final res = await _send((base) => http.post(
          Uri.parse(
              '$base/users/${Uri.encodeComponent(senderId)}/message-requests'),
          headers: _headers(recoveryCode: recoveryCode.trim().toUpperCase()),
          body: jsonEncode({
            'id': messageId,
            'recipient_id': recipientId,
            'conversation_id': conversationId,
            'content': content,
            'message_type': messageType,
          }),
        ));
    if (res.statusCode == 201) return true;
    if (res.statusCode == 403)
      throw Exception('Code de secours invalide pour envoyer ce message.');
    if (res.statusCode == 404)
      throw Exception('Le destinataire n’existe plus sur le serveur.');
    throw ApiUnavailableException(
        'Le message n’a pas été remis (${res.statusCode})');
  }

  Future<List<MessageRequest>> fetchMessageRequests({
    required String userId,
    required String recoveryCode,
  }) async {
    final res = await _send((base) => http.get(
          Uri.parse(
              '$base/users/${Uri.encodeComponent(userId)}/message-requests'),
          headers: _headers(recoveryCode: recoveryCode.trim().toUpperCase()),
        ));
    if (res.statusCode != 200) return const [];
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return (data['requests'] as List? ?? [])
        .map((item) =>
            MessageRequest.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<bool> respondToMessageRequest({
    required String userId,
    required String recoveryCode,
    required String requestId,
    required bool accept,
  }) async {
    final res = await _send((base) => http.post(
          Uri.parse(
              '$base/users/${Uri.encodeComponent(userId)}/message-requests/${Uri.encodeComponent(requestId)}'),
          headers: _headers(recoveryCode: recoveryCode.trim().toUpperCase()),
          body: jsonEncode({'status': accept ? 'ACCEPTED' : 'IGNORED'}),
        ));
    if (res.statusCode == 200) return true;
    if (res.statusCode == 404) return false;
    throw ApiUnavailableException(
        'La demande n’a pas pu être traitée (${res.statusCode})');
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

/// Raised when the online server cannot be reached.
class ApiUnavailableException implements Exception {
  final String message;
  ApiUnavailableException(this.message);
  @override
  String toString() => message;
}

/// Result of reconciling local contacts/members with the server.
class UsersStatus {
  final Map<String, Map<String, dynamic>> active;
  final Map<String, Map<String, dynamic>> deleted;
  final Set<String> missing;
  UsersStatus(
      {required this.active, required this.deleted, this.missing = const {}});
}
