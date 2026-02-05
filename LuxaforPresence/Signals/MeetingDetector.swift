import Foundation

final class MeetingDetector: MeetingDetectorProtocol {
    private let detectors: [MeetingDetectorProtocol]

    init(
        detectors: [MeetingDetectorProtocol] = [
            ZoomMeetingDetector(),
            WebexMeetingDetector(),
            TeamsMeetingDetector(),
            SlackMeetingDetector(),
            GoogleMeetDetector(),
        ],
        enabledNames: Set<String>? = nil
    ) {
        if let enabledNames {
            self.detectors = detectors.filter { enabledNames.contains($0.name) }
        } else {
            self.detectors = detectors
        }
    }

    var name: String { "Aggregate" }

    func isMeetingActive() -> Bool {
        detectors.contains { $0.isMeetingActive() }
    }
}
