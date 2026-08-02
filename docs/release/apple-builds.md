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

## Local iOS signing

The iOS app and widget both use automatic signing. On a publishing Mac, make a
machine-local signing file once:

```sh
cp ios/Flutter/Signing.xcconfig.example ios/Flutter/Signing.xcconfig
```

Set `DEVELOPMENT_TEAM` in that ignored file to the publishing organization’s
team ID, then sign in to that organization in Xcode. The same local setting is
inherited by Runner and PVECompanionWidgets, while the repository remains free
of team IDs, certificates, provisioning profile names, credentials, and server
configuration. Let Xcode create or refresh automatic distribution profiles;
never add a manual `PROVISIONING_PROFILE_SPECIFIER` to the project.

The targets include an app-level privacy manifest and declare
`ITSAppUsesNonExemptEncryption = false`. That declaration reflects the current
implementation, which uses platform TLS, Keychain, and SHA-256 certificate
fingerprinting without shipping non-exempt encryption. Reassess it whenever
cryptographic or transport behavior changes.

The iOS workspace also contains the `PVECompanionWidgets` extension with
bundle ID `com.knuckleheadcodedesign.pvecompanion.widgets`. The main app and
extension require the registered App Group
`group.com.knuckleheadcodedesign.pvecompanion`. The main app declares
`NSSupportsLiveActivities = true`; local Live Activities do not add a separate
App ID capability. Add Push Notifications only when remote ActivityKit updates
are introduced. Both targets inherit the Flutter version and build number, and
the checked-in privacy manifests declare the App Group UserDefaults reason
`1C8F.1`.

## Initial TestFlight record

The initial App Store Connect app is an iOS/iPadOS record with SKU
`pve-companion-ios` and App Store Connect ID `6797252365`. Version 0.1.0
(build 1) was uploaded on August 2, 2026 and must finish processing before it
can be assigned to testers. The macOS target is quality-qualified locally but
is not yet configured as an App Store Connect distribution platform.

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
  suite, builds a signed IPA, and uploads it to internal TestFlight. Its build
  number uses Codemagic's monotonically increasing project number when App
  Store Connect has no usable build response; otherwise it increments the
  newer App Store Connect build. This supports the first upload and later or
  manually uploaded builds without reusing a build number.
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
4. On an isolated test guest, smoke-test every state-changing guest/node
   operation and verify its tracked task status. Exercise Backup Center,
   Portfolio, Cluster Administration, notification permission, and browser
   console handoff on each Apple platform.
5. Confirm no profile export, diagnostics, screenshot, or log includes a
   password, token secret, ticket, CSRF token, private hostname, or IP address.
6. Configure App Store signing in Xcode or the approved release system; never
   commit it here.
7. On a physical iPhone, qualify every widget family and the complete
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
