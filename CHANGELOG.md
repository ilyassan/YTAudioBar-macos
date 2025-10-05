# Changelog

All notable changes to YTAudioBar will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Future features and improvements

## [1.0.1] - 2025-10-05

### Performance Improvements
- ⚡ Optimized animations and background operations reducing CPU usage by ~70%
- 🔋 Implemented aggressive power management for better battery life
- 🎨 Replaced animated minimized player with static design to eliminate CPU-intensive wave animations
- 📱 Enhanced menu visibility detection to pause animations when popup is closed

### Bug Fixes
- 🎵 Fixed playback speed persistence when switching tracks
- 🖱️ Improved mini player button usability with larger touch targets and hover effects
- 🎯 Enhanced UI responsiveness and reduced energy impact

### Improvements
- 📦 Removed FFmpeg dependency reducing download size by 60MB (from 95MB to 15MB)
- 🤖 Implemented YouTube bot detection bypass system for improved reliability
- 📊 Added real-time progress tracking for dependency downloads on first launch
- 📋 Updated system requirements to macOS 14.0+ for better compatibility

### Documentation
- 📚 Updated README to reflect FFmpeg removal and reduced dependency footprint
- 🔧 Enhanced contribution guidelines with updated system requirements

## [1.0.0] - 2025-08-23

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