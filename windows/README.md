# TahoePaste Windows

Native Windows 11 version of TahoePaste. The macOS project is used only as the product reference; this implementation is rebuilt for Windows with .NET 10 LTS, WPF, Windows Forms tray integration, and Win32 interop.

## What Is Implemented

- local clipboard history in `%APPDATA%\TahoePaste`
- text, code, links, images, and file-drop captures
- global shortcut `Ctrl + Shift + C`
- bottom overlay with searchable horizontal cards
- direct typing search, tag filters, delete buttons, and newest-item scroll
- restore-to-clipboard and optional auto-paste with `Ctrl + V`
- reactivation of the previously focused window before paste
- Windows tray menu with status, saved item count, settings, and quit
- launch-at-login via the current user's Startup registry key
- day, night, system, and scheduled themes
- English, Russian, and Simplified Chinese UI with English fallback
- x64 Windows publishing target
- bundled TahoePaste `.ico` application/tray icon

## Requirements

- Windows 11 x64
- .NET 10 SDK
- Visual Studio 2026 / Rider / a current editor with .NET desktop workload support

The project targets `net10.0-windows10.0.26100.0`, publishes as `win-x64`, and declares Windows 11 `10.0.22000.0` as the minimum supported OS platform.

## Run

From PowerShell:

```powershell
cd C:\Path\To\TahoePaste\windows
.\scripts\run.ps1
```

Or open `TahoePasteWindows.sln` and run `TahoePaste.Windows`.

## Publish

```powershell
cd C:\Path\To\TahoePaste\windows
.\scripts\build.ps1 -Configuration Release
```

The published app is self-contained and is written to:

```text
src\TahoePaste.Windows\bin\Release\net10.0-windows10.0.26100.0\win-x64\publish
```

## Windows Notes

Auto-paste uses Win32 `SendInput`. Windows blocks lower-privilege apps from automating elevated/admin windows, so if the target app is running as administrator, TahoePaste can still copy the selected item back to the clipboard, but manual `Ctrl + V` may be required.

The tray icon extracts the packaged TahoePaste icon from the running executable and falls back to the Windows application icon if extraction is unavailable.
