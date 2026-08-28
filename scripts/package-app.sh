#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build --product Musicloud
binary_dir="$(swift build --show-bin-path)"
app_dir="dist/Musicloud.app/Contents"
mkdir -p "$app_dir/MacOS" "$app_dir/Resources"
cp "$binary_dir/Musicloud" "$app_dir/MacOS/Musicloud"
cp packaging/Info.plist "$app_dir/Info.plist"
printf 'Built %s/dist/Musicloud.app\n' "$PWD"
