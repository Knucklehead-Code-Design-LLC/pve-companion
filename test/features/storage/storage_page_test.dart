import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pve_companion/app/pve_companion_theme.dart';
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

    await tester.tap(find.text('Shared').first);
    await tester.pump();

    expect(find.text('local'), findsNothing);
    expect(find.text('backup-nfs'), findsOneWidget);
  });

  testWidgets('uses storage summary cards on iPad', (
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
    debugDefaultTargetPlatformOverride = null;
  });
}
