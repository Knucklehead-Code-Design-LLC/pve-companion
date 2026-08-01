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
flutter build ios --simulator --no-codesign
xcodebuild -workspace macos/Runner.xcworkspace -scheme Runner \
  -configuration Release -derivedDataPath /tmp/pve-companion-macos-build \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build
```

The compile-only macOS command validates the app and CocoaPods integration
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

Use the focused [TestFlight checklist](testflight-checklist.md) for App Store
Connect setup, archive validation, upload, and review information. Proposed
store copy and URLs live in [app-store-metadata.md](app-store-metadata.md), and
validated screenshot assets live under
[`docs/app-store/screenshots`](../app-store/screenshots/README.md).

GitHub Actions intentionally does not perform Apple builds by default: hosted
macOS runners are more expensive, and unsigned simulator builds are practical
on a maintainer Mac.
