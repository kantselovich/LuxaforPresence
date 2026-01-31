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
        guard isProcessRunning(processNames) else { return false }
        guard let nodes = snapshotProvider.snapshot(bundleIdentifiers: bundleIdentifiers, processNames: processNames) else {
            logger.debug("AX snapshot unavailable (not authorized or failed)")
            return false
        }

        if nodes.contains(where: { node in
            guard let domIdentifier = node.domIdentifier else { return false }
            return domIdentifiers.contains(domIdentifier)
        }) {
            return true
        }

        return nodes.contains { node in
            guard let label = node.label, let role = node.role else { return false }
            return role == "AXToolbar" && toolbarLabels.contains(label)
        }
    }
}
