# Shipping LuxaforPresence

This guide covers code signing, notarizing, and validating the `.app` / `.dmg` produced by `scripts/package-dmg.sh`.

## Prerequisites
- Apple Developer Program membership with a **Developer ID Application** certificate installed in your login keychain.
- Apple ID credentials (or an App-Specific Password) for notarization.
- Xcode Command Line Tools (`xcode-select --install`) to get `codesign`, `notarytool`, and `stapler`.
- `scripts/package-dmg.sh` already run once (creates `dist/LuxaforPresence.app` and `dist/LuxaforPresence.dmg`).

## 1. Build the Release Artifacts
```bash
./scripts/package-dmg.sh -c release
```
This regenerates `dist/LuxaforPresence.app` and `dist/LuxaforPresence.dmg`.

## 2. Code Sign the App Bundle
```bash
codesign \
  --deep --force --options runtime \
  --sign "Developer ID Application: YOUR NAME (TEAMID)" \
  dist/LuxaforPresence.app
```
- `--deep` walks the bundle so the embedded resource bundle and binary are also signed.
- `--options runtime` opts into the hardened runtime (required for notarization).

Verify the signature:
```bash
codesign --verify --deep --strict --verbose=2 dist/LuxaforPresence.app
```

## 3. Rebuild / Resign the DMG
If you signed after running the packaging script, recreate the DMG so it contains the signed app:
```bash
./scripts/package-dmg.sh -c release
```
Alternatively, manually remove and recreate `dist/LuxaforPresence.dmg` (copying in the newly signed `.app`).

## 4. Submit for Notarization
First store credentials once (creates a secure profile):
```bash
xcrun notarytool store-credentials LuxaforPresenceNotary \
  --apple-id "appleid@example.com" \
  --team-id TEAMID \
  --password "app-specific-password"
```

Submit the DMG:
```bash
xcrun notarytool submit dist/LuxaforPresence.dmg \
  --keychain-profile LuxaforPresenceNotary \
  --wait
```
`--wait` keeps the command running until Apple completes the review; remove it if you prefer polling via `xcrun notarytool log`.

## 5. Staple the Ticket
Once notarization succeeds, embed the ticket so end users can verify offline:
```bash
xcrun stapler staple dist/LuxaforPresence.dmg
```
You can also staple the `.app` itself (`xcrun stapler staple dist/LuxaforPresence.app`) if you distribute the bundle directly.

## 6. Final Verification
Mount or assess the DMG locally to confirm macOS trusts it:
```bash
spctl --assess --type open --verbose dist/LuxaforPresence.dmg
```
Then double-click the DMG, drag `LuxaforPresence.app` to `/Applications`, and launch it; there should be no Gatekeeper warnings.

## Tips
- Keep the `Developer ID` certificate up to date; expired certs cause signing failures.
- Automate the signing/notarization flow in CI by exporting the certificate to a password-protected `.p12` and importing it at build time.
- If notarization fails, fetch the JSON log via `xcrun notarytool log <request-id>`; it lists missing entitlements, unsigned binaries, or hardened runtime violations.
