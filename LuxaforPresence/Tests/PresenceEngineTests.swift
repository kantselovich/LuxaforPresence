import XCTest
@testable import LuxaforPresence

final class PresenceEngineTests: XCTestCase {
    func testTick_transitionsToInMeeting_whenMeetingDetectorActive_andVoiceActive() {
        var config = PresenceEngine.Config()
        config.useCalendar = false
        let mic = FakeMicCamSignal()
        mic.nextMic = true
        let front = FakeFrontmostAppSignal()
        let calendar = FakeCalendarSignal()
        let meetingDetector = FakeMeetingDetector()
        meetingDetector.isActive = true
        let voiceActivity = FakeVoiceActivitySignal()
        voiceActivity.active = true
        let lux = FakeLuxaforClient()
        let engine = PresenceEngine(
            config: config,
            micCam: mic,
            frontApp: front,
            calendar: calendar,
            meetingDetector: meetingDetector,
            voiceActivity: voiceActivity,
            luxafor: lux
        )

        engine.tick()

        XCTAssertEqual(lux.actions, [.on(config.remoteWebhookUserId)])
    }

    func testTick_staysNotMeeting_whenMeetingDetectorInactive_evenIfMicActive() {
        var config = PresenceEngine.Config()
        config.useCalendar = false
        let mic = FakeMicCamSignal()
        mic.nextMic = true
        let front = FakeFrontmostAppSignal()
        let calendar = FakeCalendarSignal()
        let meetingDetector = FakeMeetingDetector()
        meetingDetector.isActive = false
        let lux = FakeLuxaforClient()
        let engine = PresenceEngine(
            config: config,
            micCam: mic,
            frontApp: front,
            calendar: calendar,
            meetingDetector: meetingDetector,
            luxafor: lux
        )

        engine.tick()

        XCTAssertEqual(lux.actions, [.off(config.remoteWebhookUserId)])
    }

    func testTick_transitionsToInMeeting_whenCameraActive_evenIfMeetingDetectorInactive() {
        var config = PresenceEngine.Config()
        config.useCalendar = false
        let mic = FakeMicCamSignal()
        mic.nextCamera = true
        let front = FakeFrontmostAppSignal()
        let calendar = FakeCalendarSignal()
        let meetingDetector = FakeMeetingDetector()
        meetingDetector.isActive = false
        let lux = FakeLuxaforClient()
        let engine = PresenceEngine(
            config: config,
            micCam: mic,
            frontApp: front,
            calendar: calendar,
            meetingDetector: meetingDetector,
            luxafor: lux
        )

        engine.tick()

        XCTAssertEqual(lux.actions, [.on(config.remoteWebhookUserId)])
    }

    func testTick_transitionsToInMeeting_whenCalendarActive_evenIfMeetingDetectorInactive() {
        var config = PresenceEngine.Config()
        config.useCalendar = true
        config.vadEnabled = false
        let mic = FakeMicCamSignal()
        let front = FakeFrontmostAppSignal()
        let calendar = FakeCalendarSignal()
        calendar.ongoingMeeting = true
        let meetingDetector = FakeMeetingDetector()
        meetingDetector.isActive = false
        let lux = FakeLuxaforClient()
        let engine = PresenceEngine(
            config: config,
            micCam: mic,
            frontApp: front,
            calendar: calendar,
            meetingDetector: meetingDetector,
            luxafor: lux
        )

        engine.tick()

        XCTAssertEqual(lux.actions, [.on(config.remoteWebhookUserId)])
    }

    func testTick_usesDebugFlagToAssumeMeetingWhenFrontmostAllowlisted() {
        var config = PresenceEngine.Config()
        config.useCalendar = false
        config.debugAssumeFrontmostImpliesMic = true
        config.vadEnabled = false
        let mic = FakeMicCamSignal()
        let front = FakeFrontmostAppSignal()
        front.isMeetingApp = true
        let calendar = FakeCalendarSignal()
        let meetingDetector = FakeMeetingDetector()
        meetingDetector.isActive = false
        let lux = FakeLuxaforClient()
        let engine = PresenceEngine(
            config: config,
            micCam: mic,
            frontApp: front,
            calendar: calendar,
            meetingDetector: meetingDetector,
            luxafor: lux
        )

        engine.tick()

        XCTAssertEqual(lux.actions, [.on(config.remoteWebhookUserId)])
    }

    func testTick_frontmostAloneDoesNotTriggerMeetingWithoutDebug() {
        var config = PresenceEngine.Config()
        config.useCalendar = false
        let mic = FakeMicCamSignal()
        let front = FakeFrontmostAppSignal()
        front.isMeetingApp = true
        let calendar = FakeCalendarSignal()
        let meetingDetector = FakeMeetingDetector()
        meetingDetector.isActive = false
        let lux = FakeLuxaforClient()
        let engine = PresenceEngine(
            config: config,
            micCam: mic,
            frontApp: front,
            calendar: calendar,
            meetingDetector: meetingDetector,
            luxafor: lux
        )

        engine.tick()

        XCTAssertEqual(lux.actions, [.off(config.remoteWebhookUserId)])
    }

    func testForceBypassesSignalsUntilChanged() {
        let config = PresenceEngine.Config()
        let mic = FakeMicCamSignal()
        mic.nextMic = true
        let front = FakeFrontmostAppSignal()
        front.isMeetingApp = true
        let calendar = FakeCalendarSignal()
        let meetingDetector = FakeMeetingDetector()
        meetingDetector.isActive = true
        let voiceActivity = FakeVoiceActivitySignal()
        voiceActivity.active = true
        let lux = FakeLuxaforClient()
        let engine = PresenceEngine(
            config: config,
            micCam: mic,
            frontApp: front,
            calendar: calendar,
            meetingDetector: meetingDetector,
            voiceActivity: voiceActivity,
            luxafor: lux
        )

        engine.force(.notMeeting)
        mic.nextMic = true
        front.isMeetingApp = true
        engine.tick()

        XCTAssertEqual(lux.actions, [.off(config.remoteWebhookUserId), .off(config.remoteWebhookUserId)])
    }

