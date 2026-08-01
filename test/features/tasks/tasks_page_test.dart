import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pve_companion/app/pve_companion_theme.dart';
import 'package:pve_companion/features/tasks/presentation/tasks_page.dart';

import '../cluster_overview/datacenter_dashboard_fixture.dart';

void main() {
  testWidgets('filters recent tasks by state', (WidgetTester tester) async {
    final controller = await readyDashboardController(
      healthyDatacenterSnapshot(),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: PveCompanionTheme.light(),
        home: Scaffold(
          body: TasksPage(controller: controller, onRefresh: () async {}),
        ),
      ),
    );

    expect(find.text('backup on pve-01'), findsOneWidget);

    await tester.tap(find.text('Failed'));
    await tester.pump();

    expect(find.text('backup on pve-01'), findsNothing);
    expect(find.text('No tasks match this filter.'), findsOneWidget);
  });

  testWidgets('uses activity summary cards on iPad', (
    WidgetTester tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await tester.binding.setSurfaceSize(const Size(1366, 1024));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = await readyDashboardController(
      healthyDatacenterSnapshot(),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: PveCompanionTheme.light(),
        home: Scaffold(
          body: TasksPage(
            controller: controller,
            showsSliverNavigationBar: false,
            onRefresh: () async {},
          ),
        ),
      ),
    );

    expect(find.text('Recent activity'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('ipad-task-card-UPID:running')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('ipad-task-card-UPID:complete')),
      findsOneWidget,
    );
    debugDefaultTargetPlatformOverride = null;
  });
}
