#!/usr/bin/env bash
# Godot 4.7.2's official ios.zip advertises an arm64 simulator slice, but
# libgodot.a and libgodot_camera.a in that slice are x86_64 only. Apple Silicon
# Simulator builds then fail at link time. This script lipos an arm64 simulator
# build of those two debug libraries into the template when the slice is thin.
#
# Usage:
#   tools/ensure_ios_simulator_libgodot.sh <export_templates/4.7.2.stable> [cache_dir]
#
# cache_dir receives the patched ios.zip so a later run can skip the engine build.
set -euo pipefail

TEMPLATES="${1:?path to the Godot 4.7.2.stable export templates directory}"
CACHE="${2:-}"
IOS_ZIP="$TEMPLATES/ios.zip"
GODOT_TAG="4.7.2-stable"
SIM_MEMBER="libgodot.ios.debug.xcframework/ios-arm64_x86_64-simulator/libgodot.a"
CAM_MEMBER="libgodot_camera.ios.debug.xcframework/ios-arm64_x86_64-simulator/libgodot_camera.a"

if [[ ! -f "$IOS_ZIP" ]]; then
  echo "No ios.zip at $IOS_ZIP" >&2
  exit 1
fi

slice_archs() {
  local zip="$1"
  local member="$2"
  local tmp archive archs
  tmp="$(mktemp -d)"
  unzip -qo "$zip" "$member" -d "$tmp"
  archive="$tmp/$member"
  if [[ ! -f "$archive" ]]; then
    echo "missing"
    rm -rf "$tmp"
    return 0
  fi
  archs="$(lipo -archs "$archive")"
  rm -rf "$tmp"
  echo "$archs"
}

has_arm64() {
  [[ " $1 " == *" arm64 "* ]]
}

install_cached() {
  local cached="$CACHE/ios.zip"
  if [[ -z "$CACHE" || ! -f "$cached" ]]; then
    return 1
  fi
  local archs
  archs="$(slice_archs "$cached" "$SIM_MEMBER")"
  echo "Cached libgodot simulator archs: $archs"
  if has_arm64 "$archs"; then
    cp "$cached" "$IOS_ZIP"
    echo "Installed cached ios.zip with an arm64 simulator slice."
    return 0
  fi
  return 1
}

remember() {
  if [[ -n "$CACHE" ]]; then
    mkdir -p "$CACHE"
    cp "$IOS_ZIP" "$CACHE/ios.zip"
    echo "Saved patched ios.zip to $CACHE/ios.zip"
  fi
}

if install_cached; then
  exit 0
fi

current="$(slice_archs "$IOS_ZIP" "$SIM_MEMBER")"
echo "Template libgodot simulator archs: $current"
if has_arm64 "$current"; then
  echo "Template already contains an arm64 simulator libgodot."
  remember
  exit 0
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${SWEATPUNK_GODOT_SRC:-$ROOT/build/godot-src}"
if [[ ! -f "$SRC/SConstruct" ]]; then
  rm -rf "$SRC"
  git clone --depth 1 --branch "$GODOT_TAG" https://github.com/godotengine/godot.git "$SRC"
fi

if command -v scons >/dev/null 2>&1; then
  SCONS=(scons)
else
  SCONS=(python3 -m scons)
fi

echo "Building Godot $GODOT_TAG for the arm64 iOS Simulator (template_debug)."
(
  cd "$SRC"
  "${SCONS[@]}" platform=ios target=template_debug arch=arm64 simulator=yes debug_symbols=no \
    -j"$(sysctl -n hw.ncpu)"
)

find_built() {
  local base="$1"
  local found
  found="$(find "$SRC/bin" -type f \
    \( -name "${base}.ios.template_debug.arm64.simulator.a" \
    -o -name "${base}.ios.template_debug.arm64.simulator" \) \
    | head -n 1)"
  if [[ -z "$found" ]]; then
    echo "SCons did not produce ${base} for the arm64 simulator." >&2
    find "$SRC/bin" -type f -name "${base}*" >&2 || true
    exit 1
  fi
  echo "$found"
}

GODOT_ARM="$(find_built libgodot)"
CAMERA_ARM="$(find_built libgodot_camera)"
echo "Built $GODOT_ARM"
echo "Built $CAMERA_ARM"

WORK="$(mktemp -d)"
unzip -q "$IOS_ZIP" -d "$WORK"

lipo_in() {
  local built="$1"
  local relative="$2"
  local dest="$WORK/$relative"
  local fat="$WORK/fat-$(basename "$relative")"
  if [[ ! -f "$dest" ]]; then
    echo "Template is missing $relative" >&2
    exit 1
  fi
  local before
  before="$(lipo -archs "$dest")"
  echo "$relative before: $before"
  lipo -create "$built" "$dest" -output "$fat"
  cp "$fat" "$dest"
  local after
  after="$(lipo -archs "$dest")"
  echo "$relative after: $after"
  if ! has_arm64 "$after"; then
    echo "lipo did not add arm64 to $relative" >&2
    exit 1
  fi
}

lipo_in "$GODOT_ARM" "$SIM_MEMBER"
lipo_in "$CAMERA_ARM" "$CAM_MEMBER"

rm -f "$IOS_ZIP"
(
  cd "$WORK"
  zip -qr "$IOS_ZIP" .
)
rm -rf "$WORK"

patched="$(slice_archs "$IOS_ZIP" "$SIM_MEMBER")"
echo "Patched libgodot simulator archs: $patched"
if ! has_arm64 "$patched"; then
  echo "Repacked ios.zip lost the arm64 slice." >&2
  exit 1
fi
remember
