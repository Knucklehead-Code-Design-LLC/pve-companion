import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import 'workspace_section.dart';

/// Desktop command picker for navigation and safe, non-destructive actions.
/// Infrastructure-changing commands intentionally remain in their dedicated
/// screens and confirmation flows.
Future<void> showWorkspaceCommandPalette(
  BuildContext context, {
  required Future<void> Function() onRefresh,
  required ValueChanged<WorkspaceSection> onSectionSelected,
  required VoidCallback onManageServers,
  required VoidCallback onManageNotifications,
  required VoidCallback onViewPortfolio,
}) {
  return showCupertinoModalPopup<void>(
    context: context,
    builder: (BuildContext paletteContext) => Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.escape): _DismissPaletteIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _DismissPaletteIntent: CallbackAction<_DismissPaletteIntent>(
            onInvoke: (_DismissPaletteIntent intent) {
              Navigator.of(paletteContext).pop();
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: CupertinoActionSheet(
            title: const Text('Command Palette'),
            message: const Text('Navigation and safe workspace actions'),
            actions: <Widget>[
              CupertinoActionSheetAction(
                onPressed: () {
                  Navigator.of(paletteContext).pop();
                  unawaited(onRefresh());
                },
                child: const Text('Refresh datacenter'),
              ),
              for (final section in WorkspaceSection.values)
                CupertinoActionSheetAction(
                  onPressed: () {
                    Navigator.of(paletteContext).pop();
                    onSectionSelected(section);
                  },
                  child: Text('Go to ${section.label}'),
                ),
              CupertinoActionSheetAction(
                onPressed: () {
                  Navigator.of(paletteContext).pop();
                  onManageServers();
                },
                child: const Text('Manage servers'),
              ),
              CupertinoActionSheetAction(
                onPressed: () {
                  Navigator.of(paletteContext).pop();
                  onManageNotifications();
                },
                child: const Text('Notification settings'),
              ),
              CupertinoActionSheetAction(
                onPressed: () {
                  Navigator.of(paletteContext).pop();
                  onViewPortfolio();
                },
                child: const Text('Datacenter portfolio'),
              ),
            ],
            cancelButton: CupertinoActionSheetAction(
              isDefaultAction: true,
              onPressed: () => Navigator.of(paletteContext).pop(),
              child: const Text('Cancel'),
            ),
          ),
        ),
      ),
    ),
  );
}

class _DismissPaletteIntent extends Intent {
  const _DismissPaletteIntent();
}
