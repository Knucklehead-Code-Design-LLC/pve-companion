import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

import '../core/api/proxmox_session.dart';
import '../core/presentation/pve_apple_ui.dart';
import '../features/cluster_administration/presentation/cluster_administration_sheet.dart';
import '../features/cluster_overview/application/cluster_overview_controller.dart';
import '../features/cluster_overview/domain/cluster_overview_snapshot.dart';
import '../features/cluster_overview/presentation/cluster_nodes_page.dart';
import '../features/cluster_overview/presentation/cluster_overview_page.dart';
import '../features/connection_profiles/application/connection_profiles_controller.dart';
import '../features/connection_profiles/domain/connection_profile.dart';
import '../features/connection_profiles/presentation/connection_profiles_screen.dart';
import '../features/fleet/presentation/fleet_workspace_sheet.dart';
import '../features/guests/presentation/guest_list_page.dart';
import '../features/incidents/domain/datacenter_incident_evaluator.dart';
import '../features/notifications/presentation/datacenter_notifications_sheet.dart';
import '../features/storage/presentation/storage_page.dart';
import '../features/system_surfaces/presentation/datacenter_watch_sheet.dart';
import '../features/tasks/presentation/tasks_page.dart';
import 'pve_companion_about.dart';
import 'pve_companion_controller.dart';
import 'workspace/adaptive_workspace_content.dart';
import 'workspace/disconnected_workspace.dart';
import 'workspace/server_menu.dart';
import 'workspace/workspace_actions_menu.dart';
import 'workspace/workspace_command_palette.dart';
import 'workspace/workspace_keyboard_shortcuts.dart';
import 'workspace/workspace_section.dart';
import 'workspace/workspace_toolbar.dart';

class PveWorkspace extends StatefulWidget {
  const PveWorkspace({super.key, required this.controller});

  final PveCompanionController controller;

  @override
  State<PveWorkspace> createState() => _PveWorkspaceState();
}

class _PveWorkspaceState extends State<PveWorkspace> {
  late WorkspaceSection _section;
  late int _handledNavigationRequestId;

  @override
  void initState() {
    super.initState();
    _section = widget.controller.requestedWorkspaceSection;
    _handledNavigationRequestId =
        widget.controller.workspaceNavigationRequestId;
    widget.controller.addListener(_handleWorkspaceNavigationRequest);
  }

  @override
  void didUpdateWidget(PveWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) {
      return;
    }
    oldWidget.controller.removeListener(_handleWorkspaceNavigationRequest);
    _section = widget.controller.requestedWorkspaceSection;
    _handledNavigationRequestId =
        widget.controller.workspaceNavigationRequestId;
    widget.controller.addListener(_handleWorkspaceNavigationRequest);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleWorkspaceNavigationRequest);
    super.dispose();
  }

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
    return WorkspaceKeyboardShortcuts(
      enabled: session != null && defaultTargetPlatform == TargetPlatform.macOS,
      onRefresh: widget.controller.refreshCluster,
      onSectionSelected: _selectSection,
      onOpenCommandPalette: _showCommandPalette,
      child: CupertinoPageScaffold(
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
                sidebarActions: _sidebarActions(),
                pages: _buildPages(session, compact: compact),
              ),
      ),
    );
  }

  List<WorkspaceSidebarAction> _sidebarActions() {
    final ClusterOverviewSnapshot? snapshot =
        widget.controller.clusterOverview.snapshot;
    final int attentionCount = snapshot == null
        ? 0
        : DatacenterIncidentEvaluator.evaluate(snapshot).incidents.length;
    return <WorkspaceSidebarAction>[
      WorkspaceSidebarAction(
        label: attentionCount == 0 ? 'Notifications' : 'Needs attention',
        icon: CupertinoIcons.bell,
        badgeCount: attentionCount,
        onPressed: _showNotifications,
      ),
      WorkspaceSidebarAction(
        label: 'Manage servers',
        icon: CupertinoIcons.rectangle_stack_badge_plus,
        onPressed: () =>
            showConnectionProfilesSheet(context, controller: widget.controller),
      ),
      WorkspaceSidebarAction(
        label: 'Datacenter portfolio',
        icon: CupertinoIcons.rectangle_stack_badge_person_crop,
        onPressed: _showFleetWorkspace,
      ),
      WorkspaceSidebarAction(
        label: 'Cluster administration',
        icon: CupertinoIcons.shield_lefthalf_fill,
        onPressed: _showClusterAdministration,
      ),
    ];
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
        session: session,
        showsSliverNavigationBar: compact,
        navigationLeading: compact ? _buildCompactLeading() : null,
        navigationTrailing: compact ? _buildCompactTrailing() : null,
        onRefresh: widget.controller.refreshCluster,
        onNodeOperation: widget.controller.refreshCluster,
      ),
      StoragePage(
        controller: widget.controller.clusterOverview,
        session: session,
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
      onViewFleet: _showFleetWorkspace,
      onManageNotifications: _showNotifications,
      onClusterAdministration: _showClusterAdministration,
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
      onViewFleet: _showFleetWorkspace,
      onManageNotifications: _showNotifications,
      onClusterAdministration: _showClusterAdministration,
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

  void _handleWorkspaceNavigationRequest() {
    final int requestId = widget.controller.workspaceNavigationRequestId;
    if (requestId == _handledNavigationRequestId) {
      return;
    }
    _handledNavigationRequestId = requestId;
    final WorkspaceSection requestedSection =
        widget.controller.requestedWorkspaceSection;
    if (requestedSection != _section && mounted) {
      setState(() => _section = requestedSection);
    }
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

  Future<void> _showFleetWorkspace() {
    return showFleetWorkspaceSheet(
      context,
      controller: widget.controller.fleetOverview,
      activeProfileId: widget.controller.connectionProfiles.selectedProfile?.id,
      onOpenProfile: _connectToProfile,
    );
  }

  Future<void> _showCommandPalette() {
    return showWorkspaceCommandPalette(
      context,
      onRefresh: widget.controller.refreshCluster,
      onSectionSelected: _selectSection,
      onManageServers: () =>
          showConnectionProfilesSheet(context, controller: widget.controller),
      onManageNotifications: _showNotifications,
      onViewPortfolio: _showFleetWorkspace,
    );
  }

  Future<void> _showNotifications() {
    return showDatacenterNotificationsSheet(
      context,
      controller: widget.controller.notifications,
    );
  }

  Future<void> _showClusterAdministration() async {
    final ProxmoxSession? session =
        widget.controller.connectionProfiles.activeSession;
    final ClusterOverviewSnapshot? overview =
        widget.controller.clusterOverview.snapshot;
    if (session == null || overview == null) {
      return;
    }
    await showClusterAdministrationSheet(
      context,
      session: session,
      overview: overview,
      onViewNodes: () => _selectSection(WorkspaceSection.nodes),
    );
  }
}
