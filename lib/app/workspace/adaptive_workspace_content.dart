import 'package:flutter/material.dart';

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
    final List<NavigationDestination> destinations = WorkspaceSection.values
        .map(
          (WorkspaceSection item) =>
              NavigationDestination(icon: Icon(item.icon), label: item.label),
        )
        .toList(growable: false);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int selectedIndex = section.index;
        if (constraints.maxWidth >= 760) {
          return Row(
            children: <Widget>[
              NavigationRail(
                selectedIndex: selectedIndex,
                onDestinationSelected: _selectIndex,
                labelType: NavigationRailLabelType.all,
                destinations: destinations
                    .map(
                      (NavigationDestination item) => NavigationRailDestination(
                        icon: item.icon,
                        label: Text(item.label),
                      ),
                    )
                    .toList(growable: false),
              ),
              const VerticalDivider(width: 1),
              Expanded(child: pages[selectedIndex]),
            ],
          );
        }
        return Column(
          children: <Widget>[
            Expanded(child: pages[selectedIndex]),
            NavigationBar(
              selectedIndex: selectedIndex,
              onDestinationSelected: _selectIndex,
              destinations: destinations,
            ),
          ],
        );
      },
    );
  }

  void _selectIndex(int index) =>
      onSectionChanged(WorkspaceSection.values[index]);
}
