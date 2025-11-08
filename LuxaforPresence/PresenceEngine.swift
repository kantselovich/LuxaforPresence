import Foundation

final class PresenceEngine {
    struct Config {
        var userId: String
        var pollInterval: TimeInterval
        var meetingBundles: Set<String>
        var useCalendar: Bool

        init() {
            // Default values
            userId = "YOUR_USER_ID_HERE" // Fallback default
            pollInterval = 2.0
            meetingBundles = [
                "us.zoom.xos",
                "com.microsoft.teams2",
                "com.microsoft.teams",
                "com.cisco.webex.meetingapp",
                "com.slack.slack",
                "com.google.Chrome",
                "com.apple.Safari"
            ]
            useCalendar = false

            // Try to load from user's config directory first
            if let userConfigURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?.appendingPathComponent("LuxaforPresence/config.plist"),
               let userConfig = NSDictionary(contentsOf: userConfigURL) as? [String: Any] {
                if let id = userConfig["userId"] as? String {
                    userId = id
                }
                if let interval = userConfig["pollInterval"] as? TimeInterval {
                    pollInterval = interval
                }
                if let bundles = userConfig["meetingBundles"] as? [String] {
                    meetingBundles = Set(bundles)
                }
                if let useCal = userConfig["useCalendar"] as? Bool {
                    useCalendar = useCal
                }
            } else if let bundledConfigURL = Bundle.main.url(forResource: "config", withExtension: "plist"),
                      let bundledConfig = NSDictionary(contentsOf: bundledConfigURL) as? [String: Any] {
                // Fallback to bundled config
                if let id = bundledConfig["userId"] as? String {
                    userId = id
                }
                if let interval = bundledConfig["pollInterval"] as? TimeInterval {
                    pollInterval = interval
                }
                if let bundles = bundledConfig["meetingBundles"] as? [String] {
                    meetingBundles = Set(bundles)
                }
                if let useCal = bundledConfig["useCalendar"] as? Bool {
                    useCalendar = useCal
                }
            }
        }
    }

    var config = Config()
    var onStateChange: ((PresenceState) -> Void)?

    private let micCam = MicCamSignal()
    private let frontApp = FrontmostAppSignal()
    private let calendar = CalendarSignal()
    private let luxafor = LuxaforClient()
    private var lastState: PresenceState = .unknown
    private var forcedState: PresenceState?

    func force(_ state: PresenceState) {
        forcedState = state
        apply(state)
    }

    func tick() {
        if let s = forcedState { apply(s); return }

        let micOrCam = micCam.anyInUse()
        let isMeetingApp = frontApp.isFrontmostIn(allowlist: config.meetingBundles)
        var eventOK = false
        if config.useCalendar { eventOK = calendar.hasOngoingMeetingEvent() }

        let newState: PresenceState =
            (micOrCam && (isMeetingApp || eventOK)) ? .inMeeting : .notMeeting

        if newState != lastState {
            apply(newState)
        }
    }

    private func apply(_ state: PresenceState) {
        lastState = state
        onStateChange?(state)
        switch state {
        case .inMeeting:  luxafor.turnOnRed(userId: config.userId)
        case .notMeeting: luxafor.turnOff(userId: config.userId)
        case .unknown: break
        }
    }
}
