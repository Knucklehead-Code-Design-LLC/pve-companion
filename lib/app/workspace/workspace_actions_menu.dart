import 'package:flutter/cupertino.dart';

import '../../core/presentation/pve_apple_ui.dart';
import 'workspace_settings_sheet.dart';

class WorkspaceActionsMenu extends StatelessWidget {
  const WorkspaceActionsMenu({
    super.key,
    required this.connected,
    required this.onDisconnect,
    required this.onManageServers,
    required this.onAbout,
    this.onViewFleet,
    this.onManageNotifications,
    this.onClusterAdministration,
    this.liveActivitiesAvailable = false,
    this.datacenterWatchActive = false,
    this.onStartDatacenterWatch,
    this.onEndDatacenterWatch,
  });

  final bool connected;
  final VoidCallback onDisconnect;
  final VoidCallback onManageServers;
  final VoidCallback onAbout;
  final VoidCallback? onViewFleet;
  final VoidCallback? onManageNotifications;
  final VoidCallback? onClusterAdministration;
  final bool liveActivitiesAvailable;
  final bool datacenterWatchActive;
  final VoidCallback? onStartDatacenterWatch;
  final VoidCallback? onEndDatacenterWatch;

  @override
  Widget build(BuildContext context) {
    return PveIconAction(
      icon: CupertinoIcons.gear_alt,
      label: PveActionLabels.workspaceSettings,
      onPressed: () => showWorkspaceSettingsSheet(
        context,
        connected: connected,
        onDisconnect: onDisconnect,
        onManageServers: onManageServers,
        onAbout: onAbout,
        onViewFleet: onViewFleet,
        onManageNotifications: onManageNotifications,
        onClusterAdministration: onClusterAdministration,
        liveActivitiesAvailable: liveActivitiesAvailable,
        datacenterWatchActive: datacenterWatchActive,
        onStartDatacenterWatch: onStartDatacenterWatch,
        onEndDatacenterWatch: onEndDatacenterWatch,
      ),
    );
  }
}
