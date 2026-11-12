abstract class PlatformSocket {
  Stream<dynamic> get stream;
  void add(String data);
  Future<void> close();
}
