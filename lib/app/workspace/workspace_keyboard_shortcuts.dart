import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import 'workspace_section.dart';

/// macOS workspace shortcuts for navigation and explicitly requested refreshes.
///
/// This wrapper is only enabled by the desktop workspace. It intentionally
/// contains no shortcuts that change infrastructure state.
class WorkspaceKeyboardShortcuts extends StatelessWidget {
  const WorkspaceKeyboardShortcuts({
    super.key,
    required this.enabled,
    required this.onRefresh,
    required this.onSectionSelected,
    required this.child,
    this.onOpenCommandPalette,
  });

  final bool enabled;
  final Future<void> Function() onRefresh;
  final ValueChanged<WorkspaceSection> onSectionSelected;
  final Widget child;
  final VoidCallback? onOpenCommandPalette;

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return child;
    }
    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.keyR, meta: true):
            _WorkspaceRefreshIntent(),
        SingleActivator(LogicalKeyboardKey.keyK, meta: true):
            _WorkspaceCommandPaletteIntent(),
        SingleActivator(LogicalKeyboardKey.escape): _WorkspaceDismissIntent(),
        SingleActivator(LogicalKeyboardKey.digit1, meta: true):
            _WorkspaceSectionIntent(WorkspaceSection.overview),
        SingleActivator(LogicalKeyboardKey.digit2, meta: true):
            _WorkspaceSectionIntent(WorkspaceSection.guests),
        SingleActivator(LogicalKeyboardKey.digit3, meta: true):
            _WorkspaceSectionIntent(WorkspaceSection.nodes),
        SingleActivator(LogicalKeyboardKey.digit4, meta: true):
            _WorkspaceSectionIntent(WorkspaceSection.storage),
        SingleActivator(LogicalKeyboardKey.digit5, meta: true):
            _WorkspaceSectionIntent(WorkspaceSection.tasks),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _WorkspaceRefreshIntent: CallbackAction<_WorkspaceRefreshIntent>(
            onInvoke: (_WorkspaceRefreshIntent intent) {
              unawaited(onRefresh());
              return null;
            },
          ),
          _WorkspaceSectionIntent: CallbackAction<_WorkspaceSectionIntent>(
            onInvoke: (_WorkspaceSectionIntent intent) {
              onSectionSelected(intent.section);
              return null;
            },
          ),
          _WorkspaceCommandPaletteIntent:
              CallbackAction<_WorkspaceCommandPaletteIntent>(
                onInvoke: (_WorkspaceCommandPaletteIntent intent) {
                  onOpenCommandPalette?.call();
                  return null;
                },
              ),
          _WorkspaceDismissIntent: CallbackAction<_WorkspaceDismissIntent>(
            onInvoke: (_WorkspaceDismissIntent intent) {
              final NavigatorState navigator = Navigator.of(context);
              if (navigator.canPop()) {
                navigator.maybePop();
              }
              return null;
            },
          ),
        },
        child: Focus(autofocus: true, child: child),
      ),
    );
  }
}

class _WorkspaceRefreshIntent extends Intent {
  const _WorkspaceRefreshIntent();
}

class _WorkspaceSectionIntent extends Intent {
  const _WorkspaceSectionIntent(this.section);

  final WorkspaceSection section;
}

class _WorkspaceCommandPaletteIntent extends Intent {
  const _WorkspaceCommandPaletteIntent();
}

class _WorkspaceDismissIntent extends Intent {
  const _WorkspaceDismissIntent();
}
