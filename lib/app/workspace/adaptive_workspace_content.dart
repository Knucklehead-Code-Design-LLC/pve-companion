import 'package:flutter/cupertino.dart';

import '../../core/presentation/pve_apple_ui.dart';
import 'workspace_section.dart';

class AdaptiveWorkspaceContent extends StatelessWidget {
  const AdaptiveWorkspaceContent({
    super.key,
    required this.section,
    required this.onSectionChanged,
    required this.pages,
  });

  final WorkspaceSection section;
  final ValueChanged<WorkspaceSection> onSectionChanged;
  final List<Widget> pages;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int selectedIndex = section.index;
        if (constraints.maxWidth >= 760) {
          return Row(
            children: <Widget>[
              _WorkspaceSidebar(
                section: section,
                onSectionChanged: onSectionChanged,
              ),
              Container(
                width: 0.5,
                color: PveAppleColors.separator(
                  context,
                ).withValues(alpha: 0.55),
              ),
              Expanded(
                child: IndexedStack(index: selectedIndex, children: pages),
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
                activeColor: PveAppleColors.primary(context),
                inactiveColor: PveAppleColors.secondaryLabel(context),
                backgroundColor: PveAppleColors.surface(
                  context,
                ).withValues(alpha: 0.94),
                border: Border(
                  top: BorderSide(
                    color: PveAppleColors.separator(
                      context,
                    ).withValues(alpha: 0.45),
                    width: 0.5,
                  ),
                ),
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
  });

  final WorkspaceSection section;
  final ValueChanged<WorkspaceSection> onSectionChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      color: PveAppleColors.surface(context).withValues(alpha: 0.68),
      padding: const EdgeInsets.fromLTRB(12, 18, 12, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
            child: Text(
              'DATACENTER',
              style: PveAppleText.caption(context).copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ),
          for (final WorkspaceSection item in WorkspaceSection.values)
            _SidebarDestination(
              item: item,
              selected: item == section,
              onTap: () => onSectionChanged(item),
            ),
        ],
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
    return Semantics(
      selected: selected,
      button: true,
      label: item.label,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          minimumSize: const Size(44, 42),
          borderRadius: BorderRadius.circular(8),
          color: selected ? accent.withValues(alpha: 0.14) : null,
          pressedOpacity: 0.62,
          onPressed: onTap,
          child: Row(
            children: <Widget>[
              Icon(
                selected ? item.selectedIcon : item.icon,
                size: 20,
                color: selected ? accent : PveAppleColors.label(context),
              ),
              const SizedBox(width: 10),
              Text(
                item.label,
                style: PveAppleText.body(context).copyWith(
                  color: PveAppleColors.label(context),
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
