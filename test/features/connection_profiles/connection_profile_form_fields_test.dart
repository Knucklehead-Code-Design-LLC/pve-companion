import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pve_companion/app/pve_companion_theme.dart';
import 'package:pve_companion/features/connection_profiles/domain/connection_profile.dart';
import 'package:pve_companion/features/connection_profiles/presentation/connection_profile_form_fields.dart';

void main() {
  testWidgets(
    'reveals only the fields required by the selected sign-in method',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(const _ConnectionFormHarness());
      expect(find.text('Username'), findsOneWidget);
      expect(find.text('Realm'), findsOneWidget);
      expect(find.text('Token ID'), findsNothing);

      await tester.tap(find.text('API Token'));
      await tester.pumpAndSettle();

      expect(find.text('Username'), findsNothing);
      expect(find.text('Realm'), findsNothing);
      expect(find.text('Token ID'), findsOneWidget);
      expect(find.text('Remember credential'), findsOneWidget);
      expect(
        find.textContaining('dedicated, least-privilege Proxmox API token'),
        findsOneWidget,
      );
    },
  );

  testWidgets('keeps sign-in choices usable with larger text', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const _ConnectionFormHarness(textScaler: TextScaler.linear(2)),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Password'), findsWidgets);
    expect(find.text('API Token'), findsOneWidget);
  });
}

class _ConnectionFormHarness extends StatefulWidget {
  const _ConnectionFormHarness({this.textScaler = TextScaler.noScaling});

  final TextScaler textScaler;

  @override
  State<_ConnectionFormHarness> createState() => _ConnectionFormHarnessState();
}

class _ConnectionFormHarnessState extends State<_ConnectionFormHarness> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _endpoint = TextEditingController();
  final TextEditingController _username = TextEditingController();
  final TextEditingController _realm = TextEditingController(text: 'pam');
  final TextEditingController _tokenId = TextEditingController();
  final TextEditingController _secret = TextEditingController();
  ConnectionAuthenticationKind _kind = ConnectionAuthenticationKind.password;
  bool _remember = true;
  bool _secretVisible = false;

  @override
  void dispose() {
    _name.dispose();
    _endpoint.dispose();
    _username.dispose();
    _realm.dispose();
    _tokenId.dispose();
    _secret.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: PveCompanionTheme.light(),
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: widget.textScaler),
          child: child!,
        );
      },
      home: Scaffold(
        body: Form(
          child: ListView(
            children: <Widget>[
              ConnectionProfileFormFields(
                authenticationKind: _kind,
                nameController: _name,
                endpointController: _endpoint,
                usernameController: _username,
                realmController: _realm,
                tokenIdController: _tokenId,
                secretController: _secret,
                secretVisible: _secretVisible,
                persistCredentials: _remember,
                enabled: true,
                onAuthenticationKindChanged:
                    (ConnectionAuthenticationKind kind) {
                      setState(() => _kind = kind);
                    },
                onToggleSecretVisibility: () {
                  setState(() => _secretVisible = !_secretVisible);
                },
                onPersistCredentialsChanged: (bool value) {
                  setState(() => _remember = value);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
