import 'package:flutter/cupertino.dart';

enum WorkspaceSection { overview, guests, nodes, storage, tasks }

extension WorkspaceSectionPresentation on WorkspaceSection {
  String get label => switch (this) {
    WorkspaceSection.overview => 'Overview',
    WorkspaceSection.guests => 'Guests',
    WorkspaceSection.nodes => 'Nodes',
    WorkspaceSection.storage => 'Storage',
    WorkspaceSection.tasks => 'Tasks',
  };

  IconData get icon => switch (this) {
    WorkspaceSection.overview => CupertinoIcons.square_grid_2x2,
    WorkspaceSection.guests => CupertinoIcons.cube_box,
    WorkspaceSection.nodes => CupertinoIcons.rectangle_stack,
    WorkspaceSection.storage => CupertinoIcons.tray_full,
    WorkspaceSection.tasks => CupertinoIcons.check_mark_circled,
  };

  IconData get selectedIcon => switch (this) {
    WorkspaceSection.overview => CupertinoIcons.square_grid_2x2_fill,
    WorkspaceSection.guests => CupertinoIcons.cube_box_fill,
    WorkspaceSection.nodes => CupertinoIcons.rectangle_stack_fill,
    WorkspaceSection.storage => CupertinoIcons.tray_full_fill,
    WorkspaceSection.tasks => CupertinoIcons.check_mark_circled_solid,
  };
}
