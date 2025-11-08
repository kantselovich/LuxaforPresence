import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var timer: Timer?
    private let engine = PresenceEngine()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
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

        timer = Timer.scheduledTimer(withTimeInterval: engine.config.pollInterval, repeats: true) { [weak self] _ in
            self?.engine.tick()
        }
    }

    private func updateStatusIcon(_ state: PresenceState) {
        let iconName: String = {
            switch state {
            case .inMeeting: return "StatusIconOn"   // red dot
            case .notMeeting: return "StatusIconOff" // hollow/gray
            case .unknown: return "StatusIconIdle"
            }
        }()
        statusItem.button?.image = NSImage(named: iconName)
        statusItem.button?.image?.isTemplate = true
        statusItem.button?.toolTip = "Luxafor: \(state.rawValue)"
    }

    @objc private func forceOn()  { engine.force(.inMeeting) }
    @objc private func forceOff() { engine.force(.notMeeting) }
    @objc private func openPrefs() { /* simple NSAlert or NSPanel for userId etc. */ }
    @objc private func quit() { NSApp.terminate(nil) }
}
