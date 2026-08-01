import 'package:flutter/cupertino.dart';

import '../../core/presentation/pve_apple_ui.dart';
import '../../features/connection_profiles/domain/connection_profile.dart';
import 'server_menu.dart';
import 'workspace_actions_menu.dart';

class WorkspaceToolbar extends StatelessWidget {
  const WorkspaceToolbar({
    super.key,
    required this.profiles,
    required this.selectedProfile,
    required this.connected,
    required this.onConnectToProfile,
    required this.onRefresh,
    required this.onDisconnect,
    required this.onManageServers,
    required this.onAbout,
  });

  final List<ConnectionProfile> profiles;
  final ConnectionProfile? selectedProfile;
  final bool connected;
  final ValueChanged<String> onConnectToProfile;
  final VoidCallback onRefresh;
  final VoidCallback onDisconnect;
  final VoidCallback onManageServers;
  final VoidCallback onAbout;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: PveAppleColors.surface(context).withValues(alpha: 0.88),
        border: Border(
          bottom: BorderSide(
            color: PveAppleColors.separator(context).withValues(alpha: 0.45),
            width: 0.5,
          ),
        ),
      ),
      child: SizedBox(
        height: 62,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: ServerMenu(
                    profiles: profiles,
                    selectedProfile: selectedProfile,
                    onSelected: onConnectToProfile,
                  ),
                ),
              ),
              if (connected)
                CupertinoButton(
                  padding: const EdgeInsets.all(8),
                  minimumSize: const Size(44, 44),
                  onPressed: onRefresh,
                  child: Icon(
                    CupertinoIcons.refresh,
                    size: 23,
                    color: PveAppleColors.primary(context),
                  ),
                ),
              WorkspaceActionsMenu(
                connected: connected,
                onRefresh: onRefresh,
                onDisconnect: onDisconnect,
                onManageServers: onManageServers,
                onAbout: onAbout,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
