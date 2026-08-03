import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../../../core/presentation/pve_haptics.dart';
import '../domain/pve_guest.dart';

Future<bool> confirmGuestPowerAction(
  BuildContext context, {
  required PveGuest guest,
  required GuestPowerAction action,
}) async {
  final approved = await showCupertinoDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      final caution = switch (action) {
        GuestPowerAction.start => 'Proxmox will start this guest normally.',
        GuestPowerAction.shutdown =>
          'Proxmox will request a graceful shutdown. Active users may be interrupted.',
        GuestPowerAction.reboot =>
          'Proxmox will restart this guest. Active users and workloads will be interrupted.',
        GuestPowerAction.stop =>
          'Force Stop immediately cuts power to this guest and can corrupt in-flight writes.',
        GuestPowerAction.reset =>
          'Reset immediately restarts this virtual machine and can corrupt in-flight writes.',
      };
      return CupertinoAlertDialog(
        title: Text('${action.label} ${guest.title}?'),
        content: Text(caution),
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
  if (approved != true) {
    return false;
  }
  if (action.isPotentiallyDisruptive) {
    unawaited(PveHaptics.warning());
    return true;
  }
  unawaited(PveHaptics.mediumImpact());
  return true;
}
