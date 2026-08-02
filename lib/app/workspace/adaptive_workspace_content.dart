import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

import '../../core/presentation/pve_apple_ui.dart';
import 'workspace_section.dart';

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

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int selectedIndex = section.index;
        if (constraints.maxWidth >= 760) {
          final bool usesIpadSidebar =
              defaultTargetPlatform == TargetPlatform.iOS;
          return Row(
            children: <Widget>[
              _WorkspaceSidebar(
                section: section,
                onSectionChanged: onSectionChanged,
                header: sidebarHeader,
                width: usesIpadSidebar ? 288 : 264,
                onRefresh: onRefresh,
                refreshing: refreshing,
                lastUpdatedAt: lastUpdatedAt,
                refreshErrorMessage: refreshErrorMessage,
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
  });

  final WorkspaceSection section;
  final ValueChanged<WorkspaceSection> onSectionChanged;
  final Widget header;
  final double width;
  final Future<void> Function() onRefresh;
  final bool refreshing;
  final DateTime? lastUpdatedAt;
  final String? refreshErrorMessage;

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
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 16),
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
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 7),
                  child: Text(
                    'Datacenter',
                    style: PveAppleText.caption(
                      context,
                    ).copyWith(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
                for (final WorkspaceSection item in WorkspaceSection.values)
                  _SidebarDestination(
                    item: item,
                    selected: item == section,
                    onTap: () => onSectionChanged(item),
                  ),
                const Spacer(),
                _WorkspaceConnectionFooter(
                  refreshing: refreshing,
                  lastUpdatedAt: lastUpdatedAt,
                  refreshErrorMessage: refreshErrorMessage,
                  onRefresh: onRefresh,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WorkspaceConnectionFooter extends StatelessWidget {
  const _WorkspaceConnectionFooter({
    required this.refreshing,
    required this.lastUpdatedAt,
    required this.refreshErrorMessage,
    required this.onRefresh,
  });

  final bool refreshing;
  final DateTime? lastUpdatedAt;
  final String? refreshErrorMessage;
  final Future<void> Function() onRefresh;

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
                    Text(
                      'Refresh failed',
                      style: PveAppleText.caption(context).copyWith(
                        color: PveAppleColors.warning(context),
                        fontSize: 11,
                      ),
                    )
                  else if (lastUpdatedAt != null)
                    _LastUpdatedText(updatedAt: lastUpdatedAt!),
                ],
              ),
            ),
            Semantics(
              button: true,
              label: refreshing
                  ? 'Refreshing datacenter'
                  : 'Refresh datacenter',
              child: CupertinoButton(
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
                    Text(refreshing ? 'Updating' : 'Refresh'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LastUpdatedText extends StatefulWidget {
  const _LastUpdatedText({required this.updatedAt});

  final DateTime updatedAt;

  @override
  State<_LastUpdatedText> createState() => _LastUpdatedTextState();
}

class _LastUpdatedTextState extends State<_LastUpdatedText> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _scheduleNextUpdate();
  }

  @override
  void didUpdateWidget(_LastUpdatedText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.updatedAt != widget.updatedAt) {
      _scheduleNextUpdate();
    }
  }

  void _scheduleNextUpdate() {
    _timer?.cancel();
    final int elapsedSeconds = DateTime.now()
        .difference(widget.updatedAt)
        .inSeconds;
    final int normalizedSeconds = elapsedSeconds < 0 ? 0 : elapsedSeconds;
    final int secondsUntilNextMinute = 60 - normalizedSeconds.remainder(60);
    _timer = Timer(Duration(seconds: secondsUntilNextMinute), () {
      if (!mounted) {
        return;
      }
      setState(() {});
      _scheduleNextUpdate();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _lastUpdatedLabel(widget.updatedAt),
      style: PveAppleText.caption(context).copyWith(fontSize: 11),
    );
  }
}

String _lastUpdatedLabel(DateTime updatedAt) {
  final Duration elapsed = DateTime.now().difference(updatedAt);
  if (elapsed.isNegative || elapsed.inMinutes < 1) {
    return 'Updated just now';
  }
  if (elapsed.inHours < 1) {
    return 'Updated ${elapsed.inMinutes}m ago';
  }
  if (elapsed.inDays >= 1) {
    return 'Updated ${elapsed.inDays}d ago';
  }
  return 'Updated ${elapsed.inHours}h ago';
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
