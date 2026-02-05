# Changelog

All notable changes to LuxaforPresence will be documented here. This project is currently in alpha; expect rapid iteration and possible breaking changes between versions.

## [1.5.0] – Current (from `LuxaforPresence/Info.plist`)

- Current app version is `1.5.0` (from `CFBundleShortVersionString`).
- “in meeting” state is detected using camera/mic activity, voice activity, plus checks for common meeting apps like Slack and Teams showing UI elements that indicate an active meeting.
- build on MacOS 26 

## [v0.01] – First Tagged Version (check via `git ls-remote --tags origin`)

- First tagged version on the remote is `v0.01`.
- Initial menu bar app that infers “in meeting” state using mic/camera activity plus a foreground-app allowlist and updates the Luxafor flag accordingly.
- Manual overrides (Force On/Off) exposed via the status menu.
- Packaging script (`scripts/package-dmg.sh`) to build a distributable `.dmg`.
- Roadmap for additional signals, logging, and override UX tracked in `PLAN.md`.
