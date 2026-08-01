import 'package:flutter_test/flutter_test.dart';
import 'package:pve_companion/core/api/proxmox_api_exception.dart';
import 'package:pve_companion/core/api/proxmox_session.dart';
import 'package:pve_companion/features/cluster_overview/data/proxmox_cluster_overview_repository.dart';

void main() {
  test(
    'rejects a malformed node response instead of inventing cluster state',
    () async {
      final ProxmoxClusterOverviewRepository repository =
          ProxmoxClusterOverviewRepository();
      final _FixtureSession session = _FixtureSession(<String, Object?>{
        'version': <String, Object?>{'version': '8.4'},
        'nodes': <String, Object?>{'not': 'a list'},
        'cluster/resources': const <Object?>[],
        'storage': const <Object?>[],
        'cluster/tasks': const <Object?>[],
      });

      await expectLater(
        repository.load(session),
        throwsA(isA<ProxmoxMalformedResponseException>()),
      );
    },
  );
}

class _FixtureSession implements ProxmoxSession {
  _FixtureSession(this.responses);

  final Map<String, Object?> responses;

  @override
  void close() {}

  @override
  Future<Object?> getData(
    String resource, {
    Map<String, String> query = const <String, String>{},
  }) async {
    return responses[resource];
  }

  @override
  Future<Object?> postForm(
    String resource, {
    required Map<String, String> fields,
  }) async {
    return null;
  }
}
