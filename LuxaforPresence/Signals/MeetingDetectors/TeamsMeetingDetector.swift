import Foundation
import OSLog

final class TeamsMeetingDetector: MeetingDetectorProtocol {
    private let logger = Logger(subsystem: "com.example.LuxaforPresence", category: "TeamsMeetingDetector")
    private let snapshotProvider: AXSnapshotProviding
    private let isProcessRunning: ([String]) -> Bool
    private let processNames = ["Microsoft Teams", "Teams"]
    private let bundleIdentifiers = ["com.microsoft.teams2", "com.microsoft.teams"]
    private let domIdentifiers: Set<String> = [
        "microphone-button",
        "video-button",
        "share-button",
        "hangup-button",
    ]
    private let toolbarLabels: Set<String> = [
        "Calling controls",
        "Meeting controls",
    ]

    var name: String { "Teams" }

    init(
        snapshotProvider: AXSnapshotProviding = AccessibilitySnapshotProvider(),
        isProcessRunning: @escaping ([String]) -> Bool = ProcessSignal.isRunning
    ) {
        self.snapshotProvider = snapshotProvider
        self.isProcessRunning = isProcessRunning
    }

    func isMeetingActive() -> Bool {
        // Teams meeting detection uses AX-only, privacy-safe signals from call controls.
        guard isProcessRunning(processNames) else {
            logger.debug("Teams process not running")
            return false
        }
        guard let nodes = snapshotProvider.snapshot(bundleIdentifiers: bundleIdentifiers, processNames: processNames) else {
            logger.debug("AX snapshot unavailable (not authorized or failed)")
            return false
        }

        var matchedDomIdentifiers = Set<String>()
        var matchedToolbarLabels = Set<String>()

        for node in nodes {
            if let domIdentifier = node.domIdentifier, domIdentifiers.contains(domIdentifier) {
                matchedDomIdentifiers.insert(domIdentifier)
            }
            if let label = node.label, let role = node.role, role == "AXToolbar", toolbarLabels.contains(label) {
                matchedToolbarLabels.insert(label)
            }
        }

        logger.debug(
            "Teams AX snapshot: nodes=\(nodes.count) domMatches=\(matchedDomIdentifiers.sorted(), privacy: .public) toolbarMatches=\(matchedToolbarLabels.sorted(), privacy: .public)"
        )

        if !matchedDomIdentifiers.isEmpty {
            logger.debug("Teams meeting detected via DOM identifiers")
            return true
        }

        if !matchedToolbarLabels.isEmpty {
            logger.debug("Teams meeting detected via toolbar label fallback")
            return true
        }

        logger.debug("Teams meeting not detected (no matching AX controls)")
        return false
    }
}
