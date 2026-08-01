import 'package:flutter/material.dart';

import '../../../app/pve_companion_controller.dart';
import 'connection_profile_form_sheet.dart';

export 'connection_profile_form_sheet.dart' show showAddConnectionProfileSheet;
export 'connection_profiles_list_sheet.dart' show showConnectionProfilesSheet;

class ConnectionProfilesWelcomeScreen extends StatelessWidget {
  const ConnectionProfilesWelcomeScreen({
    super.key,
    required this.controller,
    required this.onAbout,
  });

  final PveCompanionController controller;
  final VoidCallback onAbout;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PVE Companion'),
        actions: <Widget>[
          IconButton(
            onPressed: onAbout,
            tooltip: 'About and privacy',
            icon: const Icon(Icons.info_outline),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.asset(
                        'assets/brand/pve_companion_mark.png',
                        width: 64,
                        height: 64,
                        semanticLabel: 'PVE Companion logo',
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Connect a Proxmox VE server',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'PVE Companion keeps server metadata on this device and, '
                      'if you choose, stores credentials only in Apple Keychain. '
                      'Connect over HTTPS or a trusted VPN—never expose the '
                      'Proxmox management port publicly.',
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () => showAddConnectionProfileSheet(
                        context,
                        controller: controller,
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text('Add a server'),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Supports password sessions and API tokens. Password '
                      'sessions use an in-memory ticket after sign-in.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
