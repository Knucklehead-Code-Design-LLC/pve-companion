import 'package:flutter/cupertino.dart';

import '../core/api/proxmox_session.dart';
import '../core/presentation/pve_apple_ui.dart';
import '../features/cluster_overview/application/cluster_overview_controller.dart';
import '../features/cluster_overview/presentation/cluster_nodes_page.dart';
import '../features/cluster_overview/presentation/cluster_overview_page.dart';
import '../features/connection_profiles/application/connection_profiles_controller.dart';
import '../features/connection_profiles/domain/connection_profile.dart';
import '../features/connection_profiles/presentation/connection_profiles_screen.dart';
import '../features/guests/presentation/guest_list_page.dart';
import '../features/storage/presentation/storage_page.dart';
import '../features/system_surfaces/presentation/datacenter_watch_sheet.dart';
import '../features/tasks/presentation/tasks_page.dart';
import 'pve_companion_about.dart';
import 'pve_companion_controller.dart';
import 'workspace/adaptive_workspace_content.dart';
import 'workspace/disconnected_workspace.dart';
import 'workspace/server_menu.dart';
import 'workspace/workspace_actions_menu.dart';
import 'workspace/workspace_section.dart';
import 'workspace/workspace_toolbar.dart';

class PveWorkspace extends StatefulWidget {
  const PveWorkspace({super.key, required this.controller});

  final PveCompanionController controller;

  @override
  State<PveWorkspace> createState() => _PveWorkspaceState();
}

class _PveWorkspaceState extends State<PveWorkspace> {
  WorkspaceSection _section = WorkspaceSection.overview;

  @override
  Widget build(BuildContext context) {
    final ConnectionProfilesController profiles =
        widget.controller.connectionProfiles;
    final ConnectionProfile? selectedProfile = profiles.selectedProfile;
    final ProxmoxSession? session = profiles.activeSession;
    final bool compact = MediaQuery.sizeOf(context).width < 760;

    final WorkspaceToolbar disconnectedToolbar = _buildToolbar(
      context,
      title: 'PVE Companion',
      connected: false,
    );
    return CupertinoPageScaffold(
      backgroundColor: PveAppleColors.page(context),
      navigationBar: session == null ? disconnectedToolbar : null,
      child: session == null
          ? DisconnectedWorkspace(
              profile: selectedProfile,
              status: profiles.connectionStatus,
              errorMessage: profiles.errorMessage,
              onConnect: _connectSelectedProfile,
              onAddServer: () => showAddConnectionProfileSheet(
                context,
                controller: widget.controller,
              ),
            )
          : AdaptiveWorkspaceContent(
              section: _section,
              onSectionChanged: _selectSection,
              sidebarHeader: ServerMenu(
                profiles: profiles.profiles,
                selectedProfile: selectedProfile,
                onSelected: _connectToProfile,
              ),
              wideNavigationBar: _buildToolbar(
                context,
                title: _section.navigationTitle,
                connected: true,
                showServerMenu: false,
                includeRefreshMenuAction: false,
              ),
              onRefresh: widget.controller.refreshCluster,
              refreshing:
                  widget.controller.clusterOverview.state ==
                  ClusterOverviewLoadState.loading,
              lastUpdatedAt: widget.controller.clusterOverview.lastUpdatedAt,
              refreshErrorMessage:
                  widget.controller.clusterOverview.errorMessage,
              pages: _buildPages(session, compact: compact),
            ),
    );
  }

  List<Widget> _buildPages(ProxmoxSession session, {required bool compact}) {
    return <Widget>[
      ClusterOverviewPage(
        controller: widget.controller.clusterOverview,
        showsSliverNavigationBar: compact,
        navigationLeading: compact ? _buildCompactLeading() : null,
        navigationTrailing: compact ? _buildCompactTrailing() : null,
        onRefresh: widget.controller.refreshCluster,
        onViewGuests: () => _selectSection(WorkspaceSection.guests),
        onViewNodes: () => _selectSection(WorkspaceSection.nodes),
        onViewStorage: () => _selectSection(WorkspaceSection.storage),
        onViewTasks: () => _selectSection(WorkspaceSection.tasks),
      ),
      GuestListPage(
        overviewController: widget.controller.clusterOverview,
        session: session,
        showsSliverNavigationBar: compact,
        navigationLeading: compact ? _buildCompactLeading() : null,
        navigationTrailing: compact ? _buildCompactTrailing() : null,
        onRefresh: widget.controller.refreshCluster,
        onGuestPowerAction: widget.controller.refreshCluster,
      ),
      ClusterNodesPage(
        controller: widget.controller.clusterOverview,
        showsSliverNavigationBar: compact,
        navigationLeading: compact ? _buildCompactLeading() : null,
        navigationTrailing: compact ? _buildCompactTrailing() : null,
        onRefresh: widget.controller.refreshCluster,
      ),
      StoragePage(
        controller: widget.controller.clusterOverview,
        showsSliverNavigationBar: compact,
        navigationLeading: compact ? _buildCompactLeading() : null,
        navigationTrailing: compact ? _buildCompactTrailing() : null,
        onRefresh: widget.controller.refreshCluster,
      ),
      TasksPage(
        controller: widget.controller.clusterOverview,
        showsSliverNavigationBar: compact,
        navigationLeading: compact ? _buildCompactLeading() : null,
        navigationTrailing: compact ? _buildCompactTrailing() : null,
        onRefresh: widget.controller.refreshCluster,
      ),
    ];
  }

