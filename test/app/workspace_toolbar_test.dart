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

    await tester.tap(find.bySemanticsLabel('More datacenter actions'));
    await tester.pumpAndSettle();

    expect(find.text('Refresh Datacenter'), findsOneWidget);
    expect(find.text('Manage Servers'), findsOneWidget);
    expect(find.text('Datacenter Portfolio'), findsOneWidget);
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Cluster Administration'), findsOneWidget);
    expect(find.byType(CupertinoActionSheet), findsNothing);
    expect(routeObserver.pushCount, initialPushCount);

    final Rect menuRect = tester.getRect(
      find.byKey(const ValueKey<String>('pve-command-menu-panel')),
    );
    expect(menuRect.width, 260);
    expect(menuRect.height, lessThan(500));
    expect(menuRect.bottom, lessThanOrEqualTo(844));

    await tester.tap(find.text('Refresh Datacenter'));
    await tester.pump();

    expect(refreshed, isTrue);
    expect(find.text('Refresh Datacenter'), findsNothing);
    expect(routeObserver.pushCount, initialPushCount);
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
