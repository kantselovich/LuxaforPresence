import AppKit
import ApplicationServices
import OSLog

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var timer: Timer?
    private let engine = PresenceEngine()
    private let logger = Logger(subsystem: "com.example.LuxaforPresence", category: "AppDelegate")
    private let accessibilityPromptShownKey = "AccessibilityPromptShown"
    private let accessibilityPromptedExecutablePathKey = "AccessibilityPromptedExecutablePath"

    func applicationDidFinishLaunching(_ notification: Notification) {
        logger.log("Application did finish launching")
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if statusItem.button == nil {
            logger.error("Status item button is nil; status item will not render")
        }
        updateStatusIcon(.unknown)

        let menu = NSMenu()
        menu.addItem(withTitle: "Force ON (Red)", action: #selector(forceOn), keyEquivalent: "o")
        menu.addItem(withTitle: "Force OFF", action: #selector(forceOff), keyEquivalent: "f")
        menu.addItem(withTitle: "Auto Detect", action: #selector(forceClear), keyEquivalent: "a")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Preferences…", action: #selector(openPrefs), keyEquivalent: ",")
        menu.addItem(withTitle: "Quit", action: #selector(quit), keyEquivalent: "q")
        statusItem.menu = menu

        engine.onStateChange = { [weak self] state in
            DispatchQueue.main.async { self?.updateStatusIcon(state) }
        }
        engine.prepare()
        promptForAccessibilityIfNeeded()

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
            case .inMeetingSilent: return StatusIconName.on.image()
            case .notMeeting: return StatusIconName.off.image()
            case .unknown: return StatusIconName.idle.image()
            }
        }()
        statusItem.button?.image = icon
        statusItem.button?.toolTip = "Luxafor: \(state.rawValue)"
        logger.debug("Status icon updated to state \(state.rawValue, privacy: .public)")
    }

    private func promptForAccessibilityIfNeeded() {
        guard !AXIsProcessTrusted() else { return }
        AccessibilityTrustDiagnostics.logNotTrusted(logger: logger, context: "startup")

        let executablePath = AccessibilityTrustDiagnostics.currentExecutablePath()
        let lastPromptedPath = UserDefaults.standard.string(forKey: accessibilityPromptedExecutablePathKey)
        if UserDefaults.standard.bool(forKey: accessibilityPromptShownKey), lastPromptedPath == executablePath {
            AccessibilityTrustDiagnostics.logNotTrusted(logger: logger, context: "prompt suppressed; already shown for this executable")
            return
        }

        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        UserDefaults.standard.set(true, forKey: accessibilityPromptShownKey)
        UserDefaults.standard.set(executablePath, forKey: accessibilityPromptedExecutablePathKey)

        let alert = NSAlert()
        alert.messageText = "Enable Accessibility Access"
        let appPath = AccessibilityTrustDiagnostics.currentBundlePath()
        alert.informativeText = """
LuxaforPresence needs Accessibility access to read meeting UI controls.

Running app path:
\(appPath)

Open System Settings → Privacy & Security → Accessibility, then enable this app.
"""
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "OK")
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            self.openAccessibilitySettings()
        }
        logger.info("Prompted for Accessibility access")
    }

    private func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            logger.error("Failed to build Accessibility settings URL")
            return
        }
        NSWorkspace.shared.open(url)
        logger.info("Opened Accessibility settings")
    }

    @objc private func forceOn()  { engine.force(.inMeeting) }
    @objc private func forceOff() { engine.force(.notMeeting) }
    @objc private func forceClear() { engine.clear(.unknown) }
    @objc private func openPrefs() { /* simple NSAlert or NSPanel for remoteWebhookUserId etc. */ }
    @objc private func quit() { NSApp.terminate(nil) }
}
