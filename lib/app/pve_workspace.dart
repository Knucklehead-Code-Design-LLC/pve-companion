import 'package:flutter/cupertino.dart';

import '../core/api/proxmox_session.dart';
import '../core/presentation/pve_apple_ui.dart';
import '../features/cluster_overview/presentation/cluster_nodes_page.dart';
import '../features/cluster_overview/presentation/cluster_overview_page.dart';
import '../features/connection_profiles/application/connection_profiles_controller.dart';
import '../features/connection_profiles/domain/connection_profile.dart';
import '../features/connection_profiles/presentation/connection_profiles_screen.dart';
import '../features/guests/presentation/guest_list_page.dart';
import '../features/storage/presentation/storage_page.dart';
import '../features/tasks/presentation/tasks_page.dart';
import 'pve_companion_about.dart';
import 'pve_companion_controller.dart';
import 'workspace/adaptive_workspace_content.dart';
import 'workspace/disconnected_workspace.dart';
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

    return CupertinoPageScaffold(
      backgroundColor: PveAppleColors.page(context),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            WorkspaceToolbar(
              profiles: profiles.profiles,
              selectedProfile: selectedProfile,
              connected: session != null,
              onConnectToProfile: _connectToProfile,
              onRefresh: widget.controller.refreshCluster,
              onDisconnect: widget.controller.disconnect,
              onManageServers: () => showConnectionProfilesSheet(
                context,
                controller: widget.controller,
              ),
              onAbout: () => showPveCompanionAboutDialog(context),
            ),
            Expanded(
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
                      pages: _buildPages(session),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildPages(ProxmoxSession session) {
    return <Widget>[
      ClusterOverviewPage(
        controller: widget.controller.clusterOverview,
        onRefresh: widget.controller.refreshCluster,
        onViewGuests: () => _selectSection(WorkspaceSection.guests),
        onViewNodes: () => _selectSection(WorkspaceSection.nodes),
        onViewStorage: () => _selectSection(WorkspaceSection.storage),
        onViewTasks: () => _selectSection(WorkspaceSection.tasks),
      ),
      GuestListPage(
        overviewController: widget.controller.clusterOverview,
        session: session,
        onGuestPowerAction: widget.controller.refreshCluster,
      ),
      ClusterNodesPage(controller: widget.controller.clusterOverview),
      StoragePage(controller: widget.controller.clusterOverview),
      TasksPage(controller: widget.controller.clusterOverview),
    ];
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
