import 'package:flutter/material.dart';

import '../domain/connection_profile.dart';

class ConnectionProfileFormFields extends StatelessWidget {
  const ConnectionProfileFormFields({
    super.key,
    required this.authenticationKind,
    required this.nameController,
    required this.endpointController,
    required this.usernameController,
    required this.realmController,
    required this.tokenIdController,
    required this.secretController,
    required this.secretVisible,
    required this.persistCredentials,
    required this.enabled,
    required this.onAuthenticationKindChanged,
    required this.onToggleSecretVisibility,
    required this.onPersistCredentialsChanged,
  });

  final ConnectionAuthenticationKind authenticationKind;
  final TextEditingController nameController;
  final TextEditingController endpointController;
  final TextEditingController usernameController;
  final TextEditingController realmController;
  final TextEditingController tokenIdController;
  final TextEditingController secretController;
  final bool secretVisible;
  final bool persistCredentials;
  final bool enabled;
  final ValueChanged<ConnectionAuthenticationKind> onAuthenticationKindChanged;
  final VoidCallback onToggleSecretVisibility;
  final ValueChanged<bool> onPersistCredentialsChanged;

  @override
  Widget build(BuildContext context) {
    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _ConnectionIdentityFields(
            nameController: nameController,
            endpointController: endpointController,
          ),
          const SizedBox(height: 22),
          _AuthenticationMethodPicker(
            authenticationKind: authenticationKind,
            onChanged: enabled ? onAuthenticationKindChanged : null,
          ),
          const SizedBox(height: 16),
          _AuthenticationCredentialFields(
            authenticationKind: authenticationKind,
            usernameController: usernameController,
            realmController: realmController,
            tokenIdController: tokenIdController,
            secretController: secretController,
            secretVisible: secretVisible,
            onToggleSecretVisibility: enabled ? onToggleSecretVisibility : null,
          ),
          const SizedBox(height: 8),
          _CredentialPersistenceOption(
            enabled: persistCredentials,
            onChanged: enabled ? onPersistCredentialsChanged : null,
          ),
        ],
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
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Friendly name',
            hintText: 'Home cluster',
          ),
          validator: requiredConnectionField('Enter a friendly name.'),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: endpointController,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.next,
          autocorrect: false,
          enableSuggestions: false,
          autofillHints: const <String>[AutofillHints.url],
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
            autofillHints: const <String>[AutofillHints.username],
            decoration: const InputDecoration(
              labelText: 'Username',
              hintText: 'root or admin@pve',
            ),
            validator: requiredConnectionField('Enter the username.'),
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
            validator: requiredConnectionField(
              'Enter the authentication realm.',
            ),
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
          autofillHints: passwordAuthentication
              ? const <String>[AutofillHints.password]
              : null,
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
          validator: requiredConnectionField('Enter the secret.'),
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

String? Function(String?) requiredConnectionField(String message) {
  return (String? value) => value?.trim().isNotEmpty == true ? null : message;
}
