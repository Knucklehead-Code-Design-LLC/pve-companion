import 'package:flutter/material.dart';

import '../../../app/pve_companion_controller.dart';
import '../application/connection_profiles_controller.dart';
import '../domain/connection_profile.dart';
import 'connection_profile_form_sheet.dart';

Future<void> showConnectionProfilesSheet(
  BuildContext context, {
  required PveCompanionController controller,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (BuildContext sheetContext) {
      return ConnectionProfilesListSheet(controller: controller);
    },
  );
}

class ConnectionProfilesListSheet extends StatelessWidget {
  const ConnectionProfilesListSheet({super.key, required this.controller});

  final PveCompanionController controller;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: AnimatedBuilder(
        animation: controller,
        builder: (BuildContext context, Widget? child) {
          final List<ConnectionProfile> profiles =
              controller.connectionProfiles.profiles;
          final ConnectionProfile? selected =
              controller.connectionProfiles.selectedProfile;
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const _SheetGrabber(),
                  const SizedBox(height: 20),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          'Servers',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: controller.connectionProfiles.isBusy
                            ? null
                            : () => _openAddServer(context),
                        icon: const Icon(Icons.add),
                        label: const Text('Add'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: profiles.isEmpty
                        ? const Center(child: Text('No saved servers yet.'))
                        : ListView.separated(
                            itemCount: profiles.length,
                            separatorBuilder:
                                (BuildContext context, int index) =>
                                    const Divider(height: 1),
                            itemBuilder: (BuildContext context, int index) {
                              final ConnectionProfile profile = profiles[index];
                              return _ConnectionProfileListItem(
                                profile: profile,
                                selected: selected?.id == profile.id,
                                disabled: controller.connectionProfiles.isBusy,
                                onConnect: () => _connect(context, profile),
                                onRemove: () => _remove(context, profile),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
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
        ? 'The server certificate changed. Remove and re-add this profile after '
              'verifying its new fingerprint.'
        : result.message ?? 'Connection was not completed.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _remove(BuildContext context, ConnectionProfile profile) async {
    final bool? approved = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Remove ${profile.displayName}?'),
          content: const Text(
            'This removes the saved server profile and its locally stored '
            'Keychain credential from this device.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
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

class _SheetGrabber extends StatelessWidget {
  const _SheetGrabber();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.outlineVariant,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
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
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      leading: Icon(
        profile.authenticationKind == ConnectionAuthenticationKind.password
            ? Icons.key_outlined
            : Icons.vpn_key_outlined,
      ),
      title: Text(profile.displayName),
      subtitle: Text(profile.endpoint.toString()),
      selected: selected,
      onTap: disabled ? null : onConnect,
      trailing: PopupMenuButton<String>(
        onSelected: (String action) {
          if (action == 'remove') {
            onRemove();
          }
        },
        itemBuilder: (BuildContext context) => const <PopupMenuEntry<String>>[
          PopupMenuItem<String>(value: 'remove', child: Text('Remove server')),
        ],
      ),
    );
  }
}
