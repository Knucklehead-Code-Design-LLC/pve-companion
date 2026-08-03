import 'package:flutter/cupertino.dart'
    show CupertinoPageScaffold, CupertinoTheme;
import 'package:flutter/material.dart';
import 'package:pve_companion/app/pve_companion_theme.dart';
import 'package:pve_companion/app/workspace/adaptive_workspace_content.dart';
import 'package:pve_companion/app/workspace/server_menu.dart';
import 'package:pve_companion/app/workspace/workspace_actions_menu.dart';
import 'package:pve_companion/app/workspace/workspace_section.dart';
import 'package:pve_companion/app/workspace/workspace_toolbar.dart';
import 'package:pve_companion/core/api/proxmox_session.dart';
import 'package:pve_companion/core/presentation/pve_apple_ui.dart';
import 'package:pve_companion/features/cluster_overview/application/cluster_overview_controller.dart';
import 'package:pve_companion/features/cluster_overview/data/proxmox_cluster_overview_repository.dart';
import 'package:pve_companion/features/cluster_overview/domain/cluster_overview_snapshot.dart';
import 'package:pve_companion/features/cluster_overview/presentation/cluster_nodes_page.dart';
import 'package:pve_companion/features/cluster_overview/presentation/cluster_overview_page.dart';
import 'package:pve_companion/features/connection_profiles/domain/connection_profile.dart';
import 'package:pve_companion/features/guests/presentation/guest_list_page.dart';
import 'package:pve_companion/features/storage/presentation/storage_page.dart';
import 'package:pve_companion/features/tasks/presentation/tasks_page.dart';

import 'support/datacenter_dashboard_preview_data.dart';

const String _sceneName = String.fromEnvironment(
  'SCREENSHOT_SCENE',
  defaultValue: 'overview',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(await createStoreScreenshotPreview(_sceneName));
}

Future<Widget> createStoreScreenshotPreview(String sceneName) async {
  final controller = ClusterOverviewController(
    _PreviewClusterOverviewRepository(
      datacenterDashboardHealthyPreviewSnapshot(),
    ),
  );
  final session = _PreviewProxmoxSession();
  await controller.refresh(session);
  return StoreScreenshotApp(
    controller: controller,
    session: session,
    initialSection: _sectionFromName(sceneName),
  );
}

WorkspaceSection _sectionFromName(String name) {
  return WorkspaceSection.values.firstWhere(
    (WorkspaceSection section) => section.name == name,
    orElse: () => WorkspaceSection.overview,
  );
}

class StoreScreenshotApp extends StatefulWidget {
  const StoreScreenshotApp({
    super.key,
    required this.controller,
    required this.session,
    required this.initialSection,
  });

  final ClusterOverviewController controller;
  final ProxmoxSession session;
  final WorkspaceSection initialSection;

  @override
  State<StoreScreenshotApp> createState() => _StoreScreenshotAppState();
}

class _StoreScreenshotAppState extends State<StoreScreenshotApp> {
  late WorkspaceSection _section = widget.initialSection;
  final ConnectionProfile _profile = ConnectionProfile.apiToken(
    displayName: 'Pennsylvania Lab',
    endpoint: Uri.parse('https://pve-01.pa.internal.example.com:8006'),
    tokenId: 'viewer@pve!companion',
  );

  @override
  void dispose() {
    widget.controller.dispose();
    widget.session.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 760;
    return RepaintBoundary(
      key: ValueKey<String>(
        'store-screenshot-capture-${widget.initialSection.name}',
      ),
      child: MaterialApp(
        title: 'PVE Companion',
        debugShowCheckedModeBanner: false,
        theme: PveCompanionTheme.light(),
        builder: (BuildContext context, Widget? child) => CupertinoTheme(
          data: PveCompanionTheme.cupertino(Brightness.light),
          child: child!,
        ),
        home: CupertinoPageScaffold(
          backgroundColor: PveAppleColors.page(context),
          child: AdaptiveWorkspaceContent(
            section: _section,
            onSectionChanged: (WorkspaceSection section) {
              setState(() => _section = section);
            },
            sidebarHeader: ServerMenu(
              profiles: <ConnectionProfile>[_profile],
              selectedProfile: _profile,
              onSelected: (_) {},
            ),
            wideNavigationBar: WorkspaceToolbar(
              profiles: <ConnectionProfile>[_profile],
              selectedProfile: _profile,
              title: _section.navigationTitle,
              connected: true,
              showServerMenu: false,
              includeRefreshMenuAction: false,
              onConnectToProfile: (_) {},
              onRefresh: () {},
              onDisconnect: () {},
              onManageServers: () {},
              onAbout: () {},
            ),
            onRefresh: () async {},
            refreshing: false,
            lastUpdatedAt: DateTime.now(),
            pages: <Widget>[
              ClusterOverviewPage(
                controller: widget.controller,
                showsSliverNavigationBar: compact,
                navigationLeading: compact ? _compactLeading() : null,
                navigationTrailing: compact ? _compactTrailing() : null,
                onRefresh: () async {},
                onViewGuests: () => _select(WorkspaceSection.guests),
                onViewNodes: () => _select(WorkspaceSection.nodes),
                onViewStorage: () => _select(WorkspaceSection.storage),
                onViewTasks: () => _select(WorkspaceSection.tasks),
              ),
              GuestListPage(
                overviewController: widget.controller,
                session: widget.session,
                showsSliverNavigationBar: compact,
                navigationLeading: compact ? _compactLeading() : null,
                navigationTrailing: compact ? _compactTrailing() : null,
                onRefresh: () async {},
                onGuestPowerAction: () async {},
              ),
              ClusterNodesPage(
                controller: widget.controller,
                showsSliverNavigationBar: compact,
                navigationLeading: compact ? _compactLeading() : null,
                navigationTrailing: compact ? _compactTrailing() : null,
                onRefresh: () async {},
              ),
              StoragePage(
                controller: widget.controller,
                showsSliverNavigationBar: compact,
                navigationLeading: compact ? _compactLeading() : null,
                navigationTrailing: compact ? _compactTrailing() : null,
                onRefresh: () async {},
              ),
              TasksPage(
                controller: widget.controller,
                showsSliverNavigationBar: compact,
                navigationLeading: compact ? _compactLeading() : null,
                navigationTrailing: compact ? _compactTrailing() : null,
                onRefresh: () async {},
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _select(WorkspaceSection section) {
    setState(() => _section = section);
  }

  Widget _compactLeading() {
    return ServerMenu(
      profiles: <ConnectionProfile>[_profile],
      selectedProfile: _profile,
      onSelected: (_) {},
      compact: true,
    );
  }

  Widget _compactTrailing() {
    return WorkspaceActionsMenu(
      connected: true,
      onRefresh: () {},
      onDisconnect: () {},
      onManageServers: () {},
      onAbout: () {},
    );
  }
}

class _PreviewClusterOverviewRepository implements ClusterOverviewRepository {
  const _PreviewClusterOverviewRepository(this.snapshot);

  final ClusterOverviewSnapshot snapshot;

  @override
  Future<ClusterOverviewSnapshot> load(ProxmoxSession session) async {
    return snapshot;
  }
}

class _PreviewProxmoxSession implements ProxmoxSession {
  @override
  void close() {}

  @override
  Future<Object?> getData(
    String resource, {
    Map<String, String> query = const <String, String>{},
  }) {
    throw UnsupportedError('Store previews never make network requests.');
  }

  @override
  Future<Object?> postForm(
    String resource, {
    required Map<String, String> fields,
  }) {
    throw UnsupportedError('Store previews never make network requests.');
  }
}
