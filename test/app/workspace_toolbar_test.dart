import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pve_companion/app/pve_companion_theme.dart';
import 'package:pve_companion/app/workspace/workspace_toolbar.dart';
import 'package:pve_companion/core/presentation/pve_apple_ui.dart';
import 'package:pve_companion/features/connection_profiles/domain/connection_profile.dart';

void main() {
  testWidgets('uses a navigation bar and anchored command menus', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var refreshed = false;
    final routeObserver = _RoutePushObserver();
    final profile = ConnectionProfile.apiToken(
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
    expect(find.byTooltip('Workspace actions and settings'), findsOneWidget);
    final initialPushCount = routeObserver.pushCount;

    await tester.tap(find.bySemanticsLabel('Workspace actions and settings'));
    await tester.pumpAndSettle();

    expect(find.text('Refresh data'), findsOneWidget);
    expect(find.text('Manage servers'), findsOneWidget);
    expect(find.text('Datacenter portfolio'), findsOneWidget);
    expect(find.text('Notification settings'), findsOneWidget);
    expect(find.text('Cluster administration'), findsOneWidget);
    expect(find.byType(CupertinoActionSheet), findsNothing);
    expect(routeObserver.pushCount, initialPushCount);

    final menuRect = tester.getRect(
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
            onRefresh: () {},
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

class _RoutePushObserver extends NavigatorObserver {
  int pushCount = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushCount += 1;
    super.didPush(route, previousRoute);
  }
}
