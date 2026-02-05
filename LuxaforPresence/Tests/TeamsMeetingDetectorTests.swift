import XCTest
@testable import LuxaforPresence

final class TeamsMeetingDetectorTests: XCTestCase {
    func test_isMeetingActive_returnsTrue_whenDomIdentifierPresent() {
        let provider = FakeAXSnapshotProvider()
        provider.nextSnapshot = [
            AXNodeSnapshot(
                role: "AXButton",
                roleDescription: "button",
                label: "Unmute mic",
                placeholder: nil,
                domIdentifier: "microphone-button"
            ),
        ]
        let detector = TeamsMeetingDetector(snapshotProvider: provider, isProcessRunning: { _ in true })

        XCTAssertTrue(detector.isMeetingActive())
    }

    func test_isMeetingActive_returnsTrue_whenToolbarLabelPresent() {
        let provider = FakeAXSnapshotProvider()
        provider.nextSnapshot = [
            AXNodeSnapshot(
                role: "AXToolbar",
                roleDescription: "toolbar",
                label: "Calling controls",
                placeholder: nil,
                domIdentifier: nil
            ),
        ]
        let detector = TeamsMeetingDetector(snapshotProvider: provider, isProcessRunning: { _ in true })

        XCTAssertTrue(detector.isMeetingActive())
    }

    func test_isMeetingActive_returnsFalse_whenNoMeetingIndicators() {
        let provider = FakeAXSnapshotProvider()
        provider.nextSnapshot = [
            AXNodeSnapshot(
                role: "AXButton",
                roleDescription: "button",
                label: "Random button",
                placeholder: nil,
                domIdentifier: "something-else"
            ),
        ]
        let detector = TeamsMeetingDetector(snapshotProvider: provider, isProcessRunning: { _ in false })

        XCTAssertFalse(detector.isMeetingActive())
    }
}

private final class FakeAXSnapshotProvider: AXSnapshotProviding {
    var nextSnapshot: [AXNodeSnapshot]?

    func snapshot(bundleIdentifiers: [String], processNames: [String]) -> [AXNodeSnapshot]? {
        nextSnapshot
    }
}
