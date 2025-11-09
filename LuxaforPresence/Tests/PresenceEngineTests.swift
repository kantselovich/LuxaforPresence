import XCTest
@testable import LuxaforPresence

final class PresenceEngineTests: XCTestCase {
    func testTick_transitionsToInMeeting_whenMicAndFrontAppTrue() {
        var config = PresenceEngine.Config()
        config.useCalendar = false
        let mic = FakeMicCamSignal()
        mic.nextValue = true
        let front = FakeFrontmostAppSignal()
        front.isMeetingApp = true
        let calendar = FakeCalendarSignal()
        let lux = FakeLuxaforClient()
        let engine = PresenceEngine(config: config, micCam: mic, frontApp: front, calendar: calendar, luxafor: lux)

        engine.tick()

        XCTAssertEqual(lux.actions, [.on(config.userId)])
    }

    func testTick_usesDebugFlagToAssumeMicActivity() {
        var config = PresenceEngine.Config()
        config.useCalendar = false
        config.debugAssumeFrontmostImpliesMic = true
        let mic = FakeMicCamSignal()
        mic.nextValue = false
        let front = FakeFrontmostAppSignal()
        front.isMeetingApp = true
        let calendar = FakeCalendarSignal()
        let lux = FakeLuxaforClient()
        let engine = PresenceEngine(config: config, micCam: mic, frontApp: front, calendar: calendar, luxafor: lux)

        engine.tick()

        XCTAssertEqual(lux.actions, [.on(config.userId)])
    }

    func testForceBypassesSignalsUntilChanged() {
        var config = PresenceEngine.Config()
        let mic = FakeMicCamSignal()
        mic.nextValue = true
        let front = FakeFrontmostAppSignal()
        front.isMeetingApp = true
        let calendar = FakeCalendarSignal()
        let lux = FakeLuxaforClient()
        let engine = PresenceEngine(config: config, micCam: mic, frontApp: front, calendar: calendar, luxafor: lux)

        engine.force(.notMeeting)
        mic.nextValue = true
        front.isMeetingApp = true
        engine.tick()

        XCTAssertEqual(lux.actions, [.off(config.userId), .off(config.userId)])
    }
}

// MARK: - Test Doubles

private final class FakeMicCamSignal: MicCamSignalProtocol {
    var nextValue = false
    func requestAccessIfNeeded() {}
    func anyInUse() -> Bool { nextValue }
}

private final class FakeFrontmostAppSignal: FrontmostAppSignalProtocol {
    var isMeetingApp = false
    func isFrontmostIn(allowlist: Set<String>) -> Bool { isMeetingApp }
}

private final class FakeCalendarSignal: CalendarSignalProtocol {
    var granted = true
    var ongoingMeeting = false
    func requestAccess(completion: @escaping (Bool) -> Void) { completion(granted) }
    func hasOngoingMeetingEvent() -> Bool { ongoingMeeting }
}

private final class FakeLuxaforClient: LuxaforClientProtocol {
    enum Action: Equatable {
        case on(String)
        case off(String)
    }

    private(set) var actions: [Action] = []

    func turnOnRed(userId: String) {
        actions.append(.on(userId))
    }

    func turnOff(userId: String) {
        actions.append(.off(userId))
    }
}
