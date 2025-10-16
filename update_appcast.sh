#!/bin/bash

# Script to update appcast.xml with new version
# Usage: ./update_appcast.sh VERSION "RELEASE_NOTES"
# Example: ./update_appcast.sh 1.120.0 "Fixed bugs and improved performance"

set -e

VERSION=$1
RELEASE_NOTES=$2

if [ -z "$VERSION" ]; then
    echo "Error: Version not provided"
    echo "Usage: ./update_appcast.sh VERSION \"RELEASE_NOTES\""
    exit 1
fi

if [ -z "$RELEASE_NOTES" ]; then
    echo "Error: Release notes not provided"
    echo "Usage: ./update_appcast.sh VERSION \"RELEASE_NOTES\""
    exit 1
fi

APPCAST_FILE="docs/appcast.xml"
CURRENT_DATE=$(date -u +"%a, %d %b %Y %H:%M:%S %z")

echo "Updating appcast.xml with version $VERSION"

cat > "$APPCAST_FILE" << EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
  <channel>
    <title>ClashX</title>
    <link>https://charlessnow.github.io/ClashX/appcast.xml</link>
    <description>Most recent ClashX updates</description>
    <language>en</language>
    <item>
      <title>Version $VERSION</title>
      <description><![CDATA[
        $RELEASE_NOTES
      ]]></description>
      <pubDate>$CURRENT_DATE</pubDate>
      <sparkle:version>$VERSION</sparkle:version>
      <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>10.13</sparkle:minimumSystemVersion>
      <enclosure
        url="https://github.com/charlessnow/ClashX/releases/download/$VERSION/ClashX.dmg"
        sparkle:version="$VERSION"
        sparkle:shortVersionString="$VERSION"
        type="application/octet-stream"
      />
    </item>
  </channel>
</rss>
EOF

echo "✅ Updated appcast.xml successfully"
echo "📝 Next steps:"
echo "1. Commit the changes: git add docs/appcast.xml && git commit -m 'Update appcast for version $VERSION'"
echo "2. Push to GitHub: git push origin master"
echo "3. Make sure GitHub Pages is enabled for the /docs folder"
echo "4. Create a release with tag $VERSION and upload ClashX.dmg"
