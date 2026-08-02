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
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    bool refreshed = false;
    final _RoutePushObserver routeObserver = _RoutePushObserver();
    final ConnectionProfile profile = ConnectionProfile.apiToken(
      displayName: 'Pennsylvania Lab',
      endpoint: Uri.parse('https://pve-01.example.com:8006'),
      tokenId: 'viewer@pve!companion',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: PveCompanionTheme.light(),
        navigatorObservers: <NavigatorObserver>[routeObserver],
        home: CupertinoPageScaffold(
          navigationBar: WorkspaceToolbar(
            profiles: <ConnectionProfile>[profile],
            selectedProfile: profile,
            title: 'Datacenter',
            connected: true,
            onConnectToProfile: (_) {},
            onRefresh: () => refreshed = true,
            onDisconnect: () {},
            onManageServers: () {},
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
    final int initialPushCount = routeObserver.pushCount;

    await tester.tap(find.bySemanticsLabel('Workspace actions and settings'));
    await tester.pumpAndSettle();

    expect(find.text('Refresh data'), findsOneWidget);
    expect(find.text('Manage servers'), findsOneWidget);
    expect(find.text('Datacenter portfolio'), findsOneWidget);
    expect(find.text('Notification settings'), findsOneWidget);
    expect(find.text('Cluster administration'), findsOneWidget);
    expect(find.byType(CupertinoActionSheet), findsNothing);
    expect(routeObserver.pushCount, initialPushCount);

    final Rect menuRect = tester.getRect(
      find.byKey(const ValueKey<String>('pve-command-menu-panel')),
    );
    expect(menuRect.width, 260);
    expect(menuRect.height, lessThan(500));
    expect(menuRect.bottom, lessThanOrEqualTo(844));

    await tester.tap(find.text('Refresh data'));
    await tester.pump();

    expect(refreshed, isTrue);
    expect(find.text('Refresh data'), findsNothing);
    expect(routeObserver.pushCount, initialPushCount);
  });

  testWidgets('exposes notification and server management on macOS', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    bool openedNotifications = false;
    bool openedServerManagement = false;
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
            onRefresh: () {},
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
}

class _RoutePushObserver extends NavigatorObserver {
  int pushCount = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushCount += 1;
    super.didPush(route, previousRoute);
  }
}
