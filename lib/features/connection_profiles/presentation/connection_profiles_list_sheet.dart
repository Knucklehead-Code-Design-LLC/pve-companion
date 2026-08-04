import 'package:flutter/cupertino.dart';

import '../../../app/pve_companion_controller.dart';
import '../../../core/presentation/pve_apple_ui.dart';
import '../../../core/presentation/pve_modal_sheet.dart';
import '../application/connection_profiles_controller.dart';
import '../domain/connection_profile.dart';
import 'connection_profile_form_sheet.dart';

Future<void> showConnectionProfilesSheet(
  BuildContext context, {
  required PveCompanionController controller,
}) {
  return showPveModalSheet<void>(
    context: context,
    scrollableBuilder:
        (BuildContext sheetContext, ScrollController scrollController) {
          return ConnectionProfilesListSheet(
            controller: controller,
            scrollController: scrollController,
          );
        },
  );
}

class ConnectionProfilesListSheet extends StatelessWidget {
  const ConnectionProfilesListSheet({
    super.key,
    required this.controller,
    required this.scrollController,
  });

  final PveCompanionController controller;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: PveAppleColors.page(context),
      navigationBar: CupertinoNavigationBar(
        automaticallyImplyLeading: false,
        middle: const Text('Servers'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ),
      child: SafeArea(
        top: false,
        child: AnimatedBuilder(
          animation: controller,
          builder: (BuildContext context, Widget? child) {
            final profiles = controller.connectionProfiles.profiles;
            final selected = controller.connectionProfiles.selectedProfile;
            final profilesController = controller.connectionProfiles;
            if (profiles.isEmpty) {
              return PveEmptyState(
                icon: CupertinoIcons.rectangle_stack_badge_plus,
                title: 'No saved servers',
                message:
                    'Add a Proxmox VE server to see your datacenter from this device.',
                actionLabel: 'Add Server',
                onAction: () => _openAddServer(context),
              );
            }
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: <Widget>[
                PveInsetGroup(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: <Widget>[
                      PveListRow(
                        leading: const Icon(
                          CupertinoIcons.add_circled_solid,
                          size: 20,
                        ),
                        title: const Text('Add Server'),
                        subtitle: const Text('New Proxmox connection'),
                        onTap: controller.connectionProfiles.isBusy
                            ? null
                            : () => _openAddServer(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const PveSectionTitle(title: 'Saved Servers'),
                const SizedBox(height: 8),
                PveInsetGroup(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: <Widget>[
                      for (
                        int index = 0;
                        index < profiles.length;
                        index++
                      ) ...<Widget>[
                        _ConnectionProfileListItem(
                          profile: profiles[index],
                          selected: selected?.id == profiles[index].id,
                          status: profilesController.statusForProfile(
                            profiles[index],
                          ),
                          failureMessage: profilesController
                              .failureMessageForProfile(profiles[index]),
                          disabled: profilesController.isBusy,
                          onConnect: () => _connect(context, profiles[index]),
                          onManage: () =>
                              _showProfileActions(context, profiles[index]),
                        ),
                        if (index < profiles.length - 1)
                          const PveRowSeparator(),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap a server to connect. Saved credentials stay in Apple '
                  'Keychain only when you chose to remember them.',
                  style: PveAppleText.caption(context),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _openAddServer(BuildContext context) async {
    final navigator = Navigator.of(context);
    navigator.pop();
    await showAddConnectionProfileSheet(
      navigator.context,
      controller: controller,
    );
  }

  Future<void> _connect(BuildContext context, ConnectionProfile profile) async {
    final result = await controller.connectProfile(profile.id);
    if (!context.mounted) {
      return;
    }
    if (result.kind == ConnectionAttemptKind.connected) {
      Navigator.of(context).pop();
      return;
    }
    final message =
        result.kind == ConnectionAttemptKind.certificateTrustRequired
        ? 'The server certificate changed. Remove and add this server again '
              'after verifying its new fingerprint.'
        : result.message ?? 'The connection could not be completed.';
    await showCupertinoDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => CupertinoAlertDialog(
        title: const Text('Couldn’t Connect'),
        content: Text(message),
        actions: <Widget>[
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _remove(BuildContext context, ConnectionProfile profile) async {
    final approved = await showCupertinoDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return CupertinoAlertDialog(
          title: Text('Remove ${profile.displayName}?'),
          content: const Text(
            'This removes the server and its saved Keychain credential from '
            'this device. Nothing changes on Proxmox.',
          ),
          actions: <Widget>[
            CupertinoDialogAction(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );
    if (approved == true) {
      await controller.removeProfile(profile.id);
    }
  }

  Future<void> _showProfileActions(
    BuildContext context,
    ConnectionProfile profile,
  ) async {
    final action = await showCupertinoModalPopup<_SavedServerAction>(
      context: context,
      builder: (BuildContext popupContext) => CupertinoActionSheet(
        title: Text(profile.displayName),
        message: Text(_profileEndpointLabel(profile)),
        actions: <Widget>[
          CupertinoActionSheetAction(
            onPressed: () =>
                Navigator.of(popupContext).pop(_SavedServerAction.connect),
            child: const Text('Connect'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () =>
                Navigator.of(popupContext).pop(_SavedServerAction.remove),
            child: const Text('Remove Server'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(popupContext).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
    if (!context.mounted || action == null) {
      return;
    }
    switch (action) {
      case _SavedServerAction.connect:
        await _connect(context, profile);
      case _SavedServerAction.remove:
        await _remove(context, profile);
    }
  }
}

enum _SavedServerAction { connect, remove }

class _ConnectionProfileListItem extends StatelessWidget {
  const _ConnectionProfileListItem({
    required this.profile,
    required this.selected,
    required this.status,
    required this.failureMessage,
    required this.disabled,
    required this.onConnect,
    required this.onManage,
  });

  final ConnectionProfile profile;
  final bool selected;
  final ConnectionStatus status;
  final String? failureMessage;
  final bool disabled;
  final VoidCallback onConnect;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final statusLabel = _connectionStatusLabel(status);
    return Semantics(
      label: selected
          ? '${profile.displayName}, active server, $statusLabel'
          : '${profile.displayName}, $statusLabel',
      child: CupertinoListTile(
        leading: Icon(
          CupertinoIcons.rectangle_stack,
          color: _connectionStatusColor(context, status),
        ),
        title: Text(profile.displayName),
        subtitle: _ConnectionProfileSubtitle(
          profile: profile,
          status: status,
          failureMessage: failureMessage,
        ),
        onTap: disabled ? null : onConnect,
        trailing: Semantics(
          button: true,
          label: 'Actions for ${profile.displayName}',
          child: PveIconAction(
            icon: CupertinoIcons.ellipsis_circle,
            label: 'Actions for ${profile.displayName}',
            onPressed: disabled ? null : onManage,
          ),
        ),
      ),
    );
  }
}

class _ConnectionProfileSubtitle extends StatelessWidget {
  const _ConnectionProfileSubtitle({
    required this.profile,
    required this.status,
    required this.failureMessage,
  });

  final ConnectionProfile profile;
  final ConnectionStatus status;
  final String? failureMessage;

  @override
  Widget build(BuildContext context) {
    final statusDetail = switch (status) {
      ConnectionStatus.connected => 'Connected',
      ConnectionStatus.connecting => 'Connecting…',
      ConnectionStatus.failed => failureMessage ?? 'Last connection failed',
      ConnectionStatus.disconnected => 'Not connected',
    };
    return Text(
      '${_profileEndpointLabel(profile)} · $statusDetail',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

String _profileEndpointLabel(ConnectionProfile profile) {
  final endpoint = profile.endpoint;
  final port = endpoint.hasPort ? ':${endpoint.port}' : '';
  return '${endpoint.host}$port';
}

String _connectionStatusLabel(ConnectionStatus status) => switch (status) {
  ConnectionStatus.connected => 'Connected',
  ConnectionStatus.connecting => 'Connecting',
  ConnectionStatus.failed => 'Needs attention',
  ConnectionStatus.disconnected => 'Offline',
};

Color _connectionStatusColor(BuildContext context, ConnectionStatus status) =>
    switch (status) {
      ConnectionStatus.connected => PveAppleColors.success(context),
      ConnectionStatus.connecting => PveAppleColors.primary(context),
      ConnectionStatus.failed => PveAppleColors.destructive(context),
      ConnectionStatus.disconnected => PveAppleColors.secondaryLabel(context),
    };
