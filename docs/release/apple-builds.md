# Apple build and release guide

PVE Companion supports macOS, iOS, and iPadOS from the same Flutter target.
The repository does not contain signing certificates, provisioning profiles,
Apple team identifiers, or production server configuration.

## Local verification

Run these before preparing an Apple release:

```sh
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build ios --simulator --no-codesign
xcodebuild -workspace macos/Runner.xcworkspace -scheme Runner \
  -configuration Debug -derivedDataPath /tmp/pve-companion-macos-build \
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

## Release checklist

1. Verify the version in `pubspec.yaml`.
2. Build and smoke-test an iPhone simulator, an iPad simulator, and a macOS
   build at compact and wide window sizes.
3. Test a valid HTTPS server and a self-signed server. Independently verify the
   shown fingerprint before trusting it.
4. Confirm no profile export, diagnostics, screenshot, or log includes a
   password, token secret, ticket, CSRF token, private hostname, or IP address.
5. Configure App Store signing in Xcode or the approved release system; never
   commit it here.

GitHub Actions intentionally does not perform Apple builds by default: hosted
macOS runners are more expensive, and unsigned simulator builds are practical
on a maintainer Mac.
