#!/bin/bash

# Script to download ffmpeg binaries for YTAudioBar
# This script downloads pre-built ffmpeg binaries for both Intel and ARM architectures

set -e

echo "🎬 Downloading FFmpeg binaries for YTAudioBar..."

# Create Resources directory if it doesn't exist
mkdir -p YTAudioBar/Resources

# FFmpeg version to download (you can update this)
FFMPEG_VERSION="6.1.1"

# Download URLs for pre-built ffmpeg binaries
# Using evermeet.cx which provides static builds
FFMPEG_INTEL_URL="https://evermeet.cx/ffmpeg/getrelease/ffmpeg/zip"
FFPROBE_INTEL_URL="https://evermeet.cx/ffmpeg/getrelease/ffprobe/zip"

echo "📥 Downloading Intel (x86_64) binaries..."

# Download Intel ffmpeg
curl -L "$FFMPEG_INTEL_URL" -o ffmpeg-intel.zip
unzip -q ffmpeg-intel.zip
mv ffmpeg YTAudioBar/Resources/ffmpeg-x86_64
chmod +x YTAudioBar/Resources/ffmpeg-x86_64
rm ffmpeg-intel.zip

# Download Intel ffprobe
curl -L "$FFPROBE_INTEL_URL" -o ffprobe-intel.zip
unzip -q ffprobe-intel.zip  
mv ffprobe YTAudioBar/Resources/ffprobe-x86_64
chmod +x YTAudioBar/Resources/ffprobe-x86_64
rm ffprobe-intel.zip

echo "📥 Creating universal binaries..."

# For ARM, we'll use the same Intel binary with Rosetta 2 translation
# This is simpler than building native ARM ffmpeg
cp YTAudioBar/Resources/ffmpeg-x86_64 YTAudioBar/Resources/ffmpeg-arm64
cp YTAudioBar/Resources/ffprobe-x86_64 YTAudioBar/Resources/ffprobe-arm64

echo "✅ FFmpeg binaries downloaded successfully!"
echo "Files created:"
echo "  - YTAudioBar/Resources/ffmpeg-x86_64"
echo "  - YTAudioBar/Resources/ffprobe-x86_64"
echo "  - YTAudioBar/Resources/ffmpeg-arm64"
echo "  - YTAudioBar/Resources/ffprobe-arm64"

echo ""
echo "⚠️  Note: ARM binaries are x86_64 binaries that will run under Rosetta 2"
echo "   This provides compatibility while maintaining app size efficiency."

# Verify the binaries work
echo ""
echo "🔍 Verifying binaries..."
YTAudioBar/Resources/ffmpeg-x86_64 -version | head -1
YTAudioBar/Resources/ffprobe-x86_64 -version | head -1

echo ""
echo "🎉 Setup complete! FFmpeg binaries are ready for bundling with YTAudioBar."