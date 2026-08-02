# TestFlight submission checklist

The source tree is prepared for an Apple archive without embedding a signing
team, certificate, provisioning profile, or production server credential.
Complete this list from the Apple Developer organization that will publish the
app.

## One-time App Store Connect setup

- [ ] Confirm the legal entity that should own PVE Companion and select its
      Apple Developer team in Xcode.
- [ ] Register `com.knuckleheadcodedesign.pvecompanion` as an explicit App ID.
- [ ] Register `com.knuckleheadcodedesign.pvecompanion.widgets` as the WidgetKit
      extension App ID.
- [ ] Register the App Group
      `group.com.knuckleheadcodedesign.pvecompanion`, enable it for both App
      IDs, and enable Live Activities for the main App ID.
- [ ] Create the App Store Connect app using the metadata in
      [app-store-metadata.md](app-store-metadata.md).
- [ ] Complete agreements, banking/tax status if applicable, trader status,
      age rating, app privacy, availability, and contact information.
- [ ] Confirm the privacy and support URLs are public and functional.
- [ ] Provide a live, least-privilege review server and credentials in **App
      Review Information**. Apple requires review access for sign-in features;
      do not place reviewer credentials in this repository.

## Build qualification

```sh
flutter pub get
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze
flutter test
tool/capture_macos_store_screenshots.sh
flutter build ios --simulator
xcodebuild -workspace macos/Runner.xcworkspace -scheme Runner \
  -configuration Release -derivedDataPath /tmp/pve-companion-macos-release \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build
```

- [ ] Exercise password and API-token authentication against a test server.
- [ ] Exercise trusted-chain TLS and the explicit self-signed fingerprint
      path. Verify the fingerprint independently before accepting it.
- [ ] Verify profile deletion removes the profile and its remembered secret.
- [ ] Exercise overview, every drill-down, and guest power confirmations on an
      iPhone, iPad, and Mac.
- [ ] Add the small, medium, and large Home Screen families plus every Lock
      Screen family on iPhone and iPad. Verify placeholder, no-data, populated,
      stale, critical, full-color, tinted, clear-glass, dark, and Always-On
      appearances. Confirm the whole widget opens Overview and each metric link
      opens Nodes, Guests, or Tasks as labeled.
- [ ] Start, update, open, and end Datacenter Watch on a Dynamic
      Island-capable physical iPhone. Verify Lock Screen, compact, minimal, and
      expanded presentations contain no sensitive identifiers.
- [ ] Confirm all screenshot files meet the dimensions documented in
      [the App Store screenshot guide](../app-store/screenshots/README.md).
- [ ] Review the built archive for both privacy manifests, the `1C8F.1` App
      Group UserDefaults reason, app icons, matching host/extension versions,
      build number, and `ITSAppUsesNonExemptEncryption = false`.

## Archive and upload

1. Open `ios/Runner.xcworkspace` in Xcode.
2. Select the publishing team for both Runner and PVECompanionWidgets and
   allow Xcode to manage their distribution profiles. Confirm both targets use
   the registered App Group. Keep team identifiers out of the repository.
3. Select **Any iOS Device (arm64)** and choose **Product → Archive**.
4. In Organizer, run **Validate App**, resolve all errors, then choose
   **Distribute App → App Store Connect → Upload**.
5. Wait for processing in App Store Connect, answer export-compliance prompts
   consistently with the Info.plist declaration, and attach the processed
   build to the TestFlight version.
6. Add complete beta description, feedback email, review contact, review
   notes, and the live review credentials. Start with an internal tester group;
   submit for TestFlight App Review before inviting external testers.

Increment the build number for every upload. Do not reuse `+1` after a build
has been accepted by App Store Connect.
