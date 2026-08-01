import 'package:flutter/cupertino.dart';

import '../../core/presentation/pve_apple_ui.dart';
import '../../features/connection_profiles/domain/connection_profile.dart';

class ServerMenu extends StatelessWidget {
  const ServerMenu({
    super.key,
    required this.profiles,
    required this.selectedProfile,
    required this.onSelected,
  });

  final List<ConnectionProfile> profiles;
  final ConnectionProfile? selectedProfile;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      minimumSize: const Size(44, 40),
      onPressed: () => _showServerPicker(context),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              'assets/brand/pve_companion_mark.png',
              width: 32,
              height: 32,
              excludeFromSemantics: true,
            ),
          ),
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
      ),
    );
  }

  Future<void> _showServerPicker(BuildContext context) async {
    final String? profileId = await showCupertinoModalPopup<String>(
      context: context,
      builder: (BuildContext popupContext) {
        return CupertinoActionSheet(
          title: const Text('Connect to a server'),
          message: const Text('Choose a saved Proxmox VE server.'),
          actions: profiles
              .map(
                (ConnectionProfile profile) => CupertinoActionSheetAction(
                  isDefaultAction: profile.id == selectedProfile?.id,
                  onPressed: () => Navigator.of(popupContext).pop(profile.id),
                  child: Column(
                    children: <Widget>[
                      Text(profile.displayName),
                      Text(
                        profile.endpoint.host,
                        style: PveAppleText.caption(popupContext),
                      ),
                    ],
                  ),
                ),
              )
              .toList(growable: false),
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.of(popupContext).pop(),
            child: const Text('Cancel'),
          ),
        );
      },
    );
    if (profileId != null) {
      onSelected(profileId);
    }
  }
}
