#!/bin/zsh
# Builds the Catalyst smoke-test app against Build/GoogleCast.xcframework (run
# Scripts/make-catalyst-xcframework.sh first), launches it and prints its log.
# macOS asks for local network access the first time; allow it so discovery can work.

set -euo pipefail

HERE=${0:A:h}
ROOT=${HERE:h:h}
ARCH=${ARCH:-$(uname -m)} # ARCH=x86_64 tests the Intel slice under Rosetta
SLICE=$ROOT/Build/GoogleCast.xcframework/ios-arm64_x86_64-maccatalyst
APP=$ROOT/Build/CatalystSmokeTest.app
LOG=$ROOT/Build/CatalystSmokeTest.log

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Frameworks"

SDK=$(xcrun -sdk macosx --show-sdk-path)
IOS_SUPPORT=$SDK/System/iOSSupport

xcrun -sdk macosx swiftc "$HERE/main.swift" \
    -target $ARCH-apple-ios16.0-macabi \
    -Fsystem "$IOS_SUPPORT/System/Library/Frameworks" \
    -I "$IOS_SUPPORT/usr/lib/swift" -L "$IOS_SUPPORT/usr/lib/swift" \
    -F "$SLICE" -framework GoogleCast \
    -Xlinker -rpath -Xlinker @executable_path/../Frameworks \
    -o "$APP/Contents/MacOS/CatalystSmokeTest"

cp -R "$SLICE/GoogleCast.framework" "$APP/Contents/Frameworks/"

cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>CatalystSmokeTest</string>
    <key>CFBundleIdentifier</key><string>ca.voyagerweb.GoogleCastCatalystSmokeTest</string>
    <key>CFBundleName</key><string>CatalystSmokeTest</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>CFBundleSupportedPlatforms</key><array><string>MacOSX</string></array>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>UIDeviceFamily</key><array><integer>2</integer></array>
    <key>NSLocalNetworkUsageDescription</key><string>Discovers Cast devices on the local network.</string>
    <key>UIApplicationSceneManifest</key>
    <dict>
        <key>UIApplicationSupportsMultipleScenes</key><false/>
        <key>UISceneConfigurations</key>
        <dict>
            <key>UIWindowSceneSessionRoleApplication</key>
            <array>
                <dict>
                    <key>UISceneConfigurationName</key><string>Default</string>
                    <key>UISceneDelegateClassName</key><string>CatalystSmokeTest.SceneDelegate</string>
                </dict>
            </array>
        </dict>
    </dict>
    <key>NSBonjourServices</key>
    <array>
        <string>_googlecast._tcp</string>
        <string>_CC1AD845._googlecast._tcp</string>
    </array>
</dict>
</plist>
EOF

codesign --force --sign - "$APP/Contents/Frameworks/GoogleCast.framework"

# SANDBOX=1 signs with App Sandbox + outgoing connections, like a sandboxed Catalyst app;
# SANDBOX_INCOMING=1 also allows incoming connections.
ENTITLEMENTS=()
if [[ -n ${SANDBOX:-} ]]; then
    ENT=$ROOT/Build/CatalystSmokeTest.entitlements
    INCOMING=$([[ -n ${SANDBOX_INCOMING:-} ]] && echo true || echo false)
    cat > "$ENT" <<ENTITLEMENTS_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key><true/>
    <key>com.apple.security.network.client</key><true/>
    <key>com.apple.security.network.server</key><$INCOMING/>
</dict>
</plist>
ENTITLEMENTS_EOF
    ENTITLEMENTS=(--entitlements "$ENT")
fi
codesign --force --sign - "${ENTITLEMENTS[@]}" "$APP"

# Pass SMOKE_CONNECT="<device name>" to also start a Cast session with that device.
# Run the executable directly so its stderr is captured; the app exits by itself after ~25s.
# (only go through arch for a non-native slice; it can stop the app from becoming active)
RUN=("$APP/Contents/MacOS/CatalystSmokeTest")
[[ $ARCH != $(uname -m) ]] && RUN=(arch -$ARCH "${RUN[@]}")
"${RUN[@]}" 2>&1 | tee "$LOG" | grep '^\[smoke\]'
