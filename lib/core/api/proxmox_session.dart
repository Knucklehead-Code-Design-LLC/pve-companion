abstract interface class ProxmoxSession {
  Future<Object?> getData(String resource, {Map<String, String> query});

  Future<Object?> postForm(
    String resource, {
    required Map<String, String> fields,
  });

  void close();
}

/// A Proxmox session that can change server state.
///
/// Read-only surfaces depend only on [ProxmoxSession]. Feature repositories
/// that submit a configuration change or delete a resource opt into this
/// narrower contract so test doubles and read-only sessions stay simple.
abstract interface class ProxmoxWritableSession implements ProxmoxSession {
  Future<Object?> putForm(
    String resource, {
    required Map<String, String> fields,
  });

  Future<Object?> deleteResource(String resource, {Map<String, String> query});
}
