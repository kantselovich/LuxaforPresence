import AppKit
import OSLog

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var timer: Timer?
    private let engine = PresenceEngine()
    private let logger = Logger(subsystem: "com.example.LuxaforPresence", category: "AppDelegate")

    func applicationDidFinishLaunching(_ notification: Notification) {
        logger.log("Application did finish launching")
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if statusItem.button == nil {
            logger.error("Status item button is nil; status item will not render")
        }
        updateStatusIcon(.unknown)

        let menu = NSMenu()
        menu.addItem(withTitle: "Force ON (Red)", action: #selector(forceOn), keyEquivalent: "")
        menu.addItem(withTitle: "Force OFF", action: #selector(forceOff), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Preferences…", action: #selector(openPrefs), keyEquivalent: ",")
        menu.addItem(withTitle: "Quit", action: #selector(quit), keyEquivalent: "q")
        statusItem.menu = menu

        engine.onStateChange = { [weak self] state in
            DispatchQueue.main.async { self?.updateStatusIcon(state) }
        }
        engine.prepare()

        timer = Timer.scheduledTimer(withTimeInterval: engine.config.pollInterval, repeats: true) { [weak self] _ in
            self?.logger.debug("Timer fired; invoking PresenceEngine.tick()")
            self?.engine.tick()
        }
        RunLoop.main.add(timer!, forMode: .common)
        self.logger.log("Scheduled PresenceEngine timer at \(self.engine.config.pollInterval, privacy: .public)s intervals")
    }

    private func updateStatusIcon(_ state: PresenceState) {
        let icon: NSImage? = {
            switch state {
            case .inMeeting: return StatusIconName.on.image()
            case .notMeeting: return StatusIconName.off.image()
            case .unknown: return StatusIconName.idle.image()
            }
        }()
        statusItem.button?.image = icon
        statusItem.button?.toolTip = "Luxafor: \(state.rawValue)"
        logger.debug("Status icon updated to state \(state.rawValue, privacy: .public)")
    }

    @objc private func forceOn()  { engine.force(.inMeeting) }
    @objc private func forceOff() { engine.force(.notMeeting) }
    @objc private func openPrefs() { /* simple NSAlert or NSPanel for userId etc. */ }
    @objc private func quit() { NSApp.terminate(nil) }
}
