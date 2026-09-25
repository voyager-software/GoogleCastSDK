#!/bin/zsh
# EXPERIMENTAL: adds an unofficial Mac Catalyst slice to Google's GoogleCast.xcframework.
#
# Google only ships iOS device and iOS simulator slices. This script retags the iOS
# arm64 (device) and x86_64 (simulator) binaries as Mac Catalyst with vtool, repackages
# them as a versioned macOS-style framework and appends it to the xcframework.
# Nothing is recompiled, so anything the SDK does that is iOS-only may still fail at runtime.
#
# Usage: Scripts/make-catalyst-xcframework.sh [version]   (default 4.8.6)
# Output: Build/GoogleCast.xcframework and Build/GoogleCastSDK-ios-<version>_dynamic_catalyst.zip

set -euo pipefail

VERSION=${1:-4.8.6}
CATALYST_MIN=16.0 # Mac Catalyst uses iOS version numbers in LC_BUILD_VERSION
MACOS_MIN=13.0    # macOS release matching Mac Catalyst 16
ROOT=${0:A:h:h}
OUT=$ROOT/Build
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

ZIP_NAME=GoogleCastSDK-ios-${VERSION}_dynamic.zip
echo "Downloading $ZIP_NAME"
curl -fsSL -o "$WORK/$ZIP_NAME" "https://dl.google.com/dl/chromecast/sdk/ios/$ZIP_NAME"
unzip -q "$WORK/$ZIP_NAME" -d "$WORK/src"
XCF=$(find "$WORK/src" -name GoogleCast.xcframework -maxdepth 3 | head -1)
DEVICE=$XCF/ios-arm64/GoogleCast.framework
SIM=$XCF/ios-arm64_x86_64-simulator/GoogleCast.framework

# 1. Retag binaries: arm64 from the device slice, x86_64 from the simulator slice.
SDK_VERSION=$(vtool -show-build "$DEVICE/GoogleCast" | awk '/sdk/ {print $2; exit}')
vtool -set-build-version maccatalyst $CATALYST_MIN $SDK_VERSION -replace \
    -output "$WORK/GoogleCast-arm64" "$DEVICE/GoogleCast"
lipo "$SIM/GoogleCast" -thin x86_64 -output "$WORK/GoogleCast-x86_64-sim"
vtool -set-build-version maccatalyst $CATALYST_MIN $SDK_VERSION -replace \
    -output "$WORK/GoogleCast-x86_64" "$WORK/GoogleCast-x86_64-sim"

# 2. Build a versioned (macOS layout) framework; Catalyst frameworks can't be flat.
CAT=$WORK/catalyst/GoogleCast.framework
A=$CAT/Versions/A
mkdir -p "$A/Resources"
lipo -create "$WORK/GoogleCast-arm64" "$WORK/GoogleCast-x86_64" -output "$A/GoogleCast"
cp -R "$DEVICE/Headers" "$DEVICE/Modules" "$A/"
for item in "$DEVICE"/*.bundle "$DEVICE/PrivacyInfo.xcprivacy"; do
    cp -R "$item" "$A/Resources/"
done

PLIST=$A/Resources/Info.plist
cp "$DEVICE/Info.plist" "$PLIST"
plutil -convert xml1 "$PLIST"
plutil -replace CFBundleSupportedPlatforms -json '["MacOSX"]' "$PLIST"
plutil -replace DTPlatformName -string macosx "$PLIST"
plutil -replace LSMinimumSystemVersion -string $MACOS_MIN "$PLIST"
plutil -remove MinimumOSVersion "$PLIST"
plutil -remove DTSDKName "$PLIST"

ln -s A "$CAT/Versions/Current"
for link in GoogleCast Headers Modules Resources; do
    ln -s Versions/Current/$link "$CAT/$link"
done

# 3. Assemble the new xcframework from all three slices.
rm -rf "$OUT/GoogleCast.xcframework"
mkdir -p "$OUT"
xcodebuild -create-xcframework \
    -framework "$DEVICE" \
    -framework "$SIM" \
    -framework "$CAT" \
    -output "$OUT/GoogleCast.xcframework" >/dev/null

# 4. Zip for use as a SwiftPM binary target (symlinks preserved).
ZIP_OUT=$OUT/GoogleCastSDK-ios-${VERSION}_dynamic_catalyst.zip
rm -f "$ZIP_OUT"
(cd "$OUT" && zip -qry "$ZIP_OUT" GoogleCast.xcframework)

echo "Created $OUT/GoogleCast.xcframework"
echo "Created $ZIP_OUT"
echo "Checksum: $(cd "$ROOT" && swift package compute-checksum "$ZIP_OUT")"
