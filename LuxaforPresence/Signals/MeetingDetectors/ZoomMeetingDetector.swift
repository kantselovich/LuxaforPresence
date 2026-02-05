import Foundation

final class ZoomMeetingDetector: MeetingDetectorProtocol {
    var name: String { "Zoom" }

    func isMeetingActive() -> Bool {
        ProcessSignal.isRunning(executableNames: ["CptHost"])
    }
}
