import 'package:flutter_test/flutter_test.dart';
import 'package:pve_companion/core/api/proxmox_api_exception.dart';
import 'package:pve_companion/core/api/proxmox_session.dart';
import 'package:pve_companion/features/backups/data/proxmox_backup_repository.dart';
import 'package:pve_companion/features/backups/domain/pve_backup_center.dart';
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

  test(
    'identifies permission-limited backup inventory separately from no data',
    () async {
      const ClusterOverviewSnapshot overview = ClusterOverviewSnapshot(
        version: PveVersion(version: '9.0'),
        nodes: <ClusterNode>[ClusterNode(name: 'pve-01', status: 'online')],
        guests: <PveGuest>[],
        storages: <ClusterStorage>[
          ClusterStorage(
            name: 'backup-nfs',
            type: 'nfs',
            content: 'backup',
            shared: true,
            resources: <ClusterStorageResource>[
              ClusterStorageResource(node: 'pve-01', status: 'available'),
            ],
          ),
        ],
        tasks: <ClusterTask>[],
      );

      final PveBackupCenterSnapshot snapshot = await ProxmoxBackupRepository()
          .load(const _PermissionBackupSession(), overview);

      expect(snapshot.destinations, hasLength(1));
      expect(snapshot.schedules, isEmpty);
      expect(snapshot.records, isEmpty);
      expect(snapshot.scheduleDataState, PveBackupDataState.permissionLimited);
      expect(snapshot.recordDataState, PveBackupDataState.permissionLimited);
    },
  );

  test(
    'reports backup copies as not configured when no destination exists',
    () async {
      const ClusterOverviewSnapshot overview = ClusterOverviewSnapshot(
        version: PveVersion(version: '9.0'),
        nodes: <ClusterNode>[ClusterNode(name: 'pve-01', status: 'online')],
        guests: <PveGuest>[],
        storages: <ClusterStorage>[],
        tasks: <ClusterTask>[],
      );
      final _BackupSession session = _BackupSession(<String, Object?>{
        'cluster/backup': <Object?>[],
      });

      final PveBackupCenterSnapshot snapshot = await ProxmoxBackupRepository()
          .load(session, overview);

      expect(snapshot.destinations, isEmpty);
      expect(snapshot.records, isEmpty);
      expect(snapshot.recordDataState, PveBackupDataState.notConfigured);
      expect(session.requestedResources, <String>['cluster/backup']);
    },
  );

  test(
    'reports partially available copies when another destination is denied',
    () async {
      const ClusterOverviewSnapshot overview = ClusterOverviewSnapshot(
        version: PveVersion(version: '9.0'),
        nodes: <ClusterNode>[ClusterNode(name: 'pve-01', status: 'online')],
        guests: <PveGuest>[],
        storages: <ClusterStorage>[
          ClusterStorage(
            name: 'backup-a',
            type: 'nfs',
            content: 'backup',
            shared: true,
            resources: <ClusterStorageResource>[
              ClusterStorageResource(node: 'pve-01', status: 'available'),
            ],
          ),
          ClusterStorage(
            name: 'backup-b',
            type: 'nfs',
            content: 'backup',
            shared: true,
            resources: <ClusterStorageResource>[
              ClusterStorageResource(node: 'pve-01', status: 'available'),
            ],
          ),
        ],
        tasks: <ClusterTask>[],
      );
      final _BackupSession session = _BackupSession(
        <String, Object?>{
          'cluster/backup': <Object?>[],
          'nodes/pve-01/storage/backup-a/content': <Object?>[
            <String, Object?>{
              'volid': 'backup-a:backup/vzdump-qemu-101.vma.zst',
              'content': 'backup',
            },
          ],
        },
        errors: <String, Object>{
          'nodes/pve-01/storage/backup-b/content':
              const ProxmoxUnauthorizedException('Denied.'),
        },
      );

      final PveBackupCenterSnapshot snapshot = await ProxmoxBackupRepository()
          .load(session, overview);

      expect(snapshot.records, hasLength(1));
      expect(snapshot.recordDataState, PveBackupDataState.partiallyAvailable);
    },
  );
}

class _BackupSession implements ProxmoxSession {
  _BackupSession(this.responses, {this.errors = const <String, Object>{}});

  final Map<String, Object?> responses;
  final Map<String, Object> errors;
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
    final Object? error = errors[requestKey];
    if (error != null) {
      return Future<Object?>.error(error);
    }
    return responses[requestKey];
  }

  @override
  Future<Object?> postForm(
    String resource, {
    required Map<String, String> fields,
  }) async => null;
}

class _PermissionBackupSession implements ProxmoxSession {
  const _PermissionBackupSession();

  @override
  void close() {}

  @override
  Future<Object?> getData(
    String resource, {
    Map<String, String> query = const <String, String>{},
  }) => Future<Object?>.error(const ProxmoxUnauthorizedException('Denied.'));

  @override
  Future<Object?> postForm(
    String resource, {
    required Map<String, String> fields,
  }) async => null;
}
