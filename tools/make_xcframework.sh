#!/usr/bin/env bash
# Wrap one or more static libraries in an xcframework.
# Pass the device archive and the arm64 simulator archive. xcodebuild reads
# each archive's platform load command and writes ios-arm64 plus
# ios-arm64-simulator. A hand-written bundle is the fallback.
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "usage: $0 OUTPUT.xcframework LIBRARY.a [LIBRARY.a ...]" >&2
  exit 2
fi

OUTPUT="$1"
shift
rm -rf "$OUTPUT"

args=()
for library in "$@"; do
  args+=(-library "$library")
done

if xcodebuild -create-xcframework "${args[@]}" -output "$OUTPUT"; then
  echo "xcframework via xcodebuild: $OUTPUT"
  exit 0
fi

echo "xcodebuild -create-xcframework failed; writing the bundle by hand."

is_simulator() {
  local dump
  dump="$(vtool -show-build "$1" 2>/dev/null || true)"
  if grep -q IOSSIMULATOR <<<"$dump"; then
    return 0
  fi
  if grep -q "platform 7" <<<"$dump"; then
    return 0
  fi
  dump="$(otool -l "$1" 2>/dev/null | awk '/LC_BUILD_VERSION/{p=1} p && /platform/{print; exit}')"
  grep -q -E 'IOSSIMULATOR|[[:space:]]7$' <<<"$dump"
}

mkdir -p "$OUTPUT"
entries=()
for library in "$@"; do
  name="$(basename "$library")"
  if is_simulator "$library"; then
    ident="ios-arm64-simulator"
    variant="simulator"
  else
    ident="ios-arm64"
    variant=""
  fi
  if [[ -e "$OUTPUT/$ident" ]]; then
    echo "Two libraries classified as $ident." >&2
    exit 1
  fi
  mkdir -p "$OUTPUT/$ident"
  cp "$library" "$OUTPUT/$ident/$name"
  entries+=("$ident|$name|$variant")
done

python3 - "$OUTPUT/Info.plist" "${entries[@]}" <<'PY'
import plistlib
import sys

path = sys.argv[1]
libs = []
for item in sys.argv[2:]:
    ident, name, variant = item.split("|", 2)
    entry = {
        "BinaryPath": name,
        "LibraryIdentifier": ident,
        "LibraryPath": name,
        "SupportedArchitectures": ["arm64"],
        "SupportedPlatform": "ios",
    }
    if variant:
        entry["SupportedPlatformVariant"] = variant
    libs.append(entry)

plistlib.dump(
    {
        "AvailableLibraries": libs,
        "CFBundlePackageType": "XFWK",
        "XCFrameworkFormatVersion": "1.0",
    },
    open(path, "wb"),
    fmt=plistlib.FMT_XML,
)
PY
echo "Hand-written xcframework: $OUTPUT"
