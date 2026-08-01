import 'package:flutter/material.dart';

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
