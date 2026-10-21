#!/usr/bin/env bash
# Confirm the native iOS libraries that the export will link contain arm64
# simulator slices. Run this after the Godot export, on macOS.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

require_arm64() {
  local label="$1"
  local archive="$2"
  if [[ ! -f "$archive" ]]; then
    echo "$label archive missing: $archive" >&2
    exit 1
  fi
  local archs
  archs="$(lipo -archs "$archive")"
  echo "$label: $archs ($archive)"
  if [[ " $archs " != *" arm64 "* ]]; then
    echo "$label is missing arm64." >&2
    exit 1
  fi
}

one_archive() {
  local dir="$1"
  find "$dir" -maxdepth 1 -type f \( -name '*.a' -o -name '*.o' \) | head -n 1
}

hk="$ROOT/addons/healthkit/bin/libhealthkit.ios.template_debug.xcframework"
cpp="$ROOT/addons/healthkit/bin/libgodot-cpp.ios.template_debug.xcframework"
for framework in "$hk" "$cpp"; do
  sim="$(find "$framework" -maxdepth 1 -type d -name '*simulator*' | head -n 1)"
  device="$(find "$framework" -maxdepth 1 -type d -name 'ios-arm64' | head -n 1)"
  if [[ -z "$sim" || -z "$device" ]]; then
    echo "Missing device or simulator slice in $framework" >&2
    find "$framework" -maxdepth 2 -print >&2
    exit 1
  fi
  require_arm64 "$(basename "$framework") simulator" "$(one_archive "$sim")"
  require_arm64 "$(basename "$framework") device" "$(one_archive "$device")"
done

ads="$(find "$ROOT/addons/admob/ios/bin" -type d -name 'poing-godot-admob-ads.debug.xcframework' | head -n 1)"
if [[ -z "$ads" ]]; then
  echo "AdMob iOS debug xcframework was not downloaded." >&2
  exit 1
fi
ads_sim="$(find "$ads" -maxdepth 1 -type d -name '*simulator*' | head -n 1)"
require_arm64 "AdMob ads simulator" "$(one_archive "$ads_sim")"

# Godot renames libgodot.ios.debug.xcframework to <binary>.xcframework on export.
libgodot="$(find "$ROOT/build/ios" -path '*simulator*/libgodot.a' | head -n 1)"
require_arm64 "exported libgodot simulator" "$libgodot"
camera="$(find "$ROOT/build/ios" -path '*simulator*/libgodot_camera.a' | head -n 1)"
if [[ -n "$camera" ]]; then
  require_arm64 "exported libgodot_camera simulator" "$camera"
else
  echo "Exported project has no camera xcframework (modules/camera is off)."
fi
