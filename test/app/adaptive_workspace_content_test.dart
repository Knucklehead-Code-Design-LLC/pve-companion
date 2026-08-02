import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pve_companion/app/pve_companion_theme.dart';
import 'package:pve_companion/app/workspace/adaptive_workspace_content.dart';
import 'package:pve_companion/app/workspace/workspace_section.dart';
import 'package:pve_companion/app/workspace/workspace_toolbar.dart';
import 'package:pve_companion/core/presentation/pve_apple_ui.dart';

void main() {
  testWidgets('uses stable tabs in a compact window', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const _NavigationHarness());

    expect(find.byType(CupertinoTabBar), findsOneWidget);
    expect(find.text('Page: Overview'), findsOneWidget);

    await tester.tap(find.text('Guests'));
    await tester.pump();

    expect(find.text('Page: Guests'), findsOneWidget);
    expect(find.bySemanticsLabel('Guests'), findsWidgets);
  });

  testWidgets('uses a persistent sidebar in a wide window', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1024, 768));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const _NavigationHarness());

    expect(find.byType(CupertinoTabBar), findsNothing);
    expect(find.text('Datacenter'), findsWidgets);

    await tester.tap(find.text('Storage'));
    await tester.pump();

    expect(find.text('Page: Storage'), findsOneWidget);
  });

  test('selects compact, regular, and wide workspace navigation layouts', () {
    expect(
      WorkspaceLayout.forWidth(WorkspaceLayout.compactBreakpoint - 1),
      WorkspaceLayoutSize.compact,
    );
    expect(
      WorkspaceLayout.forWidth(WorkspaceLayout.compactBreakpoint),
      WorkspaceLayoutSize.regular,
    );
    expect(
      WorkspaceLayout.forWidth(WorkspaceLayout.wideBreakpoint),
      WorkspaceLayoutSize.wide,
    );
  });

  testWidgets('widens the macOS sidebar as the workspace grows', (
    WidgetTester tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.binding.setSurfaceSize(const Size(1024, 768));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const _NavigationHarness());
    expect(
      tester
          .getSize(find.byKey(const ValueKey<String>('workspace-sidebar')))
          .width,
      304,
    );
    expect(find.text('Refresh data'), findsOneWidget);

    await tester.binding.setSurfaceSize(const Size(1440, 900));
    await tester.pump();
    expect(
      tester
          .getSize(find.byKey(const ValueKey<String>('workspace-sidebar')))
          .width,
      320,
    );
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('keeps macOS commands in overflow beside the narrow sidebar', (
    WidgetTester tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.binding.setSurfaceSize(const Size(760, 768));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const _NavigationHarness());

    expect(
      tester
          .getSize(find.byKey(const ValueKey<String>('workspace-sidebar')))
          .width,
      304,
    );
    expect(find.text('Manage Servers'), findsNothing);
    expect(
      find.bySemanticsLabel('Workspace actions and settings'),
      findsOneWidget,
    );
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('uses the expanded connected sidebar on iPad', (
    WidgetTester tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.binding.setSurfaceSize(const Size(1366, 1024));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const _NavigationHarness());

    expect(find.text('Connected'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('workspace-footer-refresh')),
      findsOneWidget,
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey<String>('workspace-sidebar')))
          .width,
      288,
    );
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('keeps compact navigation readable with larger text', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const _NavigationHarness(textScaler: TextScaler.linear(2)),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Tasks'), findsOneWidget);
  });

  testWidgets('shows the current last-updated age with an exact hover label', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1024, 768));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final DateTime updatedAt = DateTime.now().subtract(
      const Duration(minutes: 2),
    );

    await tester.pumpWidget(_NavigationHarness(lastUpdatedAt: updatedAt));
    expect(find.text('Data refreshed 2m ago'), findsOneWidget);
    final String freshnessLabel = tester
        .getSemantics(find.byType(PveFreshnessLabel))
        .label;
    expect(freshnessLabel, startsWith('Data refreshed at '));
    expect(find.byTooltip(freshnessLabel), findsOneWidget);
  });

  testWidgets('discloses a failed refresh in the connection footer', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1024, 768));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const _NavigationHarness(refreshErrorMessage: 'Refresh failed.'),
    );

    expect(find.text('Connected'), findsOneWidget);
    expect(find.text('Data refresh failed'), findsOneWidget);
    expect(find.bySemanticsLabel('Data refresh failed'), findsOneWidget);
  });

  testWidgets('keeps attention and workspace actions visible in the sidebar', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 768));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const _NavigationHarness(
        sidebarActions: <WorkspaceSidebarAction>[
          WorkspaceSidebarAction(
            label: 'Needs attention',
            icon: CupertinoIcons.bell,
            onPressed: _noop,
            badgeCount: 2,
          ),
          WorkspaceSidebarAction(
            label: 'Manage servers',
            icon: CupertinoIcons.rectangle_stack_badge_plus,
            onPressed: _noop,
          ),
        ],
      ),
    );

    expect(find.text('Needs attention'), findsOneWidget);
    expect(find.text('Manage servers'), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        'Needs attention, 2 datacenter incidents need attention',
      ),
      findsOneWidget,
    );
  });

  testWidgets('reserves a persistent wide inspector only when supplied', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const _NavigationHarness(desktopInspector: Text('Selected guest')),
    );

    expect(
      find.byKey(const ValueKey<String>('workspace-desktop-inspector')),
      findsOneWidget,
    );
    expect(find.text('Selected guest'), findsOneWidget);
  });

  testWidgets('moves through sidebar destinations with arrow keys', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1024, 768));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const _NavigationHarness());
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();

    expect(find.text('Page: Guests'), findsOneWidget);
  });

  testWidgets('gives the compact refresh control an accessible tooltip', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1024, 768));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    await tester.pumpWidget(const _NavigationHarness());

    expect(find.byTooltip('Refresh data'), findsOneWidget);
    expect(
      tester
          .getSemantics(
            find.byKey(const ValueKey<String>('workspace-footer-refresh')),
          )
          .label,
      'Refresh data',
    );
    debugDefaultTargetPlatformOverride = null;
  });
}

