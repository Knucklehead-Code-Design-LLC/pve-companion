import 'package:flutter_test/flutter_test.dart';
import 'package:pve_companion/core/api/proxmox_session.dart';
import 'package:pve_companion/features/backups/data/proxmox_backup_repository.dart';
import 'package:pve_companion/features/cluster_overview/domain/cluster_overview_snapshot.dart';
import 'package:pve_companion/features/guests/domain/pve_guest.dart';

void main() {
  test('uses an available reporting node for shared backup content', () async {
    final _BackupSession session = _BackupSession(<String, Object?>{
      'cluster/backup': <Object?>[
        <String, Object?>{
          'id': 'weekly',
          'storage': 'backup-nfs',
          'schedule': 'sun 02:00',
          'enabled': 1,
          'vmid': 'all',
        },
      ],
      'nodes/pve-02/storage/backup-nfs/content': <Object?>[
        <String, Object?>{
          'volid': 'backup-nfs:backup/vzdump-qemu-101.vma.zst',
          'content': 'backup',
          'vmid': 101,
          'ctime': 1767225600,
          'size': 4096,
          'format': 'vma.zst',
          'protected': 1,
        },
        <String, Object?>{
          'volid': 'backup-nfs:iso/proxmox-ve.iso',
          'content': 'iso',
          'size': 4096,
        },
      ],
    });

    final snapshot = await ProxmoxBackupRepository().load(
      session,
      ClusterOverviewSnapshot(
        version: const PveVersion(version: '9.0'),
        nodes: const <ClusterNode>[
          ClusterNode(name: 'pve-01', status: 'online'),
          ClusterNode(name: 'pve-02', status: 'online'),
        ],
        guests: const <PveGuest>[],
        storages: const <ClusterStorage>[
          ClusterStorage(
            name: 'backup-nfs',
            type: 'nfs',
            content: 'backup,iso',
            shared: true,
            resources: <ClusterStorageResource>[
              ClusterStorageResource(node: 'pve-01', status: 'inactive'),
              ClusterStorageResource(node: 'pve-02', status: 'available'),
            ],
          ),
        ],
        tasks: <ClusterTask>[
          ClusterTask(
            upid: 'UPID:backup',
            node: 'pve-02',
            type: 'vzdump',
            user: 'root@pam',
            status: 'TASK ERROR: failed',
            endedAt: DateTime(2026),
          ),
        ],
      ),
    );

    expect(
      session.requestedResources,
      contains('nodes/pve-02/storage/backup-nfs/content'),
    );
    expect(
      session.requestedResources,
      isNot(contains('nodes/pve-01/storage/backup-nfs/content')),
    );
    expect(snapshot.destinations.single.name, 'backup-nfs');
    expect(snapshot.schedules.single.id, 'weekly');
    expect(snapshot.records.single.guestId, 101);
    expect(snapshot.records.single.protected, isTrue);
    expect(snapshot.failedRecentTaskCount, 1);
  });
}

class _BackupSession implements ProxmoxSession {
  _BackupSession(this.responses);

  final Map<String, Object?> responses;
  final List<String> requestedResources = <String>[];

  @override
  void close() {}

  @override
  Future<Object?> getData(
    String resource, {
    Map<String, String> query = const <String, String>{},
  }) async {
    final String querySuffix = query.entries
        .map((MapEntry<String, String> entry) => '${entry.key}=${entry.value}')
        .join('&');
    final String requestKey = querySuffix.isEmpty
        ? resource
        : '$resource?$querySuffix';
    requestedResources.add(requestKey);
    return responses[requestKey];
  }

  @override
  Future<Object?> postForm(
    String resource, {
    required Map<String, String> fields,
  }) async => null;
}
