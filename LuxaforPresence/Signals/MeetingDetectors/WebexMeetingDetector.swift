import Foundation

final class WebexMeetingDetector: MeetingDetectorProtocol {
    var name: String { "Webex" }

    func isMeetingActive() -> Bool {
        ProcessSignal.isRunning(executableNames: ["WebexAppLauncher"])
    }
}
