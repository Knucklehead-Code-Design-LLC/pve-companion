abstract interface class ProxmoxSession {
  Future<Object?> getData(String resource, {Map<String, String> query});

  Future<Object?> postForm(
    String resource, {
    required Map<String, String> fields,
  });

  void close();
}
