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

    func turnOnRed(userId: String) {
        post(["userId": userId, "actionFields": LuxaforColor.red.remoteActionFields])
    }

    func turnOnYellow(userId: String) {
        post(["userId": userId, "actionFields": LuxaforColor.orange.remoteActionFields])
    }

    func turnOff(userId: String) {
        post(["userId": userId, "actionFields": LuxaforColor.off.remoteActionFields])
    }

    private func post(_ body: [String: Any]) {
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
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
