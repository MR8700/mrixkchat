import 'dart:async';
import 'dart:convert';
import 'platform_socket/socket_adapter.dart';

/// Real-time multiplatform WebSocket connection to the MRixk server hub.
class WebSocketClient {
  static final WebSocketClient _instance = WebSocketClient._internal();
  factory WebSocketClient() => _instance;
  WebSocketClient._internal();

  String wsUrl = 'wss://mrixk-backend.onrender.com/api/v1/ws';
  PlatformSocket? _socket;
  StreamSubscription? _socketSubscription;
  bool _isConnected = false;
  bool get isConnected => _isConnected;

  final StreamController<Map<String, dynamic>> _eventController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get events => _eventController.stream;

  Timer? _reconnectTimer;
  String? _token;

  Future<void> connect(String token) async {
    _token = token;
    if (_isConnected) return;

    try {
      final uri = Uri.parse('$wsUrl?token=$token');
      _socket = await createPlatformSocket(uri.toString(), timeout: const Duration(seconds: 4));
      _isConnected = true;

      _socketSubscription?.cancel();
      _socketSubscription = _socket!.stream.listen(
        (data) {
          try {
            if (data is String) {
              final jsonEvent = jsonDecode(data) as Map<String, dynamic>;
              _eventController.add(jsonEvent);
            }
          } catch (_) {}
        },
        onDone: () {
          _isConnected = false;
          _scheduleReconnect();
        },
        onError: (err) {
          _isConnected = false;
          _scheduleReconnect();
        },
        cancelOnError: true,
      );
    } catch (_) {
      _isConnected = false;
      _scheduleReconnect();
    }
  }

  void send(Map<String, dynamic> event) {
    if (_isConnected && _socket != null) {
      try {
        _socket!.add(jsonEncode(event));
      } catch (_) {}
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (!_isConnected && _token != null) {
        connect(_token!);
      }
    });
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _socketSubscription?.cancel();
    _socketSubscription = null;
    _socket?.close();
    _socket = null;
    _isConnected = false;
  }
}
