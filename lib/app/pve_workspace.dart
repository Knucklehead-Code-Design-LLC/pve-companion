import 'package:flutter/material.dart';

import '../core/api/proxmox_session.dart';
import '../features/cluster_overview/presentation/cluster_nodes_page.dart';
import '../features/cluster_overview/presentation/cluster_overview_page.dart';
import '../features/connection_profiles/application/connection_profiles_controller.dart';
import '../features/connection_profiles/domain/connection_profile.dart';
import '../features/connection_profiles/presentation/connection_profiles_screen.dart';
import '../features/guests/presentation/guest_list_page.dart';
import '../features/storage/presentation/storage_page.dart';
import '../features/tasks/presentation/tasks_page.dart';
import 'pve_companion_controller.dart';

enum _WorkspaceSection { overview, guests, nodes, storage, tasks }

class PveWorkspace extends StatefulWidget {
  const PveWorkspace({super.key, required this.controller});

  final PveCompanionController controller;

  @override
  State<PveWorkspace> createState() => _PveWorkspaceState();
}

class _PveWorkspaceState extends State<PveWorkspace> {
  _WorkspaceSection _section = _WorkspaceSection.overview;

  @override
  Widget build(BuildContext context) {
    final ConnectionProfilesController profiles =
        widget.controller.connectionProfiles;
    final ConnectionProfile? selectedProfile = profiles.selectedProfile;
    final ProxmoxSession? session = profiles.activeSession;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: _ServerMenu(
          profiles: profiles.profiles,
          selectedProfile: selectedProfile,
          onSelected: _connectToProfile,
        ),
        actions: <Widget>[
          if (session != null)
            IconButton(
              tooltip: 'Refresh cluster',
              onPressed: widget.controller.refreshCluster,
              icon: const Icon(Icons.refresh),
            ),
          if (session != null)
            IconButton(
              tooltip: 'Disconnect',
              onPressed: widget.controller.disconnect,
              icon: const Icon(Icons.link_off_outlined),
            ),
          IconButton(
            tooltip: 'Manage servers',
            onPressed: () => showConnectionProfilesSheet(
              context,
              controller: widget.controller,
            ),
            icon: const Icon(Icons.dns_outlined),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: session == null
          ? _DisconnectedWorkspace(
              profile: selectedProfile,
              status: profiles.connectionStatus,
              errorMessage: profiles.errorMessage,
              onConnect: _connectSelectedProfile,
              onAddServer: () => showAddConnectionProfileSheet(
                context,
                controller: widget.controller,
              ),
            )
          : _AdaptiveWorkspaceContent(
              section: _section,
              onSectionChanged: (int index) {
                setState(() => _section = _WorkspaceSection.values[index]);
              },
              pages: _buildPages(session),
            ),
    );
  }

  List<Widget> _buildPages(ProxmoxSession session) {
    return <Widget>[
      ClusterOverviewPage(
        controller: widget.controller.clusterOverview,
        onRefresh: widget.controller.refreshCluster,
      ),
      GuestListPage(
        overviewController: widget.controller.clusterOverview,
        session: session,
        onGuestPowerAction: widget.controller.refreshCluster,
      ),
      ClusterNodesPage(controller: widget.controller.clusterOverview),
      StoragePage(controller: widget.controller.clusterOverview),
      TasksPage(controller: widget.controller.clusterOverview),
    ];
  }

  Future<void> _connectToProfile(String profileId) async {
    final ConnectionAttemptResult result = await widget.controller
        .connectProfile(profileId);
    if (!mounted || result.kind == ConnectionAttemptKind.connected) {
      return;
    }
    final String message =
        result.kind == ConnectionAttemptKind.certificateTrustRequired
        ? 'The server certificate changed. Remove and add this server again '
              'after verifying its new fingerprint.'
        : result.message ?? 'Connection was not completed.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _connectSelectedProfile() async {
    final ConnectionAttemptResult result = await widget.controller
        .connectSelectedProfile();
    if (!mounted || result.kind == ConnectionAttemptKind.connected) {
      return;
    }
    final String message =
        result.kind == ConnectionAttemptKind.certificateTrustRequired
        ? 'The server certificate changed. Remove and add this server again '
              'after verifying its new fingerprint.'
        : result.message ?? 'Connection was not completed.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ServerMenu extends StatelessWidget {
  const _ServerMenu({
    required this.profiles,
    required this.selectedProfile,
    required this.onSelected,
  });

  final List<ConnectionProfile> profiles;
  final ConnectionProfile? selectedProfile;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Choose server',
      initialValue: selectedProfile?.id,
      onSelected: onSelected,
      itemBuilder: (BuildContext context) => profiles
          .map(
            (ConnectionProfile profile) => PopupMenuItem<String>(
              value: profile.id,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(profile.displayName),
                  Text(
                    profile.endpoint.host,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          )
          .toList(growable: false),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.hub_outlined),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              selectedProfile?.displayName ?? 'Choose server',
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const Icon(Icons.arrow_drop_down),
        ],
      ),
    );
  }
}

class _AdaptiveWorkspaceContent extends StatelessWidget {
  const _AdaptiveWorkspaceContent({
    required this.section,
    required this.onSectionChanged,
    required this.pages,
  });

  final _WorkspaceSection section;
  final ValueChanged<int> onSectionChanged;
  final List<Widget> pages;

  @override
  Widget build(BuildContext context) {
    final List<NavigationDestination> destinations = <NavigationDestination>[
      const NavigationDestination(
        icon: Icon(Icons.grid_view_outlined),
        label: 'Overview',
      ),
      const NavigationDestination(
        icon: Icon(Icons.memory_outlined),
        label: 'Guests',
      ),
      const NavigationDestination(
        icon: Icon(Icons.dns_outlined),
        label: 'Nodes',
      ),
      const NavigationDestination(
        icon: Icon(Icons.storage_outlined),
        label: 'Storage',
      ),
      const NavigationDestination(
        icon: Icon(Icons.task_outlined),
        label: 'Tasks',
      ),
    ];
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int selectedIndex = section.index;
        if (constraints.maxWidth >= 760) {
          return Row(
            children: <Widget>[
              NavigationRail(
                selectedIndex: selectedIndex,
                onDestinationSelected: onSectionChanged,
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
              onDestinationSelected: onSectionChanged,
              destinations: destinations,
            ),
          ],
        );
      },
    );
  }
}

class _DisconnectedWorkspace extends StatelessWidget {
  const _DisconnectedWorkspace({
    required this.profile,
    required this.status,
    required this.errorMessage,
    required this.onConnect,
    required this.onAddServer,
  });

  final ConnectionProfile? profile;
  final ConnectionStatus status;
  final String? errorMessage;
  final Future<void> Function() onConnect;
  final VoidCallback onAddServer;

  @override
  Widget build(BuildContext context) {
    final bool isConnecting = status == ConnectionStatus.connecting;
    final String connectionMessage = profile == null
        ? 'Choose or add a server to begin.'
        : 'Connect to ${profile!.displayName} to view its cluster.';
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    Icons.link_off_outlined,
                    size: 38,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Not connected',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(connectionMessage),
                  if (errorMessage != null) ...<Widget>[
                    const SizedBox(height: 12),
                    Text(
                      errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: profile == null || isConnecting
                        ? null
                        : () => onConnect(),
                    icon: isConnecting
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.link_outlined),
                    label: Text(isConnecting ? 'Connecting…' : 'Connect'),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: onAddServer,
                    icon: const Icon(Icons.add),
                    label: const Text('Add another server'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
