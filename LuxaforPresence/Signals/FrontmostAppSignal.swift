import AppKit

final class FrontmostAppSignal {
    func isFrontmostIn(allowlist: Set<String>) -> Bool {
        guard let app = NSWorkspace.shared.frontmostApplication else { return false }
        guard let bid = app.bundleIdentifier else { return false }
        return allowlist.contains(bid)
    }
}
