import 'package:flutter/cupertino.dart';

import '../../core/presentation/pve_apple_ui.dart';

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
    return CupertinoButton(
      padding: const EdgeInsets.all(8),
      minimumSize: const Size(44, 44),
      onPressed: () => _showActions(context),
      child: Icon(
        CupertinoIcons.ellipsis_circle,
        size: 24,
        color: PveAppleColors.primary(context),
      ),
    );
  }

  Future<void> _showActions(BuildContext context) async {
    final _WorkspaceAction? action = await showCupertinoModalPopup(
      context: context,
      builder: (BuildContext popupContext) {
        return CupertinoActionSheet(
          title: const Text('PVE Companion'),
          actions: <Widget>[
            if (connected)
              CupertinoActionSheetAction(
                onPressed: () =>
                    Navigator.pop(popupContext, _WorkspaceAction.refresh),
                child: const Text('Refresh datacenter'),
              ),
            CupertinoActionSheetAction(
              onPressed: () =>
                  Navigator.pop(popupContext, _WorkspaceAction.manageServers),
              child: const Text('Manage servers'),
            ),
            CupertinoActionSheetAction(
              onPressed: () =>
                  Navigator.pop(popupContext, _WorkspaceAction.about),
              child: const Text('About and privacy'),
            ),
            if (connected)
              CupertinoActionSheetAction(
                isDestructiveAction: true,
                onPressed: () =>
                    Navigator.pop(popupContext, _WorkspaceAction.disconnect),
                child: const Text('Disconnect'),
              ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(popupContext),
            child: const Text('Cancel'),
          ),
        );
      },
    );
    switch (action) {
      case _WorkspaceAction.refresh:
        onRefresh();
      case _WorkspaceAction.disconnect:
        onDisconnect();
      case _WorkspaceAction.manageServers:
        onManageServers();
      case _WorkspaceAction.about:
        onAbout();
      case null:
        return;
    }
  }
}

enum _WorkspaceAction { refresh, disconnect, manageServers, about }
