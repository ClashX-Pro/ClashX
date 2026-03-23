#!/bin/bash

# Update appcast.xml with a new release version.
# Prepends a new <item> while preserving existing version history.
#
# Usage:
#   ./update_appcast.sh VERSION SIGNATURE LENGTH "RELEASE_NOTES_HTML"
#
# Example:
#   ./update_appcast.sh 1.123.0 "abc123sig==" 28000000 "<h2>v1.123.0</h2><ul><li>Fixed bug</li></ul>"
#
# Generate EdDSA signature with Sparkle's sign_update tool:
#   ./Pods/Sparkle/bin/sign_update ClashFX.dmg

set -euo pipefail

VERSION="${1:-}"
SIGNATURE="${2:-}"
LENGTH="${3:-}"
RELEASE_NOTES="${4:-}"

if [ -z "$VERSION" ] || [ -z "$SIGNATURE" ] || [ -z "$LENGTH" ] || [ -z "$RELEASE_NOTES" ]; then
    echo "Error: Missing required arguments"
    echo ""
    echo "Usage: ./update_appcast.sh VERSION SIGNATURE LENGTH \"RELEASE_NOTES_HTML\""
    echo ""
    echo "  VERSION          - Semantic version (e.g. 1.123.0)"
    echo "  SIGNATURE        - EdDSA signature from: ./Pods/Sparkle/bin/sign_update ClashFX.dmg"
    echo "  LENGTH           - File size in bytes of ClashFX.dmg"
    echo "  RELEASE_NOTES    - HTML release notes"
    exit 1
fi

APPCAST_FILE="docs/appcast.xml"
CURRENT_DATE=$(date -u +"%a, %d %b %Y %H:%M:%S %z")

if [ ! -f "$APPCAST_FILE" ]; then
    echo "Error: $APPCAST_FILE not found. Run from project root."
    exit 1
fi

NEW_ITEM=$(cat <<EOF
    <item>
      <title>Version $VERSION</title>
      <description><![CDATA[
        $RELEASE_NOTES
      ]]></description>
      <pubDate>$CURRENT_DATE</pubDate>
      <sparkle:version>$VERSION</sparkle:version>
      <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>10.14</sparkle:minimumSystemVersion>
      <enclosure
        url="https://github.com/Clash-FX/ClashFX/releases/download/$VERSION/ClashFX.dmg"
        sparkle:version="$VERSION"
        sparkle:shortVersionString="$VERSION"
        sparkle:edSignature="$SIGNATURE"
        length="$LENGTH"
        type="application/octet-stream"
      />
    </item>
EOF
)

MARKER="<language>en</language>"
if ! grep -q "$MARKER" "$APPCAST_FILE"; then
    echo "Error: Cannot find insertion point in $APPCAST_FILE"
    exit 1
fi

sed -i '' "/$MARKER/a\\
$(echo "$NEW_ITEM" | sed 's/$/\\/' | sed '$ s/\\$//')
" "$APPCAST_FILE"

echo "✅ Added version $VERSION to $APPCAST_FILE"
echo ""
echo "Next steps:"
echo "  1. Review: git diff docs/appcast.xml"
echo "  2. Commit: git add docs/appcast.xml && git commit -m 'release: update appcast for v$VERSION'"
echo "  3. Push to GitHub (triggers GitHub Pages deploy)"
echo "  4. Create GitHub Release with tag $VERSION and upload ClashFX.dmg"
