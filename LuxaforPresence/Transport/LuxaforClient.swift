import Foundation
import OSLog

protocol LuxaforClientProtocol {
    func turnOnRed(userId: String)
    func turnOnYellow(userId: String)
    func turnOff(userId: String)
}

final class LuxaforClient: LuxaforClientProtocol {
    private let endpoint = URL(string: "https://api.luxafor.com/webhook/v1/actions/solid_color")!
    private let session = URLSession(configuration: .ephemeral)
    private let logger = Logger(subsystem: "com.example.LuxaforPresence", category: "LuxaforClient")
    private let maxAttempts = 3

    func turnOnRed(userId: String) {
        post(["userId": userId, "actionFields": LuxaforColor.red.remoteActionFields], action: "red", attempt: 1)
    }

    func turnOnYellow(userId: String) {
        post(["userId": userId, "actionFields": LuxaforColor.orange.remoteActionFields], action: "orange", attempt: 1)
    }

    func turnOff(userId: String) {
        post(["userId": userId, "actionFields": LuxaforColor.off.remoteActionFields], action: "off", attempt: 1)
    }

    private func post(_ body: [String: Any], action: String, attempt: Int) {
        logger.debug("Sending remote webhook action \(action, privacy: .public) attempt \(attempt, privacy: .public) to \(self.endpoint.absoluteString, privacy: .public)")
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        let task = session.dataTask(with: req) { _, resp, err in
            if let err = err {
                self.logger.error("Remote webhook request failed on attempt \(attempt, privacy: .public): \(err.localizedDescription, privacy: .public)")
                self.retryIfNeeded(body, action: action, attempt: attempt)
                return
            }
            if let http = resp as? HTTPURLResponse {
                if http.statusCode != 200 {
                    self.logger.error("Remote webhook returned status \(http.statusCode, privacy: .public) on attempt \(attempt, privacy: .public)")
                    self.retryIfNeeded(body, action: action, attempt: attempt)
                } else {
                    self.logger.debug("Remote webhook succeeded for action \(action, privacy: .public) on attempt \(attempt, privacy: .public)")
                }
            } else {
                self.logger.error("Remote webhook missing HTTP response on attempt \(attempt, privacy: .public)")
                self.retryIfNeeded(body, action: action, attempt: attempt)
            }
        }
        task.resume()
    }

    private func retryIfNeeded(_ body: [String: Any], action: String, attempt: Int) {
        guard attempt < maxAttempts else {
            logger.error("Remote webhook giving up after \(attempt, privacy: .public) attempts for action \(action, privacy: .public)")
            return
        }
        let delaySeconds = retryDelaySeconds(for: attempt)
        logger.debug("Scheduling retry \(attempt + 1, privacy: .public) in \(delaySeconds, privacy: .public)s for action \(action, privacy: .public)")
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + delaySeconds) {
            self.post(body, action: action, attempt: attempt + 1)
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
