import 'package:flutter/material.dart';

import '../../features/connection_profiles/application/connection_profiles_controller.dart';
import '../../features/connection_profiles/domain/connection_profile.dart';

class DisconnectedWorkspace extends StatelessWidget {
  const DisconnectedWorkspace({
    super.key,
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
