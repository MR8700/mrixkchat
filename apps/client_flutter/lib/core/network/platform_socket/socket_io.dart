import 'dart:io';
import 'socket_interface.dart';

Future<PlatformSocket> connectSocket(String url, {Duration? timeout}) async {
  final ws = await WebSocket.connect(url).timeout(timeout ?? const Duration(seconds: 4));
  return _IoPlatformSocket(ws);
}

class _IoPlatformSocket implements PlatformSocket {
  final WebSocket _ws;
  _IoPlatformSocket(this._ws);

  @override
  Stream<dynamic> get stream => _ws;

  @override
  void add(String data) => _ws.add(data);

  @override
  Future<void> close() => _ws.close();
}
