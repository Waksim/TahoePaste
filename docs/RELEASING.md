# Releasing TahoePaste

TahoePaste publishes macOS and Windows downloads from one GitHub Release.

## Assets

The release workflow uploads:

- `TahoePaste-macOS.dmg`
- `TahoePaste-Windows-x64-Setup.exe`
- `TahoePaste-Windows-x64.zip`
- `SHA256SUMS.txt`

## Tag Release

```bash
git switch main
git pull --ff-only
git tag v0.3.0
git push origin v0.3.0
```

Pushing a `v*` tag triggers `.github/workflows/release.yml`.

## Manual Re-run

If a release asset needs to be rebuilt for an existing tag:

1. Open GitHub Actions.
2. Run the `Release` workflow manually.
3. Enter the existing tag, for example `v0.3.0`.

The workflow uploads assets with `--clobber`, so a manual re-run replaces existing files for that tag.

## Signing Notes

The macOS workflow currently uses the existing local development signing flow from `scripts/build-dmg.sh`. Public distribution will eventually benefit from Apple Developer ID signing, notarization, and stapling.

The Windows workflow creates a self-contained x64 app, a portable zip, and an Inno Setup installer. For wider public distribution, add Authenticode signing to reduce Windows SmartScreen friction.
