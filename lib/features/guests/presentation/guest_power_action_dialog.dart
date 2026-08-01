import 'package:flutter/cupertino.dart';

import '../domain/pve_guest.dart';

Future<bool> confirmGuestPowerAction(
  BuildContext context, {
  required PveGuest guest,
  required GuestPowerAction action,
}) async {
  final bool? approved = await showCupertinoDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      final String caution = action.isPotentiallyDisruptive
          ? 'This can interrupt workloads and active users.'
          : 'Proxmox will start this guest normally.';
      return CupertinoAlertDialog(
        title: Text('${action.label} ${guest.title}?'),
        content: Text('$caution PVE Companion never sends a force action.'),
        actions: <Widget>[
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDefaultAction: !action.isPotentiallyDisruptive,
            isDestructiveAction: action.isPotentiallyDisruptive,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(action.label),
          ),
        ],
      );
    },
  );
  return approved == true;
}
