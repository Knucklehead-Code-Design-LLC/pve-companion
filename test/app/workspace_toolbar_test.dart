import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pve_companion/app/pve_companion_theme.dart';
import 'package:pve_companion/app/workspace/workspace_toolbar.dart';
import 'package:pve_companion/core/presentation/pve_apple_ui.dart';
import 'package:pve_companion/features/connection_profiles/domain/connection_profile.dart';

void main() {
  testWidgets('opens workspace settings from the navigation bar', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final profile = ConnectionProfile.apiToken(
      displayName: 'Pennsylvania Lab',
      endpoint: Uri.parse('https://pve-01.example.com:8006'),
      tokenId: 'viewer@pve!companion',
    );

    var openedServerManagement = false;
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
            onDisconnect: () {},
            onManageServers: () => openedServerManagement = true,
            onAbout: () {},
            onViewFleet: () {},
            onManageNotifications: () {},
            onClusterAdministration: () {},
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );

    expect(find.byType(CupertinoNavigationBar), findsOneWidget);
    expect(find.text('Datacenter'), findsOneWidget);
    expect(find.byTooltip('Workspace settings'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Workspace settings'));
    await tester.pumpAndSettle();

    expect(find.text('Workspace settings'), findsOneWidget);
    expect(find.text('Manage Servers'), findsOneWidget);
    expect(find.text('Datacenter Portfolio'), findsOneWidget);
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Cluster Administration'), findsOneWidget);
    expect(find.text('Refresh data'), findsNothing);
    expect(find.byType(CupertinoActionSheet), findsNothing);

    await tester.tap(find.text('Manage Servers'));
    await tester.pumpAndSettle();

    expect(openedServerManagement, isTrue);
    expect(find.text('Workspace settings'), findsNothing);
  });

  testWidgets('exposes notification and server management on macOS', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var openedNotifications = false;
    var openedServerManagement = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: PveCompanionTheme.light(),
        home: CupertinoPageScaffold(
          navigationBar: WorkspaceToolbar(
            profiles: const <ConnectionProfile>[],
            selectedProfile: null,
            title: 'Datacenter',
            connected: true,
            onConnectToProfile: (_) {},
            onDisconnect: () {},
            onManageServers: () => openedServerManagement = true,
            onAbout: () {},
            onManageNotifications: () => openedNotifications = true,
            desktopWorkspaceCommandsEnabled: true,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );

    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Manage Servers'), findsOneWidget);

    await tester.tap(find.text('Notifications'));
    await tester.tap(find.text('Manage Servers'));

    expect(openedNotifications, isTrue);
    expect(openedServerManagement, isTrue);
  });

  testWidgets('keeps a desktop page title and freshness together on the left', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final refreshedAt = DateTime.now().subtract(const Duration(minutes: 2));

    await tester.pumpWidget(
      MaterialApp(
        theme: PveCompanionTheme.light(),
        home: CupertinoPageScaffold(
          navigationBar: WorkspaceToolbar(
            profiles: const <ConnectionProfile>[],
            selectedProfile: null,
            title: 'Datacenter',
            connected: true,
            showServerMenu: false,
            lastUpdatedAt: refreshedAt,
            onConnectToProfile: (_) {},
            onDisconnect: () {},
            onManageServers: () {},
            onAbout: () {},
            desktopWorkspaceCommandsEnabled: true,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );

    expect(find.text('Data refreshed 2m ago'), findsOneWidget);
    expect(find.byType(PveFreshnessLabel), findsOneWidget);
    expect(tester.getTopLeft(find.text('Datacenter')).dx, lessThan(300));
  });
}
