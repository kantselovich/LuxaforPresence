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
    private let huddleControlLabels = [
        "Share your screen",
        "More actions",
        "View members",
    ]
    private let huddleControlRoles = [
        "AXCheckBox",
        "AXPopUpButton",
        "AXButton",
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
            AccessibilityTrustDiagnostics.logNotTrusted(logger: logger, context: "slack snapshot")
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
        let pids = Set(nodes.compactMap { $0.pid }).sorted()
        if !anchorFound {
            logger.debug("Slack AX snapshot: nodes=\(nodes.count) pids=\(pids, privacy: .public) anchorFound=false")
            return false
        }

        var matchedControls = Set<String>()
        for node in nodes {
            guard let label = node.label, let role = node.role else { continue }
            guard huddleControlRoles.contains(role) else { continue }
            let normalizedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
            if huddleControlLabels.contains(where: { normalizedLabel.localizedCaseInsensitiveContains($0) }) {
                matchedControls.insert(normalizedLabel)
            }
        }
        logger.debug(
            "Slack AX snapshot: nodes=\(nodes.count) pids=\(pids, privacy: .public) anchorFound=true matchedControls=\(matchedControls.sorted(), privacy: .public)"
        )

        if matchedControls.isEmpty {
            logger.debug("Slack huddle detected via anchor (no control matches)")
        }
        return true
    }
}
