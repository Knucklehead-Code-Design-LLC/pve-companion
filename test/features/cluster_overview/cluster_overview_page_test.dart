import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pve_companion/app/pve_companion_theme.dart';
import 'package:pve_companion/features/cluster_overview/application/cluster_overview_controller.dart';
import 'package:pve_companion/features/cluster_overview/presentation/cluster_overview_page.dart';

import 'datacenter_dashboard_fixture.dart';

void main() {
  testWidgets(
    'shows a healthy compact command center and opens guest drill-down',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final ClusterOverviewController controller =
          await readyDashboardController(healthyDatacenterSnapshot());
      addTearDown(controller.dispose);
      int guestDrillDownCount = 0;

      await tester.pumpWidget(
        _DashboardTestApp(
          controller: controller,
          onViewGuests: () => guestDrillDownCount += 1,
        ),
      );
      await tester.pump();

      expect(find.text('Datacenter'), findsOneWidget);
      expect(find.text('No reported issues.'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('dashboard-capacity-stacked')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('dashboard-capacity-two-columns')),
        findsNothing,
      );
      expect(find.text('3 / 4 running'), findsOneWidget);

      await tester.drag(find.byType(ListView), const Offset(0, -900));
      await tester.pump();
      await tester.tap(find.text('View guests'));
      expect(guestDrillDownCount, 1);
    },
  );

  testWidgets('surfaces a critical wide command-center state', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1180, 860));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final ClusterOverviewController controller = await readyDashboardController(
      criticalDatacenterSnapshot(),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(_DashboardTestApp(controller: controller));
    await tester.pump();

    expect(find.text('Critical attention needed'), findsOneWidget);
    expect(find.text('1 node is offline.'), findsOneWidget);
    expect(find.textContaining('compute-a reports critical'), findsOneWidget);
    expect(find.text('Peak CPU use'), findsOneWidget);
    expect(find.text('Cluster memory use'), findsOneWidget);
    expect(find.text('Cluster root disk use'), findsOneWidget);
    expect(
      find.text('53% cluster total · 2/3 nodes reporting'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('dashboard-capacity-two-columns')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('dashboard-storage-inventory-wide')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('dashboard-nodes-two-columns')),
      findsOneWidget,
    );
    expect(find.text('Failed'), findsOneWidget);
    expect(find.text('Running'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('edge-a')).dx,
      lessThan(tester.getTopLeft(find.text('compute-a')).dx),
    );
  });

  testWidgets('forwards each dashboard drill-down callback', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1180, 860));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final ClusterOverviewController controller = await readyDashboardController(
      healthyDatacenterSnapshot(),
    );
    addTearDown(controller.dispose);
    int guestDrillDownCount = 0;
    int nodeDrillDownCount = 0;
    int storageDrillDownCount = 0;
    int taskDrillDownCount = 0;

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

    await tester.tap(find.text('View nodes'));
    await tester.tap(find.text('View guests'));
    await tester.tap(find.text('View storage'));
    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('View all tasks'));

    expect(guestDrillDownCount, 1);
    expect(nodeDrillDownCount, 1);
    expect(storageDrillDownCount, 1);
    expect(taskDrillDownCount, 1);
  });
}

class _DashboardTestApp extends StatelessWidget {
  const _DashboardTestApp({
    required this.controller,
    this.onViewGuests,
    this.onViewNodes,
    this.onViewStorage,
    this.onViewTasks,
  });

  final ClusterOverviewController controller;
  final VoidCallback? onViewGuests;
  final VoidCallback? onViewNodes;
  final VoidCallback? onViewStorage;
  final VoidCallback? onViewTasks;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: PveCompanionTheme.light(),
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
