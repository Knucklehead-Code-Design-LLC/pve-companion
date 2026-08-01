import 'package:flutter/material.dart';

import '../../../app/pve_companion_controller.dart';
import '../../../core/presentation/modal_sheet_grabber.dart';
import '../application/connection_profiles_controller.dart';
import '../domain/connection_credentials.dart';
import '../domain/connection_profile.dart';
import 'certificate_trust_dialog.dart';
import 'connection_profile_form_fields.dart';

Future<void> showAddConnectionProfileSheet(
  BuildContext context, {
  required PveCompanionController controller,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (BuildContext sheetContext) {
      return AddConnectionProfileSheet(controller: controller);
    },
  );
}

class AddConnectionProfileSheet extends StatefulWidget {
  const AddConnectionProfileSheet({super.key, required this.controller});

  final PveCompanionController controller;

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
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const ModalSheetGrabber(),
                  const SizedBox(height: 20),
                  Text(
                    'Add server',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'HTTPS is required. Credentials are never written to '
                    'preferences or logs.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 24),
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
                    onAuthenticationKindChanged:
                        (ConnectionAuthenticationKind kind) {
                          setState(() => _authenticationKind = kind);
                        },
                    onToggleSecretVisibility: () =>
                        setState(() => _secretVisible = !_secretVisible),
                    onPersistCredentialsChanged: (bool value) {
                      setState(() => _persistCredentials = value);
                    },
                  ),
                  if (_submitError != null) ...<Widget>[
                    const SizedBox(height: 12),
                    Text(
                      _submitError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _submitting ? null : _submit,
                      icon: _submitting
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.lock_open_outlined),
                      label: Text(
                        _submitting ? 'Connecting…' : 'Test and save',
                      ),
                    ),
                  ),
                ],
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
    final bool? trustsCertificate = await showDialog<bool>(
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
