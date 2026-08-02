import 'package:flutter_test/flutter_test.dart';
import 'package:pve_companion/core/api/proxmox_session.dart';
import 'package:pve_companion/features/cluster_administration/data/proxmox_cluster_administration_repository.dart';
import 'package:pve_companion/features/cluster_overview/domain/cluster_overview_snapshot.dart';
import 'package:pve_companion/features/guests/domain/pve_guest.dart';

void main() {
  test(
    'loads cluster posture while exposing only intentionally safe options',
    () async {
      final _ClusterSession session = _ClusterSession(<String, Object?>{
        'cluster/status': <Object?>[
          <String, Object?>{
            'type': 'cluster',
            'name': 'pa',
            'quorate': 1,
            'version': 12,
          },
          <String, Object?>{
            'type': 'node',
            'name': 'pve-01',
            'nodeid': 1,
            'online': 1,
            'local': 1,
            'ip': '192.0.2.10',
          },
        ],
        'cluster/options': <String, Object?>{
          'console': 'xtermjs',
          'migration': '192.0.2.0/24',
          'email_from': 'not-exposed@example.test',
        },
        'cluster/ha/status/current': <Object?>[
          <String, Object?>{
            'sid': 'vm:101',
            'state': 'started',
            'node': 'pve-01',
          },
        ],
      });

      final snapshot = await ProxmoxClusterAdministrationRepository().load(
        session,
        const ClusterOverviewSnapshot(
          version: PveVersion(version: '9.0'),
          nodes: <ClusterNode>[ClusterNode(name: 'pve-01', status: 'online')],
          guests: <PveGuest>[],
          storages: <ClusterStorage>[],
          tasks: <ClusterTask>[],
        ),
      );

      expect(snapshot.clusterStatus!.name, 'pa');
      expect(snapshot.clusterStatus!.quorate, isTrue);
      expect(snapshot.clusterStatus!.members.single.address, '192.0.2.10');
      expect(snapshot.options, <String, String>{
        'console': 'xtermjs',
        'migration': '192.0.2.0/24',
      });
      expect(snapshot.haResources.single.service, 'vm:101');
    },
  );
}

class _ClusterSession implements ProxmoxSession {
  _ClusterSession(this.responses);

  final Map<String, Object?> responses;

  @override
  void close() {}

  @override
  Future<Object?> getData(
    String resource, {
    Map<String, String> query = const <String, String>{},
  }) async => responses[resource];

  @override
  Future<Object?> postForm(
    String resource, {
    required Map<String, String> fields,
  }) async => null;
}
