import 'package:flutter_test/flutter_test.dart';
import 'package:pve_companion/core/api/proxmox_api_exception.dart';
import 'package:pve_companion/core/api/proxmox_session.dart';
import 'package:pve_companion/features/cluster_overview/domain/cluster_overview_snapshot.dart';
import 'package:pve_companion/features/node_operations/data/proxmox_node_repository.dart';
import 'package:pve_companion/features/node_operations/domain/pve_node_details.dart';

void main() {
  const PveNodeDetailsSeed seed = PveNodeDetailsSeed(
    ClusterNode(name: 'pve-01', status: 'online'),
  );

  test(
    'loads optional operational node telemetry without inventing values',
    () async {
      final _NodeSession session = _NodeSession(<String, Object?>{
        'nodes/pve-01/status': <String, Object?>{
          'pveversion': '9.0.4',
          'kversion': 'Linux 6.14.11-2-pve',
          'cpuinfo': <String, Object?>{'model': 'AMD Ryzen'},
          'loadavg': <Object?>[0.4, 0.3, 0.2],
        },
        'nodes/pve-01/services': <Object?>[
          <String, Object?>{
            'service': 'pveproxy',
            'state': 'running',
            'desc': 'Proxmox API proxy',
          },
        ],
        'nodes/pve-01/apt/update': <Object?>[
          <String, Object?>{
            'Package': 'pve-manager',
            'OldVersion': '9.0.3',
            'Version': '9.0.4',
            'Title': 'PVE Manager',
          },
        ],
      });

      final PveNodeDetails details = await ProxmoxNodeRepository().loadDetails(
        session,
        seed,
      );

      expect(details.pveVersion, '9.0.4');
      expect(details.kernelVersion, 'Linux 6.14.11-2-pve');
      expect(details.cpuModel, 'AMD Ryzen');
      expect(details.loadAverages, <double>[0.4, 0.3, 0.2]);
      expect(details.services.single.name, 'pveproxy');
      expect(details.availablePackageUpdates.single.packageName, 'pve-manager');
    },
  );

  test('submits a node restart as a tracked Proxmox task', () async {
    final _NodeSession session = _NodeSession(
      const <String, Object?>{},
      postResponse: 'UPID:pve-01:node-restart',
    );

    final task = await ProxmoxNodeRepository().runPowerAction(
      session,
      seed,
      PveNodePowerAction.reboot,
    );

    expect(task.upid, 'UPID:pve-01:node-restart');
    expect(session.posted.single.resource, 'nodes/pve-01/status');
    expect(session.posted.single.fields, <String, String>{'command': 'reboot'});
  });

  test(
    'does not interpolate an unsafe service name into an endpoint',
    () async {
      final _NodeSession session = _NodeSession(const <String, Object?>{});

      await expectLater(
        ProxmoxNodeRepository().restartService(
          session,
          seed,
          const PveNodeService(name: '../pveproxy', state: 'stopped'),
        ),
        throwsA(isA<ProxmoxResponseException>()),
      );

      expect(session.posted, isEmpty);
    },
  );
}

class _NodeSession implements ProxmoxSession {
  _NodeSession(this.responses, {this.postResponse});

  final Map<String, Object?> responses;
  final Object? postResponse;
  final List<_PostedRequest> posted = <_PostedRequest>[];

  @override
  void close() {}

  @override
  Future<Object?> getData(
    String resource, {
    Map<String, String> query = const <String, String>{},
  }) async {
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
    posted.add(_PostedRequest(resource, fields));
    return postResponse;
  }
}

class _PostedRequest {
  const _PostedRequest(this.resource, this.fields);

  final String resource;
  final Map<String, String> fields;
}
