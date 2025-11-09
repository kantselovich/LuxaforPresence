# Repository Guidelines

## Project Structure & Module Organization
Source for the macOS menu bar app lives under `LuxaforPresence/`. Key folders: `Model/` (state & value types like `PresenceState`), `Signals/` (mic/camera, calendar, and foreground app detectors), `Transport/` (Luxafor USB/API client), `UI/` (status item and icon glue), and `Resources/` (config template and app assets). Tests reside in `LuxaforPresence/Tests/`, mirroring the modules they exercise. Keep new assets or plist files inside `Resources/` so SwiftPM bundles them via the existing `Package.swift` directives.

## Build, Test, and Development Commands
- `CLANG_MODULE_CACHE_PATH=$PWD/.cache swift build --disable-sandbox` – preferred way to compile inside containers where `$HOME` caches are read-only; still validates the linker flags that embed `Info.plist`.
- `swift build` – standard local build when you have normal write access to the user caches.
- `swift run` – launches the debug build; use during iterative development to see menu bar changes instantly.
- `swift run -c release` – produces an optimized binary for field testing with the real Luxafor hardware.
- `swift test` – executes `LuxaforPresenceTests`, including Luxafor client fakes and `PresenceEngine` scenarios.
- `./scripts/package-dmg.sh` – builds (release by default), creates `LuxaforPresence.app`, and emits `dist/LuxaforPresence.dmg` for distribution; accepts `-c debug|release` and `-n VolumeName`.

## Coding Style & Naming Conventions
Follow Swift API Design Guidelines: UpperCamelCase for types (`PresenceEngine`), lowerCamelCase for methods/properties (`updateState()`), and enums for state machines. Prefer 4-space indentation, trailing commas in multiline collections, and mark protocol conformances in dedicated `extension` blocks. When adding files, keep filenames aligned with the primary type (e.g., `FooSignal.swift`). Run Xcode's built-in formatter before committing; extra tooling (SwiftFormat/SwiftLint) is currently out of scope.

## Testing Guidelines
Add a peer test in `LuxaforPresence/Tests/` for every non-trivial feature; organize fixtures by feature (`LuxaforClientTests`, `PresenceEngineTests`). Name tests using the `test_<Scenario>_<Expectation>` pattern so failures read clearly. Mock external systems (calendar, audio) rather than touching real services. Aim to cover new branches introduced in `PresenceEngine` and any heuristics inside `Signals/`.

## Commit & Pull Request Guidelines
History currently uses concise, descriptive summaries (e.g., “1st vibe-coded version - runs, but does not display icons”). Keep future commit subjects imperative, ≤72 characters, and include scope when useful (`presence: add idle debounce`). For pull requests, link the motivating issue, describe user-visible changes, call out configuration impacts, and attach screenshots when UI changes affect the menu bar icon. Ensure CI (or at least `swift test`) passes locally before requesting review.

## Configuration & Security Tips
Do not hardcode Luxafor `userId`s; prefer the per-user config at `~/.config/LuxaforPresence/config.plist` and keep sample placeholders in `Resources/config.plist`. Uploaded asset catalogs must be template images (`StatusIconOn/Off/Idle`) so menu bar tinting works. Avoid logging raw calendar titles or meeting URLs; redact sensitive strings before writing to stdout or diagnostics.
