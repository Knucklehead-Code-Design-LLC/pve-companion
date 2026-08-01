import 'package:flutter/material.dart';

import '../domain/pve_guest.dart';

Future<bool> confirmGuestPowerAction(
  BuildContext context, {
  required PveGuest guest,
  required GuestPowerAction action,
}) async {
  final bool? approved = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      final String caution = action.isPotentiallyDisruptive
          ? 'This can interrupt workloads and active users.'
          : 'The guest will be started through the Proxmox API.';
      return AlertDialog(
        title: Text('${action.label} ${guest.title}?'),
        content: Text('$caution No force action will be sent.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(action.label),
          ),
        ],
      );
    },
  );
  return approved == true;
}
