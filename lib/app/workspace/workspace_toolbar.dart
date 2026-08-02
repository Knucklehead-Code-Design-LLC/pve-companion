import 'package:flutter/cupertino.dart';

import '../../features/connection_profiles/domain/connection_profile.dart';
import 'server_menu.dart';
import 'workspace_actions_menu.dart';

class WorkspaceToolbar extends StatelessWidget
    implements ObstructingPreferredSizeWidget {
  const WorkspaceToolbar({
    super.key,
    required this.profiles,
    required this.selectedProfile,
    required this.title,
    required this.connected,
    required this.onConnectToProfile,
    required this.onRefresh,
    required this.onDisconnect,
    required this.onManageServers,
    required this.onAbout,
    this.showServerMenu = true,
    this.includeRefreshMenuAction = true,
    this.liveActivitiesAvailable = false,
    this.datacenterWatchActive = false,
    this.onStartDatacenterWatch,
    this.onEndDatacenterWatch,
  });

  final List<ConnectionProfile> profiles;
  final ConnectionProfile? selectedProfile;
  final String title;
  final bool connected;
  final ValueChanged<String> onConnectToProfile;
  final VoidCallback onRefresh;
  final VoidCallback onDisconnect;
  final VoidCallback onManageServers;
  final VoidCallback onAbout;
  final bool showServerMenu;
  final bool includeRefreshMenuAction;
  final bool liveActivitiesAvailable;
  final bool datacenterWatchActive;
  final VoidCallback? onStartDatacenterWatch;
  final VoidCallback? onEndDatacenterWatch;

  @override
  Widget build(BuildContext context) {
    return CupertinoNavigationBar(
      transitionBetweenRoutes: false,
      automaticallyImplyLeading: false,
      leading: showServerMenu
          ? ServerMenu(
              profiles: profiles,
              selectedProfile: selectedProfile,
              onSelected: onConnectToProfile,
              compact: true,
            )
          : null,
      middle: Text(title),
      trailing: WorkspaceActionsMenu(
        connected: connected,
        onRefresh: onRefresh,
        onDisconnect: onDisconnect,
        onManageServers: onManageServers,
        onAbout: onAbout,
        includeRefreshAction: includeRefreshMenuAction,
        liveActivitiesAvailable: liveActivitiesAvailable,
        datacenterWatchActive: datacenterWatchActive,
        onStartDatacenterWatch: onStartDatacenterWatch,
        onEndDatacenterWatch: onEndDatacenterWatch,
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(44);

  @override
  bool shouldFullyObstruct(BuildContext context) => true;
}
