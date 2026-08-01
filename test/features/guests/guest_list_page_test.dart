import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pve_companion/app/pve_companion_theme.dart';
import 'package:pve_companion/core/api/proxmox_session.dart';
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

    await tester.enterText(find.byType(CupertinoSearchTextField), 'runner');
    await tester.pump();

    expect(find.text('app-prod-01'), findsNothing);
    expect(find.text('gh-runner-01'), findsOneWidget);

    await tester.enterText(find.byType(CupertinoSearchTextField), '');
    await tester.tap(find.text('Stopped').first);
    await tester.pump();

    expect(find.text('app-prod-01'), findsNothing);
    expect(find.text('gh-runner-01'), findsOneWidget);
  });

  testWidgets('uses summary metrics and scan-friendly cards on iPad', (
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

    expect(find.text('Virtual machines'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('ipad-guest-card-101')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('ipad-guest-card-202')),
      findsOneWidget,
    );
    debugDefaultTargetPlatformOverride = null;
  });
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
