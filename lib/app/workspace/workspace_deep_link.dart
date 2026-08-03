import 'workspace_section.dart';

const String pveCompanionDeepLinkScheme = 'pvecompanion';

WorkspaceSection? workspaceSectionFromDeepLink(Uri uri) {
  if (uri.scheme.isNotEmpty && uri.scheme != pveCompanionDeepLinkScheme) {
    return null;
  }

  final destinations = <String>[
    if (uri.host.isNotEmpty) uri.host,
    ...uri.pathSegments,
  ];
  if (destinations.isEmpty) {
    return null;
  }
  return switch (destinations.last.toLowerCase()) {
    'datacenter' || 'overview' => WorkspaceSection.overview,
    'guests' => WorkspaceSection.guests,
    'nodes' => WorkspaceSection.nodes,
    'storage' => WorkspaceSection.storage,
    'tasks' => WorkspaceSection.tasks,
    _ => null,
  };
}
