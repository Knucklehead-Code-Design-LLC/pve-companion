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
}
