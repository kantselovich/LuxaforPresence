# Changelog

All notable changes to LuxaforPresence will be documented here.

## [1.5.0] – Current

- Version `1.5.0` "Beta", the app actually works for Teams and Slack, needs more testing
- Accessibliy Framework to detect Teams and Slack meetings
- Voice Activity Detection (VAD) support
- 3 states: in a meeting (muted) , in a meeting, Off
- Support Local Luxafor Webhook
- BUGFIX:  Forced ON/OFF state would stick, requiring app restart to clear
- build on MacOS 26

## [v0.01] – First Tagged Version

- First tagged version on the remote is `v0.01`.
- Initial menu bar app that infers “in meeting” state using mic/camera activity plus a foreground-app allowlist and updates the Luxafor flag accordingly.
- Manual overrides (Force On/Off) exposed via the status menu.
- Packaging script (`scripts/package-dmg.sh`) to build a distributable `.dmg`.
- Roadmap for additional signals, logging, and override UX tracked in `PLAN.md`.
