import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pve_companion/app/pve_companion_theme.dart';
import 'package:pve_companion/features/cluster_overview/presentation/cluster_nodes_page.dart';

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
}
