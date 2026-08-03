# App Store screenshots

The English (U.S.) App Store images pair a polished PVE Companion treatment
with production-widget captures. The interface shown in every image is
rendered from deterministic, local-only fixture data: it never contacts a
server and contains no real hostnames, IP addresses, users, or credentials.

| Source capture | Upload-ready image | Required canvas | Current scenes |
| --- | --- | --- | --- |
| `source/en-US/iphone-6.9` | `en-US/iphone-6.9` | 1320 × 2868 | Overview, guests, nodes, storage, tasks |
| `source/en-US/ipad-13` | `en-US/ipad-13` | 2064 × 2752 | Overview, guests, nodes, storage, tasks |
| `source/en-US/mac` | `en-US/mac` | 1280 × 800 | Overview, guests, nodes, storage, tasks |

The `source` folders hold the literal app captures. The `en-US` folders are
the only upload-ready assets: they add the app mark, a feature-specific
headline, and a restrained network backdrop around the real screen. This
keeps the storefront presentation intentional without manufacturing UI or
making feature claims the shipping app cannot support.

All submitted files are JPEGs without alpha. Apple accepts one to 10
screenshots per family; this release uses five in a consistent order.

Validate the checked-in assets before upload or App Store submission:

```sh
tool/verify_app_store_submission.sh
```

Apple updates accepted device sizes independently of this repository. Check
the current [App Store Connect screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications)
before recapturing or adding a platform.

## iPhone and iPad capture

Boot the target simulators, set a clean status bar, and run the capture helper:

```sh
tool/capture_ios_store_screenshots.sh \
  <iphone-6.9-simulator-udid> \
  <ipad-13-simulator-udid>
```

The helper clean-boots each simulator to reset stale rotation, launches
`tool/store_screenshot_preview.dart` once per scene, and waits for the first
stable frame before using `simctl` to capture raw JPEG source images. It then
renders the App Store treatment automatically. Use `sips` or the validator to
verify pixel dimensions and the absence of alpha before upload.

## Mac capture

Render the same production-widget preview at the exact 1280 × 800 canvas:

```sh
tool/capture_macos_store_screenshots.sh
```

The helper uses Flutter's deterministic golden renderer, converts the results
to raw JPEG source images, and renders the App Store treatment automatically.
It needs no signing identity and does not change project signing settings.

## Re-rendering the treatment

After reviewing or recapturing the source images, re-render all platform
assets with:

```sh
swift tool/render_app_store_marketing_screenshots.swift
tool/verify_app_store_submission.sh
```

The renderer is intentionally macOS-native so it can use the installed system
font and needs no image-processing dependency or generated placeholder art.
