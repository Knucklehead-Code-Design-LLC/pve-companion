import 'package:flutter/cupertino.dart';

import '../../core/presentation/pve_apple_ui.dart';
import '../../core/presentation/pve_command_menu.dart';

class WorkspaceActionsMenu extends StatelessWidget {
  const WorkspaceActionsMenu({
    super.key,
    required this.connected,
    required this.onRefresh,
    required this.onDisconnect,
    required this.onManageServers,
    required this.onAbout,
    this.onViewFleet,
    this.onManageNotifications,
    this.onClusterAdministration,
    this.includeRefreshAction = true,
    this.liveActivitiesAvailable = false,
    this.datacenterWatchActive = false,
    this.onStartDatacenterWatch,
    this.onEndDatacenterWatch,
  });

  final bool connected;
  final VoidCallback onRefresh;
  final VoidCallback onDisconnect;
  final VoidCallback onManageServers;
  final VoidCallback onAbout;
  final VoidCallback? onViewFleet;
  final VoidCallback? onManageNotifications;
  final VoidCallback? onClusterAdministration;
  final bool includeRefreshAction;
  final bool liveActivitiesAvailable;
  final bool datacenterWatchActive;
  final VoidCallback? onStartDatacenterWatch;
  final VoidCallback? onEndDatacenterWatch;

  @override
  Widget build(BuildContext context) {
    return PveCommandMenuButton<_WorkspaceAction>(
      semanticLabel: 'Workspace actions and settings',
      items: <PveCommandMenuItem<_WorkspaceAction>>[
        if (connected && includeRefreshAction)
          const PveCommandMenuItem<_WorkspaceAction>(
            value: _WorkspaceAction.refresh,
            label: 'Refresh data',
            icon: CupertinoIcons.refresh,
          ),
        if (connected && liveActivitiesAvailable && !datacenterWatchActive)
          const PveCommandMenuItem<_WorkspaceAction>(
            value: _WorkspaceAction.startDatacenterWatch,
            label: 'Start Datacenter Watch',
            icon: CupertinoIcons.waveform_path_ecg,
            startsNewSection: true,
          ),
        if (connected && liveActivitiesAvailable && datacenterWatchActive)
          const PveCommandMenuItem<_WorkspaceAction>(
            value: _WorkspaceAction.endDatacenterWatch,
            label: 'End Datacenter Watch',
            icon: CupertinoIcons.stop_circle,
            startsNewSection: true,
          ),
        const PveCommandMenuItem<_WorkspaceAction>(
          value: _WorkspaceAction.manageServers,
          label: 'Manage servers',
          icon: CupertinoIcons.rectangle_stack_badge_plus,
        ),
        if (onViewFleet != null)
          const PveCommandMenuItem<_WorkspaceAction>(
            value: _WorkspaceAction.viewFleet,
            label: 'Datacenter portfolio',
            icon: CupertinoIcons.rectangle_stack_badge_person_crop,
          ),
        if (onManageNotifications != null)
          const PveCommandMenuItem<_WorkspaceAction>(
            value: _WorkspaceAction.manageNotifications,
            label: 'Notification settings',
            icon: CupertinoIcons.bell,
          ),
        if (connected && onClusterAdministration != null)
          const PveCommandMenuItem<_WorkspaceAction>(
            value: _WorkspaceAction.clusterAdministration,
            label: 'Cluster administration',
            icon: CupertinoIcons.shield_lefthalf_fill,
          ),
        const PveCommandMenuItem<_WorkspaceAction>(
          value: _WorkspaceAction.about,
          label: 'About PVE Companion',
          icon: CupertinoIcons.info_circle,
        ),
        if (connected)
          const PveCommandMenuItem<_WorkspaceAction>(
            value: _WorkspaceAction.disconnect,
            label: 'Disconnect server',
            icon: CupertinoIcons.arrow_right_square,
            destructive: true,
            startsNewSection: true,
          ),
      ],
      onSelected: _performAction,
      child: Icon(
        CupertinoIcons.ellipsis,
        size: 21,
        color: PveAppleColors.primary(context),
      ),
    );
  }

  void _performAction(_WorkspaceAction action) {
    switch (action) {
      case _WorkspaceAction.refresh:
        onRefresh();
      case _WorkspaceAction.disconnect:
        onDisconnect();
      case _WorkspaceAction.manageServers:
        onManageServers();
      case _WorkspaceAction.viewFleet:
        onViewFleet?.call();
      case _WorkspaceAction.manageNotifications:
        onManageNotifications?.call();
      case _WorkspaceAction.clusterAdministration:
        onClusterAdministration?.call();
      case _WorkspaceAction.about:
        onAbout();
      case _WorkspaceAction.startDatacenterWatch:
        onStartDatacenterWatch?.call();
      case _WorkspaceAction.endDatacenterWatch:
        onEndDatacenterWatch?.call();
    }
  }
}

enum _WorkspaceAction {
  refresh,
  startDatacenterWatch,
  endDatacenterWatch,
  disconnect,
  manageServers,
  viewFleet,
  manageNotifications,
  clusterAdministration,
  about,
}
