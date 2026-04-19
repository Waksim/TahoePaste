#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA_DIR="$PROJECT_DIR/.build/DerivedData"
APP_NAME="TahoePaste.app"
APP_PROCESS_NAME="TahoePaste"
INSTALL_DIR="$HOME/Applications"
INSTALLED_APP_PATH="$INSTALL_DIR/$APP_NAME"
BUILT_APP_PATH="$DERIVED_DATA_DIR/Build/Products/Debug/$APP_NAME"
DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
SIGNING_IDENTITY="${SIGNING_IDENTITY:-TahoePaste Local Development}"

mkdir -p "$INSTALL_DIR"

export DEVELOPER_DIR

"$PROJECT_DIR/scripts/ensure-local-signing-identity.sh"

echo "Building TahoePaste..."
xcodebuild \
  -project "$PROJECT_DIR/TahoePaste.xcodeproj" \
  -scheme TahoePaste \
  -configuration Debug \
  -derivedDataPath "$DERIVED_DATA_DIR" \
  build

if [[ ! -d "$BUILT_APP_PATH" ]]; then
  echo "Built app was not found at $BUILT_APP_PATH" >&2
  exit 1
fi

if pgrep -x "$APP_PROCESS_NAME" >/dev/null 2>&1; then
  echo "Stopping running TahoePaste..."
  pkill -x "$APP_PROCESS_NAME" || true
  sleep 1
fi

echo "Installing TahoePaste to $INSTALLED_APP_PATH..."
if command -v rsync >/dev/null 2>&1; then
  mkdir -p "$INSTALLED_APP_PATH"
  rsync -a --delete "$BUILT_APP_PATH/" "$INSTALLED_APP_PATH/"
else
  rm -rf "$INSTALLED_APP_PATH"
  ditto "$BUILT_APP_PATH" "$INSTALLED_APP_PATH"
fi

echo "Signing TahoePaste with local identity..."
codesign \
  --force \
  --deep \
  --sign "$SIGNING_IDENTITY" \
  --timestamp=none \
  "$INSTALLED_APP_PATH"
codesign --verify --deep --strict "$INSTALLED_APP_PATH"

xattr -dr com.apple.quarantine "$INSTALLED_APP_PATH" 2>/dev/null || true
/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister -f -R -trusted "$INSTALLED_APP_PATH" >/dev/null 2>&1 || true

echo "Launching TahoePaste..."
open -a "$INSTALLED_APP_PATH"

echo
echo "TahoePaste is running from:"
echo "  $INSTALLED_APP_PATH"
echo
echo "Accessibility tip:"
echo "  Grant access to the TahoePaste app from ~/Applications so macOS sees a stable app path."
