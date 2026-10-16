#!/usr/bin/env bash
# Compile the HealthKit GDExtension and stage debug xcframeworks for export.
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
"${SCONS[@]}" platform=ios arch=arm64 target=template_debug ios_min_version=15.0 -j"$(sysctl -n hw.ncpu)"

HEALTHKIT_A="$(find "$SRC/bin" -type f -name 'libhealthkit*' ! -name '*.o' | head -n 1)"
GODOTCPP_A="$(find "$CPP/bin" -type f -name 'libgodot-cpp*' | head -n 1)"
if [[ -z "$HEALTHKIT_A" || -z "$GODOTCPP_A" ]]; then
  echo "Static libraries were not produced." >&2
  find "$SRC" -type f \( -name 'libhealthkit*' -o -name 'libgodot-cpp*' \) >&2 || true
  exit 1
fi
if [[ "$HEALTHKIT_A" != *.a ]]; then
  cp "$HEALTHKIT_A" "${HEALTHKIT_A}.a"
  HEALTHKIT_A="${HEALTHKIT_A}.a"
fi
if [[ "$GODOTCPP_A" != *.a ]]; then
  cp "$GODOTCPP_A" "${GODOTCPP_A}.a"
  GODOTCPP_A="${GODOTCPP_A}.a"
fi
echo "healthkit: $HEALTHKIT_A"
echo "godot-cpp: $GODOTCPP_A"

DEST="$ROOT/addons/healthkit/bin"
mkdir -p "$DEST"
bash "$ROOT/tools/make_xcframework.sh" "$HEALTHKIT_A" "$DEST/libhealthkit.ios.template_debug.xcframework"
bash "$ROOT/tools/make_xcframework.sh" "$GODOTCPP_A" "$DEST/libgodot-cpp.ios.template_debug.xcframework"
