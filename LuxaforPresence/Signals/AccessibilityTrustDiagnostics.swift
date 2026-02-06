import Foundation
import OSLog

struct AccessibilityTrustDiagnostics {
    static func currentBundleIdentifier() -> String {
        Bundle.main.bundleIdentifier ?? "unknown"
    }

    static func currentBundlePath() -> String {
        Bundle.main.bundlePath
    }

    static func currentExecutablePath() -> String {
        Bundle.main.executableURL?.path ?? "unknown"
    }

    static func currentProcessIdentifier() -> Int {
        Int(ProcessInfo.processInfo.processIdentifier)
    }

    static func logNotTrusted(logger: Logger, context: String) {
        let bundleId = currentBundleIdentifier()
        let bundlePath = currentBundlePath()
        let executablePath = currentExecutablePath()
        let pid = currentProcessIdentifier()
        logger.info(
            "AX not trusted: context=\(context, privacy: .public) bundleId=\(bundleId, privacy: .public) bundlePath=\(bundlePath, privacy: .public) executablePath=\(executablePath, privacy: .public) pid=\(pid, privacy: .public)"
        )
    }
}
