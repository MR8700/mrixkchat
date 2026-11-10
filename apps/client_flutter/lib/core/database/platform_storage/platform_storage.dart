import 'storage_interface.dart';
import 'storage_stub.dart'
    if (dart.library.html) 'storage_web.dart'
    if (dart.library.io) 'storage_io.dart';

export 'storage_interface.dart';

PlatformStorage createPlatformStorage() => PlatformStorageImpl();
