#!/bin/sh

set -eu

repository_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repository_root"

generated_directory="tool/mac_store_screenshots"
source_directory="docs/app-store/screenshots/source/en-US/mac"

flutter test --update-goldens tool/capture_macos_store_screenshots_test.dart
mkdir -p "$source_directory"

for filename in \
  01-datacenter-overview \
  02-guest-inventory \
  03-node-health \
  04-storage-inventory \
  05-recent-tasks
do
  sips \
    -s format jpeg \
    "$generated_directory/$filename.png" \
    --out "$source_directory/$filename.jpg" >/dev/null
done

rm \
  "$generated_directory/01-datacenter-overview.png" \
  "$generated_directory/02-guest-inventory.png" \
  "$generated_directory/03-node-health.png" \
  "$generated_directory/04-storage-inventory.png" \
  "$generated_directory/05-recent-tasks.png"
rmdir "$generated_directory"

swift tool/render_app_store_marketing_screenshots.swift
