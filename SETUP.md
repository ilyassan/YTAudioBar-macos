# 🚀 YTAudioBar Setup Guide

This guide helps you get YTAudioBar running after cloning the repository.

## 📋 Prerequisites

- **macOS 13.0** or later
- **Xcode 15.0** or later  
- **Internet connection** (for downloading dependencies)

## ⚡ Quick Setup

### Step 1: Clone the Repository
```bash
git clone https://github.com/ilyassan/YTAudioBar-macos.git
cd YTAudioBar-macos
```

### Step 2: Download Dependencies
```bash
./Scripts/download-dependencies.sh
```

This will download:
- `yt-dlp` (~35MB) - For YouTube search and streaming
- `ffmpeg` (~60MB) - For audio processing and downloads

### Step 3: Open in Xcode
```bash
open YTAudioBar.xcodeproj
```

### Step 4: Build and Run
Press `⌘R` in Xcode to build and run the app.

## 🔧 Manual Alternative

If the automatic script doesn't work, you can download dependencies manually:

### Download yt-dlp
```bash
curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos -o YTAudioBar/Resources/yt-dlp
chmod +x YTAudioBar/Resources/yt-dlp
```

### Download ffmpeg
```bash
# For Apple Silicon Macs
curl -L https://evermeet.cx/ffmpeg/getrelease/arm64 -o YTAudioBar/Resources/ffmpeg
chmod +x YTAudioBar/Resources/ffmpeg

# For Intel Macs  
curl -L https://evermeet.cx/ffmpeg/getrelease/x64 -o YTAudioBar/Resources/ffmpeg
chmod +x YTAudioBar/Resources/ffmpeg
```

## ✅ Verification

After setup, your `YTAudioBar/Resources/` directory should contain:
```
YTAudioBar/Resources/
├── ffmpeg          # Audio processing binary
└── yt-dlp          # YouTube integration binary
```

Test the binaries:
```bash
./YTAudioBar/Resources/yt-dlp --version
./YTAudioBar/Resources/ffmpeg -version
```

## 🆘 Troubleshooting

### "Permission denied" errors
```bash
chmod +x Scripts/download-dependencies.sh
chmod +x YTAudioBar/Resources/yt-dlp
chmod +x YTAudioBar/Resources/ffmpeg
```

### Download failures
- Check your internet connection
- Try running the script again
- Use the manual download method above

### App crashes on launch
- Make sure both `yt-dlp` and `ffmpeg` are downloaded
- Check that binaries are executable
- Try the verification steps above

## 🎉 You're Ready!

Once setup is complete, YTAudioBar should:
- Search YouTube from the menu bar
- Stream audio without opening a browser
- Download tracks for offline listening
- Manage playlists and favorites

Happy streaming! 🎵