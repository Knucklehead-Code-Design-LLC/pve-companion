import 'package:flutter/cupertino.dart';

import '../../core/presentation/pve_apple_ui.dart';
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
    final isConnecting = status == ConnectionStatus.connecting;
    final title = profile == null
        ? 'Choose a server'
        : 'Connect to ${profile!.displayName}';
    final message = profile == null
        ? 'Add a Proxmox VE server to open its datacenter.'
        : 'PVE Companion connects only when you ask and keeps the last '
              'reported view on this device.';
    return ListView(
      padding: const EdgeInsets.all(24),
      children: <Widget>[
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.only(top: 56),
              child: Column(
                children: <Widget>[
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: PveAppleColors.primary(
                        context,
                      ).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      CupertinoIcons.link,
                      size: 36,
                      color: PveAppleColors.primary(context),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: PveAppleText.title1(context),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: PveAppleText.secondary(context),
                  ),
                  if (errorMessage != null) ...<Widget>[
                    const SizedBox(height: 16),
                    PveInsetGroup(
                      color: PveAppleColors.destructive(
                        context,
                      ).withValues(alpha: 0.1),
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Icon(
                            CupertinoIcons.exclamationmark_triangle_fill,
                            size: 20,
                            color: PveAppleColors.destructive(context),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              errorMessage!,
                              style: PveAppleText.secondary(context).copyWith(
                                color: PveAppleColors.destructive(context),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: CupertinoButton.filled(
                      onPressed: profile == null || isConnecting
                          ? null
                          : onConnect,
                      child: isConnecting
                          ? const CupertinoActivityIndicator(
                              color: CupertinoColors.white,
                            )
                          : const Text('Connect'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  CupertinoButton(
                    onPressed: onAddServer,
                    child: const Text('Add Another Server'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
