import 'package:pve_companion/features/cluster_overview/domain/cluster_overview_snapshot.dart';
import 'package:pve_companion/features/guests/domain/pve_guest.dart';

final DateTime _previewTime = DateTime.utc(2026, 8, 1, 12);

ClusterOverviewSnapshot datacenterDashboardHealthyPreviewSnapshot() {
  return ClusterOverviewSnapshot(
    version: const PveVersion(version: '8.4.4', release: '6.8.12-5-pve'),
    nodes: const <ClusterNode>[
      ClusterNode(
        name: 'compute-a',
        status: 'online',
        cpuFraction: 0.42,
        memoryBytes: 12 * 1024 * 1024 * 1024,
        memoryLimitBytes: 32 * 1024 * 1024 * 1024,
        diskBytes: 180 * 1024 * 1024 * 1024,
        diskLimitBytes: 500 * 1024 * 1024 * 1024,
      ),
      ClusterNode(
        name: 'compute-b',
        status: 'online',
        cpuFraction: 0.58,
        memoryBytes: 18 * 1024 * 1024 * 1024,
        memoryLimitBytes: 32 * 1024 * 1024 * 1024,
        diskBytes: 220 * 1024 * 1024 * 1024,
        diskLimitBytes: 500 * 1024 * 1024 * 1024,
      ),
    ],
    guests: const <PveGuest>[
      PveGuest(
        vmid: 101,
        node: 'compute-a',
        kind: GuestKind.virtualMachine,
        status: 'running',
        name: 'application',
      ),
      PveGuest(
        vmid: 102,
        node: 'compute-a',
        kind: GuestKind.virtualMachine,
        status: 'stopped',
        name: 'batch',
      ),
      PveGuest(
        vmid: 201,
        node: 'compute-b',
        kind: GuestKind.container,
        status: 'running',
        name: 'metrics',
      ),
      PveGuest(
        vmid: 202,
        node: 'compute-b',
        kind: GuestKind.container,
        status: 'running',
        name: 'proxy',
      ),
    ],
    storages: const <ClusterStorage>[
      ClusterStorage(
        name: 'local',
        type: 'dir',
        content: 'images,iso',
        shared: false,
      ),
      ClusterStorage(
        name: 'shared',
        type: 'nfs',
        content: 'images',
        shared: true,
      ),
    ],
    tasks: <ClusterTask>[
      ClusterTask(
        upid: 'UPID:running',
        node: 'compute-a',
        type: 'backup',
        user: 'operator',
        startedAt: _previewTime,
      ),
      ClusterTask(
        upid: 'UPID:complete',
        node: 'compute-b',
        type: 'startall',
        user: 'operator',
        status: 'OK',
        startedAt: _previewTime,
        endedAt: DateTime.utc(2026, 8, 1, 12, 10),
      ),
    ],
  );
}

ClusterOverviewSnapshot datacenterDashboardCriticalPreviewSnapshot() {
  return ClusterOverviewSnapshot(
    version: const PveVersion(version: '8.4.4', release: '6.8.12-5-pve'),
    nodes: const <ClusterNode>[
      ClusterNode(name: 'edge-a', status: 'offline'),
      ClusterNode(
        name: 'compute-a',
        status: 'online',
        cpuFraction: 0.94,
        memoryBytes: 30 * 1024 * 1024 * 1024,
        memoryLimitBytes: 32 * 1024 * 1024 * 1024,
        diskBytes: 460 * 1024 * 1024 * 1024,
        diskLimitBytes: 500 * 1024 * 1024 * 1024,
      ),
      ClusterNode(
        name: 'compute-b',
        status: 'online',
        cpuFraction: 0.20,
        memoryBytes: 4 * 1024 * 1024 * 1024,
        memoryLimitBytes: 32 * 1024 * 1024 * 1024,
        diskBytes: 90 * 1024 * 1024 * 1024,
        diskLimitBytes: 500 * 1024 * 1024 * 1024,
      ),
    ],
    guests: const <PveGuest>[
      PveGuest(
        vmid: 101,
        node: 'compute-a',
        kind: GuestKind.virtualMachine,
        status: 'running',
        name: 'application',
      ),
      PveGuest(
        vmid: 102,
        node: 'compute-a',
        kind: GuestKind.virtualMachine,
        status: 'stopped',
        name: 'batch',
      ),
      PveGuest(
        vmid: 201,
        node: 'compute-b',
        kind: GuestKind.container,
        status: 'running',
        name: 'metrics',
      ),
    ],
    storages: const <ClusterStorage>[
      ClusterStorage(
        name: 'local',
        type: 'dir',
        content: 'images,iso',
        shared: false,
      ),
    ],
    tasks: <ClusterTask>[
      ClusterTask(
        upid: 'UPID:running',
        node: 'compute-a',
        type: 'backup',
        user: 'operator',
        startedAt: _previewTime,
      ),
      ClusterTask(
        upid: 'UPID:failed',
        node: 'compute-b',
        type: 'replication',
        user: 'operator',
        status: 'ERROR: network unavailable',
        startedAt: _previewTime,
        endedAt: DateTime.utc(2026, 8, 1, 12, 5),
      ),
      ClusterTask(
        upid: 'UPID:complete',
        node: 'compute-a',
        type: 'startall',
        user: 'operator',
        status: 'OK',
        startedAt: _previewTime,
        endedAt: DateTime.utc(2026, 8, 1, 12, 10),
      ),
    ],
  );
}
