# App Store screenshots

The checked-in English (U.S.) screenshots are rendered by the production
widgets using deterministic, local-only fixture data. They never contact a
server and contain no real hostnames, IP addresses, users, or credentials.

| Folder | Required canvas | Current files |
| --- | --- | --- |
| `en-US/iphone-6.9` | 1320 × 2868 | Overview, guests, nodes |
| `en-US/ipad-13` | 2064 × 2752 | Overview, guests, nodes |
| `en-US/mac` | 1280 × 800 | Overview, guests, nodes |

All submitted files are JPEGs without alpha. The preview fixture must reflect
real shipping behavior; do not add controls or claims that are unavailable in
the application.

## iPhone and iPad capture

Boot the target simulators, set a clean status bar, and run the capture helper:

```sh
tool/capture_ios_store_screenshots.sh \
  <iphone-6.9-simulator-udid> \
  <ipad-13-simulator-udid>
```

The helper launches `tool/store_screenshot_preview.dart` once per scene and
waits for the first stable frame before using `simctl` to capture JPEG output.
Use `sips` to verify pixel dimensions and the absence of alpha before upload.

## Mac capture

Run the same preview target in a 1280 × 800 app window and use macOS window
capture without a shadow. A locally signed development app can be launched
with:

```sh
flutter run -d macos -t tool/store_screenshot_preview.dart \
  --dart-define=SCREENSHOT_SCENE=overview
```

Unsigned compile-only builds remain the repository's standard verification;
do not commit a team ID just to automate screenshot capture.
