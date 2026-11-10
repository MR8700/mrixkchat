import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Real-time WebSocket connection to the MRixk server hub.
class WebSocketClient {
  static final WebSocketClient _instance = WebSocketClient._internal();
  factory WebSocketClient() => _instance;
  WebSocketClient._internal();

  String wsUrl = 'ws://127.0.0.1:8080/api/v1/ws';
  WebSocket? _socket;
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
      _socket = await WebSocket.connect(uri.toString())
          .timeout(const Duration(seconds: 4));
      _isConnected = true;

      _socket!.listen(
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
    _socket?.close();
    _socket = null;
    _isConnected = false;
  }
}
