import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../core/presentation/pve_apple_ui.dart';
import 'workspace_section.dart';

/// The workspace's navigation layout, based on the available window width.
///
/// Pages retain control of their own responsive content, while this layout
/// selects the appropriate navigation chrome for compact, regular, and wide
/// workspaces.
enum WorkspaceLayoutSize { compact, regular, wide }

abstract final class WorkspaceLayout {
  static const double compactBreakpoint = PveAppleLayout.compactBreakpoint;
  static const double wideBreakpoint = PveAppleLayout.wideBreakpoint;

  static WorkspaceLayoutSize forWidth(double width) {
    if (width < compactBreakpoint) {
      return WorkspaceLayoutSize.compact;
    }
    if (width < wideBreakpoint) {
      return WorkspaceLayoutSize.regular;
    }
    return WorkspaceLayoutSize.wide;
  }
}

class AdaptiveWorkspaceContent extends StatelessWidget {
  const AdaptiveWorkspaceContent({
    super.key,
    required this.section,
    required this.onSectionChanged,
    required this.pages,
    required this.sidebarHeader,
    required this.wideNavigationBar,
    required this.onRefresh,
    required this.refreshing,
    this.lastUpdatedAt,
    this.refreshErrorMessage,
    this.sidebarActions = const <WorkspaceSidebarAction>[],
    this.desktopInspector,
  }) : assert(pages.length == WorkspaceSection.values.length);

  final WorkspaceSection section;
  final ValueChanged<WorkspaceSection> onSectionChanged;
  final List<Widget> pages;
  final Widget sidebarHeader;
  final ObstructingPreferredSizeWidget wideNavigationBar;
  final Future<void> Function() onRefresh;
  final bool refreshing;
  final DateTime? lastUpdatedAt;
  final String? refreshErrorMessage;

  /// Secondary workspace destinations that remain visible on desktop instead
  /// of being hidden behind the overflow menu.
  final List<WorkspaceSidebarAction> sidebarActions;

  /// An optional persistent inspector supplied by a selected-resource owner.
  /// The shell deliberately does not invent inspection content itself.
  final Widget? desktopInspector;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int selectedIndex = section.index;
        final WorkspaceLayoutSize layout = WorkspaceLayout.forWidth(
          constraints.maxWidth,
        );
        if (layout != WorkspaceLayoutSize.compact) {
          final bool usesIpadSidebar =
              defaultTargetPlatform == TargetPlatform.iOS;
          return Row(
            children: <Widget>[
              _WorkspaceSidebar(
                section: section,
                onSectionChanged: onSectionChanged,
                header: sidebarHeader,
                width: _sidebarWidth(
                  layout: layout,
                  usesIpadSidebar: usesIpadSidebar,
                ),
                onRefresh: onRefresh,
                refreshing: refreshing,
                lastUpdatedAt: lastUpdatedAt,
                refreshErrorMessage: refreshErrorMessage,
                actions: sidebarActions,
              ),
              Container(
                width: 0.5,
                color: PveAppleColors.separator(
                  context,
                ).withValues(alpha: 0.55),
              ),
              Expanded(
                child: CupertinoPageScaffold(
                  backgroundColor: PveAppleColors.page(context),
                  navigationBar: wideNavigationBar,
                  child: IndexedStack(index: selectedIndex, children: pages),
                ),
              ),
              if (layout == WorkspaceLayoutSize.wide &&
                  desktopInspector != null)
                _DesktopInspector(child: desktopInspector!),
            ],
          );
        }
        return Column(
          children: <Widget>[
            Expanded(
              child: IndexedStack(index: selectedIndex, children: pages),
            ),
            MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.25,
              child: CupertinoTabBar(
                currentIndex: selectedIndex,
                onTap: _selectIndex,
                iconSize: 23,
                activeColor: PveAppleColors.primary(context),
                inactiveColor: PveAppleColors.secondaryLabel(context),
                items: WorkspaceSection.values
                    .map(
                      (WorkspaceSection item) => BottomNavigationBarItem(
                        icon: Icon(item.icon),
                        activeIcon: Icon(item.selectedIcon),
                        label: item.label,
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          ],
        );
      },
    );
  }

