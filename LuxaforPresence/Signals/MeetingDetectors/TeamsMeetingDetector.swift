import Foundation

final class TeamsMeetingDetector: MeetingDetectorProtocol {
    var name: String { "Teams" }

    func isMeetingActive() -> Bool {
        // TODO: Add a reliable Teams meeting activity signal (logs/IPC/API) beyond process presence.
        false
    }
}
