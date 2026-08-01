import 'package:flutter/cupertino.dart';

import '../../../app/pve_companion_controller.dart';
import '../../../core/presentation/pve_apple_ui.dart';
import '../application/connection_profiles_controller.dart';
import '../domain/connection_profile.dart';
import 'connection_profile_form_sheet.dart';

Future<void> showConnectionProfilesSheet(
  BuildContext context, {
  required PveCompanionController controller,
}) {
  return showCupertinoSheet<void>(
    context: context,
    useNestedNavigation: true,
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
        middle: const Text('Servers'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: controller.connectionProfiles.isBusy
              ? null
              : () => _openAddServer(context),
          child: const Icon(CupertinoIcons.add),
        ),
      ),
      child: SafeArea(
        top: false,
        child: AnimatedBuilder(
          animation: controller,
          builder: (BuildContext context, Widget? child) {
            final List<ConnectionProfile> profiles =
                controller.connectionProfiles.profiles;
            final ConnectionProfile? selected =
                controller.connectionProfiles.selectedProfile;
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
              padding: const EdgeInsets.only(top: 14, bottom: 32),
              children: <Widget>[
                CupertinoListSection.insetGrouped(
                  header: const Text('SAVED SERVERS'),
                  footer: const Text(
                    'Tap a server to connect. Credentials are stored in Apple '
                    'Keychain only when you choose to remember them.',
                  ),
                  children: profiles
                      .map(
                        (ConnectionProfile profile) =>
                            _ConnectionProfileListItem(
                              profile: profile,
                              selected: selected?.id == profile.id,
                              disabled: controller.connectionProfiles.isBusy,
                              onConnect: () => _connect(context, profile),
                              onRemove: () => _remove(context, profile),
                            ),
                      )
                      .toList(growable: false),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _openAddServer(BuildContext context) async {
    final NavigatorState navigator = Navigator.of(context);
    navigator.pop();
    await showAddConnectionProfileSheet(
      navigator.context,
      controller: controller,
    );
  }

  Future<void> _connect(BuildContext context, ConnectionProfile profile) async {
    final ConnectionAttemptResult result = await controller.connectProfile(
      profile.id,
    );
    if (!context.mounted) {
      return;
    }
    if (result.kind == ConnectionAttemptKind.connected) {
      Navigator.of(context).pop();
      return;
    }
    final String message =
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
    final bool? approved = await showCupertinoDialog<bool>(
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
}

class _ConnectionProfileListItem extends StatelessWidget {
  const _ConnectionProfileListItem({
    required this.profile,
    required this.selected,
    required this.disabled,
    required this.onConnect,
    required this.onRemove,
  });

  final ConnectionProfile profile;
  final bool selected;
  final bool disabled;
  final VoidCallback onConnect;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return PveListRow(
      leading: Icon(
        profile.authenticationKind == ConnectionAuthenticationKind.apiToken
            ? CupertinoIcons.lock_shield_fill
            : CupertinoIcons.person_crop_circle_fill,
      ),
      title: Row(
        children: <Widget>[
          Expanded(child: Text(profile.displayName)),
          if (selected)
            Icon(
              CupertinoIcons.check_mark,
              size: 18,
              color: PveAppleColors.primary(context),
            ),
        ],
      ),
      subtitle: Text(profile.endpoint.toString()),
      onTap: disabled ? null : onConnect,
      trailing: CupertinoButton(
        padding: const EdgeInsets.all(6),
        minimumSize: const Size(36, 36),
        onPressed: disabled ? null : onRemove,
        child: Icon(
          CupertinoIcons.delete,
          size: 20,
          color: PveAppleColors.destructive(context),
        ),
      ),
    );
  }
}
