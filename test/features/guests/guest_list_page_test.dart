import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pve_companion/app/pve_companion_theme.dart';
import 'package:pve_companion/core/api/proxmox_session.dart';
import 'package:pve_companion/features/cluster_overview/application/cluster_overview_controller.dart';
import 'package:pve_companion/features/cluster_overview/domain/cluster_overview_snapshot.dart';
import 'package:pve_companion/features/guests/domain/pve_guest.dart';
import 'package:pve_companion/features/guests/presentation/guest_list_page.dart';

import '../cluster_overview/datacenter_dashboard_fixture.dart';

void main() {
  testWidgets('searches and filters the guest inventory', (
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
          body: GuestListPage(
            overviewController: controller,
            session: const _GuestListSession(),
            onRefresh: () async {},
            onGuestPowerAction: () async {},
          ),
        ),
      ),
    );

    expect(find.text('app-prod-01'), findsOneWidget);
    expect(find.text('gh-runner-01'), findsOneWidget);
    expect(find.text('Showing all 4 guests'), findsOneWidget);

    await tester.enterText(find.byType(CupertinoSearchTextField), 'runner');
    await tester.pump();

    expect(find.text('app-prod-01'), findsNothing);
    expect(find.text('gh-runner-01'), findsOneWidget);
    expect(find.text('Showing 1 of 4 guests'), findsOneWidget);

    await tester.enterText(find.byType(CupertinoSearchTextField), '');
    final Finder stoppedFilter = find.text('Stopped').first;
    await tester.tap(stoppedFilter);
    await tester.pump();

    expect(find.text('app-prod-01'), findsNothing);
    expect(find.text('gh-runner-01'), findsOneWidget);
  });

  testWidgets('keeps templates out of the stopped inventory', (
    WidgetTester tester,
  ) async {
    final ClusterOverviewSnapshot base = healthyDatacenterSnapshot();
    final ClusterOverviewSnapshot snapshot = ClusterOverviewSnapshot(
      version: base.version,
      nodes: base.nodes,
      guests: <PveGuest>[
        ...base.guests,
        const PveGuest(
          vmid: 900,
          node: 'pve-01',
          kind: GuestKind.virtualMachine,
          status: 'stopped',
          name: 'ubuntu-template',
          isTemplate: true,
        ),
      ],
      storages: base.storages,
      tasks: base.tasks,
    );
    final controller = await readyDashboardController(snapshot);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: PveCompanionTheme.light(),
        home: Scaffold(
          body: GuestListPage(
            overviewController: controller,
            session: const _GuestListSession(),
            onRefresh: () async {},
            onGuestPowerAction: () async {},
          ),
        ),
      ),
    );

    expect(find.text('Templates'), findsWidgets);
    expect(find.text('Showing all 5 guests'), findsOneWidget);

    final Finder stoppedFilter = find.text('Stopped').first;
    await tester.tap(stoppedFilter);
    await tester.pump();

    expect(find.text('gh-runner-01'), findsOneWidget);
    expect(find.text('ubuntu-template'), findsNothing);
    expect(find.text('Showing 1 of 5 guests'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey<String>('guest-status-filter')),
        matching: find.text('Templates'),
      ),
    );
    await tester.pump();

    expect(find.text('gh-runner-01'), findsNothing);
    expect(find.text('ubuntu-template'), findsOneWidget);
    expect(find.text('Showing 1 of 5 guests'), findsOneWidget);
  });

  testWidgets('does not present unreported guest vCPU allocation as zero', (
    WidgetTester tester,
  ) async {
    const ClusterOverviewSnapshot snapshot = ClusterOverviewSnapshot(
      version: PveVersion(version: '9.0'),
      nodes: <ClusterNode>[ClusterNode(name: 'pve-01', status: 'online')],
      guests: <PveGuest>[
        PveGuest(
          vmid: 101,
          node: 'pve-01',
          kind: GuestKind.virtualMachine,
          status: 'running',
          name: 'app-01',
        ),
      ],
      storages: <ClusterStorage>[],
      tasks: <ClusterTask>[],
    );
    final controller = await readyDashboardController(snapshot);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: PveCompanionTheme.light(),
        home: Scaffold(
          body: GuestListPage(
            overviewController: controller,
            session: const _GuestListSession(),
            onRefresh: () async {},
            onGuestPowerAction: () async {},
          ),
        ),
      ),
    );

    expect(find.textContaining('vCPU allocation not reported'), findsOneWidget);
    expect(find.textContaining('0 vCPU assigned'), findsNothing);
  });

  testWidgets('uses summary metrics and scan-friendly cards on iPad', (
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
          body: GuestListPage(
            overviewController: controller,
            session: const _GuestListSession(),
            showsSliverNavigationBar: false,
            onRefresh: () async {},
            onGuestPowerAction: () async {},
          ),
        ),
      ),
    );

    expect(find.text('Virtual machines'), findsWidgets);
    expect(
      find.byKey(const ValueKey<String>('guest-resource-footprint')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('ipad-guest-card-101')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('ipad-guest-card-202')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('offers desktop inventory sorting by host and resource use', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = await readyDashboardController(
      healthyDatacenterSnapshot(),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: PveCompanionTheme.light(),
        home: Scaffold(
          body: GuestListPage(
            overviewController: controller,
            session: const _GuestListSession(),
            onRefresh: () async {},
            onGuestPowerAction: () async {},
          ),
        ),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('guest-inventory-sort')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sort guest inventory'), findsOneWidget);
    expect(find.text('Host'), findsOneWidget);
    expect(find.text('Resource use'), findsOneWidget);
  });

  testWidgets('uses a persistent desktop inspector while iPad keeps cards', (
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
            body: GuestListPage(
              overviewController: controller,
              session: const _GuestListSession(),
              showsSliverNavigationBar: false,
              onRefresh: () async {},
              onGuestPowerAction: () async {},
            ),
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('desktop-guest-inspector-101')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('desktop-guest-table')),
      findsOneWidget,
    );
    expect(find.text('Status'), findsOneWidget);
    expect(find.text('Uptime'), findsWidgets);
    expect(find.text('Open operational details'), findsOneWidget);

    await tester.enterText(find.byType(CupertinoSearchTextField), 'runner');
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('desktop-guest-inspector-102')),
      findsOneWidget,
    );
    expect(find.text('Copy guest ID'), findsOneWidget);
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

class _GuestListSession implements ProxmoxSession {
  const _GuestListSession();

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
