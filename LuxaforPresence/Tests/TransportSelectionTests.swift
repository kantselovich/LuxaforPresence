import XCTest
@testable import LuxaforPresence

final class TransportSelectionTests: XCTestCase {
    func testMakeLuxaforClient_usesLocalClientWhenConfigured() {
        var config = PresenceEngine.Config()
        config.transportMode = .local
        config.localWebhookBaseUrl = "http://127.0.0.1:5383"
        config.localWebhookToken = "test"

        let client = config.makeLuxaforClient()

        XCTAssertTrue(client is LuxaforLocalWebhookClient)
    }

    func testMakeLuxaforClient_usesRemoteClientWhenConfigured() {
        var config = PresenceEngine.Config()
        config.transportMode = .remote
        config.remoteWebhookUserId = "user"

        let client = config.makeLuxaforClient()

        XCTAssertTrue(client is LuxaforClient)
    }
}
