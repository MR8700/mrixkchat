import 'dart:async';
import 'dart:html' as html;
import 'socket_interface.dart';

Future<PlatformSocket> connectSocket(String url, {Duration? timeout}) async {
  final ws = html.WebSocket(url);
  final completer = Completer<PlatformSocket>();

  ws.onOpen.first.then((_) {
    if (!completer.isCompleted) completer.complete(_WebPlatformSocket(ws));
  });

  ws.onError.first.then((e) {
    if (!completer.isCompleted) completer.completeError(e);
  });

  return completer.future.timeout(timeout ?? const Duration(seconds: 4));
}

class _WebPlatformSocket implements PlatformSocket {
  final html.WebSocket _ws;
  _WebPlatformSocket(this._ws);

  @override
  Stream<dynamic> get stream => _ws.onMessage.map((event) => event.data);

  @override
  void add(String data) => _ws.send(data);

  @override
  Future<void> close() async => _ws.close();
}
