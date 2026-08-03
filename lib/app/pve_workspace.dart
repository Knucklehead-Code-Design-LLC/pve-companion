import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

import '../core/api/proxmox_session.dart';
import '../core/presentation/pve_apple_ui.dart';
import '../core/presentation/pve_haptics.dart';
import '../features/cluster_administration/presentation/cluster_administration_sheet.dart';
import '../features/cluster_overview/application/cluster_overview_controller.dart';
import '../features/cluster_overview/presentation/cluster_nodes_page.dart';
import '../features/cluster_overview/presentation/cluster_overview_page.dart';
import '../features/connection_profiles/application/connection_profiles_controller.dart';
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
    final session = widget.controller.connectionProfiles.activeSession;
    final isCompact = !PveAppleLayout.usesExpandedPresentation(context);
    return WorkspaceKeyboardShortcuts(
      enabled: session != null && defaultTargetPlatform == TargetPlatform.macOS,
      onRefresh: widget.controller.refreshCluster,
      onSectionSelected: _selectSection,
      onOpenCommandPalette: _showCommandPalette,
      child: _buildWorkspaceContent(context, session, isCompact),
    );
  }

  Widget _buildWorkspaceContent(
    BuildContext context,
    ProxmoxSession? session,
    bool isCompact,
  ) {
    final profiles = widget.controller.connectionProfiles;
    final selectedProfile = profiles.selectedProfile;
    if (session == null) {
      return CupertinoPageScaffold(
        backgroundColor: PveAppleColors.page(context),
        navigationBar: _buildToolbar(
          context,
          title: 'PVE Companion',
          connected: false,
        ),
        child: DisconnectedWorkspace(
          profile: selectedProfile,
          status: profiles.connectionStatus,
          errorMessage: profiles.errorMessage,
          onConnect: _connectSelectedProfile,
          onAddServer: _showAddConnectionProfile,
        ),
      );
    }
    return CupertinoPageScaffold(
      backgroundColor: PveAppleColors.page(context),
      child: AdaptiveWorkspaceContent(
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
        refreshErrorMessage: widget.controller.clusterOverview.errorMessage,
        sidebarActions: _sidebarActions(),
        footerActions: _footerActions(),
        desktopInspector: _desktopInspector(),
        pages: _buildPages(session, isCompact: isCompact),
      ),
    );
  }

  List<WorkspaceSidebarAction> _sidebarActions() {
    final attentionCount = _attentionCount;
    return <WorkspaceSidebarAction>[
      WorkspaceSidebarAction(
        label: _notificationSidebarLabel(attentionCount),
        icon: CupertinoIcons.bell,
        badgeCount: attentionCount,
        onPressed: _showNotifications,
      ),
      WorkspaceSidebarAction(
        label: 'Manage servers',
        icon: CupertinoIcons.rectangle_stack_badge_plus,
        onPressed: _showConnectionProfiles,
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

  List<WorkspaceSidebarAction> _footerActions() => <WorkspaceSidebarAction>[
    WorkspaceSidebarAction(
      label: PveActionLabels.workspaceSettings,
      icon: CupertinoIcons.gear_alt,
      onPressed: _showWorkspaceSettings,
    ),
  ];

  Widget? _desktopInspector() {
    if (!_canShowDesktopInspector) {
      return null;
    }
    return _WorkspaceContextInspector(
      section: _section,
      refreshedAt: widget.controller.clusterOverview.lastUpdatedAt,
      attentionCount: _attentionCount,
      onShowNotifications: _showNotifications,
      onManageServers: _showConnectionProfiles,
    );
  }

  bool get _canShowDesktopInspector {
    if (defaultTargetPlatform != TargetPlatform.macOS) {
      return false;
    }
    return switch (_section) {
      WorkspaceSection.overview || WorkspaceSection.storage => true,
      WorkspaceSection.guests ||
      WorkspaceSection.nodes ||
      WorkspaceSection.tasks => false,
    };
  }

  int get _attentionCount {
    final snapshot = widget.controller.clusterOverview.snapshot;
    if (snapshot == null) {
      return 0;
    }
    return DatacenterIncidentEvaluator.evaluate(snapshot).incidents.length;
  }

  String _notificationSidebarLabel(int attentionCount) {
    if (attentionCount == 0) {
      return 'Notifications';
    }
    return 'Needs attention';
  }

  List<Widget> _buildPages(ProxmoxSession session, {required bool isCompact}) {
    return <Widget>[
      ClusterOverviewPage(
        controller: widget.controller.clusterOverview,
        showsSliverNavigationBar: isCompact,
        navigationLeading: _compactNavigationLeading(isCompact),
        navigationTrailing: _compactNavigationTrailing(isCompact),
        onRefresh: widget.controller.refreshCluster,
        onViewGuests: () => _selectSection(WorkspaceSection.guests),
        onViewNodes: () => _selectSection(WorkspaceSection.nodes),
        onViewStorage: () => _selectSection(WorkspaceSection.storage),
        onViewTasks: () => _selectSection(WorkspaceSection.tasks),
      ),
      GuestListPage(
        overviewController: widget.controller.clusterOverview,
        session: session,
        showsSliverNavigationBar: isCompact,
        navigationLeading: _compactNavigationLeading(isCompact),
        navigationTrailing: _compactNavigationTrailing(isCompact),
        onRefresh: widget.controller.refreshCluster,
        onGuestPowerAction: widget.controller.refreshCluster,
      ),
      ClusterNodesPage(
        controller: widget.controller.clusterOverview,
        session: session,
        showsSliverNavigationBar: isCompact,
        navigationLeading: _compactNavigationLeading(isCompact),
        navigationTrailing: _compactNavigationTrailing(isCompact),
        onRefresh: widget.controller.refreshCluster,
        onNodeOperation: widget.controller.refreshCluster,
        onViewGuests: () => _selectSection(WorkspaceSection.guests),
        onViewTasks: () => _selectSection(WorkspaceSection.tasks),
      ),
      StoragePage(
        controller: widget.controller.clusterOverview,
        session: session,
        showsSliverNavigationBar: isCompact,
        navigationLeading: _compactNavigationLeading(isCompact),
        navigationTrailing: _compactNavigationTrailing(isCompact),
        onRefresh: widget.controller.refreshCluster,
      ),
      TasksPage(
        controller: widget.controller.clusterOverview,
        session: session,
        showsSliverNavigationBar: isCompact,
        navigationLeading: _compactNavigationLeading(isCompact),
        navigationTrailing: _compactNavigationTrailing(isCompact),
        onRefresh: widget.controller.refreshCluster,
      ),
    ];
  }

  Widget? _compactNavigationLeading(bool isCompact) {
    if (!isCompact) {
      return null;
    }
    return _buildCompactLeading();
  }

  Widget? _compactNavigationTrailing(bool isCompact) {
    if (!isCompact) {
      return null;
    }
    return _buildCompactTrailing();
  }

  Widget _buildCompactLeading() {
    final profiles = widget.controller.connectionProfiles;
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
      onManageServers: _showConnectionProfiles,
      onAbout: _showAbout,
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
    final profiles = widget.controller.connectionProfiles;
    return WorkspaceToolbar(
      profiles: profiles.profiles,
      selectedProfile: profiles.selectedProfile,
      title: title,
      connected: connected,
      onConnectToProfile: _connectToProfile,
      onRefresh: widget.controller.refreshCluster,
      onDisconnect: widget.controller.disconnect,
      onManageServers: _showConnectionProfiles,
      onAbout: _showAbout,
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
      lastUpdatedAt: connected
          ? widget.controller.clusterOverview.lastUpdatedAt
          : null,
    );
  }

  void _selectSection(WorkspaceSection section) {
    if (_section == section) {
      return;
    }
    setState(() => _section = section);
  }

  void _handleWorkspaceNavigationRequest() {
    final requestId = widget.controller.workspaceNavigationRequestId;
    if (requestId == _handledNavigationRequestId) {
      return;
    }
    _handledNavigationRequestId = requestId;
    final requestedSection = widget.controller.requestedWorkspaceSection;
    if (requestedSection != _section && mounted) {
      setState(() => _section = requestedSection);
    }
  }

  Future<void> _connectToProfile(String profileId) =>
      _runConnectionAttempt(() => widget.controller.connectProfile(profileId));

  Future<void> _connectSelectedProfile() =>
      _runConnectionAttempt(widget.controller.connectSelectedProfile);

  Future<void> _runConnectionAttempt(
    Future<ConnectionAttemptResult> Function() attempt,
  ) async {
    final result = await attempt();
    if (!mounted) {
      return;
    }
    if (result.kind == ConnectionAttemptKind.connected) {
      unawaited(PveHaptics.success());
      return;
    }
    if (result.kind == ConnectionAttemptKind.certificateTrustRequired) {
      unawaited(PveHaptics.warning());
    } else if (result.kind == ConnectionAttemptKind.failed) {
      unawaited(PveHaptics.error());
    }
    await _showConnectionError(_connectionErrorMessage(result));
  }

  String _connectionErrorMessage(ConnectionAttemptResult result) {
    if (result.kind == ConnectionAttemptKind.certificateTrustRequired) {
      return 'The server certificate changed. Remove and add this server again '
          'after verifying its new fingerprint.';
    }
    return result.message ?? 'Connection was not completed.';
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
      onManageServers: _showConnectionProfiles,
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

  Future<void> _showAddConnectionProfile() {
    return showAddConnectionProfileSheet(
      context,
      controller: widget.controller,
    );
  }

  Future<void> _showConnectionProfiles() {
    return showConnectionProfilesSheet(context, controller: widget.controller);
  }

  Future<void> _showAbout() => showPveCompanionAboutDialog(context);

  Future<void> _showWorkspaceSettings() {
    return showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext settingsContext) => CupertinoActionSheet(
        title: const Text(PveActionLabels.workspaceSettings),
        message: const Text(
          'Manage saved servers, notification preferences, and workspace information.',
        ),
        actions: <Widget>[
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(settingsContext).pop();
              unawaited(_showConnectionProfiles());
            },
            child: const Text('Manage servers'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(settingsContext).pop();
              unawaited(_showNotifications());
            },
            child: const Text('Notification settings'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(settingsContext).pop();
              unawaited(_showAbout());
            },
            child: const Text('About PVE Companion'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(settingsContext).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  Future<void> _showClusterAdministration() async {
    final session = widget.controller.connectionProfiles.activeSession;
    final overview = widget.controller.clusterOverview.snapshot;
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

class _WorkspaceContextInspector extends StatelessWidget {
  const _WorkspaceContextInspector({
    required this.section,
    required this.refreshedAt,
    required this.attentionCount,
    required this.onShowNotifications,
    required this.onManageServers,
  });

  final WorkspaceSection section;
  final DateTime? refreshedAt;
  final int attentionCount;
  final VoidCallback onShowNotifications;
  final VoidCallback onManageServers;

  String get _attentionLabel {
    if (attentionCount == 0) {
      return 'No active incidents are derived from the latest refresh.';
    }
    if (attentionCount == 1) {
      return '1 incident needs attention.';
    }
    return '$attentionCount incidents need attention.';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('Workspace', style: PveAppleText.title3(context)),
          const SizedBox(height: 4),
          Text(
            '${section.label} context',
            style: PveAppleText.secondary(context),
          ),
          const SizedBox(height: 16),
          PveInsetGroup(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Datacenter status', style: PveAppleText.title3(context)),
                const SizedBox(height: 4),
                if (refreshedAt != null)
                  PveFreshnessLabel(refreshedAt: refreshedAt!)
                else
                  Text(
                    'Data has not been refreshed yet.',
                    style: PveAppleText.secondary(context),
                  ),
                const SizedBox(height: 8),
                Text(_attentionLabel, style: PveAppleText.secondary(context)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          CupertinoButton.tinted(
            onPressed: onShowNotifications,
            child: const Text('Open notifications'),
          ),
          CupertinoButton(
            onPressed: onManageServers,
            child: const Text('Manage servers'),
          ),
          const Spacer(),
          Text('Keyboard shortcuts', style: PveAppleText.caption(context)),
          const SizedBox(height: 4),
          Text(
            '⌘R refresh · ⌘K commands · ⌘1–5 sections · Esc dismisses',
            style: PveAppleText.caption(context),
          ),
        ],
      ),
    );
  }
}
