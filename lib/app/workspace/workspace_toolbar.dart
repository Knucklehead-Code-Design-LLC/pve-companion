import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

import '../../core/presentation/pve_apple_ui.dart';
import '../../features/connection_profiles/domain/connection_profile.dart';
import 'server_menu.dart';
import 'workspace_actions_menu.dart';

class WorkspaceToolbar extends StatelessWidget
    implements ObstructingPreferredSizeWidget {
  static const double _minimumDesktopCommandPaneWidth =
      PveAppleLayout.compactBreakpoint;

  const WorkspaceToolbar({
    super.key,
    required this.profiles,
    required this.selectedProfile,
    required this.title,
    required this.connected,
    required this.onConnectToProfile,
    required this.onDisconnect,
    required this.onManageServers,
    required this.onAbout,
    this.onViewFleet,
    this.onManageNotifications,
    this.onClusterAdministration,
    this.showServerMenu = true,
    this.liveActivitiesAvailable = false,
    this.datacenterWatchActive = false,
    this.onStartDatacenterWatch,
    this.onEndDatacenterWatch,
    this.desktopWorkspaceCommandsEnabled,
    this.lastUpdatedAt,
  });

  final List<ConnectionProfile> profiles;
  final ConnectionProfile? selectedProfile;
  final String title;
  final bool connected;
  final ValueChanged<String> onConnectToProfile;
  final VoidCallback onDisconnect;
  final VoidCallback onManageServers;
  final VoidCallback onAbout;
  final VoidCallback? onViewFleet;
  final VoidCallback? onManageNotifications;
  final VoidCallback? onClusterAdministration;
  final bool showServerMenu;
  final bool liveActivitiesAvailable;
  final bool datacenterWatchActive;
  final VoidCallback? onStartDatacenterWatch;
  final VoidCallback? onEndDatacenterWatch;

  /// Overrides the platform default when an embedding needs to control the
  /// desktop command presentation explicitly.
  final bool? desktopWorkspaceCommandsEnabled;

  /// The latest successful datacenter refresh, shown beside the desktop page
  /// title so the operator can judge data freshness before acting.
  final DateTime? lastUpdatedAt;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final showsDesktopWorkspaceCommands =
            desktopWorkspaceCommandsEnabled ??
            (defaultTargetPlatform == TargetPlatform.macOS &&
                constraints.maxWidth >= _minimumDesktopCommandPaneWidth);
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
              : _WorkspaceToolbarTitle(
                  title: title,
                  lastUpdatedAt: lastUpdatedAt,
                ),
          middle: showServerMenu ? Text(title) : null,
          trailing: _WorkspaceToolbarActions(
            showsDesktopWorkspaceCommands: showsDesktopWorkspaceCommands,
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
      },
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(44);

  @override
  bool shouldFullyObstruct(BuildContext context) => true;
}

class _WorkspaceToolbarTitle extends StatelessWidget {
  const _WorkspaceToolbarTitle({
    required this.title,
    required this.lastUpdatedAt,
  });

  final String title;
  final DateTime? lastUpdatedAt;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Semantics(
        header: true,
        child: Text(title, style: PveAppleText.title3(context)),
      ),
      if (lastUpdatedAt != null) PveFreshnessLabel(refreshedAt: lastUpdatedAt!),
    ],
  );
}

class _WorkspaceToolbarActions extends StatelessWidget {
  const _WorkspaceToolbarActions({
    required this.showsDesktopWorkspaceCommands,
    required this.connected,
    required this.onDisconnect,
    required this.onManageServers,
    required this.onAbout,
    required this.onViewFleet,
    required this.onManageNotifications,
    required this.onClusterAdministration,
    required this.liveActivitiesAvailable,
    required this.datacenterWatchActive,
    required this.onStartDatacenterWatch,
    required this.onEndDatacenterWatch,
  });

  final bool showsDesktopWorkspaceCommands;
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
    final menu = WorkspaceActionsMenu(
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
    );
    if (!showsDesktopWorkspaceCommands) {
      return menu;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (onManageNotifications != null)
          _DesktopWorkspaceCommand(
            label: 'Notifications',
            icon: CupertinoIcons.bell,
            onPressed: onManageNotifications!,
          ),
        _DesktopWorkspaceCommand(
          label: 'Manage Servers',
          icon: CupertinoIcons.rectangle_stack_badge_plus,
          onPressed: onManageServers,
        ),
        menu,
      ],
    );
  }
}

class _DesktopWorkspaceCommand extends StatelessWidget {
  const _DesktopWorkspaceCommand({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        minimumSize: const Size(44, 40),
        onPressed: onPressed,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 17),
            const SizedBox(width: 5),
            Text(label),
          ],
        ),
      ),
    );
  }
}