  void _selectIndex(int index) =>
      onSectionChanged(WorkspaceSection.values[index]);

  double _sidebarWidth({
    required WorkspaceLayoutSize layout,
    required bool usesIpadSidebar,
  }) {
    if (usesIpadSidebar) {
      return 288;
    }
    return switch (layout) {
      WorkspaceLayoutSize.regular => 304,
      WorkspaceLayoutSize.wide => 320,
      WorkspaceLayoutSize.compact => throw StateError(
        'Compact workspaces do not show a sidebar.',
      ),
    };
  }
}

class _WorkspaceSidebar extends StatelessWidget {
  const _WorkspaceSidebar({
    required this.section,
    required this.onSectionChanged,
    required this.header,
    required this.width,
    required this.onRefresh,
    required this.refreshing,
    required this.lastUpdatedAt,
    required this.refreshErrorMessage,
    required this.actions,
  });

  final WorkspaceSection section;
  final ValueChanged<WorkspaceSection> onSectionChanged;
  final Widget header;
  final double width;
  final Future<void> Function() onRefresh;
  final bool refreshing;
  final DateTime? lastUpdatedAt;
  final String? refreshErrorMessage;
  final List<WorkspaceSidebarAction> actions;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: PveAppleColors.surface(context).withValues(alpha: 0.9),
      child: SafeArea(
        right: false,
        child: SizedBox(
          key: const ValueKey<String>('workspace-sidebar'),
          width: width,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: PveAppleColors.page(context).withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: PveAppleColors.separator(
                        context,
                      ).withValues(alpha: 0.4),
                      width: 0.5,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 4,
                    ),
                    child: header,
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: Text(
                    'Datacenter',
                    style: PveAppleText.caption(
                      context,
                    ).copyWith(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(
                  child: _SidebarDestinations(
                    section: section,
                    onSectionChanged: onSectionChanged,
                  ),
                ),
                if (actions.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 8),
                  _SidebarWorkspaceActions(actions: actions),
                ],
                const SizedBox(height: 12),
                _WorkspaceConnectionFooter(
                  refreshing: refreshing,
                  lastUpdatedAt: lastUpdatedAt,
                  refreshErrorMessage: refreshErrorMessage,
                  onRefresh: onRefresh,
                  showRefreshLabel: width >= 300,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class WorkspaceSidebarAction {
  const WorkspaceSidebarAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.badgeCount = 0,
  }) : assert(badgeCount >= 0);

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final int badgeCount;
}

class _SidebarDestinations extends StatelessWidget {
  const _SidebarDestinations({
    required this.section,
    required this.onSectionChanged,
  });

  final WorkspaceSection section;
  final ValueChanged<WorkspaceSection> onSectionChanged;

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.arrowUp): _SidebarMoveIntent(-1),
        SingleActivator(LogicalKeyboardKey.arrowDown): _SidebarMoveIntent(1),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _SidebarMoveIntent: CallbackAction<_SidebarMoveIntent>(
            onInvoke: (_SidebarMoveIntent intent) {
              final int nextIndex = (section.index + intent.delta)
                  .clamp(0, WorkspaceSection.values.length - 1)
                  .toInt();
              onSectionChanged(WorkspaceSection.values[nextIndex]);
              return null;
            },
          ),
        },
        child: FocusableActionDetector(
          autofocus: true,
          child: ListView(
            padding: EdgeInsets.zero,
            children: WorkspaceSection.values
                .map(
                  (WorkspaceSection item) => _SidebarDestination(
                    item: item,
                    selected: item == section,
                    onTap: () => onSectionChanged(item),
                  ),
                )
                .toList(growable: false),
          ),
        ),
      ),
    );
  }
}

class _SidebarMoveIntent extends Intent {
  const _SidebarMoveIntent(this.delta);

  final int delta;
}

class _SidebarWorkspaceActions extends StatelessWidget {
  const _SidebarWorkspaceActions({required this.actions});

