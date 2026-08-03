import 'package:flutter/cupertino.dart';

import '../../core/presentation/pve_apple_ui.dart';
import '../../core/presentation/pve_command_menu.dart';
import '../../features/connection_profiles/domain/connection_profile.dart';

class ServerMenu extends StatelessWidget {
  const ServerMenu({
    super.key,
    required this.profiles,
    required this.selectedProfile,
    required this.onSelected,
    this.compact = false,
  });

  final List<ConnectionProfile> profiles;
  final ConnectionProfile? selectedProfile;
  final ValueChanged<String> onSelected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return PveCommandMenuButton<String>(
      semanticLabel: 'Switch Proxmox server',
      menuWidth: 286,
      items: <PveCommandMenuItem<String>>[
        for (final profile in profiles)
          PveCommandMenuItem<String>(
            value: profile.id,
            label: profile.displayName,
            selected: profile.id == selectedProfile?.id,
          ),
      ],
      onSelected: onSelected,
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: 4, vertical: 6)
          : const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      minimumSize: const Size(44, 40),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              'assets/brand/pve_companion_mark.png',
              width: compact ? 28 : 32,
              height: compact ? 28 : 32,
              excludeFromSemantics: true,
            ),
          ),
          if (compact) ...<Widget>[
            const SizedBox(width: 4),
            Icon(
              CupertinoIcons.chevron_down,
              size: 10,
              color: PveAppleColors.secondaryLabel(context),
            ),
          ],
          if (!compact) ...<Widget>[
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    selectedProfile?.displayName ?? 'Choose a server',
                    overflow: TextOverflow.ellipsis,
                    style: PveAppleText.title3(context),
                  ),
                  if (selectedProfile != null)
                    Text(
                      selectedProfile!.endpoint.host,
                      overflow: TextOverflow.ellipsis,
                      style: PveAppleText.caption(context),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              CupertinoIcons.chevron_down,
              size: 14,
              color: PveAppleColors.secondaryLabel(context),
            ),
          ],
        ],
      ),
    );
  }
}
