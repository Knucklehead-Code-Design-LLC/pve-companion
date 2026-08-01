import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pve_companion/app/pve_companion_theme.dart';
import 'package:pve_companion/app/workspace/workspace_toolbar.dart';
import 'package:pve_companion/features/connection_profiles/domain/connection_profile.dart';

void main() {
  testWidgets('uses a navigation bar and anchored command menus', (
    WidgetTester tester,
  ) async {
    final ConnectionProfile profile = ConnectionProfile.apiToken(
      displayName: 'Pennsylvania Lab',
      endpoint: Uri.parse('https://pve-01.example.com:8006'),
      tokenId: 'viewer@pve!companion',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: PveCompanionTheme.light(),
        home: CupertinoPageScaffold(
          navigationBar: WorkspaceToolbar(
            profiles: <ConnectionProfile>[profile],
            selectedProfile: profile,
            title: 'Datacenter',
            connected: true,
            onConnectToProfile: (_) {},
            onRefresh: () {},
            onDisconnect: () {},
            onManageServers: () {},
            onAbout: () {},
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );

    expect(find.byType(CupertinoNavigationBar), findsOneWidget);
    expect(find.text('Datacenter'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('More datacenter actions'));
    await tester.pumpAndSettle();

    expect(find.text('Refresh Datacenter'), findsOneWidget);
    expect(find.text('Manage Servers'), findsOneWidget);
    expect(find.byType(CupertinoActionSheet), findsNothing);
  });
}
