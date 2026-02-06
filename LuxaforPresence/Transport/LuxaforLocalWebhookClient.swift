import Foundation
import OSLog

final class LuxaforLocalWebhookClient: LuxaforClientProtocol {
    private let baseURL: URL
    private let token: String
    private let session: URLSession
    private let logger = Logger(subsystem: "com.example.LuxaforPresence", category: "LuxaforLocalWebhookClient")
    private let maxAttempts = 3

    init(baseURL: String, token: String, session: URLSession = URLSession(configuration: .ephemeral)) {
        self.baseURL = URL(string: baseURL)?.standardized ?? URL(string: "http://127.0.0.1:5383")!
        self.token = token
        self.session = session
    }

    func turnOnRed(userId: String) {
        postColor(.red)
    }

    func turnOnYellow(userId: String) {
        postColor(.orange)
    }

    func turnOff(userId: String) {
        postColor(.off)
    }

    private func postColor(_ color: LuxaforColor) {
        postColor(color, attempt: 1)
    }

    private func postColor(_ color: LuxaforColor, attempt: Int) {
        guard let url = URL(string: "color", relativeTo: baseURL) else {
            logger.error("Failed to build local webhook URL for color endpoint")
            return
        }
        logger.debug("Sending local webhook color \(color.localHex, privacy: .public) attempt \(attempt, privacy: .public) to \(url.absoluteString, privacy: .public)")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["color": color.localHex])

        let task = session.dataTask(with: req) { _, resp, err in
            if let err = err {
                self.logger.error("Local webhook request failed on attempt \(attempt, privacy: .public): \(err.localizedDescription, privacy: .public)")
                self.retryIfNeeded(color, attempt: attempt)
                return
            }
            if let http = resp as? HTTPURLResponse {
                if http.statusCode != 200 {
                    self.logger.error("Local webhook returned status \(http.statusCode, privacy: .public) on attempt \(attempt, privacy: .public)")
                    self.retryIfNeeded(color, attempt: attempt)
                } else {
                    self.logger.debug("Local webhook succeeded for color \(color.localHex, privacy: .public) on attempt \(attempt, privacy: .public)")
                }
            } else {
                self.logger.error("Local webhook missing HTTP response on attempt \(attempt, privacy: .public)")
                self.retryIfNeeded(color, attempt: attempt)
            }
        }
        task.resume()
    }

    private func retryIfNeeded(_ color: LuxaforColor, attempt: Int) {
        guard attempt < maxAttempts else {
            logger.error("Local webhook giving up after \(attempt, privacy: .public) attempts for color \(color.localHex, privacy: .public)")
            return
        }
        let delaySeconds = retryDelaySeconds(for: attempt)
        logger.debug("Scheduling retry \(attempt + 1, privacy: .public) in \(delaySeconds, privacy: .public)s for color \(color.localHex, privacy: .public)")
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + delaySeconds) {
            self.postColor(color, attempt: attempt + 1)
        }
    }

    private func retryDelaySeconds(for attempt: Int) -> Double {
        switch attempt {
        case 1: return 0.2
        case 2: return 0.5
        default: return 1.0
        }
    }
}
