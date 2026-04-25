#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA_DIR="$PROJECT_DIR/.build/DerivedDataRelease"
DIST_DIR="$PROJECT_DIR/dist"
STAGING_DIR="$PROJECT_DIR/.build/dmg-staging"
APP_NAME="TahoePaste.app"
APP_DISPLAY_NAME="TahoePaste"
DMG_NAME="TahoePaste.dmg"
DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
SIGNING_IDENTITY="${SIGNING_IDENTITY:-TahoePaste Local Development}"
BUILT_APP_PATH="$DERIVED_DATA_DIR/Build/Products/Release/$APP_NAME"
STAGED_APP_PATH="$STAGING_DIR/$APP_NAME"
BACKGROUND_PATH="$PROJECT_DIR/packaging/dmg/background.png"
DMG_PATH="$DIST_DIR/$DMG_NAME"

export DEVELOPER_DIR

if ! command -v create-dmg >/dev/null 2>&1; then
  echo "create-dmg is required. Install it with: brew install create-dmg" >&2
  exit 1
fi

if [[ "$SIGNING_IDENTITY" != "-" ]]; then
  IDENTITY_NAME="$SIGNING_IDENTITY" "$PROJECT_DIR/scripts/ensure-local-signing-identity.sh"
fi
"$PROJECT_DIR/scripts/generate-dmg-background.sh"

mkdir -p "$DIST_DIR"
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"

echo "Building Release app..."
xcodebuild \
  -project "$PROJECT_DIR/TahoePaste.xcodeproj" \
  -scheme TahoePaste \
  -configuration Release \
  -derivedDataPath "$DERIVED_DATA_DIR" \
  build

if [[ ! -d "$BUILT_APP_PATH" ]]; then
  echo "Built app was not found at $BUILT_APP_PATH" >&2
  exit 1
fi

echo "Preparing staged app..."
ditto "$BUILT_APP_PATH" "$STAGED_APP_PATH"

echo "Signing staged app..."
codesign \
  --force \
  --deep \
  --sign "$SIGNING_IDENTITY" \
  --timestamp=none \
  "$STAGED_APP_PATH"

codesign --verify --deep --strict "$STAGED_APP_PATH"

rm -f "$DMG_PATH"

echo "Creating DMG..."
CREATE_DMG_ARGS=(
  --volname "$APP_DISPLAY_NAME"
  --volicon "$STAGED_APP_PATH/Contents/Resources/AppIcon.icns"
  --background "$BACKGROUND_PATH"
  --window-pos 120 120
  --window-size 700 440
  --icon-size 128
  --text-size 14
  --icon "$APP_NAME" 180 245
  --hide-extension "$APP_NAME"
  --app-drop-link 520 245
)

if [[ "$SIGNING_IDENTITY" != "-" ]]; then
  CREATE_DMG_ARGS+=(--codesign "$SIGNING_IDENTITY")
fi

create-dmg "${CREATE_DMG_ARGS[@]}" "$DMG_PATH" "$STAGING_DIR"

echo
echo "TahoePaste DMG created at:"
echo "  $DMG_PATH"
