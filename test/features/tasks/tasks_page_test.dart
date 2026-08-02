import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pve_companion/app/pve_companion_theme.dart';
import 'package:pve_companion/features/cluster_overview/application/cluster_overview_controller.dart';
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

    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey<String>('task-state-filter')),
        matching: find.text('Failed'),
      ),
    );
    await tester.pump();

    expect(find.text('backup on pve-01'), findsNothing);
    expect(find.text('No tasks match these controls.'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('task-outcomes')), findsOneWidget);
  });

  testWidgets('searches tasks and reports the visible result count', (
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
          body: TasksPage(controller: controller, onRefresh: () async {}),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey<String>('task-search')),
      'automation',
    );
    await tester.pump();

    expect(find.text('snapshot on pve-02'), findsOneWidget);
    expect(find.text('backup on pve-01'), findsNothing);
    expect(find.text('Showing 1 of 5 recent tasks'), findsOneWidget);
  });

  testWidgets('uses activity summary cards on iPad', (
    WidgetTester tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.binding.setSurfaceSize(const Size(1366, 1024));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = await readyDashboardController(
      healthyDatacenterSnapshot(),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: PveCompanionTheme.light(),
        builder: _largeTextBuilder,
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
      find.byKey(const ValueKey<String>('task-activity-profile')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('ipad-task-card-UPID:running')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('ipad-task-card-UPID:complete')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets(
    'opens a truthful read-only task inspector from the desktop table',
    (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      await tester.binding.setSurfaceSize(const Size(1366, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final ClusterOverviewController controller =
          await readyDashboardController(healthyDatacenterSnapshot());
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: PveCompanionTheme.light(),
          home: Scaffold(
            body: TasksPage(controller: controller, onRefresh: () async {}),
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('desktop-task-table')),
        findsOneWidget,
      );
      await tester.tap(find.text('backup on pve-01').first);
      await tester.pumpAndSettle();

      expect(find.text('Task details'), findsOneWidget);
      expect(
        find.textContaining('has not loaded a server task log'),
        findsOneWidget,
      );
      expect(find.text('Task ID'), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    },
  );
}

Widget _largeTextBuilder(BuildContext context, Widget? child) {
  return MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: const TextScaler.linear(2)),
    child: child!,
  );
}
