import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show SelectableText;

import '../domain/connection_profile.dart';

class CertificateTrustDialog extends StatelessWidget {
  const CertificateTrustDialog({
    super.key,
    required this.profile,
    required this.fingerprint,
  });

  final ConnectionProfile profile;
  final String fingerprint;

  @override
  Widget build(BuildContext context) {
    final int port = profile.endpoint.hasPort ? profile.endpoint.port : 443;
    return CupertinoAlertDialog(
      title: const Text('Verify this server certificate'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '${profile.endpoint.host}:$port presented a certificate that your '
            'device does not trust.',
          ),
          const SizedBox(height: 16),
          const Text('SHA-256 fingerprint'),
          const SizedBox(height: 4),
          SelectableText(
            fingerprint,
            style: const TextStyle(fontFamily: 'monospace'),
          ),
          const SizedBox(height: 16),
          const Text(
            'Confirm this through a separate trusted channel before '
            'continuing. Trust is pinned only to this server host and '
            'port—not globally disabled.',
          ),
        ],
      ),
      actions: <Widget>[
        CupertinoDialogAction(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Trust & Connect'),
        ),
      ],
    );
  }
}
