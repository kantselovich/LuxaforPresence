# LuxaforPresence for macOS

Native macOS menu bar app that updates a [Luxafor flag](https://luxafor.com/product/flag/) if you are actually in a meeting.

## Why

To show your family members that you are on a call at the moment. 

Luxafor presense light comes witn an app, that integrates into Teams, Google Calendar, Zoom and a few other things.  However,
Only one integration can be active at a time, and Teams integration require approval from corporate IT team, which makes this a non starter for a lot of folks.

This is normal to use multiple call apps, for example Slack huddles for pairing, Teams for scheduled meetings, Zoom with external customers and Google Meet for Google Cloud Support calls.

It's actually non-trivial to detect "on a call".  Stracking camara use works, but a lot of calls do not use camera. 
Mic-only detection does not work when there when apps like MOTIVMix or OBS Stido keep mic always in use
Calendar-based detection misses ad hoc calls and huddles and there could be meeting on the calendar that you will not attend.

## How it works

This app works as add-on to the exiting Luxafor App, both apps need to installed.

The app runs on the backround and tries to detect if camera is on 
or if there an active meeting UI app running, like Slack Huddle or Teams call by using Accessiblity framework.
If a meeting is active, voice activity decides between `inMeeting` (red) and `inMeetingSilent` (yellow)

When on meeting state changes, the app calls the Luxafor webhook API to change the LED light.
By default it uses the local Luxafor webhook (`http://127.0.0.1:5383`) and can be switched to the remote Luxafor webhook via config.
Sometimes local webhook can be less reliable than remote webhook api.

## Screenshots

| Light ON (Red) | Light OFF |
| --- | --- |
| ![LuxaforPresence menu when On](docs/images/on.png) | ![LuxaforPresence menu when Off)](docs/images/off.png) |

## Project Status

Beta.  Should work for Slack and Teams for resent versions of MacOS.

| Info         | Status   | Notes                                             | Method              |
| -------------| ---------|---------------------------------------------------|---------------------|
| Mic           |  🟢     | Detected, not used in the meeting detection logic | MacOS Native        |
| Camera        |  🟢     | Detected, camera usage turns "on a call" flag      | MacOS Native        |
| Slack Huddle  |  🟢     | Detected, Slack Huddle turns "on a call", "muted"  | MacOS Accessibility |
| Slack Call    |         | Roadmap                                            | MacOS Accessibility |               
| Teams Meeting |  🟢     | Detected, Teams Meeting turns "on a call", "muted" | MacOS Accessibility |
| Teams Call    |  🟡     | Implemented, needs more testing                    | MacOS Accessibility |                         
| Voice Actovity|  🟢     | Voice Activity transtions "on a call", "muted" -> "on a call" | MacOS Native, VAD |                     
| Calendar      |  🟡     | Implemented, not tested.                            | MacOS Calendar   |
| Manual        |  🟢     | Manually set "on a call" ON or OF                   | Menu Bar UI      |         
| Screen Sharing|         | Roadmap                                             | MacOS Native ?   |
| Zoom          |         | Roadmap                                             |                  |
| Google Meet   |         | Roadmap                                             |                  |
| Facetime      |         | Roadmap                                             |                  |

## Prerequisites

* macOS 13.0 or newer (Apple Silicon or Intel).
* Xcode 14.3+ or Xcode Command Line Tools with Swift 5.7 (`xcode-select --install`).
* A [Luxafor flag](https://luxafor.com/product/flag/) with [Luxafor software](https://www.luxaformanual.com/) installed.
* If using the remote Luxafor webhook, register Luxafor `userId`.


## Setup

1.  [Download](https://github.com/kantselovich/LuxaforPresence/releases) and install the app.

2.  **Configure Luxafor transport:**
    *   Create a configuration file at `~/.config/LuxaforPresence/config.plist`  The app will create the directory for you. You can copy the bundeled config file and edit it.
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

- **Microphone:** required for voice activity detection. The app does not record audio, it capures small buffer of audio input to detect if there is voice pattern present.
- **Microphone/Camera:** required to detect when camera is on and detect available camera devices. No video recoding. 
- **Accessibility:** required to detect if there is active Teams Meeting or Slack huddle. It checks Accessiblity for a list of apps defined
- **Calendar (optional):** required only when `useCalendar` is true.


# Development

## How to Build and Run

All commands are executed from the repository root and require the Xcode toolchain.

`swift build Produces debug build in `.build/debug/LuxaforPresence`. 
`swift run`  Produces debug build and launches the menu bar app. The app started this way will be identified as it's parent Terminal app (iTerm2, Ghostty, etc) 
`swift run -c release` Produces normal build.
`swift test` Produces debug build and runs test suite `LuxaforPresence/Tests`

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
   Remove LuxaforPresence app from Accessibility and add it back.

## Dependencies

This project has no external package dependencies. The Swift Package Manager will handle the project setup.

## License

LuxaforPresence is available under the [Apache License 2.0](LICENSE.txt), which permits commercial use as long as copyright and attribution notices are preserved.
