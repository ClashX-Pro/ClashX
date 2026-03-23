# ClashFX Auto-Update Feed

This directory contains the Sparkle auto-update feed for ClashFX.

## Files

- `appcast.xml` - Sparkle update feed (RSS format)
- `index.html` - Human-readable page

## How It Works

1. When users click "Check for Updates" in ClashFX menu
2. The app fetches `appcast.xml` from GitHub Pages
3. Sparkle compares the version and shows update dialog
4. DMG is downloaded from GitHub Releases

## Updating the Feed

When releasing a new version, run from project root:

```bash
./update_appcast.sh VERSION SIGNATURE LENGTH "RELEASE_NOTES_HTML"
```

Generate the EdDSA signature with:
```bash
./Pods/Sparkle/bin/sign_update ClashFX.dmg
```

## GitHub Pages Setup

This feed is hosted at: https://clash-fx.github.io/ClashFX/appcast.xml

To enable GitHub Pages:
1. Go to repository Settings → Pages
2. Set Source to "main" branch and "/docs" folder
3. Save

The feed URL is configured in `ClashFX/Info.plist` under the `SUFeedURL` key.
