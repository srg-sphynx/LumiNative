#!/bin/bash
set -e

# Define variables
# Define variables
APP_NAME="MonitorControlV3"
BUILD_TARGET="MonitorControlV3" # Executable name from Package.swift
BUILD_DIR=".build/release"
APP_BUNDLE="$APP_NAME.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "🚀 Building Release version..."
swift build -c release --arch arm64

echo "📦 Creating App Bundle Structure..."
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

echo "📋 Copying Executable..."
cp "$BUILD_DIR/$BUILD_TARGET" "$MACOS_DIR/$APP_NAME"

echo "📝 Creating Info.plist..."
cat > "$CONTENTS_DIR/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.luminative.app</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleShortVersionString</key>
    <string>3.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
EOF

# Check for Icon
ICON_SOURCE="app_icon.png"
if [ -f "$ICON_SOURCE" ]; then
    echo "🖼️  Processing Icon..."
    # Create an iconset folder
    rm -rf LumiNative.iconset
    mkdir LumiNative.iconset
    sips -s format png -z 16 16     "$ICON_SOURCE" --out LumiNative.iconset/icon_16x16.png 
    sips -s format png -z 32 32     "$ICON_SOURCE" --out LumiNative.iconset/icon_16x16@2x.png 
    sips -s format png -z 32 32     "$ICON_SOURCE" --out LumiNative.iconset/icon_32x32.png 
    sips -s format png -z 64 64     "$ICON_SOURCE" --out LumiNative.iconset/icon_32x32@2x.png 
    sips -s format png -z 128 128   "$ICON_SOURCE" --out LumiNative.iconset/icon_128x128.png 
    sips -s format png -z 256 256   "$ICON_SOURCE" --out LumiNative.iconset/icon_128x128@2x.png 
    sips -s format png -z 256 256   "$ICON_SOURCE" --out LumiNative.iconset/icon_256x256.png 
    sips -s format png -z 512 512   "$ICON_SOURCE" --out LumiNative.iconset/icon_512x512.png 
    sips -s format png -z 512 512   "$ICON_SOURCE" --out LumiNative.iconset/icon_512x512@2x.png 
    sips -s format png -z 1024 1024 "$ICON_SOURCE" --out LumiNative.iconset/icon_512x512@2x.png 
    
    iconutil -c icns LumiNative.iconset
    mv LumiNative.icns "$RESOURCES_DIR/AppIcon.icns"
    rm -rf LumiNative.iconset
else
    echo "⚠️  No app_icon.png found. Skipping icon generation."
fi

echo "✅ App bundle created at $APP_BUNDLE"

echo "🔏 Ad-hoc signing (for local distribution)..."
codesign --force --deep --sign - "$APP_BUNDLE"

# ---------------------------------------------------------
# DMG Creation
# ---------------------------------------------------------
DMG_NAME="LumiNative_Installer.dmg"
DIST_DIR="dist"

echo "💿 Preparing DMG distribution..."
rm -rf "$DIST_DIR" "$DMG_NAME"
mkdir -p "$DIST_DIR"

# Generate PDF Documentation
echo "📄 Generating PDF Documentation..."
if [ -f "scripts/pdf_gen.swift" ]; then
    # User Manual
    swift scripts/pdf_gen.swift "$(pwd)/docs/manual.html" "$(pwd)/$DIST_DIR/User Manual.pdf"
    
    # Build Log
    swift scripts/pdf_gen.swift "$(pwd)/docs/build_log.html" "$(pwd)/$DIST_DIR/Build Log.pdf"
else
    echo "⚠️  PDF Generator script not found. Using Markdown README."
    cp "README.md" "$DIST_DIR/"
fi

# Copy App
cp -r "$APP_BUNDLE" "$DIST_DIR/"

# Create /Applications symlink for drag-and-drop
ln -s /Applications "$DIST_DIR/Applications"

echo "💿 creating .dmg volume..."
hdiutil create -volname "MonitorControl" -srcfolder "$DIST_DIR" -ov -format UDZO "$DMG_NAME"

echo "🧹 Cleanup..."
rm -rf "$DIST_DIR"

echo "🎉 Distribution ready: $DMG_NAME"

# Move to Applications (Local Install)
echo "📂 Moving to /Applications (Local Install)..."
rm -rf "/Applications/$APP_BUNDLE"
cp -r "$APP_BUNDLE" "/Applications/"
echo "✅ Installed locally."

# Deliver to Downloads
# Deliver to Downloads
TARGET_DMG="$HOME/Downloads/MonitorControl_V3.0.0.dmg"
cp "$DMG_NAME" "$TARGET_DMG"
echo "🚀 Final Release Saved to: $TARGET_DMG"

