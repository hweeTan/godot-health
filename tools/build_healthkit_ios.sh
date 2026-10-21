#!/usr/bin/env bash
# Compile the HealthKit GDExtension for the device and the arm64 simulator,
# then stage debug xcframeworks that contain both slices.
# Runs on macOS. godot-cpp is fetched at the commit that ships extension_api 4.7.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/native/healthkit"
CPP="$SRC/godot-cpp"
COMMIT="2bb1acf6f8ae1ce96ac7b9ba3a10b499c59c49ec"

if [[ ! -f "$CPP/SConstruct" ]]; then
  rm -rf "$CPP"
  mkdir -p "$CPP"
  git -C "$CPP" init
  git -C "$CPP" remote add origin https://github.com/godotengine/godot-cpp.git
  git -C "$CPP" fetch --depth 1 origin "$COMMIT"
  git -C "$CPP" checkout FETCH_HEAD
fi

cd "$SRC"
if command -v scons >/dev/null 2>&1; then
  SCONS=(scons)
else
  SCONS=(python3 -m scons)
fi
JOBS="$(sysctl -n hw.ncpu)"
"${SCONS[@]}" platform=ios arch=arm64 target=template_debug ios_min_version=15.0 ios_simulator=no -j"$JOBS"
"${SCONS[@]}" platform=ios arch=arm64 target=template_debug ios_min_version=15.0 ios_simulator=yes -j"$JOBS"

pick_lib() {
  local found=""
  local candidate
  for candidate in "$@"; do
    if [[ -f "$candidate" ]]; then
      found="$candidate"
      break
    fi
  done
  if [[ -z "$found" ]]; then
    echo "Missing static library. Looked for:" >&2
    printf '  %s\n' "$@" >&2
    exit 1
  fi
  if [[ "$found" != *.a ]]; then
    cp "$found" "${found}.a"
    found="${found}.a"
  fi
  echo "$found"
}

stage_pair() {
  local device_src="$1"
  local sim_src="$2"
  local staged_name="$3"
  local output="$4"
  local tmp
  tmp="$(mktemp -d)"
  mkdir -p "$tmp/device" "$tmp/simulator"
  cp "$device_src" "$tmp/device/$staged_name"
  cp "$sim_src" "$tmp/simulator/$staged_name"
  bash "$ROOT/tools/make_xcframework.sh" "$output" "$tmp/device/$staged_name" "$tmp/simulator/$staged_name"
  rm -rf "$tmp"
  local sim_dir
  sim_dir="$(find "$output" -maxdepth 1 -type d -name '*simulator*' | head -n 1)"
  local device_dir
  device_dir="$(find "$output" -maxdepth 1 -type d -name 'ios-arm64' | head -n 1)"
  if [[ -z "$sim_dir" || -z "$device_dir" ]]; then
    echo "xcframework $output is missing a device or simulator slice." >&2
    find "$output" -maxdepth 2 -print >&2
    exit 1
  fi
  local sim_archs
  sim_archs="$(lipo -archs "$sim_dir"/*.a)"
  echo "$output simulator archs: $sim_archs"
  if [[ " $sim_archs " != *" arm64 "* ]]; then
    echo "Simulator slice is missing arm64." >&2
    exit 1
  fi
}

HEALTHKIT_DEVICE="$(pick_lib \
  "$SRC/bin/libhealthkit.ios.template_debug.a" \
  "$SRC/bin/libhealthkit.ios.template_debug")"
HEALTHKIT_SIM="$(pick_lib \
  "$SRC/bin/libhealthkit.ios.template_debug.simulator.a" \
  "$SRC/bin/libhealthkit.ios.template_debug.simulator")"
GODOTCPP_DEVICE="$(pick_lib \
  "$CPP/bin/libgodot-cpp.ios.template_debug.arm64.a" \
  "$CPP/bin/libgodot-cpp.ios.template_debug.arm64")"
GODOTCPP_SIM="$(pick_lib \
  "$CPP/bin/libgodot-cpp.ios.template_debug.arm64.simulator.a" \
  "$CPP/bin/libgodot-cpp.ios.template_debug.arm64.simulator")"

echo "healthkit device: $HEALTHKIT_DEVICE"
echo "healthkit simulator: $HEALTHKIT_SIM"
echo "godot-cpp device: $GODOTCPP_DEVICE"
echo "godot-cpp simulator: $GODOTCPP_SIM"

DEST="$ROOT/addons/healthkit/bin"
mkdir -p "$DEST"
stage_pair "$HEALTHKIT_DEVICE" "$HEALTHKIT_SIM" "libhealthkit.a" \
  "$DEST/libhealthkit.ios.template_debug.xcframework"
stage_pair "$GODOTCPP_DEVICE" "$GODOTCPP_SIM" "libgodot-cpp.a" \
  "$DEST/libgodot-cpp.ios.template_debug.xcframework"
