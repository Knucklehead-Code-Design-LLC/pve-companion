import 'package:flutter_test/flutter_test.dart';
import 'package:pve_companion/features/cluster_overview/domain/cluster_overview_snapshot.dart';
import 'package:pve_companion/features/cluster_overview/domain/datacenter_health.dart';
import 'package:pve_companion/features/cluster_overview/domain/datacenter_health_evaluator.dart';
import 'package:pve_companion/features/guests/domain/pve_guest.dart';

void main() {
  test('derives workload, task activity, and reported-node pressure', () {
    final health = DatacenterHealthEvaluator.evaluate(
      ClusterOverviewSnapshot(
        version: const PveVersion(version: '8.4'),
        nodes: const <ClusterNode>[
          ClusterNode(
            name: 'alpha',
            status: 'online',
            cpuFraction: 0.70,
            memoryBytes: 2,
            memoryLimitBytes: 4,
            diskBytes: 60,
            diskLimitBytes: 100,
          ),
          ClusterNode(
            name: 'bravo',
            status: 'online',
            cpuFraction: 0.40,
            memoryBytes: 1,
            memoryLimitBytes: 2,
            diskBytes: 40,
            diskLimitBytes: 100,
          ),
        ],
        guests: const <PveGuest>[
          PveGuest(
            vmid: 101,
            node: 'alpha',
            kind: GuestKind.virtualMachine,
            status: 'running',
          ),
          PveGuest(
            vmid: 102,
            node: 'alpha',
            kind: GuestKind.virtualMachine,
            status: 'stopped',
          ),
          PveGuest(
            vmid: 201,
            node: 'bravo',
            kind: GuestKind.container,
            status: 'running',
          ),
          PveGuest(
            vmid: 202,
            node: 'bravo',
            kind: GuestKind.container,
            status: 'stopped',
          ),
        ],
        storages: const <ClusterStorage>[],
        tasks: <ClusterTask>[
          const ClusterTask(
            upid: 'UPID:running',
            node: 'alpha',
            type: 'vzdump',
            user: 'operator',
          ),
          ClusterTask(
            upid: 'UPID:ok',
            node: 'bravo',
            type: 'startall',
            user: 'operator',
            status: 'OK',
            endedAt: DateTime.utc(2026, 8, 1),
          ),
        ],
      ),
    );

    expect(health.state, DatacenterHealthState.healthy);
    expect(health.offlineNodeCount, 0);
    expect(health.workload.runningVirtualMachines, 1);
    expect(health.workload.totalVirtualMachines, 2);
    expect(health.workload.runningContainers, 1);
    expect(health.workload.totalContainers, 2);
    expect(health.tasks.runningTaskCount, 1);
    expect(health.tasks.successfulTaskCount, 1);
    expect(health.tasks.failedTaskCount, 0);
    expect(health.pressure.cpu?.fraction, 0.70);
    expect(health.pressure.cpu?.representativeNodeName, 'alpha');
    expect(health.pressure.cpu?.reportedNodeCount, 2);
    expect(health.pressure.memory?.usedBytes, 3);
    expect(health.pressure.memory?.capacityBytes, 6);
    expect(health.pressure.rootDisk?.usedBytes, 100);
    expect(health.pressure.rootDisk?.capacityBytes, 200);
  });

  test(
    'uses inclusive 75 percent warning and 90 percent critical thresholds',
    () {
      final normal = _healthWithCpu(0.749);
      final warning = _healthWithCpu(0.75);
      final critical = _healthWithCpu(0.90);

      expect(normal.state, DatacenterHealthState.healthy);
      expect(warning.state, DatacenterHealthState.warning);
      expect(
        warning.issues.single.message,
        'alpha reports elevated CPU pressure.',
      );
      expect(critical.state, DatacenterHealthState.critical);
      expect(
        critical.issues.single.message,
        'alpha reports critical CPU pressure.',
      );
    },
  );

  test(
    'raises offline nodes and failed recent tasks without flagging stopped guests',
    () {
      final health = DatacenterHealthEvaluator.evaluate(
        ClusterOverviewSnapshot(
          version: const PveVersion(version: '8.4'),
          nodes: const <ClusterNode>[
            ClusterNode(name: 'offline-node', status: 'offline'),
            ClusterNode(
              name: 'online-node',
              status: 'online',
              cpuFraction: 0.1,
            ),
          ],
          guests: const <PveGuest>[
            PveGuest(
              vmid: 100,
              node: 'online-node',
              kind: GuestKind.virtualMachine,
              status: 'stopped',
            ),
            PveGuest(
              vmid: 200,
              node: 'online-node',
              kind: GuestKind.container,
              status: 'stopped',
            ),
          ],
          storages: const <ClusterStorage>[],
          tasks: <ClusterTask>[
            ClusterTask(
              upid: 'UPID:error',
              node: 'online-node',
              type: 'backup',
              user: 'operator',
              status: 'ERROR: backup failed',
              endedAt: DateTime.utc(2026, 8, 1),
            ),
          ],
        ),
      );

      expect(health.state, DatacenterHealthState.critical);
      expect(health.offlineNodeCount, 1);
      expect(health.tasks.failedTaskCount, 1);
      expect(health.workload.runningGuests, 0);
      expect(
        health.issues.map((DatacenterHealthIssue issue) => issue.message),
        containsAll(<String>[
          '1 node is offline.',
          '1 recent reported task failed.',
        ]),
      );
      expect(health.nodes.first.node.name, 'offline-node');
    },
  );

  test(
    'treats a completed failed task as attention, not an ongoing outage',
    () {
      final health = DatacenterHealthEvaluator.evaluate(
        ClusterOverviewSnapshot(
          version: const PveVersion(version: '8.4'),
          nodes: const <ClusterNode>[
            ClusterNode(name: 'alpha', status: 'online', cpuFraction: 0.1),
          ],
          guests: const <PveGuest>[],
          storages: const <ClusterStorage>[],
          tasks: <ClusterTask>[
            ClusterTask(
              upid: 'UPID:error',
              node: 'alpha',
              type: 'backup',
              user: 'operator',
              status: 'ERROR: backup failed',
              endedAt: DateTime.utc(2026, 8, 1),
            ),
          ],
        ),
      );

      expect(health.state, DatacenterHealthState.warning);
      expect(health.tasks.failedTaskCount, 1);
      expect(
        health.issues.single.severity,
        DatacenterHealthIssueSeverity.warning,
      );
    },
  );

  test(
    'surfaces critical node pressure even when known-node aggregate is low',
    () {
      final health = DatacenterHealthEvaluator.evaluate(
        const ClusterOverviewSnapshot(
          version: PveVersion(version: '8.4'),
          nodes: <ClusterNode>[
            ClusterNode(
              name: 'alpha',
              status: 'online',
              memoryBytes: 95,
              memoryLimitBytes: 100,
            ),
            ClusterNode(
              name: 'bravo',
              status: 'online',
              memoryBytes: 10,
              memoryLimitBytes: 900,
            ),
          ],
          guests: <PveGuest>[],
          storages: <ClusterStorage>[],
          tasks: <ClusterTask>[],
        ),
      );

      expect(health.pressure.memory?.level, DatacenterPressureLevel.normal);
      expect(health.state, DatacenterHealthState.critical);
      expect(
        health.issues.single.message,
        'alpha reports critical memory pressure.',
      );
    },
  );

  test('orders offline nodes before critical, warning, and healthy nodes', () {
    final health = DatacenterHealthEvaluator.evaluate(
      const ClusterOverviewSnapshot(
        version: PveVersion(version: '8.4'),
        nodes: <ClusterNode>[
          ClusterNode(name: 'warning', status: 'online', cpuFraction: 0.75),
          ClusterNode(name: 'healthy', status: 'online', cpuFraction: 0.1),
          ClusterNode(name: 'critical', status: 'online', cpuFraction: 0.95),
          ClusterNode(name: 'offline', status: 'offline'),
        ],
        guests: <PveGuest>[],
        storages: <ClusterStorage>[],
        tasks: <ClusterTask>[],
      ),
    );

    expect(
      health.nodes.map((DatacenterNodeHealth node) => node.node.name),
      <String>['offline', 'critical', 'warning', 'healthy'],
    );
  });

  test('does not invent pressure from incomplete node metrics', () {
    final health = DatacenterHealthEvaluator.evaluate(
      const ClusterOverviewSnapshot(
        version: PveVersion(version: '8.4'),
        nodes: <ClusterNode>[
          ClusterNode(
            name: 'alpha',
            status: 'online',
            memoryBytes: 512,
            diskLimitBytes: 1024,
          ),
        ],
        guests: <PveGuest>[],
        storages: <ClusterStorage>[],
        tasks: <ClusterTask>[],
      ),
    );

    expect(health.state, DatacenterHealthState.healthy);
    expect(health.pressure.cpu, isNull);
    expect(health.pressure.memory, isNull);
    expect(health.pressure.rootDisk, isNull);
    expect(health.issues, isEmpty);
  });

  test('excludes stale offline-node telemetry from cluster pressure', () {
    final health = DatacenterHealthEvaluator.evaluate(
      const ClusterOverviewSnapshot(
        version: PveVersion(version: '9.2'),
        nodes: <ClusterNode>[
          ClusterNode(
            name: 'offline',
            status: 'offline',
            cpuFraction: 0.99,
            memoryBytes: 99,
            memoryLimitBytes: 100,
          ),
          ClusterNode(
            name: 'online',
            status: 'online',
            cpuFraction: 0.25,
            memoryBytes: 25,
            memoryLimitBytes: 100,
          ),
        ],
        guests: <PveGuest>[],
        storages: <ClusterStorage>[],
        tasks: <ClusterTask>[],
      ),
    );

    expect(health.pressure.cpu?.fraction, 0.25);
    expect(health.pressure.cpu?.representativeNodeName, 'online');
    expect(health.pressure.memory?.usedBytes, 25);
    expect(health.pressure.memory?.capacityBytes, 100);
  });
}

DatacenterHealth _healthWithCpu(double cpuFraction) {
  return DatacenterHealthEvaluator.evaluate(
    ClusterOverviewSnapshot(
      version: const PveVersion(version: '8.4'),
      nodes: <ClusterNode>[
        ClusterNode(name: 'alpha', status: 'online', cpuFraction: cpuFraction),
      ],
      guests: const <PveGuest>[],
      storages: const <ClusterStorage>[],
      tasks: const <ClusterTask>[],
    ),
  );
}
