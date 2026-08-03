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

## macOS App Store signing

The native macOS target shares the iOS bundle ID
`com.knuckleheadcodedesign.pvecompanion`, declares App Sandbox, and declares
the Mac App Store category `public.app-category.developer-tools`. Keep that
category aligned with the **Developer Tools** primary category in App Store
Connect.

On a publishing Mac, create a local signing file once:

```sh
cp macos/Flutter/Signing.xcconfig.example macos/Flutter/Signing.xcconfig
```

Set `DEVELOPMENT_TEAM` to the publishing organization’s team ID, then use
automatic signing in `macos/Runner.xcworkspace`. The ignored file keeps the
team ID, profiles, certificates, credentials, and server configuration out of
the repository. For Mac App Store distribution, use a Mac App Distribution
certificate and a Mac App Store provisioning profile; the upload path may also
need a Mac Installer Distribution certificate for its signed installer package.
Do not use iOS certificates or provisioning profiles for the macOS target.

## Existing App Store Connect record

The existing App Store Connect record has SKU `pve-companion-ios` and App
Store Connect ID `6797252365`. It contains prepared iOS/iPadOS and macOS App
Store versions at 1.0.0. Confirm a matching build has finished processing
before assigning it to testers. The first Mac build requires the protected
Codemagic signing key described below before its workflow can upload it.

macOS shares the same Apple ID, SKU, and bundle ID as the iOS app. Its
platform-local promotional text, description, version, and five prepared
screenshots are entered. Use the prepared values in
[app-store-metadata.md](app-store-metadata.md) and
[app-store-submission.md](app-store-submission.md); do not create a second
app record or upload the iOS IPA as the Mac build.

## Codemagic delivery

[`codemagic.yaml`](../../codemagic.yaml) is the release configuration for the
Knucklehead Code & Design LLC Codemagic team. The signing material is kept in
that team's protected credentials rather than in the repository. The iOS and
iPadOS workflows use one managed Apple Distribution certificate plus separate
App Store profiles for the app and widget extension. The macOS workflows use
Codemagic automatic signing and a protected private key.

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
  exactly match the marketing version in `pubspec.yaml`, such as `v1.0.0`.
  It uploads the IPA and submits the version to App Store review. Apple keeps
  the approved version as a manual App Store release.
- `macos-testflight` runs after a push to `main`. It runs the full verification
  suite, fetches or creates the Mac App Store signing files, builds a signed
  Mac app, signs a `.pkg` with the Mac Installer Distribution certificate, and
  uploads it to App Store Connect for TestFlight processing.
- `macos-app-store-release` runs for the same newly created `v*` tag. It
  validates the tag, produces the signed `.pkg`, and submits the macOS version
  to App Review with manual release selected.

Create a GitHub release by creating its new `vX.Y.Z` tag. Creating a release
around an existing tag does not emit a fresh tag event, so it does not start a
new Codemagic release build. The team App Store Connect integration must retain
an API key with the App Manager role. Before the first remote macOS build,
create the protected Codemagic variable group `macos_app_store_signing` and
store `CERTIFICATE_PRIVATE_KEY` as a secure value. It must be the private key
that matches a Mac App Distribution certificate for the publishing
organization. Codemagic uses that key to retrieve or create the Mac App Store
profile and distribution certificate, and retrieves or creates the Mac
Installer Distribution certificate. Never add API keys, certificates,
provisioning profiles, or private keys to the repository.

Each release workflow creates a new, safe App Store build number. Apple lets
the macOS platform use its own build strings, so its build number does not need
to match the iOS/iPadOS build number. To submit an already processed TestFlight
build without creating another binary, use App Store Connect manually instead.
See the [App Store submission handoff](app-store-submission.md) before choosing
either path.

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
   Portfolio, Cluster Administration, notification permission, and the in-app
   guest console on each Apple platform.
5. Confirm no profile export, diagnostics, screenshot, or log includes a
   password, token secret, ticket, CSRF token, private hostname, or IP address.
6. Configure App Store signing for iOS/iPadOS and macOS in Xcode or the
   approved release system; never commit it here.
7. On a physical iPhone, qualify every widget family and the complete
   Datacenter Watch lifecycle. Simulator builds prove compilation and basic
   rendering, but do not replace Dynamic Island, Lock Screen, Always-On, and
   signing-capability testing on hardware.

Use the focused [TestFlight checklist](testflight-checklist.md) for App Store
Connect setup, archive validation, upload, and review information. Proposed
store copy and URLs live in [app-store-metadata.md](app-store-metadata.md), and
validated screenshot assets live under
[`docs/app-store/screenshots`](../app-store/screenshots/README.md).
The [App Store submission handoff](app-store-submission.md) collects the
review-specific requirements and a safe template for App Review Information.

GitHub Actions remains the low-cost Linux format, analysis, and test path.
Codemagic owns the Apple-specific unsigned iOS pull-request compilation,
signed iOS/iPadOS and macOS TestFlight uploads, and version-tagged App Store
submissions.
