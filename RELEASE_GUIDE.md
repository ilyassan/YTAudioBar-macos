# 🚀 YTAudioBar Release Guide

This guide will walk you through the complete process of releasing a new version of YTAudioBar.

## 📋 Prerequisites

Before starting a release, ensure:
- All features/fixes are completed and tested
- The app builds successfully locally
- You have push access to the GitHub repository
- You're on the `main` branch with latest changes

## 🔢 Version Types

Choose the appropriate version bump based on changes:

- **Patch (x.x.X)**: Bug fixes, small improvements, security patches
  - Example: 1.0.1 → 1.0.2
- **Minor (x.X.x)**: New features, non-breaking changes
  - Example: 1.0.2 → 1.1.0  
- **Major (X.x.x)**: Breaking changes, major redesigns
  - Example: 1.1.0 → 2.0.0

## 📝 Step-by-Step Release Process

### Step 1: Update Version Numbers

#### 1.1 Update Xcode Project Settings

**File to modify:** `YTAudioBar.xcodeproj/project.pbxproj`

**What to change:**
```diff
- MARKETING_VERSION = 1.0.2;
+ MARKETING_VERSION = 1.0.3;

- CURRENT_PROJECT_VERSION = 2;
+ CURRENT_PROJECT_VERSION = 3;
```

**How to do it:**
```bash
# Option A: Use find and replace in your editor
# Search for: MARKETING_VERSION = 1.0.2;
# Replace with: MARKETING_VERSION = 1.0.3;
# Search for: CURRENT_PROJECT_VERSION = 2;
# Replace with: CURRENT_PROJECT_VERSION = 3;

# Option B: Use sed command (replace X.X.X with your new version)
sed -i '' 's/MARKETING_VERSION = [0-9]*\.[0-9]*\.[0-9]*;/MARKETING_VERSION = X.X.X;/g' YTAudioBar.xcodeproj/project.pbxproj
```

**Why this is needed:**
- `MARKETING_VERSION`: The user-facing version number (e.g., "1.0.3")
- `CURRENT_PROJECT_VERSION`: Build number, should increment with each release
- These values populate `CFBundleShortVersionString` and `CFBundleVersion` in the app bundle
- The auto-update system reads these values to determine if an update is available

#### 1.2 Verify Version Display

The following files automatically read from the bundle, so **NO manual changes needed**:
- `AppDelegate.swift` (About dialog)
- `AppUpdateSettingsView.swift` (Settings UI)
- `AppUpdater.swift` (Update checker)
- `MenuBarContentView.swift` (About section)

### Step 2: Test the Build

**Verify the version is correct:**
```bash
# Build the project
xcodebuild -project YTAudioBar.xcodeproj -scheme YTAudioBar -configuration Release clean build

# Check the built app's version
plutil -p "~/Library/Developer/Xcode/DerivedData/YTAudioBar-*/Build/Products/Release/YTAudioBar.app/Contents/Info.plist" | grep -E "(CFBundleShortVersionString|CFBundleVersion)"
```

**Expected output:**
```
"CFBundleShortVersionString" => "1.0.3"
"CFBundleVersion" => "3"
```

### Step 3: Create Release Commit

#### 3.1 Stage Changes
```bash
git add YTAudioBar.xcodeproj/project.pbxproj
```

#### 3.2 Commit with Proper Message
```bash
git commit -m "release: bump version to X.X.X"
```

**Commit message structure:**
- **Format**: `release: bump version to X.X.X`
- **Why this format**: 
  - `release:` prefix clearly identifies release commits
  - Consistent format makes it easy to find release commits in history
  - Simple and descriptive

#### 3.3 Push to Main Branch
```bash
git push origin main
```

**Why push first:**
- Ensures the release commit is in the main branch
- Triggers initial CI checks
- Creates a clean history before tagging

### Step 4: Create and Push Git Tag

#### 4.1 Create the Tag
```bash
git tag vX.X.X
```

**Examples:**
```bash
git tag v1.0.3
git tag v1.1.0
git tag v2.0.0
```

**Tag naming convention:**
- **Format**: `vX.X.X` (with lowercase 'v' prefix)
- **Why 'v' prefix**: Standard convention for version tags
- **Why this format**: GitHub Actions workflows expect this exact format

#### 4.2 Push the Tag
```bash
git push origin vX.X.X
```

**Example:**
```bash
git push origin v1.0.3
```

**Why push the tag:**
- Tags trigger the GitHub Actions release workflow
- The workflow builds the app, creates DMG, and publishes the release
- Without the tag, no release will be created

### Step 5: Monitor GitHub Actions

#### 5.1 Check Workflow Status
Visit: `https://github.com/ilyassan/YTAudioBar-macos/actions`

**What to look for:**
- ✅ Build workflow completes successfully
- ✅ Release workflow creates DMG file
- ✅ GitHub release is published

#### 5.2 Verify Release Created
Visit: `https://github.com/ilyassan/YTAudioBar-macos/releases`

