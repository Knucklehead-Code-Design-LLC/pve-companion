import 'package:flutter/material.dart';

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
    WorkspaceSection.overview => Icons.grid_view_outlined,
    WorkspaceSection.guests => Icons.memory_outlined,
    WorkspaceSection.nodes => Icons.dns_outlined,
    WorkspaceSection.storage => Icons.storage_outlined,
    WorkspaceSection.tasks => Icons.task_outlined,
  };
}
