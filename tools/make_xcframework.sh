#!/usr/bin/env bash
# Wrap one iOS device static library in an xcframework.
# xcodebuild is preferred. A hand-written bundle is the fallback when the
# object file has no platform load command xcodebuild will accept.
set -euo pipefail

LIBRARY="$1"
OUTPUT="$2"
rm -rf "$OUTPUT"

if xcodebuild -create-xcframework -library "$LIBRARY" -output "$OUTPUT"; then
  echo "xcframework via xcodebuild: $OUTPUT"
  exit 0
fi

echo "xcodebuild -create-xcframework failed; writing a device-only xcframework."
SLICE="$OUTPUT/ios-arm64"
mkdir -p "$SLICE"
cp "$LIBRARY" "$SLICE/$(basename "$LIBRARY")"
cat > "$OUTPUT/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>AvailableLibraries</key>
  <array>
    <dict>
      <key>BinaryPath</key>
      <string>LIBRARY_NAME</string>
      <key>LibraryIdentifier</key>
      <string>ios-arm64</string>
      <key>LibraryPath</key>
      <string>LIBRARY_NAME</string>
      <key>SupportedArchitectures</key>
      <array>
        <string>arm64</string>
      </array>
      <key>SupportedPlatform</key>
      <string>ios</string>
    </dict>
  </array>
  <key>CFBundlePackageType</key>
  <string>XFWK</string>
  <key>XCFrameworkFormatVersion</key>
  <string>1.0</string>
</dict>
</plist>
EOF
NAME="$(basename "$LIBRARY")"
sed -i.bak "s/LIBRARY_NAME/${NAME}/g" "$OUTPUT/Info.plist"
rm -f "$OUTPUT/Info.plist.bak"
echo "Hand-written xcframework: $OUTPUT"
