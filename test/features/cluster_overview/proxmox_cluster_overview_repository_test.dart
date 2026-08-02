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
      'cluster/resources?type=vm': const <Object?>[],
      'storage': <Object?>[
        <String, Object?>{
          'storage': 'backup-nfs',
          'type': 'nfs',
          'content': 'backup',
          'shared': 1,
        },
      ],
      'cluster/resources?type=storage': <Object?>[
        <String, Object?>{
          'storage': 'backup-nfs',
          'node': 'pve-01',
          'status': 'available',
          'disk': 400,
          'maxdisk': 1000,
        },
        <String, Object?>{
          'storage': 'backup-nfs',
          'node': 'pve-02',
          'status': 'available',
          'disk': 400,
          'maxdisk': 1000,
        },
      ],
      'cluster/tasks': const <Object?>[],
    });

    final snapshot = await repository.load(session);

    expect(snapshot.storages.single.reportedNodeCount, 2);
    expect(snapshot.storages.single.usedBytes, 400);
    expect(snapshot.storages.single.capacityBytes, 1000);
    expect(snapshot.storages.single.usageFraction, 0.4);
  });

  test('keeps configured storage when telemetry is not authorized', () async {
    final ProxmoxClusterOverviewRepository repository =
        ProxmoxClusterOverviewRepository();
    final _FixtureSession session = _FixtureSession(<String, Object?>{
      'version': <String, Object?>{'version': '9.2'},
      'nodes': const <Object?>[],
      'cluster/resources?type=vm': const <Object?>[],
      'storage': <Object?>[
        <String, Object?>{
          'storage': 'local',
          'type': 'dir',
          'content': 'images',
        },
      ],
      'cluster/resources?type=storage': const ProxmoxUnauthorizedException(
        'Permission denied.',
      ),
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

  @override
  void close() {}

  @override
  Future<Object?> getData(
    String resource, {
    Map<String, String> query = const <String, String>{},
  }) async {
    final String? type = query['type'];
    final String key = type == null ? resource : '$resource?type=$type';
    final Object? response = responses[key] ?? responses[resource];
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
