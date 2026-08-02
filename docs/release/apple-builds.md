# Apple build and release guide

PVE Companion supports macOS, iOS, and iPadOS from the same Flutter target.
The repository does not contain signing certificates, provisioning profiles,
Apple team identifiers, or production server configuration.

## Local verification

Run these before preparing an Apple release:

```sh
flutter pub get
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze
flutter test
flutter build ios --simulator
xcodebuild -workspace macos/Runner.xcworkspace -scheme Runner \
  -configuration Release -derivedDataPath /tmp/pve-companion-macos-build \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build
```

The compile-only macOS command validates the app and Swift Package Manager integration
without leaving a certificate or team identifier in the repository. An
installable macOS build with Keychain Sharing must use an authorized Apple
development signing identity.

Open `ios/Runner.xcworkspace` or `macos/Runner.xcworkspace` in Xcode only when
you are ready to use a signing identity owned by the release organization.
Keep the application identifier as
`com.knuckleheadcodedesign.pvecompanion` unless a deliberate migration is
planned.

The targets include an app-level privacy manifest and declare
`ITSAppUsesNonExemptEncryption = false`. That declaration reflects the current
implementation, which uses platform TLS, Keychain, and SHA-256 certificate
fingerprinting without shipping non-exempt encryption. Reassess it whenever
cryptographic or transport behavior changes.

The iOS workspace also contains the `PVECompanionWidgets` extension with
bundle ID `com.knuckleheadcodedesign.pvecompanion.widgets`. The main app and
extension require the registered App Group
`group.com.knuckleheadcodedesign.pvecompanion`; the main App ID also requires
the Live Activities capability. Both targets must use the publishing team and
matching version/build numbers. The checked-in privacy manifests declare the
App Group UserDefaults reason `1C8F.1`.

## Codemagic delivery

[`codemagic.yaml`](../../codemagic.yaml) is the release configuration for the
Knucklehead Code & Design LLC Codemagic team. The signing material is kept in
that team's Code signing identities rather than in the repository: one managed
Apple Distribution certificate plus separate App Store profiles for the app
and the widget extension.

The iOS project uses Flutter's Swift Package Manager integration, not
CocoaPods. The workflows therefore do not run `pod install` or require a
`Podfile`.

- `ios-pr-verify` runs for pull requests targeting `main`. It builds an
  unsigned iOS release app and has no signing or App Store Connect material,
  so pull requests from public forks cannot access release credentials.
- `ios-testflight` runs after a push to `main`. It runs the full verification
  suite, builds a signed IPA, and uploads it to TestFlight. Its build number
  is always at least Codemagic's monotonically increasing project build
  number; when App Store Connect returns a numeric existing build, the next
  higher number is used instead. This makes the first upload independent of
  an App Store Connect lookup while preserving safe numbering for later or
  manually uploaded builds.
- `ios-app-store-release` runs for a newly created `v*` tag. The tag must
  exactly match the marketing version in `pubspec.yaml`, such as `v0.1.0`.
  It uploads the IPA and submits the version to App Store review. Apple keeps
  the approved version as a manual App Store release.

Create a GitHub release by creating its new `vX.Y.Z` tag. Creating a release
around an existing tag does not emit a fresh tag event, so it does not start a
new Codemagic release build. The team App Store Connect integration must retain
an API key with the App Manager role. Never add API keys, certificates,
provisioning profiles, or their private keys to the repository.

## Deterministic dashboard preview

Before a release, inspect both dashboard health states without entering a
server address or credentials. Use a booted iPhone or iPad simulator:

```sh
flutter devices
flutter run -d <ios-simulator-id> -t tool/datacenter_dashboard_preview.dart
```

The preview uses only fixture data from `tool/support`. Switch between Healthy
and Critical. Use an iPhone simulator for compact layout and an iPad simulator
for wide layout. The same target can run on macOS when a valid Apple signing
identity is configured; the repository's unsigned macOS compile command is
intentionally build-only because Keychain Sharing prevents an unsigned debug
launch.

## Release checklist

1. Verify the version in `pubspec.yaml`.
2. Build and smoke-test an iPhone simulator, an iPad simulator, and a macOS
   build at compact and wide window sizes; include both dashboard preview
   states.
3. Test a valid HTTPS server and a self-signed server. Independently verify the
   shown fingerprint before trusting it.
4. Confirm no profile export, diagnostics, screenshot, or log includes a
   password, token secret, ticket, CSRF token, private hostname, or IP address.
5. Configure App Store signing in Xcode or the approved release system; never
   commit it here.
6. On a physical iPhone, qualify every widget family and the complete
   Datacenter Watch lifecycle. Simulator builds prove compilation and basic
   rendering, but do not replace Dynamic Island, Lock Screen, Always-On, and
   signing-capability testing on hardware.

Use the focused [TestFlight checklist](testflight-checklist.md) for App Store
Connect setup, archive validation, upload, and review information. Proposed
store copy and URLs live in [app-store-metadata.md](app-store-metadata.md), and
validated screenshot assets live under
[`docs/app-store/screenshots`](../app-store/screenshots/README.md).

GitHub Actions remains the low-cost Linux format, analysis, and test path.
Codemagic owns the Apple-specific unsigned iOS pull-request compilation,
TestFlight upload, and App Store submission.
