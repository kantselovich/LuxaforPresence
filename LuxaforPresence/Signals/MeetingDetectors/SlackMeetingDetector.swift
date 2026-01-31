import Foundation
import OSLog

final class SlackMeetingDetector: MeetingDetectorProtocol {
    private let logger = Logger(subsystem: "com.example.LuxaforPresence", category: "SlackMeetingDetector")
    private let snapshotProvider: AXSnapshotProviding
    private let isProcessRunning: ([String]) -> Bool
    private let processNames = ["Slack"]
    private let bundleIdentifiers = ["com.tinyspeck.slackmacgap"]
    private let huddleAnchor = "Huddles actions (toolbar)"
    private let huddleControls: [(label: String, role: String)] = [
        ("Share your screen", "AXCheckBox"),
        ("More actions", "AXPopUpButton"),
        ("View members", "AXPopUpButton"),
    ]

    var name: String { "Slack" }

    init(
        snapshotProvider: AXSnapshotProviding = AccessibilitySnapshotProvider(),
        isProcessRunning: @escaping ([String]) -> Bool = ProcessSignal.isRunning
    ) {
        self.snapshotProvider = snapshotProvider
        self.isProcessRunning = isProcessRunning
    }

    func isMeetingActive() -> Bool {
        // Slack huddle detection uses AX-only, privacy-safe signals from the huddle control strip.
        guard isProcessRunning(processNames) else { return false }
        guard let nodes = snapshotProvider.snapshot(bundleIdentifiers: bundleIdentifiers, processNames: processNames) else {
            logger.debug("AX snapshot unavailable (not authorized or failed)")
            return false
        }

        let anchorFound = nodes.contains { node in
            (node.placeholder?.contains(huddleAnchor) ?? false)
                || (node.roleDescription?.contains(huddleAnchor) ?? false)
        }
        guard anchorFound else { return false }

        let controlFound = nodes.contains { node in
            guard let label = node.label, let role = node.role else { return false }
            return huddleControls.contains { $0.label == label && $0.role == role }
        }

        return controlFound
    }
}
