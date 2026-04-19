# TahoePaste

<p align="center">
  <img src="docs/images/tahoepaste-icon.png" alt="TahoePaste app icon" width="128" height="128">
</p>

<p align="center">
  A polished, local-only clipboard manager for macOS Tahoe.
</p>

<p align="center">
  <a href="https://github.com/Waksim/TahoePaste/releases">
    <img alt="Latest release" src="https://img.shields.io/github/v/release/Waksim/TahoePaste?display_name=tag&sort=semver">
  </a>
  <img alt="Platform" src="https://img.shields.io/badge/platform-macOS%20Tahoe-black">
  <img alt="UI" src="https://img.shields.io/badge/UI-SwiftUI%20%2B%20AppKit-0A84FF">
  <img alt="Privacy" src="https://img.shields.io/badge/privacy-local--only-2DA44E">
</p>

<p align="center">
  TahoePaste runs quietly in the background, keeps clipboard history on your Mac only, and brings it back through a fast card-based overlay built for quick paste workflows.
</p>

<p align="center">
  <img src="docs/images/tahoepaste-overlay.png" alt="TahoePaste clipboard overlay" width="1000">
</p>

<p align="center">
  <sub>Keyboard-first clipboard overlay with large cards, quick scanning, and fast restore back into your workflow.</sub>
</p>

## Why TahoePaste

TahoePaste is designed for people who copy constantly and want a clipboard manager that feels native on macOS instead of bolted on. It focuses on speed, clarity, and privacy:

- local-only clipboard storage in `Application Support`
- support for text, links, code, images, and files
- quick keyboard-driven access through a bottom overlay
- native macOS theming with day, night, follow-system, and scheduled modes
- multilingual interface in English, Russian, and Simplified Chinese

## Highlights

| Feature | What it gives you |
| --- | --- |
| Smart clipboard capture | Saves text, links, code, images, and file references with useful metadata and tagging. |
| Fast overlay UI | Press `Cmd + Shift + C` to open a clean card grid for browsing, searching, and restoring clipboard items. |
| Rich text tagging | Detects practical text patterns like emails, phone numbers, passwords, tokens, dates, and addresses. |
| Native appearance controls | Switch between day and night themes manually, sync with macOS, or run automatic theme schedules. |
| Menu bar workflow | Keep TahoePaste available from the menu bar for quick access without cluttering the Dock. |
| Privacy-first design | Clipboard history stays on-device under your user Library with no cloud sync or remote processing. |

## Interface

### Clipboard Overlay

<p align="center">
  <img src="docs/images/tahoepaste-overlay.png" alt="TahoePaste overlay showing clipboard cards" width="1000">
</p>

### Settings Window

<p align="center">
  <img src="docs/images/tahoepaste-settings.png" alt="TahoePaste settings window" width="760">
</p>

<p align="center">
  <sub>Native settings window with multilingual UI, launch-at-login, appearance controls, and clipboard behavior tuning.</sub>
</p>

## Download

The easiest way to try TahoePaste is from the latest GitHub release:

- Download the latest `.dmg` from [Releases](https://github.com/Waksim/TahoePaste/releases)
- Move `TahoePaste.app` to `~/Applications` or `/Applications`
- Launch the app and grant Accessibility permission when macOS prompts you

## Quick Start

1. Copy text, code, images, or files in any app.
2. Press `Cmd + Shift + C`.
3. Browse the overlay and pick the item you want.
4. TahoePaste restores it to the clipboard and can auto-paste it back into the previous app when Accessibility access is enabled.

## App Behavior

- Clipboard history lives in `~/Library/Application Support/TahoePaste/`
- Persisted images are stored in `~/Library/Application Support/TahoePaste/Images/`
- Automatic paste depends on Accessibility permission
- A stable installed copy is expected at `~/Applications/TahoePaste.app` for reliable macOS permission handling

## Development

### Requirements

1. Install full Xcode at `/Applications/Xcode.app`
2. Point developer tools at Xcode if needed:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

3. Install XcodeGen if needed:

```bash
brew install xcodegen
```

### Generate The Xcode Project

```bash
cd /Users/mk/PycharmProjects/TahoePaste
xcodegen generate
```

This regenerates `TahoePaste.xcodeproj` from `project.yml`.

### Run In Xcode

1. Open `/Users/mk/PycharmProjects/TahoePaste/TahoePaste.xcodeproj`
2. Select the `TahoePaste` scheme
3. Pick your personal team if Xcode asks for local signing
4. Build and run the app

### Stable Dev Install

For Accessibility permission, a stable app path works better than Xcode's transient build products:

```bash
cd /Users/mk/PycharmProjects/TahoePaste
./scripts/dev-install-and-run.sh
```

This script:

- builds the app
- installs it to `~/Applications/TahoePaste.app`
- stops the previous TahoePaste process
- launches the refreshed copy

### Command-Line Build

```bash
cd /Users/mk/PycharmProjects/TahoePaste
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project TahoePaste.xcodeproj \
  -scheme TahoePaste \
  -configuration Debug \
  build
```

### Tests

```bash
cd /Users/mk/PycharmProjects/TahoePaste
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project TahoePaste.xcodeproj \
  -scheme TahoePaste \
  -configuration Debug \
  test
```

### Build A DMG

```bash
cd /Users/mk/PycharmProjects/TahoePaste
./scripts/build-dmg.sh
```

This produces `dist/TahoePaste.dmg`.

For public distribution beyond local sharing, you will eventually want:

- an Apple Developer ID Application certificate
- notarization
- stapling for the final DMG

## Project Layout

- `TahoePaste/`: app sources, views, managers, assets, localization, and window controllers
- `TahoePasteTests/`: unit tests for persistence, search, classification, settings, and localization coverage
- `docs/images/`: README visuals such as the app icon and screenshots
- `scripts/dev-install-and-run.sh`: stable local install and relaunch flow
- `scripts/build-dmg.sh`: release `.dmg` packaging

## Privacy

TahoePaste is built around a simple rule: your clipboard history stays on your Mac. The app stores data locally, works offline, and does not depend on remote services to classify or restore clipboard content.
