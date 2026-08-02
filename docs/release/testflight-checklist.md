# TestFlight submission checklist

The source tree is prepared for an Apple archive without embedding a signing
team, certificate, provisioning profile, or production server credential.
Complete this list from the Apple Developer organization that will publish the
app.

## One-time App Store Connect setup

- [x] Confirm Knucklehead Code & Design LLC as the publishing legal entity and
      add its Apple Developer account to the publishing Mac’s Xcode account list.
- [x] Register `com.knuckleheadcodedesign.pvecompanion` as an explicit App ID.
- [x] Register `com.knuckleheadcodedesign.pvecompanion.widgets` as the WidgetKit
      extension App ID.
- [x] Register the App Group
      `group.com.knuckleheadcodedesign.pvecompanion` and assign it to both App
      IDs. The main target declares `NSSupportsLiveActivities = true` for local
      ActivityKit updates.
- [x] Create the iOS/iPadOS App Store Connect app using the metadata in
      [app-store-metadata.md](app-store-metadata.md).
- [ ] Complete agreements, banking/tax status if applicable, trader status,
      age rating, app privacy, availability, and contact information.
- [ ] Confirm the privacy and support URLs are public and functional.
- [ ] Provide a live, least-privilege review server and credentials in **App
      Review Information**. Apple requires review access for sign-in features;
      do not place reviewer credentials in this repository.

The initial iOS/iPadOS build, version 0.1.0 (build 1), was uploaded to
TestFlight on August 2, 2026. Confirm its processing status in App Store
Connect before assigning testers. The macOS target is not part of this initial
App Store Connect release.

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
- [ ] Exercise overview, Incident Center, every drill-down, and all guest
      power/snapshot/backup/configuration confirmations on an iPhone, iPad,
      and Mac. Verify task status reaches a terminal state or reports an
      honest polling failure.
- [ ] Exercise node detail, service restart confirmation, node power
      confirmation, package-index refresh, Backup Center, Datacenter Portfolio,
      Cluster Administration, notification permission/settings, and the
      in-app guest console. Use a non-production guest for every
      state-changing action.
- [ ] Verify the in-app guest console connects with both password and API-token
      profiles, renders a framebuffer, accepts pointer/keyboard input, and
      closes when the app backgrounds. Confirm that no UI, alert, diagnostic,
      or external process exposes credentials, tickets, or CSRF values.
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

1. On the publishing Mac, create the ignored
   `ios/Flutter/Signing.xcconfig` from its checked-in example and set the
   publishing `DEVELOPMENT_TEAM`. Open `ios/Runner.xcworkspace` in Xcode.
2. Confirm automatic signing for Runner and PVECompanionWidgets, the publishing
   team inherited from the local config, and the registered App Group on both
   targets. Keep team identifiers, profiles, certificates, and credentials out
   of the repository.
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
