import Foundation
import OSLog

final class SlackMeetingDetector: MeetingDetectorProtocol {
    private let logger = Logger(subsystem: "com.example.LuxaforPresence", category: "SlackMeetingDetector")
    private let snapshotProvider: AXSnapshotProviding
    private let isProcessRunning: ([String]) -> Bool
    private let processNames = ["Slack"]
    private let bundleIdentifiers = ["com.tinyspeck.slackmacgap"]
    private let huddleAnchorPrefix = "Huddle:"
    private let huddleToolbarLabel = "Huddles actions"
    private let huddleControls: [(label: String, role: String)] = [
        ("Share your screen", "AXCheckBox"),
        ("More actions", "AXPopUpButton"),
        ("View members", "AXPopUpButton"),
        ("Share your screen", "AXButton"),
        ("More actions", "AXButton"),
        ("View members", "AXButton"),
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
        guard isProcessRunning(processNames) else {
            logger.debug("Slack process not running")
            return false
        }
        guard let nodes = snapshotProvider.snapshot(bundleIdentifiers: bundleIdentifiers, processNames: processNames) else {
            logger.debug("AX snapshot unavailable (not authorized or failed)")
            return false
        }

        let anchorFound = nodes.contains { node in
            if let label = node.label, label.hasPrefix(huddleAnchorPrefix) {
                return true
            }
            if let label = node.label, label == huddleToolbarLabel {
                return true
            }
            return false
        }
        if !anchorFound {
            logger.debug("Slack AX snapshot: nodes=\(nodes.count) anchorFound=false")
            return false
        }

        var matchedControls = Set<String>()
        for node in nodes {
            guard let label = node.label, let role = node.role else { continue }
            if huddleControls.contains(where: { $0.label == label && $0.role == role }) {
                matchedControls.insert(label)
            }
        }
        let controlFound = !matchedControls.isEmpty
        logger.debug("Slack AX snapshot: nodes=\(nodes.count) anchorFound=true matchedControls=\(matchedControls.sorted(), privacy: .public)")

        if !controlFound {
            logger.debug("Slack huddle not detected (no control matches)")
        }
        return controlFound
    }
}
