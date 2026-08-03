#!/bin/sh

set -eu

repository_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repository_root"

failed=0

fail() {
  echo "error: $*" >&2
  failed=1
}

verify_screenshots() {
  label="$1"
  directory="$2"
  expected_width="$3"
  expected_height="$4"
  expected_count="$5"
  count=0

  for screenshot in "$directory"/*.jpg "$directory"/*.jpeg "$directory"/*.png; do
    if [ ! -f "$screenshot" ]; then
      continue
    fi

    count=$((count + 1))
    dimensions=$(sips -g pixelWidth -g pixelHeight "$screenshot" 2>/dev/null)
    width=$(printf '%s\n' "$dimensions" | awk '/pixelWidth:/ { print $2 }')
    height=$(printf '%s\n' "$dimensions" | awk '/pixelHeight:/ { print $2 }')
    has_alpha=$(sips -g hasAlpha "$screenshot" 2>/dev/null | awk '/hasAlpha:/ { print $2 }')

    if [ "$width" != "$expected_width" ] || [ "$height" != "$expected_height" ]; then
      fail "$screenshot must be ${expected_width}x${expected_height}, found ${width}x${height}."
    fi

    if [ "$has_alpha" != "no" ]; then
      fail "$screenshot must not contain an alpha channel."
    fi
  done

  if [ "$count" -ne "$expected_count" ]; then
    fail "$label must contain $expected_count screenshots; found $count."
  fi
}

verify_plist_value() {
  file="$1"
  key="$2"
  expected_value="$3"
  actual_value=$(plutil -extract "$key" raw "$file" 2>/dev/null || true)

  if [ "$actual_value" != "$expected_value" ]; then
    fail "$file must set $key to $expected_value; found ${actual_value:-<missing>}."
  fi
}

verify_screenshots \
  "iPhone 6.9-inch source screenshots" \
  "docs/app-store/screenshots/source/en-US/iphone-6.9" \
  1320 \
  2868 \
  5
verify_screenshots \
  "iPad 13-inch source screenshots" \
  "docs/app-store/screenshots/source/en-US/ipad-13" \
  2064 \
  2752 \
  5
verify_screenshots \
  "Mac source screenshots" \
  "docs/app-store/screenshots/source/en-US/mac" \
  1280 \
  800 \
  5
verify_screenshots \
  "iPhone 6.9-inch App Store screenshots" \
  "docs/app-store/screenshots/en-US/iphone-6.9" \
  1320 \
  2868 \
  5
verify_screenshots \
  "iPad 13-inch App Store screenshots" \
  "docs/app-store/screenshots/en-US/ipad-13" \
  2064 \
  2752 \
  5
verify_screenshots \
  "Mac App Store screenshots" \
  "docs/app-store/screenshots/en-US/mac" \
  1280 \
  800 \
  5

verify_plist_value ios/Runner/Info.plist ITSAppUsesNonExemptEncryption false
verify_plist_value macos/Runner/Info.plist ITSAppUsesNonExemptEncryption false
verify_plist_value \
  macos/Runner/Info.plist \
  LSApplicationCategoryType \
  public.app-category.developer-tools
verify_plist_value ios/Runner/PrivacyInfo.xcprivacy NSPrivacyTracking false
verify_plist_value ios/PVECompanionWidgets/PrivacyInfo.xcprivacy NSPrivacyTracking false
verify_plist_value macos/Runner/PrivacyInfo.xcprivacy NSPrivacyTracking false

if [ "$failed" -ne 0 ]; then
  exit 1
fi

echo "App Store screenshot, category, and privacy-manifest checks passed."
