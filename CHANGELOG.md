# Changelog

All notable changes to YTAudioBar will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial development and feature implementation

## [1.0.0] - TBD

### Added
- 🎵 **Core Audio System**
  - YouTube audio streaming with yt-dlp integration
  - AVFoundation-based audio playback with seek controls
  - Playback speed controls (0.5x to 2.0x)
  - Smart queue management with drag & drop reordering
  - Audio wave visualization with real-time rhythm sync
  - Local file playback with metadata detection

- 🔍 **Search & Discovery**
  - Integrated YouTube search functionality
  - Real-time search with instant results
  - Thumbnail display with proper aspect ratios
  - Search history and suggestions

- 💾 **Downloads & Local Storage**
  - High-quality audio downloads with yt-dlp
  - Progress tracking for download operations
  - Local file management and organization
  - Smart playback priority (local files first)
  - Download status indicators in UI

- ❤️ **Favorites & Playlists**
  - Advanced playlist system with folder navigation
  - Many-to-many track-playlist relationships
  - Drag & drop playlist organization
  - Heart button for quick favoriting
  - Playlist creation and management UI

- 🎨 **User Interface**
  - Modern macOS menu bar integration
  - Spotify-inspired minimized player design
  - Smooth infinite scrolling text for long titles
  - Collapsible player with essential controls
  - Unified track row components for consistency
  - Native SwiftUI throughout

- ⚙️ **Settings & Preferences**
  - Comprehensive settings panel
  - Automatic dependency management
  - yt-dlp auto-updates on launch
  - App update notifications
  - System preferences integration

- 🔄 **Auto-Updates & Dependencies**
  - Automatic app update checking via GitHub releases
  - Runtime dependency downloads (yt-dlp, ffmpeg)
  - First-run setup wizard for dependencies
  - Silent background updates for yt-dlp
  - Graceful fallback for missing dependencies

- 📱 **System Integration**
  - Menu bar icon with playback state indicators
  - System notifications for track changes
  - Media key support and integration
  - Proper background/foreground state handling
  - Power management optimizations

- 🏗️ **Technical Features**
  - Universal binary support (Intel + Apple Silicon)
  - Core Data for persistent storage
  - File system caching for performance
  - CPU and battery usage optimizations
  - Memory-efficient audio streaming
  - Network error handling and retries

### Technical Details
- **Minimum macOS**: 13.0 (Ventura)
- **Architecture**: Universal (Intel + Apple Silicon)
- **Dependencies**: Downloaded automatically on first launch
- **Storage**: Core Data with SQLite backend
- **Audio**: AVFoundation with hardware acceleration
- **Updates**: Automatic via GitHub releases API

### Known Issues
- First launch requires internet connection for dependencies
- Some YouTube videos may be geo-restricted
- Large playlists may take time to load initially

---

## Release Notes Format

For future releases, each version will include:

### Added
- New features and functionality

### Changed
- Changes in existing functionality

### Deprecated
- Soon-to-be removed features

### Removed
- Features removed in this version

### Fixed
- Bug fixes and issue resolutions

### Security
- Security-related improvements

---

**Note**: This is the initial release of YTAudioBar. All features listed above represent the complete v1.0.0 implementation.