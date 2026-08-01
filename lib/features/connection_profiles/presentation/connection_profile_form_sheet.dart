import 'package:flutter/material.dart';

import '../../../app/pve_companion_controller.dart';
import '../application/connection_profiles_controller.dart';
import '../domain/connection_credentials.dart';
import '../domain/connection_profile.dart';

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
                  const _ConnectionFormGrabber(),
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
                  _ConnectionIdentityFields(
                    nameController: _nameController,
                    endpointController: _endpointController,
                  ),
                  const SizedBox(height: 22),
                  _AuthenticationMethodPicker(
                    authenticationKind: _authenticationKind,
                    onChanged: _submitting
                        ? null
                        : (ConnectionAuthenticationKind kind) {
                            setState(() => _authenticationKind = kind);
                          },
                  ),
                  const SizedBox(height: 16),
                  _AuthenticationCredentialFields(
                    authenticationKind: _authenticationKind,
                    usernameController: _usernameController,
                    realmController: _realmController,
                    tokenIdController: _tokenIdController,
                    secretController: _secretController,
                    secretVisible: _secretVisible,
                    onToggleSecretVisibility: _submitting
                        ? null
                        : () =>
                              setState(() => _secretVisible = !_secretVisible),
                  ),
                  const SizedBox(height: 8),
                  _CredentialPersistenceOption(
                    enabled: _persistCredentials,
                    onChanged: _submitting
                        ? null
                        : (bool value) {
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
        return _CertificateTrustDialog(
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

class _ConnectionFormGrabber extends StatelessWidget {
  const _ConnectionFormGrabber();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.outlineVariant,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _ConnectionIdentityFields extends StatelessWidget {
  const _ConnectionIdentityFields({
    required this.nameController,
    required this.endpointController,
  });

  final TextEditingController nameController;
  final TextEditingController endpointController;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        TextFormField(
          controller: nameController,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Friendly name',
            hintText: 'Home cluster',
          ),
          validator: _requiredField('Enter a friendly name.'),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: endpointController,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.next,
          autocorrect: false,
          enableSuggestions: false,
          decoration: const InputDecoration(
            labelText: 'Server URL',
            hintText: 'https://pve.example.net:8006',
          ),
          validator: (String? value) {
            try {
              parseSecureEndpoint(value ?? '');
              return null;
            } on FormatException catch (error) {
              return error.message;
            }
          },
        ),
      ],
    );
  }
}

class _AuthenticationMethodPicker extends StatelessWidget {
  const _AuthenticationMethodPicker({
    required this.authenticationKind,
    required this.onChanged,
  });

  final ConnectionAuthenticationKind authenticationKind;
  final ValueChanged<ConnectionAuthenticationKind>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Sign-in method', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        SegmentedButton<ConnectionAuthenticationKind>(
          segments: const <ButtonSegment<ConnectionAuthenticationKind>>[
            ButtonSegment<ConnectionAuthenticationKind>(
              value: ConnectionAuthenticationKind.password,
              label: Text('Password'),
              icon: Icon(Icons.person_outline),
            ),
            ButtonSegment<ConnectionAuthenticationKind>(
              value: ConnectionAuthenticationKind.apiToken,
              label: Text('API token'),
              icon: Icon(Icons.key_outlined),
            ),
          ],
          selected: <ConnectionAuthenticationKind>{authenticationKind},
          onSelectionChanged: onChanged == null
              ? null
              : (Set<ConnectionAuthenticationKind> selection) {
                  onChanged!(selection.first);
                },
        ),
      ],
    );
  }
}

class _AuthenticationCredentialFields extends StatelessWidget {
  const _AuthenticationCredentialFields({
    required this.authenticationKind,
    required this.usernameController,
    required this.realmController,
    required this.tokenIdController,
    required this.secretController,
    required this.secretVisible,
    required this.onToggleSecretVisibility,
  });

  final ConnectionAuthenticationKind authenticationKind;
  final TextEditingController usernameController;
  final TextEditingController realmController;
  final TextEditingController tokenIdController;
  final TextEditingController secretController;
  final bool secretVisible;
  final VoidCallback? onToggleSecretVisibility;

  @override
  Widget build(BuildContext context) {
    final bool passwordAuthentication =
        authenticationKind == ConnectionAuthenticationKind.password;
    return Column(
      children: <Widget>[
        if (passwordAuthentication) ...<Widget>[
          TextFormField(
            controller: usernameController,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(
              labelText: 'Username',
              hintText: 'root or admin@pve',
            ),
            validator: _requiredField('Enter the username.'),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: realmController,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(
              labelText: 'Realm',
              hintText: 'pam',
            ),
            validator: _requiredField('Enter the authentication realm.'),
          ),
        ] else
          TextFormField(
            controller: tokenIdController,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(
              labelText: 'Token ID',
              hintText: 'user@realm!token-name',
            ),
            validator: (String? value) {
              final String tokenId = value?.trim() ?? '';
              return tokenId.isNotEmpty && tokenId.contains('!')
                  ? null
                  : 'Use the user@realm!token-name form.';
            },
          ),
        const SizedBox(height: 16),
        TextFormField(
          controller: secretController,
          obscureText: !secretVisible,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            labelText: passwordAuthentication ? 'Password' : 'Token secret',
            suffixIcon: IconButton(
              tooltip: secretVisible ? 'Hide secret' : 'Show secret',
              icon: Icon(
                secretVisible
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
              onPressed: onToggleSecretVisibility,
            ),
          ),
          validator: _requiredField('Enter the secret.'),
        ),
      ],
    );
  }
}

class _CredentialPersistenceOption extends StatelessWidget {
  const _CredentialPersistenceOption({
    required this.enabled,
    required this.onChanged,
  });

  final bool enabled;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      title: const Text('Remember in Apple Keychain'),
      subtitle: const Text(
        'Turn this off for a session-only connection. You will need to add '
        'the server again after disconnecting.',
      ),
      value: enabled,
      onChanged: onChanged,
    );
  }
}

class _CertificateTrustDialog extends StatelessWidget {
  const _CertificateTrustDialog({
    required this.profile,
    required this.fingerprint,
  });

  final ConnectionProfile profile;
  final String fingerprint;

  @override
  Widget build(BuildContext context) {
    final int port = profile.endpoint.hasPort ? profile.endpoint.port : 443;
    return AlertDialog(
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
            'Confirm this through a separate trusted channel before continuing. '
            'Trust is pinned only to this server host and port—not globally disabled.',
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Trust and connect'),
        ),
      ],
    );
  }
}

String? Function(String?) _requiredField(String message) {
  return (String? value) => value?.trim().isNotEmpty == true ? null : message;
}