  final List<WorkspaceSidebarAction> actions;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: actions
          .map(
            (WorkspaceSidebarAction action) => Semantics(
              button: true,
              label: action.badgeCount == 0
                  ? action.label
                  : '${action.label}, ${action.badgeCount} datacenter incidents need attention',
              child: CupertinoButton(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                alignment: Alignment.centerLeft,
                onPressed: action.onPressed,
                child: Row(
                  children: <Widget>[
                    Icon(action.icon, size: 17),
                    const SizedBox(width: 9),
                    Expanded(child: Text(action.label)),
                    if (action.badgeCount > 0)
                      _AttentionBadge(count: action.badgeCount),
                  ],
                ),
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _AttentionBadge extends StatelessWidget {
  const _AttentionBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$count datacenter incidents need attention',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: PveAppleColors.warning(context),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: Text(
            '$count',
            style: PveAppleText.caption(context).copyWith(
              color: CupertinoColors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _DesktopInspector extends StatelessWidget {
  const _DesktopInspector({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey<String>('workspace-desktop-inspector'),
      width: 360,
      decoration: BoxDecoration(
        color: PveAppleColors.surface(context),
        border: Border(
          left: BorderSide(
            color: PveAppleColors.separator(context).withValues(alpha: 0.55),
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(left: false, child: child),
    );
  }
}

class _WorkspaceConnectionFooter extends StatelessWidget {
  const _WorkspaceConnectionFooter({
    required this.refreshing,
    required this.lastUpdatedAt,
    required this.refreshErrorMessage,
    required this.onRefresh,
    required this.showRefreshLabel,
  });

  final bool refreshing;
  final DateTime? lastUpdatedAt;
  final String? refreshErrorMessage;
  final Future<void> Function() onRefresh;
  final bool showRefreshLabel;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: PveAppleColors.page(context).withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: PveAppleColors.separator(context).withValues(alpha: 0.36),
          width: 0.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Row(
          children: <Widget>[
            DecoratedBox(
              decoration: BoxDecoration(
                color: PveAppleColors.success(context),
                shape: BoxShape.circle,
              ),
              child: const SizedBox.square(dimension: 8),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Connected', style: PveAppleText.caption(context)),
                  if (refreshErrorMessage != null)
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        'Data refresh failed',
                        style: PveAppleText.caption(context).copyWith(
                          color: PveAppleColors.warning(context),
                          fontSize: 12,
                        ),
                      ),
                    )
                  else if (lastUpdatedAt != null)
                    PveFreshnessLabel(refreshedAt: lastUpdatedAt!),
                ],
              ),
            ),
            if (showRefreshLabel)
              CupertinoButton(
                key: const ValueKey<String>('workspace-footer-refresh'),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                minimumSize: const Size(44, 40),
                onPressed: refreshing ? null : () => onRefresh(),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (refreshing)
                      const CupertinoActivityIndicator(radius: 8)
                    else
                      const Icon(CupertinoIcons.refresh, size: 16),
                    const SizedBox(width: 5),
                    Text(refreshing ? 'Updating' : 'Refresh data'),
                  ],
                ),
              )
            else
              KeyedSubtree(
                key: const ValueKey<String>('workspace-footer-refresh'),
                child: PveIconAction(
                  icon: refreshing
                      ? CupertinoIcons.refresh_thick
                      : CupertinoIcons.refresh,
                  label: refreshing ? 'Refreshing datacenter' : 'Refresh data',
                  onPressed: refreshing ? null : () => onRefresh(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SidebarDestination extends StatelessWidget {
  const _SidebarDestination({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final WorkspaceSection item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color accent = PveAppleColors.primary(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Semantics(
          selected: selected,
          child: CupertinoListTile(
            backgroundColor: selected
                ? accent.withValues(alpha: 0.14)
                : const Color(0x00000000),
            backgroundColorActivated: accent.withValues(alpha: 0.1),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            leadingSize: 26,
            leadingToTitle: 10,
            leading: Center(
              child: Icon(
                selected ? item.selectedIcon : item.icon,
                size: 20,
                color: selected
                    ? accent
                    : PveAppleColors.secondaryLabel(context),
              ),
            ),
            title: Text(
              item.label,
              style: PveAppleText.body(context).copyWith(
                fontSize: 15,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            onTap: onTap,
          ),
        ),
      ),
    );
  }
}
