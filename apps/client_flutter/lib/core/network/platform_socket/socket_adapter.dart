import 'socket_interface.dart';
import 'socket_stub.dart'
    if (dart.library.html) 'socket_web.dart'
    if (dart.library.io) 'socket_io.dart';

export 'socket_interface.dart';

Future<PlatformSocket> createPlatformSocket(String url, {Duration? timeout}) =>
    connectSocket(url, timeout: timeout);
