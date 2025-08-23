# Contributing to YTAudioBar

Thank you for your interest in contributing to YTAudioBar! This document provides guidelines and information for contributors.

## 🚀 Getting Started

### Prerequisites
- **macOS**: 13.0 (Ventura) or later
- **Xcode**: 15.0 or later
- **Git**: Latest version
- **GitHub account**: For submitting contributions

### Setting Up Development Environment

1. **Fork the repository**
   ```bash
   # Fork on GitHub, then clone your fork
   git clone https://github.com/YOUR_USERNAME/YTAudioBar-macos.git
   cd YTAudioBar-macos
   ```

2. **Open in Xcode**
   ```bash
   open YTAudioBar.xcodeproj
   ```

3. **First run setup**
   - Launch the app from Xcode
   - Allow dependency downloads (yt-dlp, ffmpeg) on first launch
   - Dependencies are downloaded to `~/Library/Application Support/com.ilyass.YTAudioBar/Resources/`

## 🛠️ Development Workflow

### Creating a Feature or Fix

1. **Create a feature branch**
   ```bash
   git checkout -b feature/your-feature-name
   # or
   git checkout -b fix/issue-description
   ```

2. **Make your changes**
   - Follow existing code style and conventions
   - Write clear, descriptive commit messages
   - Test your changes thoroughly

3. **Test your changes**
   ```bash
   # Build and test locally
   # Verify app functionality
   # Test on different macOS versions if possible
   ```

4. **Commit and push**
   ```bash
   git add .
   git commit -m "Add feature: playlist export functionality"
   git push origin feature/your-feature-name
   ```

5. **Create Pull Request**
   - Use the GitHub web interface
   - Fill out the PR template completely
   - Link any related issues

## 📋 Contribution Guidelines

### Code Style

- **Swift**: Follow Swift naming conventions and best practices
- **SwiftUI**: Use modern SwiftUI patterns when possible
- **Architecture**: Maintain separation between UI, business logic, and data layers
- **Comments**: Add comments for complex logic, avoid obvious comments
- **Formatting**: Use Xcode's default formatting (4 spaces, no tabs)

### Commit Messages

Use clear, descriptive commit messages:
```bash
# Good examples
git commit -m "Add playlist export to CSV functionality"
git commit -m "Fix audio stuttering on M1 Macs"
git commit -m "Update yt-dlp dependency to latest version"

# Avoid
git commit -m "Fix bug"
git commit -m "Update"
git commit -m "WIP"
```

### Pull Request Requirements

- **One feature per PR**: Keep PRs focused and atomic
- **Tests**: Ensure your changes don't break existing functionality
- **Documentation**: Update README or other docs if needed
- **Code review**: Be responsive to feedback and discussions
- **CI/CD**: Ensure all GitHub Actions checks pass

## 🐛 Reporting Issues

### Bug Reports
Use the [Bug Report template](.github/ISSUE_TEMPLATE/bug_report.yml) and include:
- YTAudioBar version
- macOS version and Mac chip (Intel/Apple Silicon)
- Steps to reproduce
- Expected vs actual behavior
- Console logs if applicable

### Feature Requests
Use the [Feature Request template](.github/ISSUE_TEMPLATE/feature_request.yml) and include:
- Clear description of the feature
- Use case and benefits
- Possible implementation approach (if known)

### Performance Issues
Use the [Performance Issue template](.github/ISSUE_TEMPLATE/performance_issue.yml) for:
- High CPU/memory usage
- Battery drain
- UI lag or stuttering
- Audio playback issues

## 🏗️ Project Structure

```
YTAudioBar/
├── YTAudioBar/
│   ├── AppDelegate.swift          # App lifecycle and menu bar setup
│   ├── MenuBarContentView.swift   # Main UI container
│   ├── AudioManager.swift         # Audio playback and streaming
│   ├── YTDLPManager.swift        # YouTube integration
│   ├── DownloadManager.swift     # Audio downloads
│   ├── FavoritesManager.swift    # Playlist and favorites
│   ├── DependencyManager.swift   # Runtime dependency management
│   ├── AppUpdater.swift          # Automatic app updates
│   └── ...
├── .github/                      # GitHub templates and workflows
├── README.md
├── CHANGELOG.md
└── CONTRIBUTING.md
```

## 🔧 Key Technologies

- **Swift/SwiftUI**: Modern declarative UI framework
- **AVFoundation**: Audio playback and processing
- **Core Data**: Local data persistence
- **yt-dlp**: YouTube video/audio extraction
- **ffmpeg**: Audio processing and conversion
- **Combine**: Reactive programming for data flow

## 🌟 Areas for Contribution

### High Priority
- **Keyboard shortcuts**: Global hotkeys for play/pause/skip
- **Search filters**: Filter by duration, upload date, etc.
- **Playlist import/export**: Support for various formats
- **Performance optimizations**: Memory usage, battery life
- **Accessibility**: VoiceOver support, high contrast

### Medium Priority
- **Dark mode**: System appearance integration
- **Mini player**: Compact floating window
- **Custom themes**: User-customizable colors
- **Lyrics support**: Display synchronized lyrics
- **equalizer**: Audio enhancement controls

### Documentation
- **Code documentation**: Improve inline documentation
- **User guides**: Usage tutorials and tips
- **Developer docs**: Architecture and API documentation
- **Localization**: Support for multiple languages

## 🤝 Community Guidelines

### Code of Conduct
- Be respectful and inclusive
- Focus on constructive feedback
- Help newcomers and answer questions
- Follow GitHub's community guidelines

### Communication
- **Issues**: For bug reports and feature requests
- **Discussions**: For questions and general topics
- **Pull Requests**: For code contributions and reviews

## 🚀 Release Process

Releases are automated through GitHub Actions:

1. **Regular development**: Push to `main` branch triggers CI/CD
2. **Creating releases**: Push version tags (`v1.0.1`) triggers release builds
3. **Release artifacts**: DMG files are automatically created and published

Contributors don't need to worry about the release process - maintainers handle version tags and releases.

## 📞 Getting Help

- **GitHub Issues**: For bugs and feature requests
- **GitHub Discussions**: For questions and community chat
- **Code Review**: Ask for feedback in pull requests
- **Documentation**: Check README and inline code comments

## 📄 License

By contributing to YTAudioBar, you agree that your contributions will be licensed under the same license as the project.

---

Thank you for contributing to YTAudioBar! Your help makes this project better for everyone. 🎵