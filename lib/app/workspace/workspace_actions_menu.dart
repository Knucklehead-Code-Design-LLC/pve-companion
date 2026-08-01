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
  final bool includeRefreshAction;
  final bool liveActivitiesAvailable;
  final bool datacenterWatchActive;
  final VoidCallback? onStartDatacenterWatch;
  final VoidCallback? onEndDatacenterWatch;

  @override
  Widget build(BuildContext context) {
    return PveCommandMenuButton<_WorkspaceAction>(
      semanticLabel: 'More datacenter actions',
      items: <PveCommandMenuItem<_WorkspaceAction>>[
        if (connected && includeRefreshAction)
          const PveCommandMenuItem<_WorkspaceAction>(
            value: _WorkspaceAction.refresh,
            label: 'Refresh Datacenter',
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
          label: 'Manage Servers',
          icon: CupertinoIcons.rectangle_stack_badge_plus,
        ),
        const PveCommandMenuItem<_WorkspaceAction>(
          value: _WorkspaceAction.about,
          label: 'About & Privacy',
          icon: CupertinoIcons.info_circle,
        ),
        if (connected)
          const PveCommandMenuItem<_WorkspaceAction>(
            value: _WorkspaceAction.disconnect,
            label: 'Disconnect',
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
  about,
}
