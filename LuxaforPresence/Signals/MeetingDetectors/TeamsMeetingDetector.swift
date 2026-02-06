import Foundation
import OSLog

final class TeamsMeetingDetector: MeetingDetectorProtocol {
    private let logger = Logger(subsystem: "com.example.LuxaforPresence", category: "TeamsMeetingDetector")
    private let snapshotProvider: AXSnapshotProviding
    private let isProcessRunning: ([String]) -> Bool
    private let processNames = [
        "Microsoft Teams",
        "Teams",
        "Microsoft Teams WebView Helper",
        "Microsoft Teams WebView Helper (Renderer)",
        "Microsoft Teams WebView Helper (GPU)",
        "Microsoft Teams WebView Helper (Plugin)",
    ]
    private let bundleIdentifiers = [
        "com.microsoft.teams2",
        "com.microsoft.teams",
        "com.microsoft.teams2.helper",
    ]
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
    private let meetingControlLabels: Set<String> = [
        "Raise",
        "Raise your hand",
        "Camera",
        "Mic",
        "Share",
        "Share content",
        "Leave",
        "Unmute mic",
        "Mute mic",
        "Turn camera on",
        "Turn camera off",
    ]
    private let meetingControlLabelThreshold = 2

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
            logger.debug("Teams process not running (names=\(self.processNames, privacy: .public))")
            return false
        }
        guard let nodes = snapshotProvider.snapshot(bundleIdentifiers: bundleIdentifiers, processNames: processNames) else {
            AccessibilityTrustDiagnostics.logNotTrusted(logger: logger, context: "teams snapshot")
            logger.debug("AX snapshot unavailable (not authorized or failed)")
            return false
        }
        if nodes.isEmpty {
            logger.debug("Teams AX snapshot empty (process running)")
        }

        var matchedDomIdentifiers = Set<String>()
        var matchedIdentifiers = Set<String>()
        var matchedToolbarLabels = Set<String>()
        var matchedMeetingControlLabels = Set<String>()
        var roleCount = 0
        var labelCount = 0
        var domIdentifierCount = 0
        var identifierCount = 0
        var toolbarRoleCount = 0
        let pids = Set(nodes.compactMap { $0.pid }).sorted()

        for node in nodes {
            if node.role != nil { roleCount += 1 }
            if node.label != nil { labelCount += 1 }
            if node.domIdentifier != nil { domIdentifierCount += 1 }
            if node.identifier != nil { identifierCount += 1 }
            if let domIdentifier = node.domIdentifier, domIdentifiers.contains(domIdentifier) {
                matchedDomIdentifiers.insert(domIdentifier)
            }
            if let identifier = node.identifier, domIdentifiers.contains(identifier) {
                matchedIdentifiers.insert(identifier)
            }
            if let role = node.role, role == "AXToolbar" {
                toolbarRoleCount += 1
            }
            if let label = node.label {
                if toolbarLabels.contains(label) {
                    matchedToolbarLabels.insert(label)
                }
                if let role = node.role, role == "AXButton", meetingControlLabels.contains(label) {
                    matchedMeetingControlLabels.insert(label)
                }
            }
        }

        logger.debug(
            "Teams AX snapshot: nodes=\(nodes.count) pids=\(pids, privacy: .public) role=\(roleCount) label=\(labelCount) domId=\(domIdentifierCount) identifier=\(identifierCount) toolbarRole=\(toolbarRoleCount) domMatches=\(matchedDomIdentifiers.sorted(), privacy: .public) identifierMatches=\(matchedIdentifiers.sorted(), privacy: .public) toolbarMatches=\(matchedToolbarLabels.sorted(), privacy: .public) meetingControlMatches=\(matchedMeetingControlLabels.sorted(), privacy: .public)"
        )

        if !matchedDomIdentifiers.isEmpty || !matchedIdentifiers.isEmpty {
            logger.debug("Teams meeting detected via identifiers")
            return true
        }

        if !matchedToolbarLabels.isEmpty {
            logger.debug("Teams meeting detected via toolbar label fallback")
            return true
        }

        if matchedMeetingControlLabels.count >= meetingControlLabelThreshold {
            logger.debug(
                "Teams meeting detected via meeting control labels (matched=\(matchedMeetingControlLabels.sorted(), privacy: .public), threshold=\(self.meetingControlLabelThreshold))"
            )
            return true
        }

        logger.debug("Teams meeting not detected (no matching AX controls)")
        return false
    }
}
