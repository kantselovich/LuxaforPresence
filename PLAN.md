# macOS Menu Bar “Luxafor Presence” App — Engineer’s Brief

Goal: a small, sandboxed macOS menu bar app that:

* infers **IN_MEETING** from system signals (mic/camera usage + active app, optionally calendar),
* POSTs to Luxafor Webhook API to **turn flag RED** when IN_MEETING,
* POSTs to **turn flag OFF (black)** when NOT_MEETING,
* shows current status in the menu bar icon and lets the user manually force **On**/**Off**.

---

## Architecture Overview

**Process model**

* Menu bar **agent** app (no dock icon, LSUIElement).
* Poll every 2–3 seconds with a **lightweight heuristic**:

  * `micOrCameraInUse` (AVFoundation + CoreAudio HAL).
  * `frontmostApp ∈ meetingBundleAllowlist` (Zoom/Teams/Webex/Slack/Chrome/Safari).
  * *(Optional)* `EventKit` for ongoing calendar event with a meeting URL.

**Decision**

```
IN_MEETING = (micOrCameraInUse) AND (frontmostAppIsMeeting || calendarHasMeetingNow)
else NOT_MEETING
```

**Side effects**

* On state change, fire **Luxafor webhook**:

  * ON (red):

    ```
    POST https://api.luxafor.com/webhook/v1/actions/solid_color
    {"userId":"<USER_ID>","actionFields":{"color":"red"}}
    ```
  * OFF (black):

    ```
    POST https://api.luxafor.com/webhook/v1/actions/solid_color
    {"userId":"<USER_ID>","actionFields":{"color":"custom","custom_color":"000000"}}
    ```

**Config**

* `userId` (required).
* `pollIntervalSeconds` (default 2).
* `meetingBundleAllowlist` (defaults provided; user-editable via simple JSON in `UserDefaults`).

---

## Project Structure

```
LuxaforPresence/
  ├─ LuxaforPresenceApp.swift         # @main entry, sets AppDelegate
  ├─ AppDelegate.swift                # creates NSStatusItem, timers, menu
  ├─ PresenceEngine.swift             # heuristic + state machine
  ├─ Signals/
  │   ├─ MicCamSignal.swift           # AVFoundation + CoreAudio checks
  │   ├─ FrontmostAppSignal.swift     # NSWorkspace checks
  │   └─ CalendarSignal.swift         # EventKit (optional)
  ├─ Transport/
  │   └─ LuxaforClient.swift          # URLSession POST wrapper
  ├─ Model/
  │   └─ PresenceState.swift          # enum + transition logic
  ├─ UI/
  │   └─ StatusIcon.swift             # template images or SF Symbols
  ├─ Resources/
  │   ├─ Assets.xcassets              # template icons for On/Off
  │   └─ Info.plist                   # usage descriptions
  └─ Tests/
      ├─ PresenceEngineTests.swift    # pure logic tests
      └─ LuxaforClientTests.swift     # network stub tests
```

**Target settings**

* macOS 13+.
* App Sandbox **with outgoing network**.
* `LSUIElement` = `1` (menu bar–only).
* Usage descriptions (if using EventKit): `NSCalendarsUsageDescription`.

---

## Key Swift Snippets

### 1) Menu Bar Setup + Timer

```swift
// AppDelegate.swift
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var timer: Timer?
    private let engine = PresenceEngine()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateStatusIcon(.unknown)

        let menu = NSMenu()
        menu.addItem(withTitle: "Force ON (Red)", action: #selector(forceOn), keyEquivalent: "")
        menu.addItem(withTitle: "Force OFF", action: #selector(forceOff), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Preferences…", action: #selector(openPrefs), keyEquivalent: ",")
        menu.addItem(withTitle: "Quit", action: #selector(quit), keyEquivalent: "q")
        statusItem.menu = menu

        engine.onStateChange = { [weak self] state in
            DispatchQueue.main.async { self?.updateStatusIcon(state) }
        }

        timer = Timer.scheduledTimer(withTimeInterval: engine.config.pollInterval, repeats: true) { [weak self] _ in
            self?.engine.tick()
        }
    }

    private func updateStatusIcon(_ state: PresenceState) {
        let iconName: String = {
            switch state {
            case .inMeeting: return "StatusIconOn"   // red dot
            case .notMeeting: return "StatusIconOff" // hollow/gray
            case .unknown: return "StatusIconIdle"
            }
        }()
        statusItem.button?.image = NSImage(named: iconName)
        statusItem.button?.image?.isTemplate = true
        statusItem.button?.toolTip = "Luxafor: \(state.rawValue)"
    }

    @objc private func forceOn()  { engine.force(.inMeeting) }
    @objc private func forceOff() { engine.force(.notMeeting) }
    @objc private func openPrefs() { /* simple NSAlert or NSPanel for userId etc. */ }
    @objc private func quit() { NSApp.terminate(nil) }
}
```

### 2) Presence State & Engine

```swift
// PresenceState.swift
enum PresenceState: String {
    case inMeeting = "ON (Red)"
    case notMeeting = "OFF"
    case unknown = "Unknown"
}

