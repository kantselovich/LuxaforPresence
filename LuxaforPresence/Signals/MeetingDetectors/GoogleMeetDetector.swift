import AppKit
import Foundation

final class GoogleMeetDetector: MeetingDetectorProtocol {
    var name: String { "GoogleMeet" }

    func isMeetingActive() -> Bool {
        guard isBrowserRunning else { return false }
        return chromeMeetActive() || safariMeetActive()
    }

    private var isBrowserRunning: Bool {
        ProcessSignal.isRunning(executableNames: ["Google Chrome", "Safari"])
    }

    private func chromeMeetActive() -> Bool {
        let script = """
        tell application "Google Chrome"
            if it is running then
                repeat with w in windows
                    repeat with t in tabs of w
                        if (URL of t contains "meet.google.com") then
                            if (audible of t is true) then return true
                        end if
                    end repeat
                end repeat
            end if
        end tell
        return false
        """
        return runAppleScriptReturningBool(script)
    }

    private func safariMeetActive() -> Bool {
        let script = """
        tell application "Safari"
            if it is running then
                repeat with w in windows
                    repeat with t in tabs of w
                        if (URL of t contains "meet.google.com") then
                            if (audible of t is true) then return true
                        end if
                    end repeat
                end repeat
            end if
        end tell
        return false
        """
        return runAppleScriptReturningBool(script)
    }

    private func runAppleScriptReturningBool(_ source: String) -> Bool {
        guard let script = NSAppleScript(source: source) else { return false }
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        if error != nil {
            return false
        }
        return result.booleanValue
    }
}
