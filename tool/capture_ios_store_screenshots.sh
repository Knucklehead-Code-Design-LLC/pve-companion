#!/bin/sh

set -eu

if [ "$#" -ne 2 ]; then
  echo "usage: $0 <iphone-6.9-udid> <ipad-13-udid>" >&2
  exit 64
fi

iphone_udid="$1"
ipad_udid="$2"

capture_device() {
  device_udid="$1"
  output_directory="$2"

  mkdir -p "$output_directory"
  xcrun simctl boot "$device_udid" 2>/dev/null || true
  xcrun simctl bootstatus "$device_udid" -b
  xcrun simctl status_bar "$device_udid" override \
    --time '9:41' \
    --batteryState charged \
    --batteryLevel 100 \
    --wifiBars 3

  capture_scene "$device_udid" "$output_directory" overview \
    01-datacenter-overview.jpg
  capture_scene "$device_udid" "$output_directory" guests \
    02-guest-inventory.jpg
  capture_scene "$device_udid" "$output_directory" nodes \
    03-node-health.jpg
}

capture_scene() {
  device_udid="$1"
  output_directory="$2"
  scene="$3"
  filename="$4"

  flutter run \
    -d "$device_udid" \
    -t tool/store_screenshot_preview.dart \
    --dart-define="SCREENSHOT_SCENE=$scene" \
    --no-resident \
    --no-pub
  sleep 2
  xcrun simctl io "$device_udid" screenshot \
    --type=jpeg \
    "$output_directory/$filename"
}

capture_device "$iphone_udid" \
  docs/app-store/screenshots/en-US/iphone-6.9
capture_device "$ipad_udid" \
  docs/app-store/screenshots/en-US/ipad-13
