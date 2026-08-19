#!/bin/bash
set -e

# App version — keep in sync with Sources/PodSync/AppInfo.swift
VERSION="2.1.0"
BUILD="4"

echo "Building PodSync..."
swift build -c release

echo "Packaging PodSync.app..."
APP_DIR="PodSync.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
FRAMEWORKS_DIR="$CONTENTS_DIR/Frameworks"

# Clean up old app
rm -rf "$APP_DIR"

# Create directories
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"
mkdir -p "$FRAMEWORKS_DIR"

# Copy executable
cp .build/release/PodSync "$MACOS_DIR/"

# Copy Frameworks
cp -R Frameworks/LibGPod.framework "$FRAMEWORKS_DIR/"

# Copy app icon
if [ -f "AppIcon.icns" ]; then
    cp AppIcon.icns "$RESOURCES_DIR/AppIcon.icns"
    echo "App icon copied."
fi

# Create Info.plist
cat > "$CONTENTS_DIR/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>PodSync</string>
    <key>CFBundleIdentifier</key>
    <string>com.spencer.podsync</string>
    <key>CFBundleName</key>
    <string>PodSync</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$BUILD</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

# Sign the app (required on modern macOS)
echo "Code signing the app..."
codesign --force --deep --sign - "$APP_DIR"

echo "App bundle created successfully at $APP_DIR"

# --- CI on main: one-shot maintenance scripts ---
if [ -n "$CI" ] && [ "${GITHUB_REF:-}" = "refs/heads/main" ] && [ -f scripts/refresh_screenshots.sh ]; then
    bash scripts/refresh_screenshots.sh || echo "screenshot refresh failed (non-fatal)"
fi

# --- CI on main: build DMG and publish/update the GitHub release ---
if [ -n "$CI" ] && [ "${GITHUB_REF:-}" = "refs/heads/main" ]; then
    echo "Building release DMG..."
    rm -rf release_dist
    mkdir -p release_dist/dmg
    cp -R "$APP_DIR" release_dist/dmg/
    ln -s /Applications release_dist/dmg/Applications
    hdiutil create -volname "PodSync" -srcfolder release_dist/dmg -ov -format UDZO release_dist/PodSync.dmg

    echo "Publishing GitHub release v$VERSION..."
    # Use the credentials actions/checkout persisted for this job
    B64=$(git config --get http.https://github.com/.extraheader | awk '{print $3}')
    GH_TOKEN=$(printf '%s' "$B64" | python3 -c 'import sys,base64; print(base64.b64decode(sys.stdin.read()).decode().split(":",1)[1])')
    export GH_TOKEN

    NOTES="PodSync v$VERSION — Podcast manager (search, subscribe, download, per-show retention), playlists + smart playlists, Spotify-style auto mixes built from your listening history, Genius mix from any song, on-device metadata editing with batch edit, artwork lookup + configurable artwork resize, persistent library folders, sync plan preview with duplicate detection, multi-format conversion (FLAC/WAV/AIFF built-in; OGG/Opus/WMA + MP3 via ffmpeg), sortable columns, Settings window. Install: open the DMG, drag PodSync to Applications, then run: xattr -cr /Applications/PodSync.app"

    if gh release view "v$VERSION" --repo "${GITHUB_REPOSITORY}" >/dev/null 2>&1; then
        gh release upload "v$VERSION" release_dist/PodSync.dmg --repo "${GITHUB_REPOSITORY}" --clobber
        echo "Release v$VERSION updated with fresh DMG."
    else
        gh release create "v$VERSION" release_dist/PodSync.dmg \
            --repo "${GITHUB_REPOSITORY}" \
            --title "PodSync v$VERSION" \
            --notes "$NOTES" \
            --latest
        echo "Release v$VERSION published."
    fi
fi

if [ -z "$CI" ]; then
    echo "Opening PodSync..."
    open "$APP_DIR"
fi
