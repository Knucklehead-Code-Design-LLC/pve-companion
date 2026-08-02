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

  test('merges storage configuration with resource telemetry', () async {
    final ProxmoxClusterOverviewRepository repository =
        ProxmoxClusterOverviewRepository();
    final _FixtureSession session = _FixtureSession(<String, Object?>{
      'version': <String, Object?>{'version': '9.2'},
      'nodes': const <Object?>[],
      'cluster/resources': <Object?>[
        <String, Object?>{'type': 'node', 'node': 'pve-01', 'status': 'online'},
        <String, Object?>{
          'type': 'qemu',
          'vmid': 101,
          'node': 'pve-01',
          'status': 'running',
          'name': 'runner-01',
        },
        <String, Object?>{
          'type': 'storage',
          'storage': 'backup-nfs',
          'node': 'pve-01',
          'status': 'available',
          'disk': 400,
          'maxdisk': 1000,
        },
        <String, Object?>{
          'type': 'storage',
          'storage': 'backup-nfs',
          'node': 'pve-02',
          'status': 'available',
          'disk': 400,
          'maxdisk': 1000,
        },
      ],
      'storage': <Object?>[
        <String, Object?>{
          'storage': 'backup-nfs',
          'type': 'nfs',
          'content': 'backup',
          'shared': 1,
        },
      ],
      'cluster/tasks': List<Object?>.generate(
        26,
        (int index) => <String, Object?>{
          'upid': 'UPID:pve-01:$index',
          'node': 'pve-01',
          'type': 'task',
          'user': 'root@pam',
        },
      ),
    });

    final snapshot = await repository.load(session);

    expect(snapshot.storages.single.reportedNodeCount, 2);
    expect(snapshot.storages.single.usedBytes, 400);
    expect(snapshot.storages.single.capacityBytes, 1000);
    expect(snapshot.storages.single.usageFraction, 0.4);
    expect(snapshot.guests.single.vmid, 101);
    expect(snapshot.tasks, hasLength(25));
    expect(
      session.requests,
      contains(const _SessionRequest('cluster/resources', <String, String>{})),
    );
    expect(
      session.requests.where(
        (_SessionRequest request) => request.resource == 'cluster/resources',
      ),
      hasLength(1),
    );
  });

  test('keeps configured storage when telemetry is not authorized', () async {
    final ProxmoxClusterOverviewRepository repository =
        ProxmoxClusterOverviewRepository();
    final _FixtureSession session = _FixtureSession(<String, Object?>{
      'version': <String, Object?>{'version': '9.2'},
      'nodes': const <Object?>[],
      'cluster/resources': const ProxmoxUnauthorizedException(
        'Permission denied.',
      ),
      'storage': <Object?>[
        <String, Object?>{
          'storage': 'local',
          'type': 'dir',
          'content': 'images',
        },
      ],
      'cluster/tasks': const <Object?>[],
    });

    final snapshot = await repository.load(session);

    expect(snapshot.storages.single.name, 'local');
    expect(snapshot.storages.single.resources, isEmpty);
    expect(snapshot.storages.single.capacityBytes, isNull);
  });
}

class _FixtureSession implements ProxmoxSession {
  _FixtureSession(this.responses);

  final Map<String, Object?> responses;
  final List<_SessionRequest> requests = <_SessionRequest>[];

  @override
  void close() {}

  @override
  Future<Object?> getData(
    String resource, {
    Map<String, String> query = const <String, String>{},
  }) async {
    requests.add(_SessionRequest(resource, query));
    final Object? response = responses[resource];
    if (response is Exception) {
      throw response;
    }
    return response;
  }

  @override
  Future<Object?> postForm(
    String resource, {
    required Map<String, String> fields,
  }) async {
    return null;
  }
}

class _SessionRequest {
  const _SessionRequest(this.resource, this.query);

  final String resource;
  final Map<String, String> query;

  @override
  bool operator ==(Object other) {
    return other is _SessionRequest &&
        other.resource == resource &&
        _sameMap(other.query, query);
  }

  @override
  int get hashCode => Object.hash(resource, _canonicalQuery(query));
}

bool _sameMap(Map<String, String> left, Map<String, String> right) {
  if (left.length != right.length) {
    return false;
  }
  return left.entries.every((MapEntry<String, String> entry) {
    return right[entry.key] == entry.value;
  });
}

String _canonicalQuery(Map<String, String> query) {
  final List<String> keys = query.keys.toList()..sort();
  return keys.map((String key) => '$key=${query[key]}').join('&');
}