  Widget _buildCompactLeading() {
    final ConnectionProfilesController profiles =
        widget.controller.connectionProfiles;
    return ServerMenu(
      profiles: profiles.profiles,
      selectedProfile: profiles.selectedProfile,
      onSelected: _connectToProfile,
      compact: true,
    );
  }

  Widget _buildCompactTrailing() {
    return WorkspaceActionsMenu(
      connected: true,
      onRefresh: widget.controller.refreshCluster,
      onDisconnect: widget.controller.disconnect,
      onManageServers: () =>
          showConnectionProfilesSheet(context, controller: widget.controller),
      onAbout: () => showPveCompanionAboutDialog(context),
      liveActivitiesAvailable:
          widget.controller.systemSurfaces.liveActivitiesAvailable,
      datacenterWatchActive:
          widget.controller.systemSurfaces.datacenterWatchActive,
      onStartDatacenterWatch: () => showDatacenterWatchSheet(
        context,
        controller: widget.controller.systemSurfaces,
      ),
      onEndDatacenterWatch: widget.controller.systemSurfaces.endDatacenterWatch,
    );
  }

  WorkspaceToolbar _buildToolbar(
    BuildContext context, {
    required String title,
    required bool connected,
    bool showServerMenu = true,
    bool includeRefreshMenuAction = true,
  }) {
    final ConnectionProfilesController profiles =
        widget.controller.connectionProfiles;
    return WorkspaceToolbar(
      profiles: profiles.profiles,
      selectedProfile: profiles.selectedProfile,
      title: title,
      connected: connected,
      onConnectToProfile: _connectToProfile,
      onRefresh: widget.controller.refreshCluster,
      onDisconnect: widget.controller.disconnect,
      onManageServers: () =>
          showConnectionProfilesSheet(context, controller: widget.controller),
      onAbout: () => showPveCompanionAboutDialog(context),
      showServerMenu: showServerMenu,
      includeRefreshMenuAction: includeRefreshMenuAction,
      liveActivitiesAvailable:
          widget.controller.systemSurfaces.liveActivitiesAvailable,
      datacenterWatchActive:
          widget.controller.systemSurfaces.datacenterWatchActive,
      onStartDatacenterWatch: () => showDatacenterWatchSheet(
        context,
        controller: widget.controller.systemSurfaces,
      ),
      onEndDatacenterWatch: widget.controller.systemSurfaces.endDatacenterWatch,
    );
  }

  void _selectSection(WorkspaceSection section) {
    if (_section == section) {
      return;
    }
    setState(() => _section = section);
  }

  Future<void> _connectToProfile(String profileId) async {
    final ConnectionAttemptResult result = await widget.controller
        .connectProfile(profileId);
    if (!mounted || result.kind == ConnectionAttemptKind.connected) {
      return;
    }
    final String message =
        result.kind == ConnectionAttemptKind.certificateTrustRequired
        ? 'The server certificate changed. Remove and add this server again '
              'after verifying its new fingerprint.'
        : result.message ?? 'Connection was not completed.';
    await _showConnectionError(message);
  }

  Future<void> _connectSelectedProfile() async {
    final ConnectionAttemptResult result = await widget.controller
        .connectSelectedProfile();
    if (!mounted || result.kind == ConnectionAttemptKind.connected) {
      return;
    }
    final String message =
        result.kind == ConnectionAttemptKind.certificateTrustRequired
        ? 'The server certificate changed. Remove and add this server again '
              'after verifying its new fingerprint.'
        : result.message ?? 'Connection was not completed.';
    await _showConnectionError(message);
  }

  Future<void> _showConnectionError(String message) {
    return showCupertinoDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => CupertinoAlertDialog(
        title: const Text('Couldn’t Connect'),
        content: Text(message),
        actions: <Widget>[
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
