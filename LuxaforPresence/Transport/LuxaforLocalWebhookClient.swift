import Foundation
import OSLog

final class LuxaforLocalWebhookClient: LuxaforClientProtocol {
    private let baseURL: URL
    private let token: String
    private let session: URLSession
    private let logger = Logger(subsystem: "com.example.LuxaforPresence", category: "LuxaforLocalWebhookClient")

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
        guard let url = URL(string: "color", relativeTo: baseURL) else {
            logger.error("Failed to build local webhook URL for color endpoint")
            return
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["color": color.localHex])

        let task = session.dataTask(with: req) { _, resp, err in
            if let err = err {
                self.logger.error("Local webhook request failed: \(err.localizedDescription, privacy: .public)")
                return
            }
            if let http = resp as? HTTPURLResponse, http.statusCode != 200 {
                self.logger.error("Local webhook returned status \(http.statusCode, privacy: .public)")
            }
        }
        task.resume()
    }
}
