import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pve_companion/app/pve_companion_theme.dart';
import 'package:pve_companion/core/api/proxmox_session.dart';
import 'package:pve_companion/features/cluster_overview/application/cluster_overview_controller.dart';
import 'package:pve_companion/features/cluster_overview/domain/cluster_overview_snapshot.dart';
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
    'uses a persistent truthful task inspector from the desktop table',
    (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final ClusterOverviewController controller =
          await readyDashboardController(healthyDatacenterSnapshot());
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: PveCompanionTheme.light().copyWith(
            platform: TargetPlatform.macOS,
          ),
          home: MediaQuery(
            data: const MediaQueryData(size: Size(1440, 900)),
            child: Scaffold(
              body: TasksPage(controller: controller, onRefresh: () async {}),
            ),
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('desktop-task-table')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey<String>('desktop-task-inspector-placeholder'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('backup on pve-01').first);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('desktop-task-inspector')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey<String>('desktop-task-inspector-placeholder'),
        ),
        findsNothing,
      );
      expect(find.text('Task details'), findsOneWidget);
      expect(find.text('Load server log'), findsOneWidget);
      expect(find.text('Task ID'), findsOneWidget);
      expect(find.text('Close'), findsNothing);
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets('filters tasks by a truthfully UPID-derived known guest', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final ClusterOverviewSnapshot base = healthyDatacenterSnapshot();
    final ClusterOverviewSnapshot snapshot = ClusterOverviewSnapshot(
      version: base.version,
      nodes: base.nodes,
      guests: base.guests,
      storages: base.storages,
      tasks: <ClusterTask>[
        ClusterTask(
          upid:
              'UPID:pve-01:00000001:00000001:00000001:vzdump:101:operator@pam:',
          node: 'pve-01',
          type: 'backup',
          user: 'operator',
          startedAt: DateTime.utc(2026, 8, 1, 12),
        ),
        ClusterTask(
          upid:
              'UPID:pve-02:00000002:00000002:00000002:snapshot:201:automation@pam:',
          node: 'pve-02',
          type: 'snapshot',
          user: 'automation',
          status: 'OK',
          startedAt: DateTime.utc(2026, 8, 1, 11),
        ),
      ],
    );
    final ClusterOverviewController controller = await readyDashboardController(
      snapshot,
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

    await tester.tap(find.byKey(const ValueKey<String>('task-guest-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('(101)').first);
    await tester.pumpAndSettle();

    expect(find.text('backup on pve-01'), findsOneWidget);
    expect(find.text('snapshot on pve-02'), findsNothing);
  });

  testWidgets('loads a server task log only after the user requests it', (
    WidgetTester tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.binding.setSurfaceSize(const Size(1366, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final ClusterOverviewController controller = await readyDashboardController(
      healthyDatacenterSnapshot(),
    );
    addTearDown(controller.dispose);
    final _TaskLogSession session = _TaskLogSession();

    await tester.pumpWidget(
      MaterialApp(
        theme: PveCompanionTheme.light(),
        home: Scaffold(
          body: TasksPage(
            controller: controller,
            session: session,
            onRefresh: () async {},
          ),
        ),
      ),
    );
    await tester.tap(find.text('backup on pve-01').first);
    await tester.pumpAndSettle();
    expect(session.requests, isEmpty);
    await tester.tap(find.byKey(const ValueKey<String>('load-task-log')));
    await tester.pumpAndSettle();

    expect(session.requests, hasLength(1));
    expect(find.textContaining('backup log line'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('separates active interactive sessions and shows their age', (
    WidgetTester tester,
  ) async {
    final ClusterOverviewSnapshot base = healthyDatacenterSnapshot();
    final ClusterOverviewController controller = await readyDashboardController(
      ClusterOverviewSnapshot(
        version: base.version,
        nodes: base.nodes,
        guests: base.guests,
        storages: base.storages,
        tasks: <ClusterTask>[
          ClusterTask(
            upid: 'UPID:console',
            node: 'pve-01',
            type: 'vncproxy',
            user: 'operator',
            startedAt: DateTime.now().subtract(
              const Duration(hours: 1, minutes: 5),
            ),
          ),
          ClusterTask(
            upid: 'UPID:backup',
            node: 'pve-01',
            type: 'backup',
            user: 'operator',
            startedAt: DateTime.now(),
          ),
        ],
      ),
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

    expect(
      find.byKey(const ValueKey<String>('interactive-sessions-group')),
      findsOneWidget,
    );
    expect(find.text('vncproxy on pve-01'), findsOneWidget);
    expect(find.textContaining('Active 1h'), findsOneWidget);
    expect(find.text('backup on pve-01'), findsOneWidget);
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

class _TaskLogSession implements ProxmoxSession {
  final List<String> requests = <String>[];

  @override
  Future<Object?> getData(
    String resource, {
    Map<String, String> query = const <String, String>{},
  }) async {
    requests.add(resource);
    return <Object?>[
      <Object?, Object?>{'n': 1, 't': 'backup log line'},
    ];
  }

  @override
  Future<Object?> postForm(
    String resource, {
    required Map<String, String> fields,
  }) => throw UnimplementedError();

  @override
  void close() {}
}
