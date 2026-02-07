# LuxaforPresence for macOS

Native macOS menu bar app that updates a [Luxafor flag](https://luxafor.com/product/flag/) if you are actually in a meeting.

## Why

To show your family members that you are on a call at the moment.

The Luxafor Presence light comes with an app that integrates with Teams, Google Calendar, Zoom, and a few other tools. However, only one integration can be active at a time, and Teams integration can require approval from a corporate IT team, which makes this a non-starter for many people.

It is normal to use multiple call apps, for example Slack huddles for pairing, Teams for scheduled meetings, Zoom with external customers, and Google Meet for Google Cloud Support calls.

It is non-trivial to detect "on a call." Tracking camera use helps, but many calls do not use a camera.
Mic-only detection does not work well when apps like MOTIVMix or OBS Studio keep the mic in use.
Calendar-based detection misses ad hoc calls and huddles, and there may be calendar meetings you will not attend.

## How it works

This app works as an add-on to the existing Luxafor app, and both apps need to be installed.

The app runs in the background and tries to detect whether the camera is on, or whether there is active meeting UI in apps like Slack Huddle or Teams via the Accessibility framework.
If a meeting is active, voice activity decides between `inMeeting` (red) and `inMeetingSilent` (yellow).

When meeting state changes, the app calls the Luxafor webhook API to change the LED light.
By default it uses the local Luxafor webhook (`http://127.0.0.1:5383`) and can be switched to the remote Luxafor webhook via config.
Sometimes the local webhook can be less reliable than the remote webhook API.

## Screenshots

| Light ON (Red) | Light OFF |
| --- | --- |
| ![LuxaforPresence menu when On](docs/images/on.png) | ![LuxaforPresence menu when Off)](docs/images/off.png) |

## Project Status

Beta. Should work for Slack and Teams on recent versions of macOS.

| Info         | Status   | Notes                                             | Method              |
| -------------| ---------|---------------------------------------------------|---------------------|
| Mic           |  🟢     | Detected, not used in the meeting detection logic | macOS Native        |
| Camera        |  🟢     | Detected, camera usage sets "on a call"           | macOS Native        |
| Slack Huddle  |  🟢     | Detected, Slack Huddle turns "on a call", "muted" | macOS Accessibility |
| Slack Call    |         | Roadmap                                            | macOS Accessibility |
| Teams Meeting |  🟢     | Detected, Teams Meeting turns "on a call", "muted" | macOS Accessibility |
| Teams Call    |  🟡     | Implemented, needs more testing                    | macOS Accessibility |
| Voice Activity|  🟢     | Voice activity transitions "on a call", "muted" -> "on a call" | macOS Native, VAD |
| Calendar      |  🟡     | Implemented, limited testing                        | macOS Calendar   |
| Manual        |  🟢     | Manually set "on a call" ON or OFF                  | Menu Bar UI      |
| Screen Sharing|         | Roadmap                                             | macOS Native ?   |
| Zoom          |  🟡     | Implemented (process-based), needs more testing     | Process check     |
| Webex         |  🟡     | Implemented (process-based), needs more testing     | Process check     |
| Google Meet   |  🟡     | Implemented (browser tab + audio), needs more testing | AppleScript + browser |
| FaceTime      |         | Roadmap                                             |                  |

## Prerequisites

* macOS 13.0 or newer (Apple Silicon or Intel).
* Xcode 14.3+ or Xcode Command Line Tools with Swift 5.7 (`xcode-select --install`).
* A [Luxafor flag](https://luxafor.com/product/flag/) with [Luxafor software](https://www.luxaformanual.com/) installed.
* If using the remote Luxafor webhook, register Luxafor `userId`.


## Setup

1.  [Download](https://github.com/kantselovich/LuxaforPresence/releases) and install the app.

2.  **Configure Luxafor transport:**
    *   Create a configuration file at `~/.config/LuxaforPresence/config.plist`. The app will create the directory for you. You can copy the bundled config file and edit it.
    ```xml
    <dict>
        <key>transportMode</key>
        <string>local</string>
        <key>localWebhookBaseUrl</key>
        <string>http://127.0.0.1:5383</string>
        <key>localWebhookToken</key>
        <string>luxafor</string>
        <key>remoteWebhookUserId</key>
        <string>LUXAFOR_USER_ID_HERE</string>
    </dict>
    ```
    *   To use the remote webhook, set `transportMode` to `remote` and provide `remoteWebhookUserId`.

## Permissions

LuxaforPresence relies on macOS privacy permissions to be able to detect "on a call" state:

- **Microphone:** required for voice activity detection. The app does not record audio; it analyzes small input buffers to detect speech patterns.
- **Camera:** required to detect when the camera is in use and enumerate available camera devices. No video recording.
- **Accessibility:** required to detect active Teams meetings or Slack huddles.
- **Automation (Apple Events):** required for Google Meet checks in Chrome/Safari.
- **Calendar (optional):** required only when `useCalendar` is true.


# Development

## How to Build and Run

All commands are executed from the repository root and require the Xcode toolchain.

- `swift build` produces a debug build in `.build/debug/LuxaforPresence`.
- `swift run` produces a debug build and launches the menu bar app. The app started this way will be identified as its parent Terminal app (iTerm2, Ghostty, etc.).
- `swift run -c release` produces an optimized build.
- `swift test --enable-code-coverage` produces a debug build, runs test suite `LuxaforPresence/Tests` and creates coverage data in `.build/debug/codecov`
- `xcrun llvm-cov report .build/debug/LuxaforPresencePackageTests.xctest/Contents/MacOS/LuxaforPresencePackageTests     -instr-profile=.build/debug/codecov/default.profdata     -ignore-filename-regex=".build/|Tests/"     -use-color` test coverage report

## Packaging

```bash
./scripts/package-dmg.sh
```

The script defaults to the `release` configuration and creates `dist/LuxaforPresence.dmg` containing `LuxaforPresence.app`. 
It needs the standard macOS tools (`swift`, `hdiutil`, `plutil`) available in `$PATH`.

## Troubleshooting & Debugging

1. Check log stream
```bash
# run as admin, set 'category' to specific areas, like SlackMeetingDetector or PresenceEngine
log stream --level debug --predicate 'subsystem == "com.example.LuxaforPresence" && (category == "PresenceEngine" || category == "VoiceActivitySignal")'
```
2. Confirm Accessibility access is granted to LuxaforPresence (or Terminal/Xcode when running from `swift run`). The app prompts on first launch.
   Remove LuxaforPresence from Accessibility and add it back.

## Dependencies

This project has no external package dependencies. The Swift Package Manager will handle the project setup.

## License

LuxaforPresence is available under the [Apache License 2.0](LICENSE.txt), which permits commercial use as long as copyright and attribution notices are preserved.
