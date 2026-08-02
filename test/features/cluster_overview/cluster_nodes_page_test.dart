import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pve_companion/app/pve_companion_theme.dart';
import 'package:pve_companion/features/cluster_overview/application/cluster_overview_controller.dart';
import 'package:pve_companion/features/cluster_overview/domain/cluster_overview_snapshot.dart';
import 'package:pve_companion/features/cluster_overview/presentation/cluster_nodes_page.dart';
import 'package:pve_companion/features/guests/domain/pve_guest.dart';

import 'datacenter_dashboard_fixture.dart';

void main() {
  testWidgets('searches nodes and exposes the attention filter', (
    WidgetTester tester,
  ) async {
    final controller = await readyDashboardController(
      healthyDatacenterSnapshot(),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: PveCompanionTheme.light(),
        home: Scaffold(
          body: ClusterNodesPage(
            controller: controller,
            onRefresh: () async {},
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(CupertinoSearchTextField), 'pve-02');
    await tester.pump();

    expect(find.text('pve-01'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (Widget widget) => widget is Text && widget.data == 'pve-02',
      ),
      findsOneWidget,
    );

    await tester.enterText(find.byType(CupertinoSearchTextField), '');
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey<String>('node-status-filter')),
        matching: find.text('Attention'),
      ),
    );
    await tester.pump();

    expect(find.text('No nodes need attention'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('node-cluster-pressure')),
      findsOneWidget,
    );
  });

  testWidgets('preserves offline-first domain ordering', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final ClusterOverviewController controller = await readyDashboardController(
      criticalDatacenterSnapshot(),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: PveCompanionTheme.light(),
        home: Scaffold(
          body: ClusterNodesPage(
            controller: controller,
            onRefresh: () async {},
          ),
        ),
      ),
    );

    expect(
      tester
          .getTopLeft(
            find.byKey(const ValueKey<String>('node-inventory-edge-a')),
          )
          .dx,
      lessThan(
        tester
            .getTopLeft(
              find.byKey(const ValueKey<String>('node-inventory-compute-a')),
            )
            .dx,
      ),
    );
  });

  testWidgets('supports large accessibility text without overflow', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final ClusterOverviewController controller = await readyDashboardController(
      healthyDatacenterSnapshot(),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: PveCompanionTheme.light(),
        builder: _largeTextBuilder,
        home: Scaffold(
          body: ClusterNodesPage(
            controller: controller,
            onRefresh: () async {},
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('offers desktop inventory sorting by uptime and resource use', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final ClusterOverviewController controller = await readyDashboardController(
      healthyDatacenterSnapshot(),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: PveCompanionTheme.light(),
        home: Scaffold(
          body: ClusterNodesPage(
            controller: controller,
            onRefresh: () async {},
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey<String>('node-inventory-sort')));
    await tester.pumpAndSettle();

    expect(find.text('Sort node inventory'), findsOneWidget);
    expect(find.text('Uptime'), findsOneWidget);
    expect(find.text('Resource use'), findsOneWidget);
  });

  testWidgets('keeps node selection in a desktop inspector', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final ClusterOverviewController controller = await readyDashboardController(
      healthyDatacenterSnapshot(),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: PveCompanionTheme.light().copyWith(
          platform: TargetPlatform.macOS,
        ),
        home: MediaQuery(
          data: const MediaQueryData(size: Size(1440, 900)),
          child: Scaffold(
            body: ClusterNodesPage(
              controller: controller,
              onRefresh: () async {},
            ),
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('desktop-node-inspector-pve-01')),
      findsOneWidget,
    );
    expect(find.text('Hosted guests'), findsWidgets);
    expect(find.text('Recent activity'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('node-inventory-pve-02')),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('desktop-node-inspector-pve-02')),
      findsOneWidget,
    );
    expect(find.text('Copy node name'), findsOneWidget);
  });

  testWidgets('does not present an unreported CPU core count as zero', (
    WidgetTester tester,
  ) async {
    const ClusterOverviewSnapshot snapshot = ClusterOverviewSnapshot(
      version: PveVersion(version: '9.0'),
      nodes: <ClusterNode>[ClusterNode(name: 'pve-01', status: 'online')],
      guests: <PveGuest>[],
      storages: <ClusterStorage>[],
      tasks: <ClusterTask>[],
    );
    final ClusterOverviewController controller = await readyDashboardController(
      snapshot,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: PveCompanionTheme.light(),
        home: Scaffold(
          body: ClusterNodesPage(
            controller: controller,
            onRefresh: () async {},
          ),
        ),
      ),
    );

    expect(find.textContaining('CPU cores not reported'), findsOneWidget);
    expect(find.textContaining('0 cores'), findsNothing);
  });
}

Widget _largeTextBuilder(BuildContext context, Widget? child) {
  return MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: const TextScaler.linear(2)),
    child: child!,
  );
}
