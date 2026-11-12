import 'socket_interface.dart';

Future<PlatformSocket> connectSocket(String url, {Duration? timeout}) async {
  throw UnsupportedError('Platform not supported for sockets');
}