// PresenceEngine.swift
import Foundation

final class PresenceEngine {
    struct Config {
        var userId: String = "<REPLACE_ME>"
        var pollInterval: TimeInterval = 2.0
        var meetingBundles: Set<String> = [
            "us.zoom.xos",
            "com.microsoft.teams2",
            "com.microsoft.teams",
            "com.cisco.webex.meetingapp",
            "com.slack.slack",
            "com.google.Chrome",
            "com.apple.Safari"
        ]
        var useCalendar: Bool = false
    }

    var config = Config()
    var onStateChange: ((PresenceState) -> Void)?

    private let micCam = MicCamSignal()
    private let frontApp = FrontmostAppSignal()
    private let calendar = CalendarSignal()
    private let luxafor = LuxaforClient()
    private var lastState: PresenceState = .unknown
    private var forcedState: PresenceState?

    func force(_ state: PresenceState) {
        forcedState = state
        apply(state)
    }

    func tick() {
        if let s = forcedState { apply(s); return }

        let micOrCam = micCam.anyInUse()
        let isMeetingApp = frontApp.isFrontmostIn(allowlist: config.meetingBundles)
        var eventOK = false
        if config.useCalendar { eventOK = calendar.hasOngoingMeetingEvent() }

        let newState: PresenceState =
            (micOrCam && (isMeetingApp || eventOK)) ? .inMeeting : .notMeeting

        if newState != lastState {
            apply(newState)
        }
    }

    private func apply(_ state: PresenceState) {
        lastState = state
        onStateChange?(state)
        switch state {
        case .inMeeting:  luxafor.turnOnRed(userId: config.userId)
        case .notMeeting: luxafor.turnOff(userId: config.userId)
        case .unknown: break
        }
    }
}
```

### 3) Mic/Camera Signals

```swift
// MicCamSignal.swift
import AVFoundation
import CoreAudio

final class MicCamSignal {
    func anyInUse() -> Bool {
        let audioInUse = AVCaptureDevice.devices(for: .audio).contains { $0.isInUseByAnotherApplication }
        let videoInUse = AVCaptureDevice.devices(for: .video).contains { $0.isInUseByAnotherApplication }
        return audioInUse || videoInUse || defaultInputIsRunning()
    }

    private func defaultInputIsRunning() -> Bool {
        var dev = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &dev) == noErr, dev != 0 else { return false }

        var running: UInt32 = 0
        size = UInt32(MemoryLayout<UInt32>.size)
        addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectGetPropertyData(dev, &addr, 0, nil, &size, &running) == noErr else { return false }
        return running != 0
    }
}
```

### 4) Frontmost App Signal

```swift
// FrontmostAppSignal.swift
import AppKit

final class FrontmostAppSignal {
    func isFrontmostIn(allowlist: Set<String>) -> Bool {
        guard let app = NSWorkspace.shared.frontmostApplication else { return false }
        guard let bid = app.bundleIdentifier else { return false }
        return allowlist.contains(bid)
    }
}
```

### 5) Calendar (Optional)

```swift
// CalendarSignal.swift
import EventKit

final class CalendarSignal {
    private lazy var store = EKEventStore()

    // Call once at startup if using calendar
    func requestAccess(completion: @escaping (Bool) -> Void) {
        store.requestAccess(to: .event) { granted, _ in completion(granted) }
    }

    func hasOngoingMeetingEvent() -> Bool {
        // if you didn’t get permission, bail out:
        guard EKEventStore.authorizationStatus(for: .event) == .authorized else { return false }
        let now = Date()
        let pred = store.predicateForEvents(withStart: now.addingTimeInterval(-300),
                                            end: now.addingTimeInterval(3*3600),
                                            calendars: nil)
        let events = store.events(matching: pred).filter { $0.startDate <= now && now <= $0.endDate }
        return events.contains { ev in
            let blob = [ev.location, ev.notes, ev.url?.absoluteString].compactMap { $0 }.joined(separator: " ")
            return blob.range(of: #"(?i)(zoom\.us|teams\.microsoft\.com|meet\.google\.com|webex\.com)"#, options: .regularExpression) != nil
        }
    }
}
```

### 6) Luxafor Client

```swift
// LuxaforClient.swift
import Foundation

final class LuxaforClient {
    private let endpoint = URL(string: "https://api.luxafor.com/webhook/v1/actions/solid_color")!
    private let session = URLSession(configuration: .ephemeral)

