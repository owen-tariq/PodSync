#!/bin/bash
set -e

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
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
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
echo "Opening PodSync..."
open "$APP_DIR"
