import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'pve_companion_metadata.dart';

void showPveCompanionAboutDialog(BuildContext context) {
  showAboutDialog(
    context: context,
    applicationName: PveCompanionMetadata.name,
    applicationVersion:
        '${PveCompanionMetadata.version} '
        '(${PveCompanionMetadata.buildNumber})',
    applicationIcon: ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.asset(
        'assets/brand/pve_companion_mark.png',
        width: 56,
        height: 56,
        semanticLabel: 'PVE Companion logo',
      ),
    ),
    applicationLegalese: '© 2026 Knucklehead Code Design LLC\nApache-2.0',
    children: <Widget>[
      const SizedBox(height: 16),
      const Text(
        'An independent, open-source companion for Proxmox VE. PVE Companion '
        'is not affiliated with or endorsed by Proxmox Server Solutions GmbH.',
      ),
      const SizedBox(height: 16),
      const Text(
        'Privacy policy',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 4),
      const SelectableText(PveCompanionMetadata.privacyPolicyUrl),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => Clipboard.setData(
            const ClipboardData(text: PveCompanionMetadata.privacyPolicyUrl),
          ),
          icon: const Icon(Icons.copy_outlined),
          label: const Text('Copy privacy policy URL'),
        ),
      ),
    ],
  );
}
