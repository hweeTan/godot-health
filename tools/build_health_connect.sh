#!/usr/bin/env bash
# Build the Health Connect plugin and copy the AARs where the Godot export plugin expects them.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PLUGIN="$ROOT/native/health_connect"

if [[ -z "${ANDROID_HOME:-}" && -d "$HOME/android-sdk" ]]; then
  export ANDROID_HOME="$HOME/android-sdk"
fi
if [[ -z "${ANDROID_HOME:-}" && -d /usr/lib/android-sdk ]]; then
  export ANDROID_HOME=/usr/lib/android-sdk
fi
export ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-$ANDROID_HOME}"

cd "$PLUGIN"
chmod +x ./gradlew
./gradlew :plugin:assemble --no-daemon

copy_variant() {
  local variant="$1"
  local matches=()
  shopt -s globstar nullglob
  matches=("$PLUGIN"/plugin/build/outputs/aar/*"${variant}"*.aar)
  shopt -u globstar
  if [[ ${#matches[@]} -eq 0 ]]; then
    echo "No ${variant} AAR under plugin/build/outputs/aar" >&2
    find "$PLUGIN/plugin/build/outputs" -type f -name '*.aar' >&2 || true
    exit 1
  fi
  local dest="$ROOT/addons/health_connect/bin/${variant}/HealthConnect-${variant}.aar"
  mkdir -p "$(dirname "$dest")"
  cp "${matches[0]}" "$dest"
  echo "Copied ${matches[0]} -> $dest"
}

copy_variant debug
copy_variant release
