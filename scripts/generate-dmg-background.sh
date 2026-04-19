#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKGROUND_DIR="$PROJECT_DIR/packaging/dmg"
BACKGROUND_PATH="$BACKGROUND_DIR/background.png"
FONT_PATH="/System/Library/Fonts/Helvetica.ttc"

mkdir -p "$BACKGROUND_DIR"

if ! command -v magick >/dev/null 2>&1; then
  echo "ImageMagick is required to generate the DMG background." >&2
  exit 1
fi

magick \
  -size 700x440 xc:'#0b1118' \
  \( -size 700x440 radial-gradient:'#213a65-#0b1118' -evaluate multiply 0.92 \) -compose screen -composite \
  \( -size 700x440 xc:none -fill 'rgba(255,255,255,0.05)' -draw 'roundrectangle 16,16 684,424 28,28' \) -compose over -composite \
  \( -size 700x440 xc:none -fill 'rgba(118,178,255,0.08)' -draw 'roundrectangle 84,180 294,322 26,26' \) -compose over -composite \
  \( -size 700x440 xc:none -fill 'rgba(118,178,255,0.08)' -draw 'roundrectangle 406,180 616,322 26,26' \) -compose over -composite \
  -fill '#F5F8FF' -font "$FONT_PATH" -pointsize 30 -annotate +76+82 'TahoePaste' \
  -fill '#B9C7DA' -font "$FONT_PATH" -pointsize 16 -annotate +76+112 'Drag the app into Applications' \
  -fill '#86B6FF' -font "$FONT_PATH" -pointsize 13 -annotate +264+182 'Install' \
  -stroke '#9CC7FF' -strokewidth 6 -fill none -draw "path 'M 284,250 C 346,250 374,250 432,250'" \
  -fill '#9CC7FF' -stroke none -draw "polygon 462,250 434,235 434,265" \
  "$BACKGROUND_PATH"

echo "Generated DMG background at:"
echo "  $BACKGROUND_PATH"
