# Sparkle Auto-Update Implementation Guide

## Overview

YTAudioBar now uses the **Sparkle framework** for seamless automatic updates. Users will receive updates silently in the background without manual DMG downloads.

## What Changed

### Before (Manual Updates)
- User clicks "Check for Updates"
- Directed to GitHub releases page
- Downloads DMG manually
- Replaces app manually

### After (Sparkle Auto-Updates)
- App checks for updates automatically on launch and every 24 hours
- Downloads updates in the background
- Installs updates silently (with user permission)
- User barely notices the update process

## Implementation Details

### 1. Sparkle Framework Integration

**File:** `YTAudioBar/AppDelegate.swift`

Added Sparkle initialization:
```swift
import Sparkle

class AppDelegate: NSObject, NSApplicationDelegate {
    private let updaterController: SPUStandardUpdaterController

    override init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        super.init()
    }
}
```

### 2. Configuration (Info.plist)

**File:** `YTAudioBar/Info.plist`

Sparkle settings:
- `SUFeedURL`: Points to appcast.xml on GitHub
- `SUEnableAutomaticChecks`: Enabled
- `SUAutomaticallyUpdate`: Enabled (silent updates)
- `SUScheduledCheckInterval`: 86400 seconds (24 hours)

### 3. Appcast Generation

**File:** `scripts/generate_appcast.py`

Automatically generates `appcast.xml` from GitHub releases:
- Fetches all releases via GitHub API
- Creates Sparkle-compatible XML feed
- Includes version info, download URLs, and release notes

### 4. GitHub Actions Automation

**File:** `.github/workflows/release.yml`

Updated to automatically:
1. Build and create DMG
2. Create GitHub release
3. Generate appcast.xml
4. Commit appcast.xml to main branch

### 5. UI Updates

**Files:**
- `YTAudioBar/AppUpdateSettingsView.swift` - Updated to use Sparkle UI
- `YTAudioBar/MenuBarContentView.swift` - Passes updater through view hierarchy
- `YTAudioBar/AppDelegate.swift` - Context menu uses Sparkle's check method

## Next Steps

### 1. Add Sparkle Package Dependency

In Xcode:
1. Open `YTAudioBar.xcodeproj`
2. Select your project → YTAudioBar target
3. Go to "Package Dependencies" tab
4. Click "+" button
5. Enter URL: `https://github.com/sparkle-project/Sparkle`
6. Select version: `2.6.4` (or latest)
7. Click "Add Package"

### 2. Add Info.plist to Project

1. In Xcode, right-click `YTAudioBar` folder
2. Add Files to "YTAudioBar"
3. Select `YTAudioBar/Info.plist`
4. Ensure it's added to the YTAudioBar target

### 3. Configure Build Settings

In Xcode → YTAudioBar target → Build Settings:
1. Search for "Info.plist File"
2. Set to: `YTAudioBar/Info.plist`

### 4. Generate Initial Appcast

```bash
cd YTAudioBar
python3 scripts/generate_appcast.py
```

This creates `appcast.xml` in the scripts directory.

### 5. Commit Appcast to Repository

```bash
git add appcast.xml scripts/generate_appcast.py YTAudioBar/Info.plist
git commit -m "feat: integrate Sparkle auto-updates with appcast generation"
git push origin main
```

### 6. Test the Integration

Build and run the app:
```bash
# In Xcode, press ⌘R to build and run
```

Check:
- App launches without errors
- Settings → App Updates section shows Sparkle UI
- Right-click menu bar icon → "Check for Updates" works
- No compilation errors

### 7. Create a New Release (Testing)

To test auto-updates:

1. **Bump version** to 1.0.3 in Xcode:
   - Project → YTAudioBar target → General
   - Update "Version" field

2. **Commit and tag**:
   ```bash
   git add .
   git commit -m "release: bump version to 1.0.3"
   git tag v1.0.3
   git push origin main
   git push origin v1.0.3
   ```

3. **GitHub Actions will**:
   - Build the app
   - Create DMG
   - Create GitHub release (draft)
   - Generate and commit appcast.xml

4. **Publish the release** on GitHub (change from draft to published)

5. **Test with older version**:
   - Install the previous version (1.0.2)
   - Launch app
   - Sparkle should detect the new version (1.0.3)
   - Update dialog should appear

## Configuration Options

### Update Frequency

In `Info.plist`, adjust `SUScheduledCheckInterval`:
- `86400` = 24 hours (current)
- `3600` = 1 hour
- `604800` = 1 week

### Silent vs. Interactive Updates

**Silent (current)**: `SUAutomaticallyUpdate` = `true`
- Downloads and installs without user interaction
- User gets notification when update completes

**Interactive**: `SUAutomaticallyUpdate` = `false`
- Shows dialog asking user permission
- User controls when to download/install

### Manual Check Frequency

In `AppDelegate.swift`, the updater checks:
1. On app launch (automatic)
2. Every 24 hours (background)
3. When user clicks "Check for Updates"

## Troubleshooting

### Sparkle Not Found Error

**Solution**: Make sure you added Sparkle via Swift Package Manager in Xcode.

### Info.plist Not Found

**Solution**:
1. Verify `YTAudioBar/Info.plist` exists
2. Check Build Settings → "Info.plist File" points to correct path
3. Ensure file is added to YTAudioBar target

### Appcast.xml 404 Error

**Solution**:
1. Generate initial appcast: `python3 scripts/generate_appcast.py`
2. Commit to main branch
3. Verify it's accessible at: https://raw.githubusercontent.com/ilyassan/YTAudioBar-macos/main/appcast.xml

### No Update Check on Launch

**Solution**:
1. Check `SUEnableAutomaticChecks` is `true` in Info.plist
2. Verify Sparkle initialization in `AppDelegate.init()`
3. Look for errors in Console.app

## Benefits of Sparkle

✅ **Automatic Updates**: No manual intervention required
✅ **Delta Updates**: Downloads only changed files (smaller, faster)
✅ **Secure**: Code signing verification
✅ **Rollback**: Can revert to previous version if needed
✅ **Battle-tested**: Used by thousands of macOS apps
✅ **Standard Practice**: Industry standard for macOS app updates

## Files Modified

- `YTAudioBar/AppDelegate.swift` - Added Sparkle initialization
- `YTAudioBar/AppUpdateSettingsView.swift` - Updated UI to use Sparkle
- `YTAudioBar/MenuBarContentView.swift` - Added updater parameter passing
- `YTAudioBar/Info.plist` - Created with Sparkle configuration
- `scripts/generate_appcast.py` - Created appcast generator
- `.github/workflows/release.yml` - Added appcast generation step

## Files to be Deprecated (Future)

Once Sparkle is confirmed working:
- `YTAudioBar/AppUpdater.swift` - Old manual update checker (can be removed)

## Resources

- [Sparkle Documentation](https://sparkle-project.org/documentation/)
- [Appcast Format](https://sparkle-project.org/documentation/publishing/)
- [Code Signing Guide](https://sparkle-project.org/documentation/code-signing/)

---

**Status**: ✅ Implementation Complete & Build Successful!

## Quick Summary

Sparkle auto-updates are now fully integrated:
- ✅ Sparkle 2.8.0 added via Swift Package Manager
- ✅ Automatic updates enabled by default (no user toggle needed)
- ✅ Checks for updates on launch and every 24 hours
- ✅ Downloads and installs updates silently in the background
- ✅ Build successful - ready for testing