    func testTick_meetingActiveAndVadSilentBeyondGrace_turnsYellow() {
        var config = PresenceEngine.Config()
        config.useCalendar = false
        config.vadGraceSeconds = 10
        let mic = FakeMicCamSignal()
        let front = FakeFrontmostAppSignal()
        let calendar = FakeCalendarSignal()
        let meetingDetector = FakeMeetingDetector()
        meetingDetector.isActive = true
        let voiceActivity = FakeVoiceActivitySignal()
        voiceActivity.active = false
        let fixedNow = Date()
        voiceActivity.lastActivityDate = fixedNow.addingTimeInterval(-11)
        let lux = FakeLuxaforClient()
        let engine = PresenceEngine(
            config: config,
            micCam: mic,
            frontApp: front,
            calendar: calendar,
            meetingDetector: meetingDetector,
            voiceActivity: voiceActivity,
            luxafor: lux,
            now: { fixedNow }
        )

        engine.tick()

        XCTAssertEqual(lux.actions, [.yellow(config.remoteWebhookUserId)])
    }

    func testTick_meetingActiveAndVadActive_turnsRed() {
        var config = PresenceEngine.Config()
        config.useCalendar = false
        let mic = FakeMicCamSignal()
        let front = FakeFrontmostAppSignal()
        let calendar = FakeCalendarSignal()
        let meetingDetector = FakeMeetingDetector()
        meetingDetector.isActive = true
        let voiceActivity = FakeVoiceActivitySignal()
        voiceActivity.active = true
        voiceActivity.lastActivityDate = Date()
        let lux = FakeLuxaforClient()
        let engine = PresenceEngine(
            config: config,
            micCam: mic,
            frontApp: front,
            calendar: calendar,
            meetingDetector: meetingDetector,
            voiceActivity: voiceActivity,
            luxafor: lux
        )

        engine.tick()

        XCTAssertEqual(lux.actions, [.on(config.remoteWebhookUserId)])
    }

    func testTick_meetingActiveAndVadSilentWithinGrace_turnsRed() {
        var config = PresenceEngine.Config()
        config.useCalendar = false
        config.vadGraceSeconds = 10
        let mic = FakeMicCamSignal()
        let front = FakeFrontmostAppSignal()
        let calendar = FakeCalendarSignal()
        let meetingDetector = FakeMeetingDetector()
        meetingDetector.isActive = true
        let voiceActivity = FakeVoiceActivitySignal()
        voiceActivity.active = false
        let fixedNow = Date()
        voiceActivity.lastActivityDate = fixedNow.addingTimeInterval(-5)
        let lux = FakeLuxaforClient()
        let engine = PresenceEngine(
            config: config,
            micCam: mic,
            frontApp: front,
            calendar: calendar,
            meetingDetector: meetingDetector,
            voiceActivity: voiceActivity,
            luxafor: lux,
            now: { fixedNow }
        )

        engine.tick()

        XCTAssertEqual(lux.actions, [.on(config.remoteWebhookUserId)])
    }

    func testTick_cameraActiveOverridesVadSilent_turnsRed() {
        var config = PresenceEngine.Config()
        config.useCalendar = false
        let mic = FakeMicCamSignal()
        mic.nextCamera = true
        let front = FakeFrontmostAppSignal()
        let calendar = FakeCalendarSignal()
        let meetingDetector = FakeMeetingDetector()
        meetingDetector.isActive = true
        let voiceActivity = FakeVoiceActivitySignal()
        voiceActivity.active = false
        let lux = FakeLuxaforClient()
        let engine = PresenceEngine(
            config: config,
            micCam: mic,
            frontApp: front,
            calendar: calendar,
            meetingDetector: meetingDetector,
            voiceActivity: voiceActivity,
            luxafor: lux
        )

        engine.tick()

        XCTAssertEqual(lux.actions, [.on(config.remoteWebhookUserId)])
    }
}

// MARK: - Test Doubles

private final class FakeMicCamSignal: MicCamSignalProtocol {
    var nextMic = false
    var nextCamera = false
    func requestAccessIfNeeded() {}
    func isMicrophoneInUse() -> Bool { nextMic }
    func isCameraInUse() -> Bool { nextCamera }
    func anyInUse() -> Bool { nextMic || nextCamera }
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

private final class FakeMeetingDetector: MeetingDetectorProtocol {
    var name: String { "Fake" }
    var isActive = false
    func isMeetingActive() -> Bool { isActive }
}

private final class FakeLuxaforClient: LuxaforClientProtocol {
    enum Action: Equatable {
        case on(String)
        case yellow(String)
        case off(String)
    }

    private(set) var actions: [Action] = []

    func turnOnRed(userId: String) {
        actions.append(.on(userId))
    }

    func turnOnYellow(userId: String) {
        actions.append(.yellow(userId))
    }

    func turnOff(userId: String) {
        actions.append(.off(userId))
    }
}

private final class FakeVoiceActivitySignal: VoiceActivitySignalProtocol {
    var active = false
    var lastActivityDate: Date?
    func requestAccessIfNeeded() {}
    func isVoiceActive() -> Bool { active }
    var lastVoiceActivityDate: Date? { lastActivityDate }
}
