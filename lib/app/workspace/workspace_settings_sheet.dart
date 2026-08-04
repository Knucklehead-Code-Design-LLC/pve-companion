import 'package:flutter/cupertino.dart';

import '../../core/presentation/pve_apple_ui.dart';
import '../../core/presentation/pve_modal_sheet.dart';

/// Presents the workspace-level destinations in one predictable settings
/// surface instead of a transient command menu.
Future<void> showWorkspaceSettingsSheet(
  BuildContext context, {
  required bool connected,
  required VoidCallback onDisconnect,
  required VoidCallback onManageServers,
  required VoidCallback onAbout,
  VoidCallback? onViewFleet,
  VoidCallback? onManageNotifications,
  VoidCallback? onClusterAdministration,
  bool liveActivitiesAvailable = false,
  bool datacenterWatchActive = false,
  VoidCallback? onStartDatacenterWatch,
  VoidCallback? onEndDatacenterWatch,
}) {
  return showPveModalSheet<void>(
    context: context,
    scrollableBuilder:
        (BuildContext sheetContext, ScrollController scrollController) =>
            _WorkspaceSettingsSheet(
              connected: connected,
              scrollController: scrollController,
              onDisconnect: onDisconnect,
              onManageServers: onManageServers,
              onAbout: onAbout,
              onViewFleet: onViewFleet,
              onManageNotifications: onManageNotifications,
              onClusterAdministration: onClusterAdministration,
              liveActivitiesAvailable: liveActivitiesAvailable,
              datacenterWatchActive: datacenterWatchActive,
              onStartDatacenterWatch: onStartDatacenterWatch,
              onEndDatacenterWatch: onEndDatacenterWatch,
            ),
  );
}

class _WorkspaceSettingsSheet extends StatelessWidget {
  const _WorkspaceSettingsSheet({
    required this.connected,
    required this.scrollController,
    required this.onDisconnect,
    required this.onManageServers,
    required this.onAbout,
    required this.onViewFleet,
    required this.onManageNotifications,
    required this.onClusterAdministration,
    required this.liveActivitiesAvailable,
    required this.datacenterWatchActive,
    required this.onStartDatacenterWatch,
    required this.onEndDatacenterWatch,
  });

  final bool connected;
  final ScrollController scrollController;
  final VoidCallback onDisconnect;
  final VoidCallback onManageServers;
  final VoidCallback onAbout;
  final VoidCallback? onViewFleet;
  final VoidCallback? onManageNotifications;
  final VoidCallback? onClusterAdministration;
  final bool liveActivitiesAvailable;
  final bool datacenterWatchActive;
  final VoidCallback? onStartDatacenterWatch;
  final VoidCallback? onEndDatacenterWatch;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: PveAppleColors.page(context),
      navigationBar: CupertinoNavigationBar(
        automaticallyImplyLeading: false,
        middle: const Text(PveActionLabels.workspaceSettings),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: <Widget>[
                Text('Workspace', style: PveAppleText.title2(context)),
                const SizedBox(height: 6),
                Text(
                  'Connections, alerts, and datacenter tools.',
                  style: PveAppleText.secondary(context),
                ),
                const SizedBox(height: 18),
                _SettingsGroup(
                  children: <Widget>[
                    _SettingsRow(
                      icon: CupertinoIcons.rectangle_stack_badge_plus,
                      title: 'Manage Servers',
                      subtitle: 'Saved Proxmox connections',
                      onTap: () => _openDestination(context, onManageServers),
                    ),
                    if (onManageNotifications != null) ...<Widget>[
                      const PveRowSeparator(),
                      _SettingsRow(
                        icon: CupertinoIcons.bell,
                        title: 'Notifications',
                        subtitle: 'Alert preferences',
                        onTap: () =>
                            _openDestination(context, onManageNotifications!),
                      ),
                    ],
                    if (onViewFleet != null) ...<Widget>[
                      const PveRowSeparator(),
                      _SettingsRow(
                        icon: CupertinoIcons.rectangle_stack_badge_person_crop,
                        title: 'Datacenter Portfolio',
                        subtitle: 'Saved server overview',
                        onTap: () => _openDestination(context, onViewFleet!),
                      ),
                    ],
                    if (connected &&
                        onClusterAdministration != null) ...<Widget>[
                      const PveRowSeparator(),
                      _SettingsRow(
                        icon: CupertinoIcons.shield_lefthalf_fill,
                        title: 'Cluster Administration',
                        subtitle: 'Quorum, HA, and safe options',
                        onTap: () =>
                            _openDestination(context, onClusterAdministration!),
                      ),
                    ],
                    if (connected &&
                        liveActivitiesAvailable &&
                        (onStartDatacenterWatch != null ||
                            onEndDatacenterWatch != null)) ...<Widget>[
                      const PveRowSeparator(),
                      _SettingsRow(
                        icon: datacenterWatchActive
                            ? CupertinoIcons.stop_circle
                            : CupertinoIcons.waveform_path_ecg,
                        title: datacenterWatchActive
                            ? 'End Datacenter Watch'
                            : 'Start Datacenter Watch',
                        subtitle: datacenterWatchActive
                            ? 'Stop the active Live Activity'
                            : 'Show current datacenter health',
                        onTap: datacenterWatchActive
                            ? () => _openDestination(
                                context,
                                onEndDatacenterWatch!,
                              )
                            : () => _openDestination(
                                context,
                                onStartDatacenterWatch!,
                              ),
                      ),
                    ],
                    const PveRowSeparator(),
                    _SettingsRow(
                      icon: CupertinoIcons.info_circle,
                      title: 'About PVE Companion',
                      onTap: () => _openDestination(context, onAbout),
                    ),
                  ],
                ),
                if (connected) ...<Widget>[
                  const SizedBox(height: 24),
                  const PveSectionTitle(title: 'Server'),
                  const SizedBox(height: 8),
                  _SettingsGroup(
                    children: <Widget>[
                      _SettingsRow(
                        icon: CupertinoIcons.arrow_right_square,
                        title: 'Disconnect Server',
                        subtitle: 'Keep the saved connection on this device',
                        destructive: true,
                        onTap: () => _openDestination(context, onDisconnect),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openDestination(BuildContext context, VoidCallback action) {
    Navigator.of(context).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) => action());
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => PveInsetGroup(
    padding: EdgeInsets.zero,
    child: Column(children: children),
  );
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive
        ? PveAppleColors.destructive(context)
        : PveAppleColors.primary(context);
    return PveListRow(
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: destructive
            ? PveAppleText.body(context).copyWith(color: color)
            : null,
      ),
      subtitle: subtitle == null ? null : Text(subtitle!),
      onTap: onTap,
    );
  }
}
