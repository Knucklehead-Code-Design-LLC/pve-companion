import 'package:flutter/material.dart';

enum _WorkspaceAction { refresh, disconnect, manageServers, about }

class WorkspaceActionsMenu extends StatelessWidget {
  const WorkspaceActionsMenu({
    super.key,
    required this.connected,
    required this.onRefresh,
    required this.onDisconnect,
    required this.onManageServers,
    required this.onAbout,
  });

  final bool connected;
  final VoidCallback onRefresh;
  final VoidCallback onDisconnect;
  final VoidCallback onManageServers;
  final VoidCallback onAbout;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_WorkspaceAction>(
      tooltip: 'More actions',
      onSelected: (_WorkspaceAction action) {
        switch (action) {
          case _WorkspaceAction.refresh:
            onRefresh();
          case _WorkspaceAction.disconnect:
            onDisconnect();
          case _WorkspaceAction.manageServers:
            onManageServers();
          case _WorkspaceAction.about:
            onAbout();
        }
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<_WorkspaceAction>>[
        if (connected)
          const PopupMenuItem<_WorkspaceAction>(
            value: _WorkspaceAction.refresh,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.refresh),
              title: Text('Refresh cluster'),
            ),
          ),
        if (connected)
          const PopupMenuItem<_WorkspaceAction>(
            value: _WorkspaceAction.disconnect,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.link_off_outlined),
              title: Text('Disconnect'),
            ),
          ),
        const PopupMenuItem<_WorkspaceAction>(
          value: _WorkspaceAction.manageServers,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.dns_outlined),
            title: Text('Manage servers'),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<_WorkspaceAction>(
          value: _WorkspaceAction.about,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.info_outline),
            title: Text('About PVE Companion'),
          ),
        ),
      ],
    );
  }
}