    func turnOnRed(userId: String) {
        post(["userId": userId, "actionFields": ["color": "red"]])
    }

    func turnOff(userId: String) {
        post(["userId": userId, "actionFields": ["color": "custom", "custom_color": "000000"]])
    }

    private func post(_ body: [String: Any]) {
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        let task = session.dataTask(with: req) { data, resp, err in
            // Optional: log errors, backoff, retry on 5xx
        }
        task.resume()
    }
}
```

---

## UI/UX Notes

* **Status Icon**: three template assets: `StatusIconOn` (solid dot), `StatusIconOff` (hollow), `StatusIconIdle` (dash).
* **Menu**:

  * *Force ON (Red)*: sets forced state; persists until Force OFF or “Release override” (optional).
  * *Force OFF*: as above.
  * *Preferences…*: minimal dialog to set `userId` and toggle calendar heuristic.
  * *Quit*.

---

## Info.plist / Entitlements

* `LSUIElement` = `1` (hides dock icon).
* App Sandbox: **Outgoing Connections (Client)**.
* If using calendar: `NSCalendarsUsageDescription` = “Used to infer when you’re in a meeting.”
* No microphone permission is required; we’re not recording audio—just checking device state.

---

## Build & Run

1. Create a new **AppKit** project (Swift, Storyboards off, or SwiftUI + AppDelegate).
2. Add files per structure above.
3. Add Assets for status icons (template images).
4. Enable **App Sandbox** & **Outgoing Network**.
5. Set `LSUIElement` in Info.plist.
6. Run. First launch:

   * Enter **Luxafor `userId`** in Preferences.
   * (Optional) Allow calendar access.

---

## Testing Strategy

**Unit tests**

* `PresenceEngineTests`:

  * Inject protocol-based fakes for `MicCamSignal`, `FrontmostAppSignal`, `CalendarSignal`, `LuxaforClient`.
  * Verify transitions debounce correctly (e.g., don’t spam webhooks—consider adding a 500ms hysteresis if needed).
* `LuxaforClientTests`:

  * Inject `URLProtocol` stub, assert payload:

    * ON: `{"userId": "...", "actionFields":{"color":"red"}}`
    * OFF: `{"userId": "...", "actionFields":{"color":"custom","custom_color":"000000"}}`

**Manual tests**

* Start a Zoom/Teams/Webex call → icon should turn **ON** within ~2s; Luxafor goes **red**.
* Leave the call → icon **OFF**; Luxafor turns **black**.
* Use **Force ON/OFF** to override heuristic; verify no automatic flips while forced.
* Browser-based Meet: ensure Chrome/Safari in allowlist; icon flips when mic is active.

**Edge cases**

* Dictation/Voice Memos trigger mic without meeting app → remains OFF (unless calendar says meeting).
* Slack Huddles: ensure Slack in allowlist; verify mic in use.
* Calendar disabled → heuristic still works on mic/camera + allowlisted app.

---

## Production Hardening (nice-to-have)

* **Hysteresis/debounce** to avoid flapping (e.g., require 2 consecutive ticks before changing).
* **Backoff & retry** for network failures (exponential backoff).
* **UserDefaults** for `userId`, allowlist, interval.
* **Logging** to unified log (`os_log`).
* **Privacy**: never capture audio/video; never enumerate window contents.

---

## Quick cURL Equivalents (for reference)

**ON (red)**

```bash
curl -X POST -H "Content-Type: application/json" -d '{
  "userId": "YOUR_USER_ID_HERE",
  "actionFields": { "color": "red" }
}' https://api.luxafor.com/webhook/v1/actions/solid_color
```

**OFF (black)**

```bash
curl -X POST -H "Content-Type: application/json" -d '{
  "userId": "YOUR_USER_ID_HERE",
  "actionFields": { "color": "custom", "custom_color": "000000" }
}' https://api.luxafor.com/webhook/v1/actions/solid_color
```

---

## Summary

You’re building a minimal, reliable **menu bar presence agent**:

* infer presence from **mic/cam + active app** (+ optional calendar),
* update **Luxafor** via two simple webhooks,
* provide **manual override** and clear visual status.
  This keeps permissions light, avoids vendor-specific SDKs, and works across Zoom/Teams/Meet/Webex/Slack.

