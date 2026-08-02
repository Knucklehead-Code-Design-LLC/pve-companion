# App Store screenshots

The checked-in English (U.S.) screenshots are rendered by the production
widgets using deterministic, local-only fixture data. They never contact a
server and contain no real hostnames, IP addresses, users, or credentials.

| Folder | Required canvas | Current files |
| --- | --- | --- |
| `en-US/iphone-6.9` | 1320 × 2868 | Overview, guests, nodes, storage, tasks |
| `en-US/ipad-13` | 2064 × 2752 | Overview, guests, nodes, storage, tasks |
| `en-US/mac` | 1280 × 800 | Overview, guests, nodes, storage, tasks |

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

The helper clean-boots each simulator to reset stale rotation, launches
`tool/store_screenshot_preview.dart` once per scene, and waits for the first
stable frame before using `simctl` to capture JPEG output.
Use `sips` to verify pixel dimensions and the absence of alpha before upload.

## Mac capture

Render the same production-widget preview at the exact 1280 × 800 canvas:

```sh
tool/capture_macos_store_screenshots.sh
```

The helper uses Flutter's deterministic golden renderer and converts the
results to App Store-ready JPEGs. It needs no signing identity and does not
change project signing settings.
