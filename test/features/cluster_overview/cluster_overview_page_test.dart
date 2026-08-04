import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pve_companion/app/pve_companion_theme.dart';
import 'package:pve_companion/features/cluster_overview/application/cluster_overview_controller.dart';
import 'package:pve_companion/features/cluster_overview/domain/cluster_overview_snapshot.dart';
import 'package:pve_companion/features/cluster_overview/domain/datacenter_resource_history.dart';
import 'package:pve_companion/features/cluster_overview/presentation/cluster_overview_page.dart';
import 'package:pve_companion/features/guests/domain/pve_guest.dart';

import 'datacenter_dashboard_fixture.dart';

void main() {
  testWidgets(
    'shows a healthy compact command center and opens guest drill-down',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = await readyDashboardController(
        healthyDatacenterSnapshot(),
      );
      addTearDown(controller.dispose);
      var guestDrillDownCount = 0;

      await tester.pumpWidget(
        _DashboardTestApp(
          controller: controller,
          onViewGuests: () => guestDrillDownCount += 1,
        ),
      );
      await tester.pump();

      expect(find.text('Datacenter'), findsOneWidget);
      expect(find.text('All systems operational'), findsOneWidget);
      expect(find.text('No active incidents'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('dashboard-resource-pressure')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('dashboard-workload-composition')),
        findsOneWidget,
      );
      expect(find.text('3/4'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('View Guests'),
        160,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('View Guests'));
      await tester.tap(find.text('View Guests'));
      expect(guestDrillDownCount, 1);
    },
  );

  testWidgets('surfaces a critical wide command-center state', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1180, 860));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = await readyDashboardController(
      criticalDatacenterSnapshot(),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(_DashboardTestApp(controller: controller));
    await tester.pump();

    expect(find.text('Action required'), findsOneWidget);
    expect(find.text('1 node is offline.'), findsOneWidget);
    expect(find.textContaining('compute-a reports critical'), findsOneWidget);
    expect(find.text('CPU'), findsWidgets);
    expect(find.text('Memory'), findsWidgets);
    expect(find.text('Disk'), findsWidgets);
    expect(find.textContaining('Highest reported node'), findsOneWidget);
    expect(find.text('Workload mix'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('dashboard-resource-pressure')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('dashboard-workload-composition')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('dashboard-nodes-two-columns')),
      findsOneWidget,
    );
    expect(find.text('Failed'), findsOneWidget);
    expect(find.text('Running'), findsOneWidget);
    expect(
      tester
          .getTopLeft(
            find.byKey(const ValueKey<String>('dashboard-node-edge-a')),
          )
          .dx,
      lessThan(
        tester
            .getTopLeft(
              find.byKey(const ValueKey<String>('dashboard-node-compute-a')),
            )
            .dx,
      ),
    );
  });

  testWidgets('routes an incident directly to its operational destination', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = await readyDashboardController(
      criticalDatacenterSnapshot(),
    );
    addTearDown(controller.dispose);
    var nodeDrillDownCount = 0;

    await tester.pumpWidget(
      _DashboardTestApp(
        controller: controller,
        onViewNodes: () => nodeDrillDownCount += 1,
      ),
    );
    await tester.pump();

    expect(find.text('Needs attention'), findsOneWidget);
    await tester.tap(find.textContaining('compute-a CPU is'));

    expect(nodeDrillDownCount, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps the compact command center usable with larger text', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = await readyDashboardController(
      healthyDatacenterSnapshot(),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _DashboardTestApp(
        controller: controller,
        textScaler: const TextScaler.linear(2),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Datacenter'), findsOneWidget);
    expect(find.text('All systems operational'), findsOneWidget);
  });

  testWidgets('keeps critical compact node summaries usable with larger text', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = await readyDashboardController(
      criticalDatacenterSnapshot(),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _DashboardTestApp(
        controller: controller,
        textScaler: const TextScaler.linear(2),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Needs attention'), findsOneWidget);
  });

  testWidgets('keeps the wide command center usable with larger text', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1180, 860));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = await readyDashboardController(
      healthyDatacenterSnapshot(),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _DashboardTestApp(
        controller: controller,
        textScaler: const TextScaler.linear(2),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Operational Summary'), findsOneWidget);
    expect(find.text('Nodes'), findsOneWidget);
  });

  testWidgets('forwards each dashboard drill-down callback', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1180, 860));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = await readyDashboardController(
      healthyDatacenterSnapshot(),
    );
    addTearDown(controller.dispose);
    var guestDrillDownCount = 0;
    var nodeDrillDownCount = 0;
    var storageDrillDownCount = 0;
    var taskDrillDownCount = 0;

    await tester.pumpWidget(
      _DashboardTestApp(
        controller: controller,
        onViewGuests: () => guestDrillDownCount += 1,
        onViewNodes: () => nodeDrillDownCount += 1,
        onViewStorage: () => storageDrillDownCount += 1,
        onViewTasks: () => taskDrillDownCount += 1,
      ),
    );
    await tester.pump();

    await tester.tap(find.text('All systems operational'));
    await tester.tap(find.text('View Guests'));
    await tester.tap(find.text('View Storage'));
    await tester.drag(
      find.byKey(const ValueKey<String>('datacenter-dashboard')),
      const Offset(0, -900),
    );
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('View all tasks'));

    expect(guestDrillDownCount, 1);
    expect(nodeDrillDownCount, 1);
    expect(storageDrillDownCount, 1);
    expect(taskDrillDownCount, 1);
  });

  testWidgets('keeps stale data visible after a refresh failure', (
    WidgetTester tester,
  ) async {
    final controller = await staleDashboardController(
      healthyDatacenterSnapshot(),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(_DashboardTestApp(controller: controller));

    expect(find.text('All systems operational'), findsOneWidget);
    expect(find.text('Refresh failed.'), findsOneWidget);
    expect(find.text('Datacenter unavailable'), findsNothing);
  });

  testWidgets('states the coverage behind combined storage use', (
    WidgetTester tester,
  ) async {
    const snapshot = ClusterOverviewSnapshot(
      version: PveVersion(version: '9.0'),
      nodes: <ClusterNode>[ClusterNode(name: 'pve-01', status: 'online')],
      guests: <PveGuest>[],
      storages: <ClusterStorage>[
        ClusterStorage(
          name: 'reported',
          type: 'dir',
          content: 'images',
          shared: false,
          resources: <ClusterStorageResource>[
            ClusterStorageResource(
              node: 'pve-01',
              status: 'available',
              usedBytes: 10,
              capacityBytes: 100,
            ),
          ],
        ),
        ClusterStorage(
          name: 'unreported',
          type: 'dir',
          content: 'images',
          shared: false,
          resources: <ClusterStorageResource>[
            ClusterStorageResource(node: 'pve-01', status: 'available'),
          ],
        ),
      ],
      tasks: <ClusterTask>[],
    );
    final controller = await readyDashboardController(snapshot);
    addTearDown(controller.dispose);

    await tester.pumpWidget(_DashboardTestApp(controller: controller));

    expect(find.text('2 storage pools · 1 reporting capacity'), findsOneWidget);
  });

  testWidgets('shows server-recorded performance history when available', (
    WidgetTester tester,
  ) async {
    final base = healthyDatacenterSnapshot();
    final snapshot = ClusterOverviewSnapshot(
      version: base.version,
      nodes: base.nodes,
      guests: base.guests,
      storages: base.storages,
      tasks: base.tasks,
      resourceHistory: DatacenterResourceHistory(
        samples: <DatacenterResourceSample>[
          DatacenterResourceSample(
            recordedAt: DateTime.utc(2026, 8, 2, 11),
            cpuFraction: 0.25,
            memoryFraction: 0.4,
            diskFraction: 0.5,
          ),
          DatacenterResourceSample(
            recordedAt: DateTime.utc(2026, 8, 2, 12),
            cpuFraction: 0.5,
            memoryFraction: 0.6,
            diskFraction: 0.7,
          ),
        ],
        requestedNodeCount: 2,
        reportingNodeCount: 2,
      ),
    );
    final controller = await readyDashboardController(snapshot);
    addTearDown(controller.dispose);

    await tester.pumpWidget(_DashboardTestApp(controller: controller));
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey<String>('datacenter-resource-history')),
      220,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Performance history'), findsOneWidget);
    expect(find.text('Past 24 hours'), findsOneWidget);
    expect(
      find.text('Server-recorded node utilization · 2 nodes reporting'),
      findsOneWidget,
    );
  });

  testWidgets('uses one clear empty state when server history is unavailable', (
    WidgetTester tester,
  ) async {
    final controller = await readyDashboardController(
      healthyDatacenterSnapshot(),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(_DashboardTestApp(controller: controller));
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey<String>('datacenter-resource-history')),
      220,
      scrollable: find.byType(Scrollable).first,
    );

    expect(
      find.text('No historical metrics are available yet.'),
      findsOneWidget,
    );
    expect(find.text('Comparison unavailable'), findsNothing);
  });
}

class _DashboardTestApp extends StatelessWidget {
  const _DashboardTestApp({
    required this.controller,
    this.onViewGuests,
    this.onViewNodes,
    this.onViewStorage,
    this.onViewTasks,
    this.textScaler = TextScaler.noScaling,
  });

  final ClusterOverviewController controller;
  final VoidCallback? onViewGuests;
  final VoidCallback? onViewNodes;
  final VoidCallback? onViewStorage;
  final VoidCallback? onViewTasks;
  final TextScaler textScaler;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: PveCompanionTheme.light(),
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        );
      },
      home: Scaffold(
        body: ClusterOverviewPage(
          controller: controller,
          onRefresh: () async {},
          onViewGuests: onViewGuests ?? () {},
          onViewNodes: onViewNodes ?? () {},
          onViewStorage: onViewStorage ?? () {},
          onViewTasks: onViewTasks ?? () {},
        ),
      ),
    );
  }
}
