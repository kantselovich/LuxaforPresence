import AppKit
import OSLog

final class FrontmostAppSignal {
    private let logger = Logger(subsystem: "com.example.LuxaforPresence", category: "FrontmostAppSignal")

    func isFrontmostIn(allowlist: Set<String>) -> Bool {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            logger.error("Frontmost application unavailable")
            return false
        }
        guard let bid = app.bundleIdentifier else {
            logger.error("Frontmost application bundle identifier missing")
            return false
        }
        let result = allowlist.contains(bid)
        logger.debug("Frontmost app \(bid, privacy: .public) allowlisted? \(result)")
        return result
    }
}
