# ClashX Auto-Update Feed

This directory contains the Sparkle auto-update feed for ClashX.

## Files

- `appcast.xml` - Sparkle update feed (RSS format)
- `index.html` - Human-readable page

## How It Works

1. When users click "Check for Updates" in ClashX menu
2. The app fetches `appcast.xml` from GitHub Pages
3. Sparkle compares the version and shows update dialog
4. DMG is downloaded from GitHub Releases

## Updating the Feed

When releasing a new version, update `appcast.xml` with:
- New version number
- Release date
- Download URL (GitHub Release)
- Release notes

## GitHub Pages Setup

This feed is hosted at: https://charlessnow.github.io/ClashX/appcast.xml

To enable GitHub Pages:
1. Go to repository Settings → Pages
2. Set Source to "main" branch and "/docs" folder
3. Save

The feed URL is configured in `ClashX/Info.plist` under the `SUFeedURL` key.