**What should be there:**
- New release with tag `vX.X.X` (likely marked as "Draft")
- DMG file attachment for download
- Auto-generated release notes from commits

### Step 6: Publish the GitHub Release

⚠️ **Important**: The GitHub Actions workflow creates a **DRAFT** release by default. You need to manually publish it.

#### 6.1 Edit the Draft Release
1. Go to: `https://github.com/ilyassan/YTAudioBar-macos/releases`
2. Find your new release (it will show as "Draft")
3. Click **"Edit"** button

#### 6.2 Customize Release Content

**Release Title:**
```
YTAudioBar v1.0.3
```

**Release Notes Template:**
```markdown
## 🎉 What's New in v1.0.3

### ✨ New Features
- [List any new features added]

### 🐛 Bug Fixes  
- [List any bugs fixed]

### 🔧 Improvements
- [List any improvements made]

### 📦 Technical Changes
- [List any technical/internal changes]

## 📥 Download

Download the latest version using the DMG file below.

## 🔄 Auto-Update

If you have a previous version installed, the app will automatically notify you of this update.

---

**Full Changelog**: https://github.com/ilyassan/YTAudioBar-macos/compare/v1.0.2...v1.0.3
```

#### 6.3 Verify Release Assets
Ensure the DMG file is attached:
- ✅ `YTAudioBar-vX.X.X.dmg` should be listed under "Assets"
- ✅ File size should be reasonable (typically 15-25 MB)

#### 6.4 Set as Latest Release
- ✅ Check **"Set as the latest release"** 
- ✅ Leave **"Set as a pre-release"** unchecked (unless it's a beta)

#### 6.5 Publish the Release
1. Click **"Publish release"** button
2. The release will become public and marked as "Latest"
3. Users will now see it in the app's auto-update system

**Why this step is crucial:**
- Draft releases are invisible to the auto-update system
- Only published releases trigger user notifications
- This step makes the release officially available to all users

## 🔄 GitHub Actions Workflow Overview

### What Happens Automatically

When you push a tag, GitHub Actions will:

1. **Build the App**:
   - Clean build in Release configuration
   - Uses the version numbers you set

2. **Create DMG**:
   - Professional DMG with proper layout
   - App icon and background image
   - Named: `YTAudioBar-vX.X.X.dmg`

3. **Publish Release**:
   - Creates GitHub release with the tag
   - Uploads DMG as release asset
   - Auto-generates release notes from commits

4. **Auto-Update Integration**:
   - The app's update checker will detect the new release
   - Users will be notified of available updates

## ⚠️ Troubleshooting

### Common Issues

#### Build Fails
```bash
# Clean derived data and retry
rm -rf ~/Library/Developer/Xcode/DerivedData/YTAudioBar-*
xcodebuild clean
```

#### Wrong Version Showing
- Check that both `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` were updated
- Verify changes were committed and pushed
- Clean build and check Info.plist again

#### GitHub Actions Not Triggered
- Ensure tag was pushed: `git push origin vX.X.X`
- Check tag exists on GitHub: `https://github.com/ilyassan/YTAudioBar-macos/tags`
- Verify tag follows `vX.X.X` format exactly

#### Release Not Created
- Check Actions tab for failed workflows
- Ensure tag points to the correct commit
- Verify DMG creation didn't fail

## 📚 Quick Reference Commands

```bash
# Complete release process for version 1.0.3:

# 1. Update version in project.pbxproj file (manually)
# 2. Commit and push
git add YTAudioBar.xcodeproj/project.pbxproj
git commit -m "release: bump version to 1.0.3"
git push origin main

# 3. Tag and push
git tag v1.0.3
git push origin v1.0.3

# 4. Monitor at: https://github.com/ilyassan/YTAudioBar-macos/actions
# 5. Go to: https://github.com/ilyassan/YTAudioBar-macos/releases
# 6. Edit draft release, add release notes, and publish
```

## 🎯 Summary Checklist

Complete release checklist:

- [ ] Decided on version number (patch/minor/major)
- [ ] Updated `MARKETING_VERSION` in project.pbxproj
- [ ] Updated `CURRENT_PROJECT_VERSION` in project.pbxproj  
- [ ] Tested local build and verified version
- [ ] Committed with format: `release: bump version to X.X.X`
- [ ] Pushed commit to main branch
- [ ] Created tag with format: `vX.X.X`
- [ ] Pushed tag to trigger release workflow
- [ ] Monitored GitHub Actions completion
- [ ] Verified draft release created with DMG
- [ ] **Edited and published the GitHub release**
- [ ] Confirmed release shows as "Latest" on GitHub
- [ ] Tested auto-update detection in previous app version

## 🚀 After Release

1. **Test Auto-Update**: Launch the previous version and verify it detects the new update
2. **Announce**: Share the release with users/community
3. **Monitor**: Watch for any issues or user feedback
4. **Plan Next**: Start planning features for the next release

---

💡 **Pro Tip**: Keep this guide handy and follow it step-by-step for consistent, error-free releases!