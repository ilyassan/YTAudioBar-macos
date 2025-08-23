# YTAudioBar

[![GitHub release](https://img.shields.io/github/release/yourusername/YTAudioBar-macos.svg)](https://github.com/yourusername/YTAudioBar-macos/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/yourusername/YTAudioBar-macos/total.svg)](https://github.com/yourusername/YTAudioBar-macos/releases/latest)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![macOS](https://img.shields.io/badge/macOS-13.0+-blue.svg)](https://www.apple.com/macos/)

> A modern macOS menu bar application for YouTube audio streaming and downloading

YTAudioBar transforms your Mac's menu bar into a powerful YouTube audio player. Stream music directly, download tracks for offline listening, create custom playlists, and enjoy a beautiful Spotify-inspired interface—all without leaving your workflow.

<p align="center">
  <img src="./assets/demo.gif" alt="YTAudioBar Demo" width="600">
</p>

## ✨ Features

### 🎧 Audio Streaming & Playback
- Stream YouTube audio directly in high quality
- Smart playback with local file priority
- Advanced queue management with drag & drop
- Playback speed controls and seeking
- Auto-advance with repeat modes (off/one/all)

### 📦 Download Management
- Download tracks for offline listening
- Automatic metadata and thumbnail storage
- Visual indicators for downloaded content
- Configurable audio quality settings
- Progress tracking with notifications

### 🎵 Playlist & Organization
- Create unlimited custom playlists
- Drag & drop playlist management
- Favorites system with heart button
- Many-to-many track-playlist relationships
- Folder-based playlist navigation

### 🎨 Modern Interface
- Clean, Spotify-inspired design
- Minimalist menu bar integration
- Smooth animations and transitions
- Audio visualization with waveforms
- Infinite scrolling track titles

### 🔧 Smart Features
- Automatic yt-dlp updates
- System notifications for downloads/playback
- Configurable download locations
- Native macOS integration
- Universal binary (Intel + Apple Silicon)

## 📥 Download

### Latest Release
[**Download YTAudioBar v1.0.0**](https://github.com/yourusername/YTAudioBar-macos/releases/latest)

### Installation
1. Download the latest release from the [releases page](../../releases)
2. Open the downloaded `.dmg` file
3. Drag `YTAudioBar.app` to your `Applications` folder
4. Launch YTAudioBar from Applications or Spotlight
5. Grant necessary permissions when prompted

### System Requirements
- **macOS 13.0** or later
- **~50MB** free disk space
- **Internet connection** for streaming

## 🚀 Build from Source

### Prerequisites
- Xcode 15.0 or later
- Swift 5.9 or later
- macOS 13.0 SDK or later

### Building

#### Quick Start (Recommended)
```bash
git clone https://github.com/ilyassan/YTAudioBar-macos.git
cd YTAudioBar-macos

# Download dependencies first (required for app to work)
./Scripts/download-dependencies.sh

# Open and build in Xcode
open YTAudioBar.xcodeproj
```

Press `⌘R` in Xcode to build and run the app.

#### What the script does:
- Downloads `yt-dlp` binary for YouTube integration
- Downloads `ffmpeg` binary for audio processing  
- Places binaries in `YTAudioBar/Resources/` (ignored by Git)
- Validates downloads and sets proper permissions

#### Troubleshooting
- **"No such file or directory" errors**: Run the download script first
- **Permission denied**: Make sure script is executable (`chmod +x Scripts/download-dependencies.sh`)
- **Download fails**: Check internet connection and try again

## 🛠️ Technology Stack

- **SwiftUI** - Modern declarative UI framework
- **AVFoundation** - Audio playback and processing
- **Core Data** - Local data persistence
- **Combine** - Reactive programming
- **yt-dlp** - YouTube content extraction
- **FFmpeg** - Audio processing and conversion

## 📷 Screenshots

<p align="center">
  <img src="./assets/search.png" alt="Search Interface" width="400">
  <img src="./assets/playlists.png" alt="Playlist Management" width="400">
</p>

<p align="center">
  <img src="./assets/player.png" alt="Mini Player" width="400">
  <img src="./assets/downloads.png" alt="Download Management" width="400">
</p>

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

### Development Setup
1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'feat: add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 🐛 Issues & Support

If you encounter any issues or have feature requests:
- Check the [existing issues](../../issues) to see if it's already reported
- Create a [new issue](../../issues/new) with detailed information
- Include your macOS version, app version, and steps to reproduce

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [yt-dlp](https://github.com/yt-dlp/yt-dlp) for YouTube content extraction
- [FFmpeg](https://ffmpeg.org/) for audio processing
- The Swift and macOS developer community
- [MonitorControl](https://github.com/MonitorControl/MonitorControl) for project structure inspiration

## ⭐ Star History

If you found this project useful, please consider starring it!

[![Star History Chart](https://api.star-history.com/svg?repos=yourusername/YTAudioBar-macos&type=Date)](https://star-history.com/#yourusername/YTAudioBar-macos&Date)

---

<p align="center">
  Made with ❤️ for the macOS community
</p>