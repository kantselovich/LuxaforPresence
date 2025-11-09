import Foundation

protocol LuxaforClientProtocol {
    func turnOnRed(userId: String)
    func turnOff(userId: String)
}

final class LuxaforClient: LuxaforClientProtocol {
    private let endpoint = URL(string: "https://api.luxafor.com/webhook/v1/actions/solid_color")!
    private let session = URLSession(configuration: .ephemeral)

    func turnOnRed(userId: String) {
        post(["userId": userId, "actionFields": ["color": "red"]])
    }

    func turnOff(userId: String) {
        post(["userId": userId, "actionFields": ["color": "custom", "custom_color": "000000"]])
    }

    private func post(_ body: [String: Any]) {
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        let task = session.dataTask(with: req) { data, resp, err in
            // Optional: log errors, backoff, retry on 5xx
        }
        task.resume()
    }
}
