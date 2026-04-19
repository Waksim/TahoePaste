#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKGROUND_DIR="$PROJECT_DIR/packaging/dmg"
BACKGROUND_PATH="$BACKGROUND_DIR/background.png"
SOURCE_ICON="$PROJECT_DIR/TahoePaste/Assets.xcassets/AppIcon.appiconset/appicon_512x512@2x.png"
FONT_PATH="/System/Library/Fonts/Helvetica.ttc"

mkdir -p "$BACKGROUND_DIR"

if ! command -v magick >/dev/null 2>&1; then
  echo "ImageMagick is required to generate the DMG background." >&2
  exit 1
fi

magick \
  -size 700x440 xc:'#0b1118' \
  \( -size 700x440 radial-gradient:'#213a65-#0b1118' -evaluate multiply 0.90 \) -compose screen -composite \
  \( -size 700x440 xc:none -fill 'rgba(255,255,255,0.06)' -draw 'roundrectangle 16,16 684,424 28,28' \) -compose over -composite \
  \( "$SOURCE_ICON" -resize 156x156 \) -geometry +92+150 -compose over -composite \
  -fill '#F5F8FF' -font "$FONT_PATH" -pointsize 30 -annotate +76+82 'TahoePaste' \
  -fill '#B9C7DA' -font "$FONT_PATH" -pointsize 16 -annotate +76+112 'Drag the app into Applications' \
  -stroke '#9CC7FF' -strokewidth 6 -fill none -draw "path 'M 290,220 C 360,220 392,220 470,220'" \
  -fill '#9CC7FF' -stroke none -draw "polygon 470,220 445,206 445,234" \
  "$BACKGROUND_PATH"

echo "Generated DMG background at:"
echo "  $BACKGROUND_PATH"
