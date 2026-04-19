# TahoePaste

TahoePaste is a local-only clipboard manager for macOS Tahoe built with SwiftUI and AppKit. It runs as a background app, watches the system clipboard for text, links, code, images, and files, stores history in `Application Support`, and shows a bottom overlay with quick-paste cards.

## Project Layout

- `project.yml`: XcodeGen project definition.
- `TahoePaste/`: App sources, plist, managers, views, assets, and window controllers.
- `TahoePasteTests/`: Unit tests for model persistence, search, classification, and clipboard behavior.
- `scripts/dev-install-and-run.sh`: Stable local install and relaunch flow to `~/Applications/TahoePaste.app`.
- `scripts/build-dmg.sh`: Builds a distributable `.dmg` image.

## Prerequisites

1. Install full Xcode at `/Applications/Xcode.app`.
2. Point developer tools at Xcode if needed:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

3. Install XcodeGen if it is not already available:

```bash
brew install xcodegen
```

## Generate The Xcode Project

From the project directory:

```bash
cd /Users/mk/PycharmProjects/TahoePaste
xcodegen generate
```

This creates `TahoePaste.xcodeproj`.

## Open And Run In Xcode

1. Open `/Users/mk/PycharmProjects/TahoePaste/TahoePaste.xcodeproj`.
2. Select the `TahoePaste` scheme.
3. If Xcode asks for signing, pick your personal team for local development.
4. Build and run the app.
5. On first launch, grant Accessibility access when macOS prompts you.
6. Copy text, files, or images in another app, then press `Cmd + Shift + C` to open the overlay.

## Stable Dev Run

For Accessibility permission, it is better to run TahoePaste from one stable app path instead of directly from Xcode's transient build product. Use:

```bash
cd /Users/mk/PycharmProjects/TahoePaste
./scripts/dev-install-and-run.sh
```

What this does:

- Builds the app with Xcode.
- Installs it to `~/Applications/TahoePaste.app`.
- Stops the old TahoePaste process if it is running.
- Launches the freshly installed copy.

If Accessibility was previously granted to a debug copy from Xcode, remove old TahoePaste entries in System Settings and grant permission again to the `~/Applications/TahoePaste.app` copy.

## Build A DMG

TahoePaste can also be wrapped as a standard macOS `.dmg` for distribution:

```bash
cd /Users/mk/PycharmProjects/TahoePaste
./scripts/build-dmg.sh
```

This script:

- builds a Release copy of TahoePaste,
- signs it with the local development identity already used for stable installs,
- generates a polished DMG background,
- produces `dist/TahoePaste.dmg`.

Note: this local DMG is good for testing and sharing. For public distribution to other Macs without trust warnings, you will eventually want:

- an Apple Developer ID Application certificate,
- notarization,
- stapling the notarization ticket to the DMG.

## Command-Line Build And Test

Build:

```bash
cd /Users/mk/PycharmProjects/TahoePaste
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project TahoePaste.xcodeproj \
  -scheme TahoePaste \
  -configuration Debug \
  build
```

Test:

```bash
cd /Users/mk/PycharmProjects/TahoePaste
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project TahoePaste.xcodeproj \
  -scheme TahoePaste \
  -configuration Debug \
  test
```

## Notes

- Clipboard history is stored under `~/Library/Application Support/TahoePaste/`.
- Images are persisted as PNG files in `~/Library/Application Support/TahoePaste/Images/`.
- Automatic `Cmd + V` simulation depends on Accessibility permission.
- The stable installed app lives at `~/Applications/TahoePaste.app`.
