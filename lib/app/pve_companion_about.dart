import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../core/presentation/pve_apple_ui.dart';
import 'pve_companion_metadata.dart';

Future<void> showPveCompanionAboutDialog(BuildContext context) {
  return showCupertinoDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) => CupertinoAlertDialog(
      title: Column(
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.asset(
              'assets/brand/pve_companion_mark.png',
              width: 56,
              height: 56,
              semanticLabel: 'PVE Companion logo',
            ),
          ),
          const SizedBox(height: 10),
          const Text(PveCompanionMetadata.name),
        ],
      ),
      content: Column(
        children: <Widget>[
          const SizedBox(height: 8),
          const Text(
            'Version ${PveCompanionMetadata.version} '
            '(${PveCompanionMetadata.buildNumber})',
          ),
          const SizedBox(height: 12),
          const Text(
            'An independent, open-source companion for Proxmox VE. Not '
            'affiliated with or endorsed by Proxmox Server Solutions GmbH.',
          ),
          const SizedBox(height: 12),
          Text(
            '© 2026 Knucklehead Code & Design LLC · Apache-2.0',
            style: PveAppleText.caption(dialogContext),
          ),
        ],
      ),
      actions: <Widget>[
        CupertinoDialogAction(
          onPressed: () async {
            await Clipboard.setData(
              const ClipboardData(text: PveCompanionMetadata.privacyPolicyUrl),
            );
            if (dialogContext.mounted) {
              Navigator.of(dialogContext).pop();
            }
          },
          child: const Text('Copy Privacy Link'),
        ),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Done'),
        ),
      ],
    ),
  );
}
