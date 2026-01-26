import Foundation

final class SlackMeetingDetector: MeetingDetectorProtocol {
    var name: String { "Slack" }

    func isMeetingActive() -> Bool {
        // TODO: Implement a reliable huddle/Call detection (AX/menu/API). Placeholder returns false for now.
        false
    }
}