void _noop() {}

class _NavigationHarness extends StatefulWidget {
  const _NavigationHarness({
    this.textScaler = TextScaler.noScaling,
    this.lastUpdatedAt,
    this.refreshErrorMessage,
    this.sidebarActions = const <WorkspaceSidebarAction>[],
    this.desktopInspector,
  });

  final TextScaler textScaler;
  final DateTime? lastUpdatedAt;
  final String? refreshErrorMessage;
  final List<WorkspaceSidebarAction> sidebarActions;
  final Widget? desktopInspector;

  @override
  State<_NavigationHarness> createState() => _NavigationHarnessState();
}

class _NavigationHarnessState extends State<_NavigationHarness> {
  WorkspaceSection _section = WorkspaceSection.overview;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: PveCompanionTheme.light(),
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: widget.textScaler),
          child: child!,
        );
      },
      home: Scaffold(
        body: AdaptiveWorkspaceContent(
          section: _section,
          onSectionChanged: (WorkspaceSection section) {
            setState(() => _section = section);
          },
          pages: WorkspaceSection.values
              .map(
                (WorkspaceSection section) =>
                    Center(child: Text('Page: ${section.label}')),
              )
              .toList(growable: false),
          sidebarHeader: const Text('Pennsylvania Lab'),
          wideNavigationBar: WorkspaceToolbar(
            profiles: const [],
            selectedProfile: null,
            title: _section.navigationTitle,
            connected: true,
            showServerMenu: false,
            onConnectToProfile: (_) {},
            onRefresh: () {},
            onDisconnect: () {},
            onManageServers: () {},
            onAbout: () {},
          ),
          onRefresh: () async {},
          refreshing: false,
          lastUpdatedAt: widget.lastUpdatedAt ?? DateTime.now(),
          refreshErrorMessage: widget.refreshErrorMessage,
          sidebarActions: widget.sidebarActions,
          desktopInspector: widget.desktopInspector,
        ),
      ),
    );
  }
}
