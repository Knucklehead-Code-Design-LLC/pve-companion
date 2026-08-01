import 'package:flutter/cupertino.dart';

import '../../../app/pve_companion_controller.dart';
import '../../../core/presentation/pve_apple_ui.dart';
import '../application/connection_profiles_controller.dart';
import '../domain/connection_credentials.dart';
import '../domain/connection_profile.dart';
import 'certificate_trust_dialog.dart';
import 'connection_profile_form_fields.dart';

Future<void> showAddConnectionProfileSheet(
  BuildContext context, {
  required PveCompanionController controller,
}) {
  return showCupertinoSheet<void>(
    context: context,
    useNestedNavigation: true,
    scrollableBuilder:
        (BuildContext sheetContext, ScrollController scrollController) {
          return AddConnectionProfileSheet(
            controller: controller,
            scrollController: scrollController,
          );
        },
  );
}

class AddConnectionProfileSheet extends StatefulWidget {
  const AddConnectionProfileSheet({
    super.key,
    required this.controller,
    required this.scrollController,
  });

  final PveCompanionController controller;
  final ScrollController scrollController;

  @override
  State<AddConnectionProfileSheet> createState() =>
      _AddConnectionProfileSheetState();
}

class _AddConnectionProfileSheetState extends State<AddConnectionProfileSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _endpointController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _realmController = TextEditingController(
    text: 'pam',
  );
  final TextEditingController _tokenIdController = TextEditingController();
  final TextEditingController _secretController = TextEditingController();

  ConnectionAuthenticationKind _authenticationKind =
      ConnectionAuthenticationKind.password;
  bool _persistCredentials = true;
  bool _secretVisible = false;
  bool _submitting = false;
  String? _submitError;

  @override
  void dispose() {
    _nameController.dispose();
    _endpointController.dispose();
    _usernameController.dispose();
    _realmController.dispose();
    _tokenIdController.dispose();
    _secretController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: PveAppleColors.page(context),
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Add Server'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          controller: widget.scrollController,
          padding: EdgeInsets.only(
            top: 14,
            bottom: 28 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Column(
                        children: <Widget>[
                          Icon(
                            CupertinoIcons.lock_shield,
                            size: 40,
                            color: PveAppleColors.primary(context),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Connect securely',
                            style: PveAppleText.title2(context),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'PVE Companion verifies the server before saving '
                            'anything. Credentials never go into preferences '
                            'or logs.',
                            textAlign: TextAlign.center,
                            style: PveAppleText.secondary(context),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    ConnectionProfileFormFields(
                      authenticationKind: _authenticationKind,
                      nameController: _nameController,
                      endpointController: _endpointController,
                      usernameController: _usernameController,
                      realmController: _realmController,
                      tokenIdController: _tokenIdController,
                      secretController: _secretController,
                      secretVisible: _secretVisible,
                      persistCredentials: _persistCredentials,
                      enabled: !_submitting,
                      onAuthenticationKindChanged: _changeAuthenticationKind,
                      onToggleSecretVisibility: () =>
                          setState(() => _secretVisible = !_secretVisible),
                      onPersistCredentialsChanged: (bool value) {
                        setState(() => _persistCredentials = value);
                      },
                    ),
                    if (_submitError != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(28, 4, 28, 0),
                        child: Text(
                          _submitError!,
                          textAlign: TextAlign.center,
                          style: PveAppleText.secondary(context).copyWith(
                            color: PveAppleColors.destructive(context),
                          ),
                        ),
                      ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: CupertinoButton.filled(
                        onPressed: _submitting ? null : _submit,
                        child: _submitting
                            ? const CupertinoActivityIndicator(
                                color: CupertinoColors.white,
                              )
                            : const Text('Test & Add Server'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit([ConnectionProfile? trustedProfile]) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _submitting = true;
      _submitError = null;
    });

    final ConnectionProfile profile = trustedProfile ?? _buildProfile();
    final ConnectionCredentials credentials =
        _authenticationKind == ConnectionAuthenticationKind.password
        ? ConnectionCredentials.password(_secretController.text)
        : ConnectionCredentials.apiToken(_secretController.text);
    final ConnectionAttemptResult result = await widget.controller
        .saveAndConnect(
          profile: profile,
          credentials: credentials,
          persistCredentials: _persistCredentials,
        );
    if (!mounted) {
      return;
    }

    switch (result.kind) {
      case ConnectionAttemptKind.connected:
        Navigator.of(context).pop();
        return;
      case ConnectionAttemptKind.certificateTrustRequired:
        setState(() => _submitting = false);
        await _trustCertificateAndRetry(
          profile,
          result.certificateFingerprint!,
        );
        return;
      case ConnectionAttemptKind.busy:
        setState(() {
          _submitting = false;
          _submitError = 'Another connection attempt is still in progress.';
        });
        return;
      case ConnectionAttemptKind.failed:
        setState(() {
          _submitting = false;
          _submitError = result.message ?? 'The server could not be reached.';
        });
        return;
    }
  }

  void _changeAuthenticationKind(ConnectionAuthenticationKind kind) {
    if (_authenticationKind == kind) {
      return;
    }
    _secretController.clear();
    setState(() {
      _authenticationKind = kind;
      _secretVisible = false;
    });
  }

  ConnectionProfile _buildProfile() {
    final Uri endpoint = parseSecureEndpoint(_endpointController.text);
    return _authenticationKind == ConnectionAuthenticationKind.password
        ? ConnectionProfile.password(
            displayName: _nameController.text,
            endpoint: endpoint,
            username: _usernameController.text,
            realm: _realmController.text,
          )
        : ConnectionProfile.apiToken(
            displayName: _nameController.text,
            endpoint: endpoint,
            tokenId: _tokenIdController.text,
          );
  }

  Future<void> _trustCertificateAndRetry(
    ConnectionProfile profile,
    String fingerprint,
  ) async {
    final bool? trustsCertificate = await showCupertinoDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return CertificateTrustDialog(
          profile: profile,
          fingerprint: fingerprint,
        );
      },
    );
    if (trustsCertificate != true || !mounted) {
      return;
    }
    await _submit(profile.copyWith(trustedCertificateSha256: fingerprint));
  }
}
