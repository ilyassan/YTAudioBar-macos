#!/bin/bash

# Professional DMG Creator for YTAudioBar
# Creates a beautiful DMG with custom background and layout using create-dmg

set -e

# Configuration
APP_NAME="YTAudioBar"
VERSION="${1:-1.0.0}"
APP_PATH="build/export/${APP_NAME}.app"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
DMG_TEMP_DIR="build/dmg_temp"

echo "💿 Creating Professional DMG for ${APP_NAME} v${VERSION}"
echo "=================================================="

# Check if app exists
if [ ! -d "$APP_PATH" ]; then
    echo "❌ App not found at: $APP_PATH"
    echo "💡 Make sure to build and export the app first"
    exit 1
fi

# Check if create-dmg is available
if ! command -v /opt/homebrew/bin/create-dmg >/dev/null 2>&1; then
    echo "❌ create-dmg not found. Please install it:"
    echo "    brew install create-dmg"
    exit 1
fi

# Create temporary DMG directory
echo "📁 Setting up DMG structure..."
rm -rf "$DMG_TEMP_DIR"
mkdir -p "$DMG_TEMP_DIR"

# Copy app to DMG temp directory
echo "📦 Copying app bundle..."
cp -R "$APP_PATH" "$DMG_TEMP_DIR/"

# Create custom background with Python (white to light red gradient)
echo "🎨 Creating custom background..."
python3 -c "
from PIL import Image, ImageDraw
import os

# Create DMG background (800x450) with white to light red gradient
img = Image.new('RGB', (800, 450), (255, 255, 255))
draw = ImageDraw.Draw(img)

# Light red gradient from white to very light red
for y in range(450):
    gradient_factor = y / 450
    red = int(255 - (gradient_factor * 15))     # Very subtle red tint
    green = int(255 - (gradient_factor * 20))   # Slight reduction in green
    blue = int(255 - (gradient_factor * 20))    # Slight reduction in blue
    color = (red, green, blue)
    draw.line([(0, y), (800, y)], fill=color)

# Save background
os.makedirs('$DMG_TEMP_DIR/.background', exist_ok=True)
img.save('$DMG_TEMP_DIR/.background/background.png', 'PNG')
print('✅ DMG background generated')
"

# Get app icon for DMG volume (use the 512x512 version)
APP_ICON_PATH="YTAudioBar/Assets.xcassets/AppIcon.appiconset/icon_512x512.png"
if [ -f "$APP_ICON_PATH" ]; then
    echo "🎯 Using app icon for DMG volume..."
    VOLUME_ICON_PATH="$DMG_TEMP_DIR/.VolumeIcon.icns"
    
    # Convert PNG to ICNS (requires iconutil on macOS)
    echo "🔄 Converting app icon to ICNS format..."
    
    # Create temporary iconset
    ICONSET_DIR="build/temp.iconset"
    rm -rf "$ICONSET_DIR"
    mkdir -p "$ICONSET_DIR"
    
    # Copy our generated icons to iconset format
    cp "YTAudioBar/Assets.xcassets/AppIcon.appiconset/icon_16x16.png" "$ICONSET_DIR/icon_16x16.png"
    cp "YTAudioBar/Assets.xcassets/AppIcon.appiconset/icon_16x16@2x.png" "$ICONSET_DIR/icon_16x16@2x.png"
    cp "YTAudioBar/Assets.xcassets/AppIcon.appiconset/icon_32x32.png" "$ICONSET_DIR/icon_32x32.png"
    cp "YTAudioBar/Assets.xcassets/AppIcon.appiconset/icon_32x32@2x.png" "$ICONSET_DIR/icon_32x32@2x.png"
    cp "YTAudioBar/Assets.xcassets/AppIcon.appiconset/icon_128x128.png" "$ICONSET_DIR/icon_128x128.png"
    cp "YTAudioBar/Assets.xcassets/AppIcon.appiconset/icon_128x128@2x.png" "$ICONSET_DIR/icon_128x128@2x.png"
    cp "YTAudioBar/Assets.xcassets/AppIcon.appiconset/icon_256x256.png" "$ICONSET_DIR/icon_256x256.png"
    cp "YTAudioBar/Assets.xcassets/AppIcon.appiconset/icon_256x256@2x.png" "$ICONSET_DIR/icon_256x256@2x.png"
    cp "YTAudioBar/Assets.xcassets/AppIcon.appiconset/icon_512x512.png" "$ICONSET_DIR/icon_512x512.png"
    cp "YTAudioBar/Assets.xcassets/AppIcon.appiconset/icon_512x512@2x.png" "$ICONSET_DIR/icon_512x512@2x.png"
    
    # Create ICNS file
    iconutil -c icns "$ICONSET_DIR" -o "$VOLUME_ICON_PATH"
    
    # Clean up
    rm -rf "$ICONSET_DIR"
    
    echo "✅ Volume icon created"
else
    echo "⚠️  App icon not found, using default volume icon"
    VOLUME_ICON_PATH=""
fi

# Create the professional DMG
echo "🔨 Creating professional DMG with create-dmg..."

# Remove existing DMG
rm -f "$DMG_NAME"

# Create professional DMG with custom layout
VOLUME_ICON_ARG=""
if [ -n "$VOLUME_ICON_PATH" ] && [ -f "$VOLUME_ICON_PATH" ]; then
    VOLUME_ICON_ARG="--volicon $VOLUME_ICON_PATH"
fi

/opt/homebrew/bin/create-dmg \
    --volname "${APP_NAME} ${VERSION}" \
    $VOLUME_ICON_ARG \
    --background "$DMG_TEMP_DIR/.background/background.png" \
    --window-pos 200 120 \
    --window-size 800 450 \
    --icon-size 100 \
    --icon "${APP_NAME}.app" 200 190 \
    --hide-extension "${APP_NAME}.app" \
    --app-drop-link 600 185 \
    --format UDZO \
    "$DMG_NAME" \
    "$DMG_TEMP_DIR"

# Verify DMG was created
if [ -f "$DMG_NAME" ]; then
    echo "✅ DMG created successfully!"
    echo "📁 File: $DMG_NAME"
    echo "📏 Size: $(du -h "$DMG_NAME" | cut -f1)"
    
    # Test mount the DMG to verify it works
    echo "🧪 Testing DMG mount..."
    hdiutil attach "$DMG_NAME" -readonly -nobrowse -mountpoint "/tmp/ytaudiobar_test" >/dev/null
    
    if [ -d "/tmp/ytaudiobar_test/${APP_NAME}.app" ]; then
        echo "✅ DMG mounts correctly and app is accessible"
        hdiutil detach "/tmp/ytaudiobar_test" >/dev/null
    else
        echo "❌ DMG mount test failed"
        hdiutil detach "/tmp/ytaudiobar_test" >/dev/null 2>/dev/null || true
        exit 1
    fi
    
else
    echo "❌ DMG creation failed"
    exit 1
fi

# Clean up temporary files
echo "🧹 Cleaning up..."
rm -rf "$DMG_TEMP_DIR"

echo ""
echo "🎉 Professional DMG created successfully!"
echo "📦 ${DMG_NAME}"
echo "🎨 Features:"
echo "   • Custom white/red gradient background"
echo "   • Professional layout with drag-to-Applications"
echo "   • Custom volume icon"
echo "   • Optimized compression"
echo ""
echo "🚀 Ready for distribution!"