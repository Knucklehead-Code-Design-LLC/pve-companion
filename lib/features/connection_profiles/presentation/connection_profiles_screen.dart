import 'package:flutter/cupertino.dart';

import '../../../app/pve_companion_controller.dart';
import '../../../core/presentation/pve_apple_ui.dart';
import 'connection_profile_form_sheet.dart';

export 'connection_profile_form_sheet.dart' show showAddConnectionProfileSheet;
export 'connection_profiles_list_sheet.dart' show showConnectionProfilesSheet;

class ConnectionProfilesWelcomeScreen extends StatelessWidget {
  const ConnectionProfilesWelcomeScreen({
    super.key,
    required this.controller,
    required this.onAbout,
  });

  final PveCompanionController controller;
  final VoidCallback onAbout;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: PveAppleColors.page(context),
      navigationBar: CupertinoNavigationBar(
        middle: const Text('PVE Companion'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: onAbout,
          child: const Icon(CupertinoIcons.info_circle),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                children: <Widget>[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Image.asset(
                      'assets/brand/pve_companion_mark.png',
                      width: 88,
                      height: 88,
                      semanticLabel: 'PVE Companion logo',
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Your datacenter, at a glance',
                    textAlign: TextAlign.center,
                    style: PveAppleText.largeTitle(context),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Connect securely to Proxmox VE and understand health, '
                    'capacity, guests, storage, and recent work without sorting '
                    'through the full web console.',
                    textAlign: TextAlign.center,
                    style: PveAppleText.body(context).copyWith(
                      color: PveAppleColors.secondaryLabel(context),
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: 28),
                  PveInsetGroup(
                    child: Column(
                      children: const <Widget>[
                        _WelcomeFeature(
                          icon: CupertinoIcons.heart_fill,
                          title: 'See what needs attention',
                          message: 'Health and pressure are summarized first.',
                        ),
                        PveRowSeparator(),
                        _WelcomeFeature(
                          icon: CupertinoIcons.lock_shield_fill,
                          title: 'Keep access private',
                          message:
                              'HTTPS is required and saved secrets use Apple Keychain.',
                        ),
                        PveRowSeparator(),
                        _WelcomeFeature(
                          icon: CupertinoIcons.device_phone_portrait,
                          title: 'Built for Apple devices',
                          message:
                              'One clear experience on iPhone, iPad, and Mac.',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: CupertinoButton.filled(
                      onPressed: () => showAddConnectionProfileSheet(
                        context,
                        controller: controller,
                      ),
                      child: const Text('Add Proxmox Server'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Use a trusted local network or VPN. Never expose the '
                    'Proxmox management port directly to the internet.',
                    textAlign: TextAlign.center,
                    style: PveAppleText.caption(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WelcomeFeature extends StatelessWidget {
  const _WelcomeFeature({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return PveListRow(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(message),
    );
  }
}
