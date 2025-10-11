# Sparkle EdDSA Signing Setup Instructions

## Private Key Generated

Your Sparkle EdDSA private key has been generated and exported to:
```
/Users/ilyassanida/Desktop/YTAudioBar/sparkle_private_key.txt
```

**Private Key Value:**
```
ynaGv6ITh1HWN/wmfmm+o3rdgpyaibMwFvexNQs7bp4=
```

**Public Key (already added to Info.plist):**
```
tLphlsNrHLsCqjqpuJUAKRzUKQ2xGKIyBGxBBOeZvLw=
```

## Required GitHub Secret

You MUST add the private key as a GitHub secret for the automated signing to work:

1. Go to: https://github.com/ilyassan/YTAudioBar-macos/settings/secrets/actions
2. Click "New repository secret"
3. Name: `SPARKLE_PRIVATE_KEY`
4. Value: `ynaGv6ITh1HWN/wmfmm+o3rdgpyaibMwFvexNQs7bp4=`
5. Click "Add secret"

## What This Fixes

1. **Version Display Issue**: Now shows correct version comparison (build numbers instead of full versions)
2. **EdDSA Warning**: Eliminates the deprecation warning about unsigned updates
3. **Security**: Updates are now cryptographically signed and verified

## Files Changed

- `YTAudioBar/Info.plist` - Added SUPublicEDKey, removed SUAllowsInsecureUpdates
- `YTAudioBar/YTAudioBar.entitlements` - Added library validation entitlement for development
- `scripts/generate_appcast.py` - Updated to use build numbers and support EdDSA signing
- `.github/workflows/release.yml` - Added SPARKLE_PRIVATE_KEY environment variable
- `scripts/sign_update` - Sparkle tool for signing DMG files (binary)

## Security Note

**IMPORTANT:**
- Keep `sparkle_private_key.txt` secure and DO NOT commit it to git
- The private key should only exist in your local keychain and GitHub secrets
- Delete `sparkle_private_key.txt` after adding it to GitHub secrets

## Next Steps

1. Add the private key to GitHub secrets (instructions above)
2. Commit and push all changes
3. Create a new release to test the signed updates
