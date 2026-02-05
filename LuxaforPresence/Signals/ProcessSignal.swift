import AppKit

enum ProcessSignal {
    static func isRunning(executableNames: [String]) -> Bool {
        guard !executableNames.isEmpty else { return false }
        let normalized = Set(executableNames.map { $0.lowercased() })
        return NSWorkspace.shared.runningApplications.contains { app in
            if let name = app.localizedName?.lowercased(), normalized.contains(name) {
                return true
            }
            if let exe = app.executableURL?.lastPathComponent.lowercased(), normalized.contains(exe) {
                return true
            }
            if let bundle = app.bundleIdentifier?.lowercased(), normalized.contains(bundle) {
                return true
            }
            return false
        }
    }
}
