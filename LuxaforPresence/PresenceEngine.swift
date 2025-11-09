import Foundation
import OSLog

final class PresenceEngine {
    struct Config {
        var userId: String
        var pollInterval: TimeInterval
        var meetingBundles: Set<String>
        var useCalendar: Bool
        var debugAssumeFrontmostImpliesMic: Bool
        private let logger = Logger(subsystem: "com.example.LuxaforPresence", category: "Config")

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
            debugAssumeFrontmostImpliesMic = false

            // Try to load from user's config directory first
            let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?.appendingPathComponent("LuxaforPresence/config.plist")
            let dotConfigURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config/LuxaforPresence/config.plist")
            let candidateURLs = [dotConfigURL, appSupportURL].compactMap { $0 }

            if let userConfigURL = candidateURLs.first(where: { FileManager.default.fileExists(atPath: $0.path) }),
               let userConfig = NSDictionary(contentsOf: userConfigURL) as? [String: Any] {
                logger.log("Loaded config from user path at \(userConfigURL.path(percentEncoded: false), privacy: .public)")
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
                if let debugFlag = userConfig["debugAssumeFrontmostImpliesMic"] as? Bool {
                    debugAssumeFrontmostImpliesMic = debugFlag
                }
            } else if let bundledConfigURL = Bundle.main.url(forResource: "config", withExtension: "plist"),
                      let bundledConfig = NSDictionary(contentsOf: bundledConfigURL) as? [String: Any] {
                logger.log("Loaded config from bundled resource at \(bundledConfigURL.path, privacy: .public)")
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
                if let debugFlag = bundledConfig["debugAssumeFrontmostImpliesMic"] as? Bool {
                    debugAssumeFrontmostImpliesMic = debugFlag
                }
            } else {
                logger.error("No config file found; using default hard-coded values")
            }
            let finalizedPollInterval = pollInterval
            let finalizedBundleCount = meetingBundles.count
            let finalizedUseCalendar = useCalendar
            let finalizedDebugFlag = debugAssumeFrontmostImpliesMic
            logger.log("Config initialized: pollInterval \(finalizedPollInterval, privacy: .public)s, meeting bundles count \(finalizedBundleCount, privacy: .public), useCalendar \(finalizedUseCalendar, privacy: .public), debugAssumeFrontmostImpliesMic \(finalizedDebugFlag)")
        }
    }

    let config: Config
    var onStateChange: ((PresenceState) -> Void)?

    private let micCam: MicCamSignalProtocol
    private let frontApp: FrontmostAppSignalProtocol
    private let calendar: CalendarSignalProtocol
    private let luxafor: LuxaforClientProtocol
    private let logger = Logger(subsystem: "com.example.LuxaforPresence", category: "PresenceEngine")
    private var lastState: PresenceState = .unknown
    private var forcedState: PresenceState?

    init(
        config: Config = Config(),
        micCam: MicCamSignalProtocol = MicCamSignal(),
        frontApp: FrontmostAppSignalProtocol = FrontmostAppSignal(),
        calendar: CalendarSignalProtocol = CalendarSignal(),
        luxafor: LuxaforClientProtocol = LuxaforClient()
    ) {
        self.config = config
        self.micCam = micCam
        self.frontApp = frontApp
        self.calendar = calendar
        self.luxafor = luxafor
    }

    func prepare() {
        micCam.requestAccessIfNeeded()

        guard config.useCalendar else {
            logger.debug("Calendar disabled in config; skipping access request")
            return
        }
        calendar.requestAccess { granted in
            if granted {
                self.logger.log("Calendar access granted; calendar signal active")
            } else {
                self.logger.error("Calendar access denied; calendar signal inactive")
            }
        }
    }

    func force(_ state: PresenceState) {
        forcedState = state
        logger.log("Force invoked; new forced state \(state.rawValue, privacy: .public)")
        apply(state)
    }

    func tick() {
        logger.debug("Tick start; forced state \(String(describing: self.forcedState), privacy: .public)")
        if let s = self.forcedState {
            logger.debug("Forced state active; bypassing signals")
            apply(s)
            return
        }

        let isMeetingApp = frontApp.isFrontmostIn(allowlist: config.meetingBundles)
        let debugForcingMic = config.debugAssumeFrontmostImpliesMic && isMeetingApp
        let micOrCam = debugForcingMic ? true : micCam.anyInUse()
        if debugForcingMic {
            logger.debug("Debug flag forcing mic/cam true because frontmost app is allowlisted")
        }
        var eventOK = false
        if config.useCalendar { eventOK = calendar.hasOngoingMeetingEvent() }

        let newState: PresenceState =
            (micOrCam && (isMeetingApp || eventOK)) ? .inMeeting : .notMeeting

        logger.debug("Signals -> mic/cam: \(micOrCam), frontmost meeting: \(isMeetingApp), calendar: \(eventOK)")
        logger.log("Proposed state \(newState.rawValue, privacy: .public) (previous \(self.lastState.rawValue, privacy: .public))")

        if newState != lastState {
            apply(newState)
        } else {
            logger.debug("State unchanged; no Luxafor update")
        }
    }

    private func apply(_ state: PresenceState) {
        lastState = state
        onStateChange?(state)
        logger.log("Applying state \(state.rawValue, privacy: .public)")
        switch state {
        case .inMeeting:  luxafor.turnOnRed(userId: config.userId)
        case .notMeeting: luxafor.turnOff(userId: config.userId)
        case .unknown: break
        }
    }
}
