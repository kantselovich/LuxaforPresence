# PLAN 2 — Additional Signals, Logging, and History

## 1. Objectives
- Reduce false positives from always-on audio tools (e.g., Motiv Mix) without losing sensitivity to real meetings.
- Introduce higher-confidence cues (screen share, calendar context, per-app output).
- Capture rich diagnostics and local history (including manual overrides) so we can iterate or train heuristics later.
- Back all new behavior with tests and structured logging.

## 2. Workstreams at a Glance
1. **Signal Layer Enhancements**
   - Calendar signal (EventKit) with online-meeting detection.
   - Screen-share indicator based on ScreenCaptureKit + Accessibility fallback.
   - Per-app audio output monitor for allowlisted bundles.
   - Audio device blocklist (Motiv Mix, Loopback drivers) applied before aggregation.
2. **Presence Engine Updates**
   - Combine signals with weighted scoring + debounce.
   - Persist manual overrides and emit corrective labels into history.
3. **Logging & History**
   - Structured `os_log` for each tick (per-signal payload, chosen state, Luxafor updates).
   - Local history writer (JSONL in `~/Library/Logs/LuxaforPresence/history.log`).
4. **Testing**
   - Unit tests per signal + engine scenarios.
   - Integration smoke test wiring the new signals behind fakes.

## 3. Signal Layer Details

### 3.1 CalendarSignal v2
- **Scope**: detect active events with `hasRecurrenceRules`, `isAllDay == false`, start/end bounds, and `structuredLocation` or `URL` containing common meeting prefixes (`zoom.us`, `teams.microsoft.com`, `meet.google.com`, `webex.com`).
- **Implementation**
  - Request calendar access on first use; cache authorization status.
  - Poll once per minute; cache result for ticks in between to avoid EventKit churn.
  - Emit payload: `CalendarSignal.State(isMeeting: Bool, confidence: Double, source: .event(.title, .urlScheme))`.
- **Tests**
  - Event with valid URL → `isMeeting == true`.
  - All-day events and duplicates suppressed.

### 3.2 ScreenShareSignal
- **Primary**: use ScreenCaptureKit (`SCShareableContent.current.applicationRecordings`) to see if current process is sharing; requires Screen Recording permission.
- **Fallback**: Accessibility API to watch for the macOS screen-share menu bar indicator (`AXStatusBarButton` titled “Screen Sharing”).
- **Payload**: `isSharing: Bool`, `ownerBundleID`.
- **Risks**: permission prompt; add onboarding copy in README.
- **Tests**: injectable protocol with fake providers; verify debounce when state flaps quickly.

### 3.3 AudioOutputSignal
- **Goal**: treat non-silent audio output from allowlisted bundles as a meeting cue even when mic is muted.
- **Implementation sketch**
  - Enumerate output streams via CoreAudio (`AudioObjectID` of default output).
  - Capture per-stream peak/RMS levels and associated `kAudioStreamPropertyOwningProcessPID`.
  - Crosswalk PID → bundle ID via `NSRunningApplication`.
  - Emit when > `-35 dB` for ≥ 2 consecutive ticks from a meeting app.
- **Tests**: fake CoreAudio provider returning sample dB values; verify threshold logic.

### 3.4 MicCamSignal Hardening
- Maintain a blocklist of device names/UIDs (Motiv Mix, Loopback, Rogue Amoeba). Ignore them when aggregating mic/camera usage.
- Track per-device stats in logs for debugging.

## 4. PresenceEngine Changes
- Convert heuristic into weighted scoring:
  - `mic/cam active` (after blocklist) = +0.4
  - `frontmost allowlisted` = +0.2
  - `calendar meeting now` = +0.2
  - `screen sharing` = +0.4
  - `allowlisted audio output` = +0.2
  - Meeting detected if score ≥ 0.6 OR `(screen sharing || calendar meeting) AND (frontmost allowlisted || manual override == forceOn)`.
- Add **debounce**: require consistent score on 2 ticks before notifying Luxafor.
- Manual override now writes `HistoryEntry(kind: .manual, desiredState, reason, timestamp)` and decays after X minutes or explicit release.

## 5. Logging & Local History
- **Structured logging**: use `Logger` (swift-log) with subsystem `com.example.LuxaforPresence`.
  - Each tick logs JSON payload summarizing signals, calculated score, final decision, and Luxafor action.
  - Errors (permission denied, EventKit failures) logged at `.error`.
- **History writer**
  - Append-only JSONL file at `~/Library/Logs/LuxaforPresence/history.log`.
  - Fields: timestamp, frontmost bundle, mic devices active, calendar event id, screenShareOwner, audioOutputBundles, manualOverride state, finalPresence.
  - Rotate file at 5 MB to avoid unbounded growth.
  - History used later for ML experiments; never leaves disk without explicit user action.

## 6. Manual Override UX
- Add “Mark Not In Meeting for 10 min” option to status menu; countdown displayed in submenu.
- When override toggled, emit history entry with `labelSource: "user"` to serve as RL feedback.
- Provide “Clear Override & Resume Auto” menu item.

## 7. Testing Plan
- **Unit**
  - `CalendarSignalTests`, `ScreenShareSignalTests`, `AudioOutputSignalTests`, updated `MicCamSignalTests`.
  - `PresenceEngineScoringTests` verifying combinations and debounce.
  - `HistoryWriterTests` ensuring log rotation and JSON schema.
- **Integration**
  - End-to-end test harness injecting fakes into `PresenceEngine` and asserting LuxaforClient calls + history entries.
- **Manual**
  - Scenario matrix covering Motiv Mix running, passive webinar (audio output only), screen share without mic, and calendar-only meeting.

## 8. Logging & Privacy Considerations
- Redact sensitive calendar titles/URLs before logging (e.g., hash event identifier, truncate title).
- Screen share logs only include bundle ID, never window titles.
- Allow users to clear history via menu item (delete file + restart writer).

## 9. Rollout Steps
1. Ship CalendarSignal + blocklist first (behind feature flag).
2. Add history writer and override logging.
3. Introduce screen-share detection (opt-in, prompt users).
4. Layer per-app audio output once stability verified.
5. Iterate with history data to adjust weights; consider exposing weights in config for power users.

## 10. Done Criteria
- All new signals gated behind configuration keys with sane defaults.
- `swift test` covers the added modules.
- README + AGENTS updated with permissions and troubleshooting for new signals.
- Users can inspect history log and understand override interactions.

