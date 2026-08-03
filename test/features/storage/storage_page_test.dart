import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pve_companion/app/pve_companion_theme.dart';
import 'package:pve_companion/core/api/proxmox_session.dart';
import 'package:pve_companion/features/cluster_overview/domain/cluster_overview_snapshot.dart';
import 'package:pve_companion/features/storage/presentation/storage_page.dart';

import '../cluster_overview/datacenter_dashboard_fixture.dart';

void main() {
  testWidgets('filters storage by locality', (WidgetTester tester) async {
    final controller = await readyDashboardController(
      healthyDatacenterSnapshot(),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: PveCompanionTheme.light(),
        home: Scaffold(
          body: StoragePage(controller: controller, onRefresh: () async {}),
        ),
      ),
    );

    expect(find.text('local'), findsWidgets);
    expect(find.text('backup-nfs'), findsOneWidget);
    expect(
      find.text('Showing all 2 storage pools · highest risk first'),
      findsOneWidget,
    );
    expect(find.text('Configured pools'), findsOneWidget);
    expect(find.text('Availability coverage'), findsNWidgets(2));
    expect(find.text('Capacity used now'), findsNWidgets(3));
    expect(find.text('Capacity free now'), findsOneWidget);
    expect(find.text('2 of 2 pools report capacity'), findsNWidgets(2));

    await tester.tap(find.text('Shared').first);
    await tester.pump();

    expect(find.text('local'), findsNothing);
    expect(find.text('backup-nfs'), findsOneWidget);
    expect(
      find.text('Showing 1 of 2 storage pools · highest risk first'),
      findsOneWidget,
    );
  });

  testWidgets('uses storage summary cards on iPad', (
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
          body: StoragePage(
            controller: controller,
            showsSliverNavigationBar: false,
            onRefresh: () async {},
          ),
        ),
      ),
    );

    expect(find.text('Storage pools'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('storage-effective-capacity')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('ipad-storage-card-local')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('ipad-storage-card-backup-nfs')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('shows a retry state after an initial cluster failure', (
    WidgetTester tester,
  ) async {
    final controller = await failedDashboardController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: PveCompanionTheme.light(),
        home: Scaffold(
          body: StoragePage(controller: controller, onRefresh: () async {}),
        ),
      ),
    );

    expect(find.text('Datacenter unavailable'), findsOneWidget);
    expect(find.text('Initial load failed.'), findsOneWidget);
    expect(find.text('Try Again'), findsOneWidget);
  });

  testWidgets('reports immediate backup destination readiness', (
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
          body: StoragePage(
            controller: controller,
            session: const _StorageSession(),
            onRefresh: () async {},
          ),
        ),
      ),
    );

    expect(find.text('Destination ready'), findsOneWidget);
    expect(
      find.textContaining('available destination reported'),
      findsOneWidget,
    );
    expect(
      find.textContaining('schedules, copies, and backup activity'),
      findsOneWidget,
    );
  });

  testWidgets('does not mark an unreported backup destination as ready', (
    WidgetTester tester,
  ) async {
    const snapshot = ClusterOverviewSnapshot(
      version: PveVersion(version: '9.0'),
      nodes: <ClusterNode>[],
      guests: [],
      storages: <ClusterStorage>[
        ClusterStorage(
          name: 'backup',
          type: 'dir',
          content: 'backup',
          shared: false,
          resources: <ClusterStorageResource>[
            ClusterStorageResource(node: 'pve-01', status: ''),
          ],
        ),
      ],
      tasks: [],
    );
    final controller = await readyDashboardController(snapshot);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: PveCompanionTheme.light(),
        home: Scaffold(
          body: StoragePage(
            controller: controller,
            session: const _StorageSession(),
            onRefresh: () async {},
          ),
        ),
      ),
    );

    expect(find.text('Availability not reported'), findsOneWidget);
    expect(find.text('Destination ready'), findsNothing);
  });
}

class _StorageSession implements ProxmoxSession {
  const _StorageSession();

  @override
  void close() {}

  @override
  Future<Object?> getData(
    String resource, {
    Map<String, String> query = const <String, String>{},
  }) async => null;

  @override
  Future<Object?> postForm(
    String resource, {
    required Map<String, String> fields,
  }) async => null;
}

Widget _largeTextBuilder(BuildContext context, Widget? child) {
  return MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: const TextScaler.linear(2)),
    child: child!,
  );
}
