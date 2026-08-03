# TestFlight submission checklist

The source tree is prepared for an Apple archive without embedding a signing
team, certificate, provisioning profile, or production server credential.
Complete this list from the Apple Developer organization that will publish the
app.

For the first public release, also complete the
[App Store submission handoff](app-store-submission.md). It separates the
App Store review requirements from TestFlight distribution and includes the
review-access template.

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
- [x] Add macOS to that existing App Store Connect record as a universal
      purchase platform. Keep the same Apple ID, SKU, and bundle ID; do not
      create a second Mac app record.
- [ ] Create the protected Codemagic group `macos_app_store_signing` with a
      secure `CERTIFICATE_PRIVATE_KEY` matching a Mac App Distribution
      certificate. Confirm the `Code Magic` App Store Connect integration has
      the App Manager role. The macOS workflows retrieve or create the Mac App
      Store profile and Mac Installer Distribution certificate; do not reuse
      iOS profiles or commit the key.
- [ ] Complete agreements, banking/tax status if applicable, trader status,
      age rating, app privacy, availability, and contact information.
- [ ] Confirm the privacy and support URLs are public and functional.
- [ ] Provide a live, least-privilege review server and credentials in **App
      Review Information**. Apple requires review access for sign-in features;
      do not place reviewer credentials in this repository.

The prepared iOS/iPadOS and macOS App Store versions are 1.0.0. Confirm the
processing status of each matching build in App Store Connect before assigning
testers. A push to `main` starts a separate `macos-testflight` upload after
its signing key is configured.

## Build qualification

```sh
flutter pub get
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze --fatal-infos
flutter test
tool/capture_macos_store_screenshots.sh
tool/verify_app_store_submission.sh
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
- [ ] Before public App Store submission, resolve the separate Guest Console
      [Remote Desktop Client policy gate](app-store-submission.md#guest-console-policy-gate).
      TestFlight qualification does not establish App Store eligibility.
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
- [ ] Review every built archive for its privacy manifest, app icon, matching
      version/build number, and `ITSAppUsesNonExemptEncryption = false`. For
      the iOS archive, also verify the widget privacy manifest, the `1C8F.1`
      App Group UserDefaults reason, and matching host/extension versions. For
      the Mac archive, verify the App Sandbox entitlement and Developer Tools
      category.

## iOS and iPadOS archive and upload

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

## macOS Codemagic archive and upload

1. Confirm the uploaded Mac screenshots and platform metadata before selecting
   a build.
2. Add `CERTIFICATE_PRIVATE_KEY` to the protected
   `macos_app_store_signing` Codemagic group. It must match a Mac App
   Distribution certificate; do not create `Signing.xcconfig` or add any
   signing file to the remote build.
3. Push the qualified commit to `main` and monitor `macos-testflight`.
   Codemagic runs the same Dart checks as iOS, fetches the Mac App Store
   profile and certificates, signs the app and installer package, then uploads
   the `.pkg` to App Store Connect.
4. Wait for processing, attach the processed Mac build to the macOS `1.0.0`
   version, and complete that platform's TestFlight information before
   inviting testers.
5. If Codemagic cannot be used, follow the local macOS signing instructions in
   [apple-builds.md](apple-builds.md) and upload an Organizer archive. Do not
   change the checked-in signing settings as a workaround.

Increment the build number for every upload. Do not reuse `+1` after a build
has been accepted by App Store Connect.
