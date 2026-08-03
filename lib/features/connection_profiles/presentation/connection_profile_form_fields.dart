import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Tooltip;

import '../../../core/presentation/pve_apple_ui.dart';
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
    final passwordAuthentication =
        authenticationKind == ConnectionAuthenticationKind.password;
    return AutofillGroup(
      child: Column(
        children: <Widget>[
          CupertinoFormSection.insetGrouped(
            header: const Text('SERVER'),
            footer: const Text(
              'Enter the HTTPS address you normally use in a browser.',
            ),
            children: <Widget>[
              CupertinoTextFormFieldRow(
                controller: nameController,
                prefix: const Text('Name'),
                placeholder: 'Home lab',
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                enabled: enabled,
                validator: requiredConnectionField('Enter a name.'),
              ),
              CupertinoTextFormFieldRow(
                controller: endpointController,
                prefix: const Text('Address'),
                placeholder: 'https://pve.example.net:8006',
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                enableSuggestions: false,
                autofillHints: const <String>[AutofillHints.url],
                enabled: enabled,
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
          ),
          CupertinoFormSection.insetGrouped(
            header: const Text('SIGN IN'),
            footer: Text(
              passwordAuthentication
                  ? 'Your password creates a short-lived session and is never '
                        'written to preferences.'
                  : 'Use a dedicated token with only the permissions this app '
                        'needs. Enter user@realm!token-name.',
            ),
            children: <Widget>[
              CupertinoFormRow(
                child: SizedBox(
                  width: double.infinity,
                  child: _AuthenticationKindPicker(
                    value: authenticationKind,
                    enabled: enabled,
                    onChanged: onAuthenticationKindChanged,
                  ),
                ),
              ),
              if (passwordAuthentication) ...<Widget>[
                CupertinoTextFormFieldRow(
                  controller: usernameController,
                  prefix: const Text('Username'),
                  placeholder: 'root or admin',
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  enableSuggestions: false,
                  autofillHints: const <String>[AutofillHints.username],
                  enabled: enabled,
                  validator: requiredConnectionField('Enter the username.'),
                ),
                CupertinoTextFormFieldRow(
                  controller: realmController,
                  prefix: const Text('Realm'),
                  placeholder: 'pam',
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  enableSuggestions: false,
                  enabled: enabled,
                  validator: requiredConnectionField('Enter the realm.'),
                ),
              ] else
                CupertinoTextFormFieldRow(
                  controller: tokenIdController,
                  prefix: const Text('Token ID'),
                  placeholder: 'user@realm!token',
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  enableSuggestions: false,
                  enabled: enabled,
                  validator: (String? value) {
                    final tokenId = value?.trim() ?? '';
                    return tokenId.isNotEmpty && tokenId.contains('!')
                        ? null
                        : 'Use user@realm!token-name.';
                  },
                ),
              _SecretFormRow(
                label: passwordAuthentication ? 'Password' : 'Secret',
                controller: secretController,
                visible: secretVisible,
                enabled: enabled,
                passwordAuthentication: passwordAuthentication,
                onToggleVisibility: onToggleSecretVisibility,
              ),
            ],
          ),
          CupertinoFormSection.insetGrouped(
            header: const Text('ON THIS DEVICE'),
            footer: const Text(
              'When enabled, the credential is encrypted in Apple Keychain. '
              'When disabled, it is used only for this session.',
            ),
            children: <Widget>[
              _PersistCredentialsRow(
                value: persistCredentials,
                enabled: enabled,
                onChanged: onPersistCredentialsChanged,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PersistCredentialsRow extends StatelessWidget {
  const _PersistCredentialsRow({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final Widget toggle = CupertinoSwitch(
      value: value,
      activeTrackColor: PveAppleColors.primary(context),
      onChanged: enabled ? onChanged : null,
    );
    if (MediaQuery.textScalerOf(context).scale(15) < 20) {
      return CupertinoFormRow(
        prefix: const Text('Remember credential'),
        child: toggle,
      );
    }
    return CupertinoFormRow(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text('Remember credential'),
          const SizedBox(height: 8),
          Align(alignment: Alignment.centerRight, child: toggle),
        ],
      ),
    );
  }
}

class _AuthenticationKindPicker extends StatelessWidget {
  const _AuthenticationKindPicker({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final ConnectionAuthenticationKind value;
  final bool enabled;
  final ValueChanged<ConnectionAuthenticationKind> onChanged;

  @override
  Widget build(BuildContext context) {
    final usesLargeText = MediaQuery.textScalerOf(context).scale(17) >= 22;
    if (!usesLargeText) {
      return Opacity(
        opacity: enabled ? 1 : 0.55,
        child: IgnorePointer(
          ignoring: !enabled,
          child: PveSlidingSegmentedControl<ConnectionAuthenticationKind>(
            groupValue: value,
            children: const <ConnectionAuthenticationKind, Widget>{
              ConnectionAuthenticationKind.password: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('Password'),
              ),
              ConnectionAuthenticationKind.apiToken: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('API Token'),
              ),
            },
            onValueChanged: (ConnectionAuthenticationKind? kind) {
              if (kind != null) {
                onChanged(kind);
              }
            },
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _AuthenticationKindChoice(
          label: 'Password',
          selected: value == ConnectionAuthenticationKind.password,
          enabled: enabled,
          onPressed: () => onChanged(ConnectionAuthenticationKind.password),
        ),
        const SizedBox(height: 6),
        _AuthenticationKindChoice(
          label: 'API Token',
          selected: value == ConnectionAuthenticationKind.apiToken,
          enabled: enabled,
          onPressed: () => onChanged(ConnectionAuthenticationKind.apiToken),
        ),
      ],
    );
  }
}

class _AuthenticationKindChoice extends StatelessWidget {
  const _AuthenticationKindChoice({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final accent = PveAppleColors.primary(context);
    return Semantics(
      button: true,
      selected: selected,
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        minimumSize: const Size(44, 44),
        borderRadius: BorderRadius.circular(9),
        color: selected ? accent.withValues(alpha: 0.14) : null,
        onPressed: enabled ? onPressed : null,
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                label,
                style: PveAppleText.body(context).copyWith(
                  color: PveAppleColors.label(context),
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            if (selected) ...<Widget>[
              const SizedBox(width: 8),
              Icon(CupertinoIcons.check_mark, size: 18, color: accent),
            ],
          ],
        ),
      ),
    );
  }
}

class _SecretFormRow extends StatelessWidget {
  const _SecretFormRow({
    required this.label,
    required this.controller,
    required this.visible,
    required this.enabled,
    required this.passwordAuthentication,
    required this.onToggleVisibility,
  });

  final String label;
  final TextEditingController controller;
  final bool visible;
  final bool enabled;
  final bool passwordAuthentication;
  final VoidCallback onToggleVisibility;

  @override
  Widget build(BuildContext context) {
    return FormField<String>(
      validator: (_) => controller.text.trim().isEmpty
          ? 'Enter the ${label.toLowerCase()}.'
          : null,
      builder: (FormFieldState<String> field) {
        return CupertinoFormRow(
          prefix: Text(label),
          error: field.errorText == null ? null : Text(field.errorText!),
          child: Row(
            children: <Widget>[
              Expanded(
                child: CupertinoTextField.borderless(
                  controller: controller,
                  enabled: enabled,
                  obscureText: !visible,
                  autocorrect: false,
                  enableSuggestions: false,
                  autofillHints: passwordAuthentication
                      ? const <String>[AutofillHints.password]
                      : null,
                  placeholder: passwordAuthentication
                      ? 'Required'
                      : 'Token secret',
                  textAlign: TextAlign.end,
                  onChanged: field.didChange,
                ),
              ),
              Semantics(
                button: true,
                enabled: enabled,
                label: visible ? 'Hide secret' : 'Show secret',
                child: Tooltip(
                  message: visible ? 'Hide secret' : 'Show secret',
                  child: CupertinoButton(
                    padding: const EdgeInsets.only(left: 8),
                    minimumSize: const Size(34, 34),
                    onPressed: enabled ? onToggleVisibility : null,
                    child: ExcludeSemantics(
                      child: Icon(
                        visible ? CupertinoIcons.eye_slash : CupertinoIcons.eye,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

String? Function(String?) requiredConnectionField(String message) {
  return (String? value) => value?.trim().isNotEmpty == true ? null : message;
}
