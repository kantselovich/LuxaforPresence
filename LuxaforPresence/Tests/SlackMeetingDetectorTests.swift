import XCTest
@testable import LuxaforPresence

final class SlackMeetingDetectorTests: XCTestCase {
    func test_isMeetingActive_returnsTrue_whenHuddlesToolbarAndControlPresent() {
        let provider = FakeAXSnapshotProvider()
        provider.nextSnapshot = [
            AXNodeSnapshot(
                role: "AXGroup",
                roleDescription: "group",
                label: "Huddle: test",
                placeholder: nil,
                domIdentifier: nil,
                identifier: nil,
                pid: nil
            ),
            AXNodeSnapshot(
                role: "AXCheckBox",
                roleDescription: "checkbox",
                label: "Share your screen",
                placeholder: nil,
                domIdentifier: nil,
                identifier: nil,
                pid: nil
            ),
        ]
        let detector = SlackMeetingDetector(snapshotProvider: provider, isProcessRunning: { _ in true })

        XCTAssertTrue(detector.isMeetingActive())
    }

    func test_isMeetingActive_returnsFalse_whenAXUnavailable() {
        let provider = FakeAXSnapshotProvider()
        provider.nextSnapshot = nil
        let detector = SlackMeetingDetector(snapshotProvider: provider, isProcessRunning: { _ in true })

        XCTAssertFalse(detector.isMeetingActive())
    }

    func test_isMeetingActive_returnsFalse_whenToolbarMissing() {
        let provider = FakeAXSnapshotProvider()
        provider.nextSnapshot = [
            AXNodeSnapshot(
                role: "AXCheckBox",
                roleDescription: "checkbox",
                label: "Share your screen",
                placeholder: nil,
                domIdentifier: nil,
                identifier: nil,
                pid: nil
            ),
        ]
        let detector = SlackMeetingDetector(snapshotProvider: provider, isProcessRunning: { _ in true })

        XCTAssertFalse(detector.isMeetingActive())
    }
}

private final class FakeAXSnapshotProvider: AXSnapshotProviding {
    var nextSnapshot: [AXNodeSnapshot]?

    func snapshot(bundleIdentifiers: [String], processNames: [String]) -> [AXNodeSnapshot]? {
        nextSnapshot
    }
}
